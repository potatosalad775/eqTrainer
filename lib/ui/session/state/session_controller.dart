import 'dart:math';
import 'package:eq_trainer/data/audio_state.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/domain/session/clip_queue.dart';
import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/domain/session/session_rounds.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/ui/session/state/session_state.dart';

/// How a call to [SessionController.nextTrack] or
/// [SessionController.previousTrack] ended.
enum TrackSwitchStatus {
  /// Another clip is loaded and playing.
  switched,

  /// Previous was pressed deep into a clip, so it went back to the start
  /// instead.
  restarted,

  /// No clip in the queue could be found on disk, or the queue is empty.
  nothingPlayable,

  /// The clip chosen could not be loaded. [TrackSwitch.error] and
  /// [TrackSwitch.path] say why and which.
  failed,

  /// Another switch was still running, so this one did nothing.
  busy,
}

/// What a track switch did, for the screen to show.
class TrackSwitch {
  const TrackSwitch(
    this.status, {
    this.skipped = 0,
    this.error,
    this.path,
  });

  final TrackSwitchStatus status;

  /// How many clips were dropped from the queue on the way because they would
  /// not load.
  final int skipped;

  /// For [TrackSwitchStatus.failed], what the player threw.
  final Object? error;

  /// For [TrackSwitchStatus.failed], the last path that was tried.
  final String? path;
}

/// SessionController connects the session's rules to the audio and the screen.
///
/// There is one per session, made when the session page opens and dropped when
/// it closes, with the [SessionStore] it writes to. Which graph is the answer,
/// the score and the band ladder are [SessionRounds]'; this launches the
/// player, hands each round's band to it, and puts what changed into the store.
class SessionController {
  /// [settings] is the config as it was when the session started, so what the
  /// user does on the config page later cannot reach a running session.
  /// [random] is for tests that need to know which graph comes up.
  SessionController({
    required PlayerService player,
    required SessionStore sessionStore,
    required ClipLibrary clipLibrary,
    required AudioState audioState,
    required SessionSettings settings,
    required bool volumeCompensation,
    Random? random,
  })  : _player = player,
        _store = sessionStore,
        _clipLibrary = clipLibrary,
        _audioState = audioState,
        _settings = settings,
        _volumeCompensation = volumeCompensation,
        _random = random;

  final PlayerService _player;
  final SessionStore _store;
  final ClipLibrary _clipLibrary;
  final AudioState _audioState;
  final SessionSettings _settings;
  final bool _volumeCompensation;
  final Random? _random;

  /// The clips this session plays. Filled by [launch].
  ClipQueue _queue = ClipQueue(const []);

  /// True while a track switch is running, so a second tap cannot start
  /// another load before the first has finished.
  bool _switching = false;

  /// The queue's paths, for the error view's FFmpeg hint.
  List<String> get clipPaths => _queue.paths;

  /// The rules of the session, made once the player is open.
  SessionRounds? _rounds;

  /// How the session is going. This is what the result page shows.
  SessionResults get results => _rounds?.results ?? SessionResults.empty();

  Future<void> launch({
    // Checked before each write to the store after an await: a launch can
    // still finish after the page is gone, and writing to a disposed notifier
    // asserts. Callers that don't care can omit it.
    bool Function()? shouldContinue,
  }) async {
    bool active() => shouldContinue == null || shouldContinue();
    try {
      // Move to the loading/init state synchronously, before any await, so the
      // UI never renders ready buttons wired to a not-yet-launched player
      // during the async launch window.
      _store.setSessionState(SessionState.init);

      // Load enabled audio clip absolute paths
      final paths = await _clipLibrary.enabledClipPaths();
      if (!active()) return;
      _queue = ClipQueue(paths);

      // If List of Audio clips for Session is Not Empty
      if (!_queue.isEmpty) {
        // Open First AudioClip
        await _player.launch(
          androidBackend: _audioState.androidBackend,
          outputDevice: _audioState.outputDevice,
          path: _queue.current,
          volumeCompensation: _volumeCompensation,
        );
        if (!active()) return;
        // Q is fixed for the whole session, so it is applied once on the fresh
        // player here and re-applied only after a track switch.
        _player.setEQQ(_settings.qFactor);
      } else {
        // ... else notify the playlist is empty.
        if (active()) _store.setSessionState(SessionState.playlistEmpty);
        return;
      }

      // The first round is picked as the rounds are made.
      final rounds = SessionRounds(_settings, random: _random);
      _rounds = rounds;
      _store.applyLayout(rounds.layout);
      await _tune(rounds.current);
      if (!active()) return;

      // Notify the Session is Ready
      _store.setSessionState(SessionState.ready);
    } catch (e) {
      if (active()) _store.setSessionState(SessionState.error);
      throw Exception(e.toString());
    }
  }

