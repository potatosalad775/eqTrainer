import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/import/import_audio_data.dart';
import 'package:eq_trainer/data/import_player.dart';
import 'package:eq_trainer/data/clips/clip_import.dart';
import 'package:eq_trainer/ui/import/import_failure_message.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
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
            final clipImport = context.read<ClipImport>();
            final messenger = ScaffoldMessenger.of(context);
            final l10n = context.l10n;
            final duration = player.fetchDuration;
            try {
              await clipImport.save(
                start: clipTimeData.clipStartTime,
                end: clipTimeData.clipEndTime,
                duration: duration,
              );
            } catch (e) {
              // On failure, surface the error and re-enable the button instead
              // of leaving it permanently disabled with no feedback.
              if (mounted) {
                setState(() => _isProcessing = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(importFailureMessage(
                      l10n,
                      importFailureOf(e),
                      other: l10n.importEditorSaveError,
                    )),
                  ),
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