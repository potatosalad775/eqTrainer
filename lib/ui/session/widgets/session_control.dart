import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/core/error.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/ui/core/widget/player_control_buttons.dart';
import 'package:eq_trainer/ui/session/state/session_controller.dart';
import 'package:eq_trainer/ui/session/widgets/clip_skipped_toast.dart';

class SessionControl extends StatefulWidget {

  const SessionControl({super.key});

  @override
  State<SessionControl> createState() => _SessionControlState();
}

class _SessionControlState extends State<SessionControl> {
  // Only disables the buttons while a switch runs. The controller refuses a
  // second switch on its own, so this is for the look of it.
  bool _switching = false;

  Future<void> _switchTrack(
    Future<TrackSwitch> Function(SessionController controller) switchTrack,
  ) async {
    if (_switching) return;
    final controller = context.read<SessionController>();
    final player = context.read<PlayerService>();
    // Captured up front: the result arrives after an await, by which time this
    // widget may be gone.
    final l10n = context.l10n;
    setState(() => _switching = true);
    try {
      final result = await switchTrack(controller);
      if (!mounted) return;
      if (result.status == TrackSwitchStatus.switched && result.skipped > 0) {
        showClipSkippedToast(l10n);
      } else if (result.status == TrackSwitchStatus.failed) {
        await showPlayerErrorDialog(context,
          action: () {
            player.shutdown();
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          error: result.error,
          path: result.path,
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final playerState = context.select<PlayerService, PlayerStateResponse>((p) => p.fetchPlayerState);

    return PlayerControlButtons(
      isPlaying: playerState.isPlaying,
      onPrevious: _switching ? null : () => _switchTrack((c) => c.previousTrack()),
      onPlayPause: _switching
          ? null
          : () {
              if (playerState.isPlaying) {
                player.pause();
              } else {
                // play() is a synchronous FFI write on an already-loaded
                // source, so there is no Future to attach an error handler to
                // any more — a load failure surfaces from the awaited
                // launch() above instead. The catch stays for the rare
                // synchronous native throw, which would otherwise take down
                // the whole gesture with no feedback.
                try {
                  player.play();
                } catch (e) {
                  showPlayerErrorDialog(context,
                    action: () {
                      player.shutdown();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    error: e,
                  );
                }
              }
            },
      thirdIcon: Icons.skip_next,
      onThird: _switching ? null : () => _switchTrack((c) => c.nextTrack()),
    );
  }
}