  // Take the band out, wait for it to actually leave the signal, then retune
  // it: [PlayerService.setEQParams] owns that ordering, and it is the one EQ
  // call that genuinely awaits. (Q is session-constant and applied at launch,
  // not per round.)
  Future<void> _tune(Round round) {
    return _player.setEQParams(
      enableEQ: false,
      frequency: round.frequency,
      gainDb: round.gainDb,
    );
  }

  /// Moves to the next clip, and past the last to the first.
  Future<TrackSwitch> nextTrack() => _exclusive(() => _switchTrack(forward: true));

  /// Moves to the previous clip, or to the start of this one when it has been
  /// playing for more than three seconds. This is the only home of that rule.
  Future<TrackSwitch> previousTrack() => _exclusive(() async {
        if (_player.fetchPosition > const Duration(seconds: 3)) {
          await _player.seek(Duration.zero);
          return const TrackSwitch(TrackSwitchStatus.restarted);
        }
        return _switchTrack(forward: false);
      });

  // Rapid taps would otherwise interleave concurrent loads, and the queue could
  // advance before the previous load even finished.
  Future<TrackSwitch> _exclusive(Future<TrackSwitch> Function() action) async {
    if (_switching) return const TrackSwitch(TrackSwitchStatus.busy);
    _switching = true;
    try {
      return await action();
    } finally {
      _switching = false;
    }
  }

  /// Steps one clip and loads the first one that plays.
  ///
  /// The session plays from a snapshot taken at launch, and a clip's file can
  /// be rewritten to another format underneath it while the session runs (see
  /// `ClipLibrary.resolvePath`). A stale entry used to throw out of `launch()`
  /// and end the session, losing the user's score over a file that is still
  /// perfectly playable under a different extension. So the path is resolved
  /// first, and the resolved one written back, which means the lookup is paid
  /// once per clip rather than on every visit to it.
  ///
  /// Two kinds of unplayable clip are treated differently. One with no file is
  /// skipped and stays in the queue, since the file may come back and only the
  /// user deletes a clip (ADR 0003). One that is there but fails to load is
  /// dropped for the rest of the session and counted, so the user can be told.
  /// If none can be loaded, the switch fails and the session ends as before.
  ///
  /// Bounded by the queue's length at the start so a library that vanished
  /// entirely stops rather than looping. The last candidate can be the clip that
  /// was playing, which is loaded again.
  Future<TrackSwitch> _switchTrack({required bool forward}) async {
    final attempts = _queue.length;
    var skipped = 0;
    Object? lastError;
    String? lastPath;
    // Taken before the first load and kept: launch() takes the band out before
    // it tries to read the file, so after a failed load the player already
    // says it is off, and the view the user chose would be lost.
    bool? wasEqEnabled;

    forward ? _queue.stepForward() : _queue.stepBack();
    for (var attempt = 0; attempt < attempts; attempt++) {
      final candidate = _queue.current;
      if (candidate == null) break;

      final resolved = await _clipLibrary.resolvePath(candidate);
      if (resolved == null) {
        forward ? _queue.stepForward() : _queue.stepBack();
        continue;
      }
      _queue.replaceCurrent(resolved);

      wasEqEnabled ??= _player.fetchEQState;
      try {
        await _relaunchWith(resolved, eqEnabled: wasEqEnabled);
        return TrackSwitch(TrackSwitchStatus.switched, skipped: skipped);
      } catch (e) {
        lastError = e;
        lastPath = resolved;
        skipped++;
        // Leaves the cursor on the clip that comes next in this direction.
        _queue.removeCurrent(forward: forward);
      }
    }
    if (skipped > 0) {
      return TrackSwitch(
        TrackSwitchStatus.failed,
        skipped: skipped,
        error: lastError,
        path: lastPath,
      );
    }
    return const TrackSwitch(TrackSwitchStatus.nothingPlayable);
  }

