import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';

class PlaylistControlView extends StatelessWidget {
  const PlaylistControlView({super.key, required this.filePath});

  // Audio File Path
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final playlistPlayer = PlaylistPlayer(format: mainFormat);

    return ChangeNotifierProvider<PlaylistPlayer>.value(
      value: playlistPlayer,
      builder: (context, player) {
        // Providers
        final player = context.read<PlaylistPlayer>();
        final playerState = context.select<PlaylistPlayer, MabAudioPlayerState>((p) => p.state);
        final playerPosition = context.select<PlaylistPlayer, AudioTime>((p) => p.position);
        final playerDuration = context.select<PlaylistPlayer, AudioTime?>((p) => p.duration) ?? playerPosition;

        // if player already have file opened
        if(!playlistPlayer.isFileOpened) {
          // Open Selected Clip
          playlistPlayer.open(filePath);
          // Mark Flag
          playlistPlayer.isFileOpened = true;
        }

        return PopScope(
          canPop: true,
          onPopInvoked: (_) {
            playlistPlayer.stop();
          },
          child: Card(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
              children: [
                // Slider
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 10, 30, 10),
                  child: ProgressBar(
                    barHeight: 12,
                    timeLabelPadding: 8,
                    progress: Duration(microseconds: (playerPosition.seconds * 1000 * 1000).toInt()),
                    total: Duration(microseconds: (playerDuration.seconds * 1000 * 1000).toInt()),
                    onSeek: (player.state != MabAudioPlayerState.stopped)
                        ? (position) {
                      player.position = AudioTime(position.inMicroseconds / (1000 * 1000));
                    } : null,
                  ),
                ),
                // Audio Control Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Skip Previous
                    IconButton(
                      onPressed: () {
                        player.position = AudioTime.zero;
                      },
                      iconSize: 56,
                      icon: const Icon(Icons.skip_previous),
                      enableFeedback: false,
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
                    // Play Pause
                    IconButton(
                      onPressed: playerState != MabAudioPlayerState.stopped
                          ? () {
                        if (playerState == MabAudioPlayerState.playing) {
                          player.pause();
                        } else {
                          player.play();
                        }
                      }
                          : null,
                      iconSize: 64,
                      icon: Icon(playerState == MabAudioPlayerState.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                      enableFeedback: false,
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
                    // Skip Next
                    IconButton(
                      onPressed: () {
                        player.stop();
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
          ),
        );
      },
    );
  }
}

class PlaylistPlayer extends IsolatedMusicPlayer {
  // State containing whether file is open or not
  bool isFileOpened = false;

  PlaylistPlayer({required super.format});
}