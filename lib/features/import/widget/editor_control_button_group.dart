import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:eq_trainer/shared/player/player_service.dart';
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
          // play() is a synchronous FFI write now, so there is no Future to
          // attach an error handler to — a file that won't load already
          // failed in the awaited launch() the import workflow does.
          player.play();
        }
      },
      thirdIcon: Icons.skip_next,
      onThird: () => player.seek(clipTimeData.clipEndTime),
    );
  }
}