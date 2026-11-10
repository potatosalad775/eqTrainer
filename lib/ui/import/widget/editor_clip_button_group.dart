import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/import/import_audio_data.dart';
import 'package:eq_trainer/data/import_player.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorClipButtonGroup extends StatelessWidget {
  const EditorClipButtonGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final playerPosition = context.select<ImportPlayer, Duration>((p) => p.fetchPosition);
    final clipTimeData = context.read<ImportAudioData>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      spacing: 12,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if(playerPosition < clipTimeData.clipEndTime) {
                clipTimeData.clipStartTime = playerPosition;
              } else {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: Text(context.l10n.importEditorAlertStartContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: Text(context.l10n.importEditorAlertButton),
                      )
                    ],
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.secondary,
              foregroundColor: context.colors.onSecondary,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(context.l10n.importEditorButtonSetStart),
            ),
          ),
        ),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if(clipTimeData.clipStartTime < playerPosition) {
                clipTimeData.clipEndTime = playerPosition;
              } else {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: Text(context.l10n.importEditorAlertEndContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: Text(context.l10n.importEditorAlertButton),
                      )
                    ],
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.secondary,
              foregroundColor: context.colors.onSecondary,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(context.l10n.importEditorButtonSetEnd),
            ),
          ),
        ),
      ],
    );
  }
}