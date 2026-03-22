import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/shared/model/error.dart';
import 'package:eq_trainer/shared/widget/player_control_buttons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorControlButtonGroup extends StatelessWidget {
  const EditorControlButtonGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final clipTimeData = context.read<ImportAudioData>();
    final player = context.read<ImportPlayer>();
    final playerState = context.select<ImportPlayer, PlayerStateResponse>((p) => p.fetchPlayerState);

    return PlayerControlButtons(
      isPlaying: playerState.isPlaying,
      onPrevious: () => player.seek(clipTimeData.clipStartTime),
      onPlayPause: () {
        if (playerState.isPlaying) {
          player.pause();
        } else {
          player.play().onError((e, _) {
            if (context.mounted) {
              showPlayerErrorDialog(context,
                action: () {
                  player.shutdown();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                error: e,
              );
            }
          });
        }
      },
      thirdIcon: Icons.skip_next,
      onThird: () => player.seek(clipTimeData.clipEndTime),
    );
  }
}