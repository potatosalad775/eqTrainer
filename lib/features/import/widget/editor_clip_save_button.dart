import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/shared/service/audio_clip_service.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorClipSaveButton extends StatefulWidget {
  const EditorClipSaveButton({super.key});

  @override
  State<EditorClipSaveButton> createState() => _EditorClipSaveButtonState();
}

class _EditorClipSaveButtonState extends State<EditorClipSaveButton> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final player = context.read<ImportPlayer>();
    final clipTimeData = context.read<ImportAudioData>();

    return ElevatedButton(
      onPressed: _isProcessing
        ? null
        : () async {
            setState(() {
              _isProcessing = true;
            });
            player.pause();
            final clipService = context.read<AudioClipService>();
            final importFormat =
                context.read<MiscSettingsProvider>().importFormat;
            final messenger = ScaffoldMessenger.of(context);
            // Non-null whenever the editor is reachable — the button only
            // renders after loadAudioFile() succeeded. Handled rather than
            // forced so a torn-down player surfaces the save error instead of
            // throwing out of the callback.
            final sourcePath = player.filePath;
            // A clip counts as trimmed if either edge was moved off the full
            // extent. The previous check compared only the end time, so a
            // start-only trim was silently discarded and the whole file copied.
            final isTrimmed = clipTimeData.clipStartTime != Duration.zero ||
                clipTimeData.clipEndTime != player.fetchDuration;
            try {
              if (sourcePath == null) throw StateError('no source loaded');
              await clipService.createClip(
                sourcePath: sourcePath,
                startSec: clipTimeData.clipStartTime.inMicroseconds / 1e6,
                endSec: clipTimeData.clipEndTime.inMicroseconds / 1e6,
                isTrimmed: isTrimmed,
                importFormat: importFormat,
              );
            } catch (_) {
              // On failure, surface the error and re-enable the button instead
              // of leaving it permanently disabled with no feedback.
              if (mounted) {
                setState(() => _isProcessing = false);
                messenger.showSnackBar(
                  SnackBar(content: const Text("IMPORT_EDITOR_SAVE_ERROR").tr()),
                );
              }
              return;
            }
            if (!context.mounted) return;
            Navigator.pop(context);
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: const Text(
          "IMPORT_EDITOR_BUTTON_DONE",
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
      ),
    );
  }
}