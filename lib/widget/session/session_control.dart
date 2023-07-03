import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';
import 'package:eq_trainer/model/session_data.dart';

class SessionControl extends StatelessWidget {

  const SessionControl({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player = context.watch<IsolatedMusicPlayer>();
    final sessionAudioClip = context.watch<SessionAudioData>();

    Future<void> playerNext() async {
      sessionAudioClip.currentPlayingAudioIndex++;
      if(sessionAudioClip.currentPlayingAudioIndex >= sessionAudioClip.audioClipPathList.length) sessionAudioClip.currentPlayingAudioIndex = 0;

      await player.stop();
      await player.open(sessionAudioClip.audioClipPathList[sessionAudioClip.currentPlayingAudioIndex]);
      await player.play();

      return;
    }

    Future<void> playerPrevious() async {
      // if player position is greater than 3 seconds,
      // Previous button will reset player position to 0
      if(player.position > const AudioTime(3)) {
        player.position = const AudioTime(0);
        return;
      }
      // Else, play previous clip
      sessionAudioClip.currentPlayingAudioIndex--;
      if(sessionAudioClip.currentPlayingAudioIndex < 0) sessionAudioClip.currentPlayingAudioIndex = (sessionAudioClip.audioClipPathList.length - 1);

      await player.stop();
      await player.open(sessionAudioClip.audioClipPathList[sessionAudioClip.currentPlayingAudioIndex]);
      await player.play();

      return;
    }

    if(player.state == MabAudioPlayerState.finished) playerNext();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                playerPrevious();
              },
              iconSize: 50,
              icon: const Icon(Icons.skip_previous),
              enableFeedback: false,
            ),
            SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
            IconButton(
              onPressed: player.state != MabAudioPlayerState.stopped
                  ? () {
                      if (player.state == MabAudioPlayerState.playing) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    }
                  : null,
              iconSize: 64,
              icon: Icon(player.state == MabAudioPlayerState.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
              enableFeedback: false,
            ),
            SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
            IconButton(
              onPressed: () async {
                await playerNext();
              },
              iconSize: 50,
              icon: const Icon(Icons.skip_next),
              enableFeedback: false,
            ),
          ],
        ),
      ],
    );
  }
}