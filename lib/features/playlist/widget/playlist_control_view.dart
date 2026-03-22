
import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/model/error.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/shared/widget/player_control_buttons.dart';

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
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlaylistPlayer>.value(
      value: _player,
      builder: (context, _) {
        final playerPosition = context.select<PlaylistPlayer, AudioTime>((p) => p.fetchPosition);
        final playerDuration = context.select<PlaylistPlayer, AudioTime>((p) => p.fetchDuration);
        final playerState = context.select<PlaylistPlayer, PlayerStateResponse>((p) => p.fetchPlayerState);
        return Padding(
          padding: const EdgeInsets.all(AppDimens.padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppDimens.padding,
            children: [
              // Slider
              ProgressBar(
                barHeight: 12,
                timeLabelPadding: 8,
                progress: Duration(microseconds: (playerPosition.seconds * 1000 * 1000).toInt()),
                total: Duration(microseconds: (playerDuration.seconds * 1000 * 1000).toInt()),
                onSeek: (position) async {
                  await _player.seek(AudioTime.fromDuration(position));
                },
              ),
              // Audio Control Button Row
              PlayerControlButtons(
                isPlaying: playerState.isPlaying,
                onPrevious: () => _player.seek(AudioTime.zero),
                onPlayPause: () {
                  if (playerState.isPlaying) {
                    _player.pause();
                  } else {
                    _player.play().onError((e, _) {
                      if (context.mounted) {
                        showPlayerErrorDialog(context,
                          action: () {
                            _player.shutdown();
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          error: e,
                        );
                      }
                    });
                  }
                },
                thirdIcon: Icons.close,
                onThird: () {
                  Navigator.of(context).pop();
                },
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
