
import 'package:eq_trainer/ui/core/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/ui/core/error.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/ui/core/widget/player_control_buttons.dart';

class PlaylistControlView extends StatefulWidget {
  const PlaylistControlView({super.key, required this.filePath, this.createPlayer});

  final String filePath;

  /// Replaces the [PlaylistPlayer] the view builds, so a test can give it an
  /// in-memory engine instead of SoLoud.
  @visibleForTesting
  final PlaylistPlayer Function(BuildContext context)? createPlayer;

  @override
  State<PlaylistControlView> createState() => _PlaylistControlViewState();
}

class _PlaylistControlViewState extends State<PlaylistControlView> {
  late final PlaylistPlayer _player;

  @override
  void initState() {
    super.initState();
    // Same reason as the session page: the preview is playback, and a
    // decode-and-encode running against it costs CPU we would rather spend on
    // the audio. Nested pauses are counted, so a preview opened over a
    // session does not resume the run when only the preview closes.
    _player = widget.createPlayer?.call(context) ??
        PlaylistPlayer(
          context.read<OutputSelection>(),
          hold: context.read<ClipFormatMigration>(),
        );
    _player.launch(
      path: widget.filePath,
    ).onError((e, _) {
      // Unhandled before: a missing/unreadable file (e.g. a dangling
      // playlist record) threw into this unawaited Future with no
      // user-visible feedback, leaving the preview sheet stuck open.
      if (mounted) {
        showPlayerErrorDialog(context,
          action: () {
            _player.shutdown();
            // Twice: the dialog is the top route, and the sheet is under it.
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.pop();
          },
          error: e,
          path: widget.filePath,
        );
      }
    });
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
  PlaylistPlayer(super.output, {required super.hold, super.engine});
}
