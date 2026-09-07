import 'dart:math';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/player_service.dart';
import 'package:eq_trainer/shared/service/playlist_service.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/session_state.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';

class SessionSubmitResult {
  const SessionSubmitResult({
    required this.isCorrect,
    required this.correctIndex,
  });
  final bool isCorrect;
  // 1-based index as shown to the user
  final int correctIndex;
}

/// SessionController centralizes session launch, round submission and next-round init.
class SessionController {
  SessionController();

  // --- Internal round state ---
  final _random = Random();
  late int _answerGraphIndex;
  int _prevAnswerGraphIndex = -1;
  late int _answerFreqIndex;
  late double _answerCenterFreq;
  late double _answerGain;

  // EQ bandwidth is fixed for the whole session (set from config at launch),
  // not part of a round's answer. Kept so it can be re-applied to a fresh
  // player after a track switch.
  double _qFactor = 1;

  // Expose read-only for debugging/tests if needed
  int get answerGraphIndex => _answerGraphIndex;
  double get answerCenterFreq => _answerCenterFreq;

  /// Toggle peaking EQ on the player via controller to keep UI logic thin.
  void setEqEnabled(PlayerService player, bool enabled) {
    player.setEQ(enabled);
  }

  Future<void> launchSession(
    PlayerService player, {
    required AudioState audioState,
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
    required PlaylistService playlistService,
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

      // Reset Session
      _prevAnswerGraphIndex = -1;
      sessionStore.resetPickerValue();
      sessionStore.resetResult();

      // Load enabled audio clip absolute paths
      final paths = await playlistService.listEnabledClipPaths();
      if (!active()) return;
      sessionStore.setPlaylistPaths(paths);

      // Q is fixed for the whole session; capture it once so a track switch
      // can re-apply it to the fresh player.
      _qFactor = sessionParameter.qFactor;

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

      // Calculate Frequencies required for Session and Graph UI
      await sessionStore.initFrequency(sessionParameter: sessionParameter);
      if (!active()) return;

      // Start initialize Session (first round)
      await initSession(
        player,
        sessionStore: sessionStore,
        sessionParameter: sessionParameter,
      );
      if (!active()) return;

      // Notify the Session is Ready
      sessionStore.setSessionState(SessionState.ready);
    } catch (e) {
      if (active()) sessionStore.setSessionState(SessionState.error);
      throw Exception(e.toString());
    }
  }

  // Collective Function for initializing a round.
  Future<void> initSession(
    PlayerService player, {
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
  }) async {
    // Num of Graph
    final int numOfGraph = sessionStore.graphBarDataList.length;

    // Select Random Index of Graph (Correct Answer for Session).
    // With only 2 graphs (e.g. peak-only/dip-only at band count 1), forbidding
    // a repeat forces a strict 1,2,1,2,... alternation the user can solve
    // without listening. Only forbid repeats when there's a real choice.
    do {
      _answerGraphIndex = _random.nextInt(numOfGraph);
    } while (numOfGraph > 2 && _answerGraphIndex == _prevAnswerGraphIndex);
    _prevAnswerGraphIndex = _answerGraphIndex;

    if (sessionParameter.filterType == FilterType.peakDip) {
      _answerFreqIndex = (_answerGraphIndex / 2).floor();
    } else {
      _answerFreqIndex = _answerGraphIndex;
    }
    _answerCenterFreq = sessionStore.centerFreqLogList[_answerFreqIndex];

    // Determine Appropriate Gain Value
    // if chosen graph is dip graph, invert gain value of session.
    if (sessionParameter.filterType == FilterType.dip ||
        (sessionParameter.filterType == FilterType.peakDip && _answerGraphIndex % 2 == 1)) {
      _answerGain = 0 - sessionParameter.gain.toDouble();
    } else {
      _answerGain = sessionParameter.gain.toDouble();
    }

    // Take the band out, wait for it to actually leave the signal, then
    // retune it — [PlayerService.setEQParams] owns that ordering, and it is
    // the one EQ call that genuinely awaits. (Q is session-constant and
    // applied at launch, not per round.)
    await player.setEQParams(
      enableEQ: false,
      frequency: _answerCenterFreq,
      gainDb: _answerGain,
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
    player.setEQFreq(_answerCenterFreq);
    player.setEQGain(_answerGain);
    player.setEQ(eqEnabled);
  }

  Future<SessionSubmitResult?> submitAnswer({
    required PlayerService player,
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
    void Function(bool isCorrect, int correctIndex)? onResult,
  }) async {
    // Re-entrancy guard: only a round that is currently `ready` can be
    // submitted. A double-tap within one frame (before InteractionLock's
    // rebuild absorbs the second tap) would otherwise score the same round
    // twice and move the session point by ±2.
    if (sessionStore.sessionState != SessionState.ready) return null;

    // Mark loading
    sessionStore.setSessionState(SessionState.loading);

    try {
      // Capture current round's correct answer index before it changes
      final int correctIndex = _answerGraphIndex + 1;
      final bool isCorrect = correctIndex == sessionStore.currentPickerValue;

      // Notify caller (e.g. to show a toast) without coupling to widget layer
      onResult?.call(isCorrect, correctIndex);

      // Apply result to session
      sessionStore.applySubmission(centerFreq: _answerCenterFreq, isCorrect: isCorrect);

      // Band threshold adjustments. Use >=/<= rather than == so a point that
      // already overshot the threshold (see the clamp branches below) still
      // fires the adjustment instead of requiring an exact match.
      if (sessionStore.currentSessionPoint >= sessionParameter.threshold) {
        if (sessionParameter.startingBand < 25) {
          sessionParameter.startingBand++;
          sessionStore.resetSessionPoint();
          sessionStore.resetPickerValue();
          // The graph layout is about to change size/meaning; a stale index
          // from the old layout must not suppress a legitimate repeat (or,
          // in principle, sit outside the new range) in the next round.
          _prevAnswerGraphIndex = -1;
          await sessionStore.initFrequency(sessionParameter: sessionParameter);
        } else {
          // Already at the top band: clamp instead of letting further correct
          // answers push the point past the threshold, which would otherwise
          // force clawing back through the whole overshoot before a band
          // decrease could ever fire again.
          sessionStore.setCurrentSessionPoint(sessionParameter.threshold);
        }
      } else if (sessionStore.currentSessionPoint <= (0 - sessionParameter.threshold)) {
        if (sessionParameter.startingBand > 2) {
          sessionParameter.startingBand--;
          sessionStore.resetSessionPoint();
          sessionStore.resetPickerValue();
          _prevAnswerGraphIndex = -1;
          await sessionStore.initFrequency(sessionParameter: sessionParameter);
        } else {
          sessionStore.setCurrentSessionPoint(0 - sessionParameter.threshold);
        }
      }

      await initSession(
        player,
        sessionStore: sessionStore,
        sessionParameter: sessionParameter,
      );

      sessionStore.setSessionState(SessionState.ready);
      return SessionSubmitResult(isCorrect: isCorrect, correctIndex: correctIndex);
    } catch (e) {
      // A throw here (e.g. from initFrequency/setEQParams) would otherwise
      // leave sessionState stuck at `loading`, and InteractionLock would
      // freeze the session permanently.
      sessionStore.setSessionState(SessionState.error);
      return null;
    }
  }
}