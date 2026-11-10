import 'dart:async';
import 'package:eq_trainer/ui/import/widget/editor_clip_button_group.dart';
import 'package:eq_trainer/ui/import/widget/editor_clip_save_button.dart';
import 'package:eq_trainer/ui/import/widget/editor_control_button_group.dart';
import 'package:eq_trainer/ui/import/widget/editor_position_slider.dart';
import 'package:eq_trainer/ui/core/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/import/import_audio_data.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/data/import_player.dart';
import 'package:eq_trainer/data/clips/audio_clip_service.dart';
import 'package:eq_trainer/data/clips/clip_import.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:eq_trainer/ui/import/import_failure_message.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, this.createImport, this.createPlayer});

  /// Replaces the [ClipImport] and the [ImportPlayer] the page builds, so a test
  /// can reach neither the engine nor the encoder.
  @visibleForTesting
  final ClipImport Function(BuildContext context)? createImport;

  @visibleForTesting
  final ImportPlayer Function(BuildContext context)? createPlayer;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final importPageState =
      ValueNotifier<ImportPageState>(ImportPageState.loading);
  final clipDivProvider = ImportAudioData();
  late final ImportPlayer importPlayer;
  late final ClipImport clipImport;
  bool _importing = false;
  // Why the page is in [ImportPageState.failed]. Set just before the state.
  ImportFailure _failure = ImportFailure.other;

  @override
  void initState() {
    super.initState();
    // The editor plays audio, and an import decodes and encodes on the same
    // whole-file path as the migration, so running both doubles the memory peak.
    importPlayer = widget.createPlayer?.call(context) ??
        ImportPlayer(
          context.read<OutputSelection>(),
          hold: context.read<ClipFormatMigration>(),
        );
    clipImport = widget.createImport?.call(context) ??
        ClipImport(
          clips: context.read<AudioClipService>(),
          importFormat: context.read<MiscSettingsProvider>().importFormat,
        );
    _init();
  }

  @override
  void dispose() {
    clipDivProvider.dispose();
    importPlayer.dispose();
    clipImport.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await importFile();
  }

  void _fail(ImportFailure failure) {
    _failure = failure;
    importPageState.value = ImportPageState.failed;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ImportAudioData>.value(value: clipDivProvider),
        ChangeNotifierProvider<ImportPlayer>.value(value: importPlayer),
        Provider<ClipImport>.value(value: clipImport),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onPop();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.importAppbarTitle),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppDimens.maxWidgetWidth),
                child: ValueListenableBuilder<ImportPageState>(
                  valueListenable: importPageState,
                  builder: (context, value, _) {
                    if (value == ImportPageState.failed ||
                        value == ImportPageState.timeout) {
                      return AlertDialog(
                        title: Text(context.l10n.importAlertErrorTitle),
                        content: Text(importFailureMessage(
                          context.l10n,
                          _failure,
                          other: context.l10n.importAlertErrorContent,
                        )),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(context.l10n.importAlertErrorButton),
                          )
                        ],
                      );
                    } else if (value == ImportPageState.aborted) {
                      return AlertDialog(
                        title: Text(context.l10n.importAlertErrorTitle),
                        content: Text(context.l10n.importAlertAbortedContent),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(context.l10n.importAlertAbortedButton),
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
                            Text(context.l10n.importConverting1),
                            Text(context.l10n.importConverting2),
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
      ),
    );
  }

  Future<void> importFile() async {
    if (_importing) return;
    _importing = true;

    final List<PlatformFile> importResult;
    try {
      importResult = await FilePicker.pickFiles(
        type: FileType.custom,
        // Single source of truth with the format policy, so a format can never
        // be offered in the picker that the importer has no rule for.
        allowedExtensions: importPickerExtensions(),
      );
    } catch (e) {
      debugPrint("Error picking file: $e");
      if (mounted) _fail(ImportFailure.other);
      return;
    }

    if (!mounted) return;

    if (importResult.isEmpty) {
      importPageState.value = ImportPageState.aborted;
      return;
    }

    final pickedFile = importResult.first;
    final String? pickedPath = pickedFile.path;
    if (pickedPath == null) {
      _fail(ImportFailure.other);
      return;
    }

    if (clipImport.needsConversion(pickedFile.name)) {
      importPageState.value = ImportPageState.converting;
    }
    final String filePath;
    try {
      filePath = await clipImport.prepare(
        pickedPath: pickedPath,
        pickedName: pickedFile.name,
      );
    } catch (e) {
      debugPrint("Error converting audio file: $e");
      _fail(importFailureOf(e));
      return;
    }

    if (!mounted) return;

    try {
      // No polling: SoLoud knows a source's length as soon as it is loaded, so
      // launch() already has it by the time it returns. A zero duration means
      // the file decoded to nothing and there is nothing to trim, so it is an
      // error rather than a "not ready yet" to wait out.
      await importPlayer.launch(path: filePath);
      final duration = importPlayer.fetchDuration;
      if (duration == Duration.zero) {
        throw Exception('Audio file reported a zero duration: $filePath');
      }
      clipDivProvider.clipEndTime = duration;
      importPageState.value = ImportPageState.ready;
    } catch (e) {
      debugPrint("Error loading audio file: $e");
      _fail(importFailureOf(e));
    }
  }

  void _onPop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.importAlertExitTitle),
        content: Text(context.l10n.importAlertExitContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(context.l10n.importAlertExitNo),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              Navigator.of(context).pop();
            },
            child: Text(context.l10n.importAlertExitYes),
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
  failed,
  timeout,
  aborted,
  noedit
}
