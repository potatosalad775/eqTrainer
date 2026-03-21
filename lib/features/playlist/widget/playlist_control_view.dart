
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/model/error.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';

class PlaylistControlView extends StatefulWidget {
  const PlaylistControlView({super.key, required this.filePath});

  final String filePath;

  @override
  State<PlaylistControlView> createState() => _PlaylistControlViewState();
}

class _PlaylistControlViewState extends State<PlaylistControlView> {
  final _player = PlaylistPlayer();

  @override
  void initState() {
    super.initState();
    final audioState = context.read<AudioState>();
    _player.launch(
      backend: audioState.backend,
      outputDeviceId: audioState.outputDevice?.id,
      path: widget.filePath,
    );
  }

  @override
  void dispose() {
    _player.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlaylistPlayer>.value(
      value: _player,
      child: const _PlaylistControlBody(),
    );
  }
}

class _PlaylistControlBody extends StatelessWidget {
  const _PlaylistControlBody();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlaylistPlayer>();
    final playerPosition = context.select<PlaylistPlayer, AudioTime>((p) => p.fetchPosition);
    final playerDuration = context.select<PlaylistPlayer, AudioTime>((p) => p.fetchDuration);
    final playerState = context.select<PlaylistPlayer, PlayerStateResponse>((p) => p.fetchPlayerState);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {
        player.pause();
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
              SizedBox(width: MediaQuery.sizeOf(context).width * kControlSpacer),
              // Play Pause
              IconButton(
                onPressed: () {
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
                iconSize: 64,
                icon: Icon(playerState.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded),
                enableFeedback: false,
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width * kControlSpacer),
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
  }
}

class PlaylistPlayer extends PlayerIsolate {
  PlaylistPlayer();
}
