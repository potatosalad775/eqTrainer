import 'dart:async';
import 'package:eq_trainer/features/import/widget/editor_clip_button_group.dart';
import 'package:eq_trainer/features/import/widget/editor_clip_save_button.dart';
import 'package:eq_trainer/features/import/widget/editor_control_button_group.dart';
import 'package:eq_trainer/features/import/widget/editor_position_slider.dart';
import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/widget/max_width_center_box.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:eq_trainer/shared/service/import_workflow_service.dart';

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

  @override
  void dispose() {
    clipDivProvider.dispose();
    importPlayer.dispose();
    super.dispose();
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
                    return const Padding(
                      padding: EdgeInsets.all(AppDimens.padding),
                      child:  Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Position Slider with Timestamp
                          EditorPositionSlider(),
                          // Audio Control Button Row
                          EditorControlButtonGroup(),
                          SizedBox(height: 32),
                          // Set Start / End Buttons
                          EditorClipButtonGroup(),
                          SizedBox(height: 16),
                          // Done Button - add to Database
                          EditorClipSaveButton(),
                        ],
                      ),
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

    const allowedExtensions = [
      'wav', 'mp3', 'flac', 'm4a', 'aac', 'ogg', 'wma', 'aiff', 'opus'
    ];

    final importResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (!mounted) return;

    if (importResult == null || importResult.files.isEmpty) {
      importPageState.value = ImportPageState.aborted;
      return;
    }

    final pickedFile = importResult.files.first;
    String? filePath = pickedFile.path;
    if (filePath == null) {
      importPageState.value = ImportPageState.error;
      return;
    }

    final fileNameList = pickedFile.name.split('.');
    if (fileNameList.length > 1) fileNameList.removeLast();
    final fileName = fileNameList.join();
    final fileExtension = pickedFile.extension?.toLowerCase();

    // Convert unsupported formats to WAV on all platforms
    if (!['mp3', 'wav', 'flac'].contains(fileExtension)) {
      importPageState.value = ImportPageState.converting;
      try {
        filePath = await workflow.convertToWav(
          fileNameWithoutExt: fileName,
          sourcePath: filePath,
        );
      } catch (e) {
        debugPrint("Error converting audio file: $e");
        importPageState.value = ImportPageState.error;
        return;
      }
    }

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
