import 'dart:io';

import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/import/import_audio_data.dart';
import 'package:eq_trainer/data/import_player.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/data/clips/audio_clip_service.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A file can play and still be refused by the stricter offline decoder a trim
/// uses, so a retry is not always the right advice.
String _saveErrorMessage(AppLocalizations l10n, Object error) {
  if (error is UnsupportedChannelCountException) {
    return l10n.importAlertTooManyChannelsContent;
  }
  if (isUnreadableAudioError(error)) {
    return Platform.isLinux
        ? l10n.importAlertUnsupportedContentLinux
        : l10n.importAlertUnsupportedContent;
  }
  return l10n.importEditorSaveError;
}

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
            final l10n = context.l10n;
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
                originalPath: player.originalPath,
                startSec: clipTimeData.clipStartTime.inMicroseconds / 1e6,
                endSec: clipTimeData.clipEndTime.inMicroseconds / 1e6,
                isTrimmed: isTrimmed,
                importFormat: importFormat,
              );
            } catch (e) {
              // On failure, surface the error and re-enable the button instead
              // of leaving it permanently disabled with no feedback.
              if (mounted) {
                setState(() => _isProcessing = false);
                messenger.showSnackBar(
                  SnackBar(content: Text(_saveErrorMessage(l10n, e))),
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
        child: Text(
          context.l10n.importEditorButtonDone,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}