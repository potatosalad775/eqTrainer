import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:eq_trainer/model/error.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/session/session_playlist.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/player/player_isolate.dart';

class SessionControl extends StatelessWidget {

  const SessionControl({
    super.key,
    required this.player,
    required this.sessionPlaylist,
  });
  final SessionPlayer player;
  final SessionPlaylist sessionPlaylist;

  @override
  Widget build(BuildContext context) {
    final audioState = context.watch<AudioState>();
    final playerState = context.select<SessionPlayer, PlayerStateResponse>((p) => p.fetchPlayerState);

    Future<void> playerNext() async {
      sessionPlaylist.currentPlayingAudioIndex++;
      if(sessionPlaylist.currentPlayingAudioIndex >= sessionPlaylist.audioClipPathList.length) {
        sessionPlaylist.currentPlayingAudioIndex = 0;
      }

      await player.pause();
      await player.shutdown();
      await player.launch(
        backend: audioState.backend,
        outputDeviceId: audioState.outputDevice?.id,
        path: sessionPlaylist.audioClipPathList[sessionPlaylist.currentPlayingAudioIndex],
      );
      await player.play();

      return;
    }

    Future<void> playerPrevious() async {
      // if player position is greater than 3 seconds,
      // Previous button will reset player position to 0
      if(player.fetchPosition > const AudioTime(3)) {
        player.seek(AudioTime.zero);
        return;
      }
      // Else, play previous clip
      sessionPlaylist.currentPlayingAudioIndex--;
      if(sessionPlaylist.currentPlayingAudioIndex < 0) {
        sessionPlaylist.currentPlayingAudioIndex = (sessionPlaylist.audioClipPathList.length - 1);
      }

      await player.pause();
      await player.shutdown();
      await player.launch(
        backend: audioState.backend,
        outputDeviceId: audioState.outputDevice?.id,
        path: sessionPlaylist.audioClipPathList[sessionPlaylist.currentPlayingAudioIndex],
      );
      await player.play();

      return;
    }

    //if(player.state == MabAudioPlayerState.finished) playerNext();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () {
                playerPrevious();
              },
              iconSize: 50,
              icon: const Icon(Icons.skip_previous),
              enableFeedback: false,
            ),
            //SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
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
              icon: Icon(playerState.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded
              ),
              enableFeedback: false,
            ),
            //SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
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