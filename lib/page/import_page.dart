import 'dart:async';
import 'dart:io';
import 'package:coast_audio/coast_audio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/player/player_isolate.dart';
import 'package:eq_trainer/widget/editor_control_view.dart';
import 'package:eq_trainer/widget/common/MaxWidthCenterBox.dart';
//import 'package:eq_trainer/model/error.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final importPageState =
      ValueNotifier<ImportPageState>(ImportPageState.loading);
  final clipDivProvider = ImportAudioData();
  final importPlayer = ImportPlayer();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Open File Picker and Let user pick file
    await importFile();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ImportAudioData>.value(value: clipDivProvider),
        ChangeNotifierProvider<ImportPlayer>.value(value: importPlayer),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onPop();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text("IMPORT_APPBAR_TITLE".tr()),
          ),
          body: SafeArea(
            child: MaxWidthCenterBox(
              child: ValueListenableBuilder<ImportPageState>(
                valueListenable: importPageState,
                builder: (context, value, _) {
                  if (value == ImportPageState.error ||
                      value == ImportPageState.timeout) {
                    return AlertDialog(
                      title: Text("IMPORT_ALERT_ERROR_TITLE".tr()),
                      content: Text("IMPORT_ALERT_ERROR_CONTENT".tr()),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("IMPORT_ALERT_ERROR_BUTTON".tr()),
                        )
                      ],
                    );
                  } else if (value == ImportPageState.aborted) {
                    return AlertDialog(
                      title: Text("IMPORT_ALERT_ERROR_TITLE".tr()),
                      content: Text("IMPORT_ALERT_ABORTED_CONTENT".tr()),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("IMPORT_ALERT_ABORTED_BUTTON".tr()),
                        )
                      ],
                    );
                  } else if (value == ImportPageState.converting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          const Text("IMPORT_CONVERTING_1").tr(),
                          const Text("IMPORT_CONVERTING_2").tr(),
                        ],
                      ),
                    );
                  } else if (value == ImportPageState.loading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else {
                    clipDivProvider.clipEndTime = importPlayer.fetchDuration;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(height: 8),
                        EditorControlView(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Open File Picker and Import Selected Audio File ---
  // miniaudio backend only supports mp3, wav, flac formats.
  // if selected audio has unsupported format, this function will attempt
  // ...to convert it into flac format.
  Future<void> importFile() async {
    final audioState = Provider.of<AudioState>(context, listen: false);

    late final List<String> allowedExtensions;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      allowedExtensions = [
        'wav',
        'aiff',
        'alac',
        'flac',
        'mp3',
        'aac',
        'wma',
        'ogg',
        'm4a'
      ];
    } else {
      allowedExtensions = ['wav', 'mp3', 'flac'];
    }

    FilePickerResult? importResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    debugPrint(importResult.toString());

    // if file selection was aborted
    if (importResult == null) {
      importPageState.value = ImportPageState.aborted;
      return;
    }

    // Cutout extension part from file path
    final fileNameList = importResult.files.single.name.split('.');
    fileNameList.removeLast();

    final fileName = fileNameList.join();
    String filePath = importResult.files.single.path!;
    final fileExtension = importResult.files.single.extension?.toLowerCase();

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      if (["mp3", "wav", "flac"].contains(fileExtension)) {
        // if audio clip is supported format
        await _loadAudioFile(audioState, filePath);
      } else {
        await _convertAndLoadAudioFile(audioState, fileName, filePath);
      }
    } else {
      _loadAudioFile(audioState, filePath).then((duration) => {
        makeAudioClip(filePath, 0, duration.seconds, false).then((_) {
          Navigator.of(context).pop();
        })
      });
    }
  }

  Future<AudioTime> _loadAudioFile(
      AudioState audioState, String filePath) async {
    try {
      // Open Audio Clip with Import Player
      await importPlayer.launch(
        backend: audioState.backend,
        outputDeviceId: audioState.outputDevice?.id,
        path: filePath,
      );
      importPlayer.filePath = filePath;

      // Wait for the duration to be available
      AudioTime? duration;
      int attempts = 0;
      const maxAttempts = 50; // 5 seconds (50 * 100ms)

      while (duration == null || duration == AudioTime.zero) {
        duration = await importPlayer.getDuration();
        if (duration != null && duration != AudioTime.zero) break;

        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;

        if (attempts >= maxAttempts) {
          throw TimeoutException(
              'Failed to get audio duration after $maxAttempts attempts');
        }
      }

      // Notify File Import is done
      clipDivProvider.clipEndTime = duration;
      importPageState.value = ImportPageState.ready;
      return duration;
    } catch (e) {
      debugPrint("Error loading audio file: $e");
      importPageState.value = ImportPageState.error;
      return AudioTime.zero;
    }
  }

  // if audio clip is unsupported format - convert into flac
  // miniaudio backend only support 3 formats - mp3, wav, flac.
  Future<void> _convertAndLoadAudioFile(
      AudioState audioState, String fileName, String filePath) async {
    importPageState.value = ImportPageState.converting;
    Directory appTempDir = await getTemporaryDirectory();
    Directory tempClipDir =
        await Directory("${appTempDir.path}${Platform.pathSeparator}temp")
            .create(recursive: true);
    String newFilePath =
        "${tempClipDir.path}${Platform.pathSeparator}$fileName.flac";
    // -y : force overwrite temp files
    // -vn : Remove Video
    // -c:a flac : convert unsupported audio clip into flac
    List<String> ffmpegArg = ["-y", "-i", filePath, newFilePath];
    // Convert Audio Clip with FFMPEG
    try {
      FFmpegKit.executeWithArgumentsAsync(ffmpegArg, (session) async {
        final returnCode = await session.getReturnCode();
        final failStackTrace = await session.getFailStackTrace();
        //final failLog = await session.getLogsAsString();

        // if clip conversion was successful
        if (ReturnCode.isSuccess(returnCode)) {
          // Open Audio Clip with Import Player
          await _loadAudioFile(audioState, newFilePath);
        }
        // if conversion was cancelled or error occurred
        else {
          // Notify error occurred
          importPageState.value = ImportPageState.error;
          // Print failStackTrace and Record Fail Log
          debugPrint(failStackTrace);
          //logError(failLog);
        }
      });
    } catch (e) {
      debugPrint("Error converting audio file: $e");
      importPageState.value = ImportPageState.error;
    }

    // If nothing happens even after 10 seconds
    Timer(const Duration(seconds: 10), () async {
      // Notify error occurred
      if (importPageState.value == ImportPageState.converting) {
        importPageState.value = ImportPageState.timeout;
      }
    });
  }

  void _onPop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("IMPORT_ALERT_EXIT_TITLE".tr()),
        content: Text("IMPORT_ALERT_EXIT_CONTENT".tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text("IMPORT_ALERT_EXIT_NO".tr()),
          ),
          TextButton(
            onPressed: () {
              importPlayer.shutdown();
              Navigator.of(context).pop(true);
              Navigator.of(context).pop();
            },
            child: Text("IMPORT_ALERT_EXIT_YES".tr()),
          ),
        ],
      ),
    );
    return;
  }
}

enum ImportPageState {
  ready,
  loading,
  converting,
  error,
  timeout,
  aborted,
  noedit
}

class ImportPlayer extends PlayerIsolate {
  String _filePath = "";

  set filePath(value) {
    _filePath = value;
  }

  String get filePath => _filePath;

  ImportPlayer();
}
