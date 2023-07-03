import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/widget/editor_control_view.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({Key? key}) : super(key: key);

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final importPageState = ValueNotifier<ImportPageState>(ImportPageState.loading);
  final clipDivProvider = ImportAudioData();
  final importPlayer = ImportPlayer(format: mainFormat);

  @override
  void initState() {
    // Open File Picker and Let user pick file
    importFile();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ImportAudioData>.value(value: clipDivProvider),
        ChangeNotifierProvider<ImportPlayer>.value(value: importPlayer),
      ],
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            title: Text("IMPORT_APPBAR_TITLE".tr()),
          ),
          body: SafeArea(
            child: ValueListenableBuilder<ImportPageState>(
              valueListenable: importPageState,
              builder: (context, value, _) {
                final playerDuration = context.select<ImportPlayer, AudioTime>((p) => p.duration);
                if (value == ImportPageState.error || value == ImportPageState.timeout) {
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
                }
                else if (value == ImportPageState.aborted) {
                  return AlertDialog(
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
                }
                else if (value == ImportPageState.converting) {
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
                }
                else if(value == ImportPageState.loading || playerDuration == AudioTime.zero) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                else {
                  // Update imported audio file's duration info to ControlView
                  clipDivProvider.initEndTime(importPlayer.duration);
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(height: 8),
                      EditorControlView(),
                      SizedBox(height: 16),
                    ],
                  );
                }
              },
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
    FilePickerResult? importResult = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    // if file selection was aborted
    if(importResult == null) {
      importPageState.value = ImportPageState.aborted;
      return;
    }

    // Cutout extension part from file path
    final fileNameList = importResult.files.single.name.split('.');
    fileNameList.removeLast();

    final fileName = fileNameList.join();
    String filePath = importResult.files.single.path!;
    final fileExtension = importResult.files.single.extension;

    // if audio clip is supported format
    if(fileExtension == "mp3" || fileExtension == "wav" || fileExtension == "flac") {
      // Open Audio Clip with Import Player
      importPlayer.open(filePath).then((_) {
        // Notify File Import is done
        importPageState.value = ImportPageState.ready;
      });
      return;
    }

    // if audio clip is unsupported format - convert into flac
    // miniaudio backend only support 3 formats below
    importPageState.value = ImportPageState.converting;
    Directory appTempDir = await getTemporaryDirectory();
    Directory tempClipDir = await Directory("${appTempDir.path}/temp").create(recursive: true);
    // -y : force overwrite temp files
    // -vn : Remove Video
    // -c:a flac : convert unsupported audio clip into flac
    String newFilePath = "${tempClipDir.path}/$fileName.flac";
    List<String> ffmpegArg = ["-y", "-i", filePath, newFilePath];
    // Convert Audio Clip with FFMPEG
    FFmpegKit.executeWithArgumentsAsync(ffmpegArg, (session) async {
      final returnCode = await session.getReturnCode();
      final failStackTrace = await session.getFailStackTrace();
      final failLog = await session.getLogsAsString();

      // if clip conversion was successful
      if(ReturnCode.isSuccess(returnCode)) {
        // Open Audio Clip with Import Player
        importPlayer.open(newFilePath).then((_) {
          // Notify File Import is done
          importPageState.value = ImportPageState.ready;
        });
        return;
      }
      // if conversion was cancelled or error occurred
      else {
        // Notify error occurred
        importPageState.value = ImportPageState.error;
        // Print failStackTrace and Record Fail Log
        debugPrint(failStackTrace);
        final File file = await File("${appSupportDir.path}/log/recentLog.txt").create(recursive: true);
        file.writeAsString(failLog);
      }
      // If nothing happens even after 10 seconds
      Timer(const Duration(seconds: 10), () async {
        // Notify error occurred
        importPageState.value = ImportPageState.timeout;
      });
    });
  }

  Future<bool> _onWillPop() async {
    final value = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              importPlayer.stop();
              Navigator.of(context).pop(true);
            },
            child: Text("IMPORT_ALERT_EXIT_YES".tr()),
          ),
        ],
      ),
    );
    return value == true;
  }
}

enum ImportPageState { ready, loading, converting, error, timeout, aborted }

class ImportPlayer extends IsolatedMusicPlayer {
  ImportPlayer({required super.format});
}