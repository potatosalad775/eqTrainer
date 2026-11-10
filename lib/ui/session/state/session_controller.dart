import 'dart:math';
import 'package:eq_trainer/data/audio_state.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/domain/session/session_parameter.dart';
import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/domain/session/session_rounds.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/ui/session/state/session_state.dart';

/// SessionController connects the session's rules to the audio and the screen.
///
/// Which graph is the answer, the score and the band ladder are
/// [SessionRounds]'; this launches the player, hands each round's band to it,
/// and puts what changed into the [SessionStore].
class SessionController {
  /// [random] is for tests that need to know which graph comes up.
  SessionController({Random? random}) : _random = random;

  final Random? _random;

  /// The rules of the session in progress; every launch makes a new one.
  SessionRounds? _rounds;

  // EQ bandwidth is fixed for the whole session (set from config at launch),
  // not part of a round's answer. Kept so it can be re-applied to a fresh
  // player after a track switch.
  double _qFactor = 1;

  /// How the session in progress is going. This is what the result page shows.
  SessionResults get results => _rounds?.results ?? SessionResults.empty();

  /// Toggle peaking EQ on the player via controller to keep UI logic thin.
  void setEqEnabled(PlayerService player, bool enabled) {
    player.setEQ(enabled);
  }

  Future<void> launchSession(
    PlayerService player, {
    required AudioState audioState,
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
    required ClipLibrary clipLibrary,
    required bool volumeCompensation,
    // Checked before each write to the (app-scoped) SessionStore after an
    // await, so exiting the session page mid-launch doesn't leave a stray
    // ready/error/playlistEmpty state written into a store that outlives
    // this page. Callers that don't care can omit it.
    bool Function()? shouldContinue,
  }) async {
    bool active() => shouldContinue == null || shouldContinue();
    try {
      // Move to the loading/init state synchronously, before any await, so a
      // relaunch of the app-scoped SessionStore does not render the previous
      // session's ready UI (stale graphs, live buttons wired to a not-yet-
      // launched player) during the async launch window.
      sessionStore.setSessionState(SessionState.init);

      // The settings are frozen here, so what the user does on the config page
      // later cannot reach a session that is already running.
      final settings = sessionParameter.snapshot();

      // Reset Session
      _rounds = null;
      sessionStore.resetPickerValue();
      sessionStore.setResults(SessionResults.empty());

      // Load enabled audio clip absolute paths
      final paths = await clipLibrary.enabledClipPaths();
      if (!active()) return;
      sessionStore.setPlaylistPaths(paths);

      // Q is fixed for the whole session; capture it once so a track switch
      // can re-apply it to the fresh player.
      _qFactor = settings.qFactor;

      // If List of Audio clips for Session is Not Empty
      if (sessionStore.playlistPaths.isNotEmpty) {
        // Open First AudioClip
        await player.launch(
          androidBackend: audioState.androidBackend,
          outputDevice: audioState.outputDevice,
          path: sessionStore.playlistPaths[0],
          volumeCompensation: volumeCompensation,
        );
        if (!active()) return;
        // Apply the session's EQ bandwidth once on the fresh player.
        player.setEQQ(_qFactor);
      } else {
        // ... else notify the playlist is empty.
        if (active()) sessionStore.setSessionState(SessionState.playlistEmpty);
        return;
      }

      // The first round is picked as the rounds are made.
      final rounds = SessionRounds(settings, random: _random);
      _rounds = rounds;
      sessionStore.applyLayout(rounds.layout);
      await _tune(player, rounds.current);
      if (!active()) return;

      // Notify the Session is Ready
      sessionStore.setSessionState(SessionState.ready);
    } catch (e) {
      if (active()) sessionStore.setSessionState(SessionState.error);
      throw Exception(e.toString());
    }
  }

  // Take the band out, wait for it to actually leave the signal, then retune
  // it: [PlayerService.setEQParams] owns that ordering, and it is the one EQ
  // call that genuinely awaits. (Q is session-constant and applied at launch,
  // not per round.)
  Future<void> _tune(PlayerService player, Round round) {
    return player.setEQParams(
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
  void updatePlayerState(PlayerService player, {required bool eqEnabled}) {
    player.setEQQ(_qFactor);
    final round = _rounds?.current;
    if (round != null) {
      player.setEQFreq(round.frequency);
      player.setEQGain(round.gainDb);
    }
    player.setEQ(eqEnabled);
  }

  /// Scores the graph the picker is on and moves to the next round.
  ///
  /// Returns what happened, or null when the submit was ignored or failed.
  /// [onResult] gets whether it was right and the 0-based index of the right
  /// graph, before the next round is set up.
  Future<RoundOutcome?> submitAnswer({
    required PlayerService player,
    required SessionStore sessionStore,
    void Function(bool isCorrect, int correctGraphIndex)? onResult,
  }) async {
    final rounds = _rounds;
    // Re-entrancy guard: only a round that is currently `ready` can be
    // submitted. A double-tap within one frame (before InteractionLock's
    // rebuild absorbs the second tap) would otherwise score the same round
    // twice and move the session point by ±2.
    if (rounds == null || sessionStore.sessionState != SessionState.ready) {
      return null;
    }

    // Mark loading
    sessionStore.setSessionState(SessionState.loading);

    try {
      final outcome = rounds.submit(sessionStore.currentGraphIndex);

      // Notify caller (e.g. to show a toast) without coupling to widget layer
      onResult?.call(outcome.isCorrect, outcome.correctGraphIndex);

      sessionStore.setResults(rounds.results);
      if (outcome.bandCountChanged) {
        // The graph layout changed size and meaning, so the picker goes back
        // to the first graph along with it.
        sessionStore.applyLayout(rounds.layout);
      }

      await _tune(player, outcome.next);

      sessionStore.setSessionState(SessionState.ready);
      return outcome;
    } catch (e) {
      // A throw here (e.g. from setEQParams) would otherwise leave
      // sessionState stuck at `loading`, and InteractionLock would freeze the
      // session permanently.
      sessionStore.setSessionState(SessionState.error);
      return null;
    }
  }
}
