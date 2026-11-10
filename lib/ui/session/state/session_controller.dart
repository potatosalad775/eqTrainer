import 'dart:math';
import 'package:eq_trainer/data/audio_state.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/domain/session/session_rounds.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/ui/session/state/session_state.dart';

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
      _store.setPlaylistPaths(paths);

      // If List of Audio clips for Session is Not Empty
      if (_store.playlistPaths.isNotEmpty) {
        // Open First AudioClip
        await _player.launch(
          androidBackend: _audioState.androidBackend,
          outputDevice: _audioState.outputDevice,
          path: _store.playlistPaths[0],
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

  /// Re-applies the current answer's EQ parameters after a track switch.
  ///
  /// [PlayerService.launch] takes the band back out (the filter is global and
  /// outlives the voice, so it has to), and the new voice starts at volume
  /// 1.0 — so the gain has to be re-sent for its loudness compensation to
  /// land on the new handle. [eqEnabled] is the enabled state from before the
  /// switch, so a manually-toggled "Filtered" view doesn't silently revert to
  /// "Original".
  void updatePlayerState({required bool eqEnabled}) {
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
