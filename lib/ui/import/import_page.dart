import 'dart:async';
import 'dart:io';
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
import 'package:eq_trainer/data/clips/import_workflow_service.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:path/path.dart' as p;

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final importPageState =
      ValueNotifier<ImportPageState>(ImportPageState.loading);
  final clipDivProvider = ImportAudioData();
  late final ImportPlayer importPlayer;
  bool _importing = false;
  // Path of a temp file created by format conversion (see importFile), if
  // any. Cleaned up on dispose regardless of whether the import completed or
  // was aborted, so it doesn't linger in the temp dir forever.
  String? _tempConvertedPath;

  @override
  void initState() {
    super.initState();
    // The editor plays audio, and an import decodes and encodes on the same
    // whole-file path as the migration, so running both doubles the memory peak.
    importPlayer = ImportPlayer(
      context.read<OutputSelection>(),
      hold: context.read<ClipFormatMigration>(),
    );
    _init();
  }

  @override
  void dispose() {
    clipDivProvider.dispose();
    importPlayer.dispose();
    final tempPath = _tempConvertedPath;
    if (tempPath != null) unawaited(_deleteTemp(tempPath));
    super.dispose();
  }

  /// Best-effort: dispose() can't await it, and an orphaned temp file is a
  /// smaller problem than blocking teardown on disk I/O.
  Future<void> _deleteTemp(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> _init() async {
    await importFile();
  }

  ImportPageState _failureState(Object error) {
    if (error is UnsupportedChannelCountException) {
      return ImportPageState.tooManyChannels;
    }
    return isUnreadableAudioError(error)
        ? ImportPageState.unsupported
        : ImportPageState.error;
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
            title: Text(context.l10n.importAppbarTitle),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppDimens.maxWidgetWidth),
                child: ValueListenableBuilder<ImportPageState>(
                  valueListenable: importPageState,
                  builder: (context, value, _) {
                    final failure = switch (value) {
                      ImportPageState.error ||
                      ImportPageState.timeout =>
                        context.l10n.importAlertErrorContent,
                      ImportPageState.unsupported => Platform.isLinux
                          ? context.l10n.importAlertUnsupportedContentLinux
                          : context.l10n.importAlertUnsupportedContent,
                      ImportPageState.tooManyChannels =>
                        context.l10n.importAlertTooManyChannelsContent,
                      _ => null,
                    };
                    if (failure != null) {
                      return AlertDialog(
                        title: Text(context.l10n.importAlertErrorTitle),
                        content: Text(failure),
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

    final workflow = context.read<ImportWorkflowService>();

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
      if (mounted) importPageState.value = ImportPageState.error;
      return;
    }

    if (!mounted) return;

    if (importResult.isEmpty) {
      importPageState.value = ImportPageState.aborted;
      return;
    }

    final pickedFile = importResult.first;
    final String? originalPath = pickedFile.path;
    if (originalPath == null) {
      importPageState.value = ImportPageState.error;
      return;
    }
    String filePath = originalPath;

    final fileName = p.basenameWithoutExtension(pickedFile.name);
    final fileExtension = pickedFile.extension?.toLowerCase();

    // Determine target format based on user's import format setting
    final sourceExt = '.${fileExtension ?? ''}';
    final importFormat = context.read<MiscSettingsProvider>().importFormat;
    final targetExt = targetExtForImport(sourceExt, importFormat);

    if (targetExt != null) {
      importPageState.value = ImportPageState.converting;
      try {
        filePath = await workflow.convertTo(
          fileNameWithoutExt: fileName,
          sourcePath: filePath,
          targetExt: targetExt,
        );
        // A conversion cannot be cancelled, so the user may have left while it
        // ran, and dispose() has already looked for this file.
        if (!mounted) {
          await _deleteTemp(filePath);
          return;
        }
        // Track the converted temp file so it's cleaned up on dispose,
        // whether the import completes or is aborted.
        _tempConvertedPath = filePath;
      } catch (e) {
        debugPrint("Error converting audio file: $e");
        importPageState.value = _failureState(e);
        return;
      }
    }

    if (!mounted) return;

    try {
      final duration = await workflow.loadAudioFile(
        importPlayer: importPlayer,
        filePath: filePath,
        originalPath: originalPath,
      );
      clipDivProvider.clipEndTime = duration;
      importPageState.value = ImportPageState.ready;
    } catch (e) {
      debugPrint("Error loading audio file: $e");
      importPageState.value = _failureState(e);
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
  error,
  unsupported,
  tooManyChannels,
  timeout,
  aborted,
  noedit
}
