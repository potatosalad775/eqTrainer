import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/player/import_player.dart';
import 'package:eq_trainer/widget/editor_control_view.dart';
import 'package:eq_trainer/widget/common/MaxWidthCenterBox.dart';
import 'package:eq_trainer/repository/audio_clip_repository.dart';
import 'package:eq_trainer/service/audio_clip_service.dart';
import 'package:eq_trainer/model/state/import_audio_data.dart';
import 'package:eq_trainer/service/import_workflow_service.dart';

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
    await importFile();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ImportAudioData>.value(value: clipDivProvider),
        ChangeNotifierProvider<ImportPlayer>.value(value: importPlayer),
        Provider<AudioClipRepository>(create: (_) => AudioClipRepository()),
        Provider<AudioClipService>(
          create: (ctx) => AudioClipService(ctx.read<AudioClipRepository>()),
        ),
        Provider<ImportWorkflowService>(create: (_) => const ImportWorkflowService()),
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
                      children: const [
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
      ),
    );
  }

  Future<void> importFile() async {
    final audioState = Provider.of<AudioState>(context, listen: false);
    final workflow = context.read<ImportWorkflowService>();

    late final List<String> allowedExtensions;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      allowedExtensions = [
        'wav', 'aiff', 'flac', 'mp3', 'aac', 'wma', 'ogg', 'm4a', 'opus'
      ];
    } else {
      allowedExtensions = ['wav', 'mp3', 'flac'];
    }

    final importResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    //debugPrint(importResult.toString());

    if (importResult == null) {
      importPageState.value = ImportPageState.aborted;
      return;
    }

    final fileNameList = importResult.files.single.name.split('.');
    fileNameList.removeLast();

    final fileName = fileNameList.join();
    final filePath = importResult.files.single.path!;
    final fileExtension = importResult.files.single.extension?.toLowerCase();

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      if (["mp3", "wav", "flac"].contains(fileExtension)) {
        try {
          final duration = await workflow.loadAudioFile(
            audioState: audioState,
            importPlayer: importPlayer,
            filePath: filePath,
          );
          clipDivProvider.clipEndTime = duration;
          importPageState.value = ImportPageState.ready;
        } catch (e) {
          debugPrint("Error loading audio file: $e");
          importPageState.value = ImportPageState.error;
        }
      } else {
        importPageState.value = ImportPageState.converting;
        try {
          final converted = await workflow.convertToFlac(
            fileNameWithoutExt: fileName,
            sourcePath: filePath,
          );
          final duration = await workflow.loadAudioFile(
            audioState: audioState,
            importPlayer: importPlayer,
            filePath: converted,
          );
          clipDivProvider.clipEndTime = duration;
          importPageState.value = ImportPageState.ready;
        } catch (e) {
          debugPrint("Error converting/loading audio file: $e");
          importPageState.value = ImportPageState.error;
        }
      }
    } else {
      final clipService = context.read<AudioClipService>();
      try {
        final duration = await workflow.loadAudioFile(
          audioState: audioState,
          importPlayer: importPlayer,
          filePath: filePath,
        );
        await clipService.createClip(
          sourcePath: filePath,
          startSec: 0,
          endSec: duration.seconds,
          isEdit: false,
        );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        debugPrint("Error importing on desktop: $e");
        importPageState.value = ImportPageState.error;
      }
    }
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
