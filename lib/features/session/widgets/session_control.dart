import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:eq_trainer/shared/model/error.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/shared/widget/player_control_buttons.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';

class SessionControl extends StatelessWidget {

  const SessionControl({super.key});

  Future<void> _relaunchWith(
    BuildContext context,
    String path, {
    required AudioDeviceBackend backend,
    required AudioDeviceId? outputDeviceId,
  }) async {
    final player = context.read<PlayerIsolate>();
    await player.pause();
    await player.shutdown();
    await player.launch(
      backend: backend,
      outputDeviceId: outputDeviceId,
      path: path,
    );
    if (context.mounted) await context.read<SessionController>().updatePlayerState(player);
    await player.play();
  }

  Future<void> _playerNext(
    BuildContext context, {
    required AudioDeviceBackend backend,
    required AudioDeviceId? outputDeviceId,
  }) async {
    final sessionStore = context.read<SessionStore>();
    if (sessionStore.playlistPaths.isEmpty) return;
    sessionStore.nextTrack();
    final nextPath = sessionStore.currentClipPath;
    if (nextPath != null) {
      await _relaunchWith(context, nextPath, backend: backend, outputDeviceId: outputDeviceId);
    }
  }

  Future<void> _playerPrevious(
    BuildContext context, {
    required AudioDeviceBackend backend,
    required AudioDeviceId? outputDeviceId,
  }) async {
    final player = context.read<PlayerIsolate>();
    
    // If player position > 3 seconds, reset to 0 instead of going to previous
    if (player.fetchPosition > const AudioTime(3)) {
      await player.seek(AudioTime.zero);
      return;
    }
    final sessionStore = context.read<SessionStore>();
    if (sessionStore.playlistPaths.isEmpty) return;
    sessionStore.previousTrack();
    final prevPath = sessionStore.currentClipPath;
    if (prevPath != null) {
      await _relaunchWith(context, prevPath, backend: backend, outputDeviceId: outputDeviceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (backend, outputDeviceId) = context.select<AudioState, (AudioDeviceBackend, AudioDeviceId?)>(
      (s) => (s.backend, s.outputDevice?.id),
    );
    final player = context.read<PlayerIsolate>();
    final playerState = context.select<PlayerIsolate, PlayerStateResponse>((p) => p.fetchPlayerState);

    return PlayerControlButtons(
      isPlaying: playerState.isPlaying,
      onPrevious: () async {
        await _playerPrevious(context, backend: backend, outputDeviceId: outputDeviceId);
      },
      onPlayPause: () {
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
      thirdIcon: Icons.skip_next,
      onThird: () async {
        await _playerNext(context, backend: backend, outputDeviceId: outputDeviceId);
      },
    );
  }
}
