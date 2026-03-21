import 'package:coast_audio/coast_audio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/theme_data.dart';

class EditorClipButtonGroup extends StatelessWidget {
  const EditorClipButtonGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final playerPosition = context.select<ImportPlayer, AudioTime>((p) => p.fetchPosition);
    final clipTimeData = context.read<ImportAudioData>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    content: const Text("IMPORT_EDITOR_ALERT_START_CONTENT").tr(),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text("IMPORT_EDITOR_ALERT_BUTTON").tr(),
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
              child: const Text("IMPORT_EDITOR_BUTTON_SET_START").tr(),
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
                    content: const Text("IMPORT_EDITOR_ALERT_END_CONTENT").tr(),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text("IMPORT_EDITOR_ALERT_BUTTON").tr(),
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
              child: const Text("IMPORT_EDITOR_BUTTON_SET_END").tr(),
            ),
          ),
        ),
      ],
    );
  }
}