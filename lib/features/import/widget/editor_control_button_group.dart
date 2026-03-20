import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/index.dart';
import 'package:eq_trainer/shared/model/error.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorControlButtonGroup extends StatelessWidget {
  const EditorControlButtonGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final clipTimeData = context.read<ImportAudioData>();
    final player = context.read<ImportPlayer>();
    final playerState = context.select<ImportPlayer, PlayerStateResponse>((p) => p.fetchPlayerState);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Skip Previous
        IconButton(
          onPressed: () {
            player.seek(clipTimeData.clipStartTime);
          },
          iconSize: 56,
          icon: const Icon(Icons.skip_previous),
          enableFeedback: false,
        ),
        // Play Pause
        IconButton(
          onPressed: () {
            if (playerState.isPlaying) {
              player.pause();
            } else {
              player.play().onError((e, _) {
                if(context.mounted) {
                  showPlayerErrorDialog(context,
                    action: () {
                      player.shutdown();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    error: e
                  );
                }
              });
            }
          },
          iconSize: 64,
          icon: Icon(playerState.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
          enableFeedback: false,
        ),
        // Skip Next
        IconButton(
          onPressed: () {
            player.seek(clipTimeData.clipEndTime);
          },
          iconSize: 56,
          icon: const Icon(Icons.skip_next),
          enableFeedback: false,
        ),
      ],
    );
  }
}