import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:eq_trainer/shared/model/error.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/player_service.dart';
import 'package:eq_trainer/shared/service/playlist_service.dart';
import 'package:eq_trainer/shared/widget/player_control_buttons.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';

class SessionControl extends StatefulWidget {

  const SessionControl({super.key});

  @override
  State<SessionControl> createState() => _SessionControlState();
}

class _SessionControlState extends State<SessionControl> {
  // Guards previous/next while a track switch (pause -> launch -> play) is in
  // flight. Without it, rapid taps interleave concurrent launches and the
  // playlist index can advance before the previous relaunch even finishes.
  bool _switching = false;

  Future<void> _relaunchWith(
    BuildContext context,
    String path, {
    required AndroidAudioBackend androidBackend,
    required PlaybackDevice? outputDevice,
  }) async {
    final player = context.read<PlayerService>();
    // Capture the pre-switch EQ state: launch() always takes the band back
    // out, and updatePlayerState needs to know whether to re-enable it so a
    // manually-toggled "Filtered" view doesn't silently become "Original" on
    // the new track.
    final wasEqEnabled = player.fetchEQState;
    final volumeCompensation = context.read<MiscSettingsProvider>().volumeCompensation;
    try {
      player.pause();
      // No shutdown() first: launch() disposes the old source itself and
      // keeps the engine and its output device open, so a track switch no
      // longer pays a device re-open.
      await player.launch(
        androidBackend: androidBackend,
        outputDevice: outputDevice,
        path: path,
        volumeCompensation: volumeCompensation,
      );
      if (context.mounted) {
        context.read<SessionController>().updatePlayerState(player, eqEnabled: wasEqEnabled);
        player.play();
      }
    } catch (e) {
      if (context.mounted) {
        await showPlayerErrorDialog(context,
          action: () {
            player.shutdown();
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          error: e,
        );
      }
    }
  }

  /// Steps one track and returns a path that is actually on disk, skipping
  /// clips that are not.
  ///
  /// The session plays from a snapshot taken at launch, and a clip's file can
  /// be rewritten to another format underneath it while the session runs (see
  /// `PlaylistService.resolveClipPath`). Before this, a stale entry threw out
  /// of `launch()` into the error dialog below, which pops twice and ends the
  /// session — losing the user's score over a file that is still perfectly
  /// playable under a different extension.
  ///
  /// Bounded by the playlist length so a library that vanished entirely stops
  /// rather than looping.
  Future<String?> _stepToPlayable(BuildContext context, {required bool forward}) async {
    final sessionStore = context.read<SessionStore>();
    final playlistService = context.read<PlaylistService>();

    for (var attempt = 0; attempt < sessionStore.playlistPaths.length; attempt++) {
      forward ? sessionStore.nextTrack() : sessionStore.previousTrack();

      final candidate = sessionStore.currentClipPath;
      if (candidate == null) return null;

      final resolved = await playlistService.resolveClipPath(candidate);
      if (resolved != null) {
        sessionStore.updatePathAt(sessionStore.currentPlayingAudioIndex, resolved);
        return resolved;
      }
    }
    return null;
  }

  Future<void> _playerNext(
    BuildContext context, {
    required AndroidAudioBackend androidBackend,
    required PlaybackDevice? outputDevice,
  }) async {
    final sessionStore = context.read<SessionStore>();
    if (sessionStore.playlistPaths.isEmpty) return;
    final nextPath = await _stepToPlayable(context, forward: true);
    if (!context.mounted) return;
    if (nextPath != null) {
      await _relaunchWith(context, nextPath,
          androidBackend: androidBackend, outputDevice: outputDevice);
    }
  }

  Future<void> _playerPrevious(
    BuildContext context, {
    required AndroidAudioBackend androidBackend,
    required PlaybackDevice? outputDevice,
  }) async {
    final player = context.read<PlayerService>();

    // If player position > 3 seconds, reset to 0 instead of going to previous
    if (player.fetchPosition > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
      return;
    }
    final sessionStore = context.read<SessionStore>();
    if (sessionStore.playlistPaths.isEmpty) return;
    final prevPath = await _stepToPlayable(context, forward: false);
    if (!context.mounted) return;
    if (prevPath != null) {
      await _relaunchWith(context, prevPath,
          androidBackend: androidBackend, outputDevice: outputDevice);
    }
  }

  Future<void> _guardedSwitch(Future<void> Function() action) async {
    if (_switching) return;
    setState(() => _switching = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (androidBackend, outputDevice) =
        context.select<AudioState, (AndroidAudioBackend, PlaybackDevice?)>(
      (s) => (s.androidBackend, s.outputDevice),
    );
    final player = context.read<PlayerService>();
    final playerState = context.select<PlayerService, PlayerStateResponse>((p) => p.fetchPlayerState);

    return PlayerControlButtons(
      isPlaying: playerState.isPlaying,
      onPrevious: _switching
          ? null
          : () => _guardedSwitch(() => _playerPrevious(context,
              androidBackend: androidBackend, outputDevice: outputDevice)),
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
      onThird: _switching
          ? null
          : () => _guardedSwitch(() => _playerNext(context,
              androidBackend: androidBackend, outputDevice: outputDevice)),
    );
  }
}
