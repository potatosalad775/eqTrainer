
import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/model/error.dart';
import 'package:eq_trainer/shared/player/player_service.dart';
import 'package:eq_trainer/shared/service/clip_format_migration.dart';
import 'package:eq_trainer/shared/widget/player_control_buttons.dart';

class PlaylistControlView extends StatefulWidget {
  const PlaylistControlView({super.key, required this.filePath});

  final String filePath;

  @override
  State<PlaylistControlView> createState() => _PlaylistControlViewState();
}

class _PlaylistControlViewState extends State<PlaylistControlView> {
  final _player = PlaylistPlayer();

  /// Captured in initState rather than read in dispose, where the element is
  /// already detached from the tree.
  late final ClipFormatMigration _clipFormatMigration;

  @override
  void initState() {
    super.initState();
    // Same reason as the session page: the preview is playback, and a
    // decode-and-encode running against it costs CPU we would rather spend on
    // the audio. Nested pauses are counted, so a preview opened over a
    // session does not resume the run when only the preview closes.
    _clipFormatMigration = context.read<ClipFormatMigration>()..pause();
    final audioState = context.read<AudioState>();
    _player.launch(
      androidBackend: audioState.androidBackend,
      outputDevice: audioState.outputDevice,
      path: widget.filePath,
    ).onError((e, _) {
      // Unhandled before: a missing/unreadable file (e.g. a dangling
      // playlist record) threw into this unawaited Future with no
      // user-visible feedback, leaving the preview sheet stuck open.
      if (mounted) {
        showPlayerErrorDialog(context,
          action: () {
            _player.shutdown();
            Navigator.of(context).pop();
          },
          error: e,
        );
      }
    });
  }

  @override
  void dispose() {
    _clipFormatMigration.resume();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlaylistPlayer>.value(
      value: _player,
      builder: (context, _) {
        final playerPosition = context.select<PlaylistPlayer, Duration>((p) => p.fetchPosition);
        final playerDuration = context.select<PlaylistPlayer, Duration>((p) => p.fetchDuration);
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
                progress: playerPosition,
                total: playerDuration,
                onSeek: (position) async {
                  await _player.seek(position);
                },
              ),
              // Audio Control Button Row
              PlayerControlButtons(
                isPlaying: playerState.isPlaying,
                onPrevious: () => _player.seek(Duration.zero),
                onPlayPause: () {
                  if (playerState.isPlaying) {
                    _player.pause();
                  } else {
                    // play() is a synchronous FFI write now, so there is no
                    // Future to hang an error handler off — a file that won't
                    // load fails in the awaited launch() above instead.
                    _player.play();
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

class PlaylistPlayer extends PlayerService {
  PlaylistPlayer();
}
