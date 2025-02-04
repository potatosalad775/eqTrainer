import 'package:eq_trainer/player/player_isolate.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/error.dart';

class PlaylistControlView extends StatelessWidget {
  const PlaylistControlView({super.key, required this.filePath});

  // Audio File Path
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final playlistPlayer = PlaylistPlayer();

    return ChangeNotifierProvider<PlaylistPlayer>.value(
      value: playlistPlayer,
      builder: (context, player) {
        // Providers
        final player = context.read<PlaylistPlayer>();
        final audioState = context.watch<AudioState>();
        final playerPosition = context.select<PlaylistPlayer, AudioTime>((p) => p.fetchPosition);
        final playerDuration = context.select<PlaylistPlayer, AudioTime>((p) => p.fetchDuration);
        final playerState = context.select<PlaylistPlayer, PlayerStateResponse>((p) => p.fetchPlayerState);

        if(!playlistPlayer.isLaunched) {
          playlistPlayer.launch(
            backend: audioState.backend,
            outputDeviceId: audioState.outputDevice?.id,
            path: filePath,
          );
        }

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (_, __) {
            playlistPlayer.pause();
          },
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
            children: [
              // Slider
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 10),
                child: ProgressBar(
                  barHeight: 12,
                  timeLabelPadding: 8,
                  progress: Duration(microseconds: (playerPosition.seconds * 1000 * 1000).toInt()),
                  total: Duration(microseconds: (playerDuration.seconds * 1000 * 1000).toInt()),
                  onSeek: (position) async {
                    player.seek(AudioTime.fromDuration(position));
                  },
                ),
              ),
              // Audio Control Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Skip Previous
                  IconButton(
                    onPressed: () {
                      player.seek(AudioTime.zero);
                    },
                    iconSize: 56,
                    icon: const Icon(Icons.skip_previous),
                    enableFeedback: false,
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
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
                  SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
                  // Close
                  IconButton(
                    onPressed: () {
                      player.pause();
                      Navigator.of(context).pop();
                    },
                    iconSize: 56,
                    icon: const Icon(Icons.close),
                    enableFeedback: false,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class PlaylistPlayer extends PlayerIsolate {
  PlaylistPlayer();
}