  /// [eqEnabled] is the Original or Filtered view from before the switch began:
  /// launch() always takes the band back out, so it is re-applied afterwards, and
  /// a manually-toggled "Filtered" view doesn't silently become "Original" on the
  /// new track.
  Future<void> _relaunchWith(String path, {required bool eqEnabled}) async {
    _player.pause();
    // No shutdown() first: launch() disposes the old source itself and keeps
    // the engine and its output device open, so a track switch no longer pays
    // a device re-open.
    await _player.launch(
      androidBackend: _audioState.androidBackend,
      outputDevice: _audioState.outputDevice,
      path: path,
      volumeCompensation: _volumeCompensation,
    );
    // The page can close while the clip is loading, and it takes the player
    // with it.
    if (_store.isDisposed) return;
    _reapplyRound(eqEnabled: eqEnabled);
    _player.play();
  }

  /// Re-applies the current answer's EQ parameters after a track switch.
  ///
  /// [PlayerService.launch] takes the band back out (the filter is global and
  /// outlives the voice, so it has to), and the new voice starts at volume
  /// 1.0, so the gain has to be re-sent for its loudness compensation to land
  /// on the new handle. [eqEnabled] is the enabled state from before the
  /// switch.
  void _reapplyRound({required bool eqEnabled}) {
    _player.setEQQ(_settings.qFactor);
    final round = _rounds?.current;
    if (round != null) {
      _player.setEQFreq(round.frequency);
      _player.setEQGain(round.gainDb);
    }
    _player.setEQ(eqEnabled);
  }

  /// Scores the graph the picker is on and moves to the next round.
  ///
  /// Returns what happened, or null when the submit was ignored or failed.
  /// [onResult] gets whether it was right and the 0-based index of the right
  /// graph, before the next round is set up.
  Future<RoundOutcome?> submitAnswer({
    void Function(bool isCorrect, int correctGraphIndex)? onResult,
  }) async {
    final rounds = _rounds;
    // Re-entrancy guard: only a round that is currently `ready` can be
    // submitted. A double-tap within one frame (before InteractionLock's
    // rebuild absorbs the second tap) would otherwise score the same round
    // twice and move the session point by ±2.
    if (rounds == null || _store.sessionState != SessionState.ready) {
      return null;
    }

    // Mark loading
    _store.setSessionState(SessionState.loading);

    try {
      final outcome = rounds.submit(_store.currentGraphIndex);

      // Notify caller (e.g. to show a toast) without coupling to widget layer
      onResult?.call(outcome.isCorrect, outcome.correctGraphIndex);

      _store.setResults(rounds.results);
      if (outcome.bandCountChanged) {
        // The graph layout changed size and meaning, so the picker goes back
        // to the first graph along with it.
        _store.applyLayout(rounds.layout);
      }

      await _tune(outcome.next);

      // The page can close while the band is being retuned.
      if (_store.isDisposed) return null;
      _store.setSessionState(SessionState.ready);
      return outcome;
    } catch (e) {
      // A throw here (e.g. from setEQParams) would otherwise leave
      // sessionState stuck at `loading`, and InteractionLock would freeze the
      // session permanently.
      if (!_store.isDisposed) _store.setSessionState(SessionState.error);
      return null;
    }
  }
}
