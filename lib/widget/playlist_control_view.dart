import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/theme_data.dart';
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

        // if player already have file opened
        if(!playlistPlayer.isFileOpened) {
          // Open Selected Clip
          playlistPlayer.open(filePath);
          // Mark Flag
          playlistPlayer.isFileOpened = true;
        }

        return WillPopScope(
          onWillPop: () async {
            playlistPlayer.stop();
            return true;
          },
          child: Card(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
              children: [
                // Slider
                Padding(
                  padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 10,
                      trackShape: CustomTrackShape(),
                    ),
                    child: Slider(
                      value: playerPosition.seconds,
                      min: 0,
                      max: playlistPlayer.duration.seconds,
                      onChanged: (player.state != MabAudioPlayerState.stopped)
                          ? (position) {
                        playlistPlayer.position = AudioTime(position);
                      } : null,
                    ),
                  ),
                ),
                // Audio Duration Indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          playerPosition.formatMMSS(),
                          style: const TextStyle(
                            height: 1,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          (playlistPlayer.duration - playerPosition).formatMMSS(),
                          style: const TextStyle(
                            height: 1,
                          ),
                        ),
                      ),
                    ],
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