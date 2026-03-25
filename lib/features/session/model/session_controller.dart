import 'dart:math';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
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

  // Expose read-only for debugging/tests if needed
  int get answerGraphIndex => _answerGraphIndex;
  double get answerCenterFreq => _answerCenterFreq;

  /// Toggle peaking EQ on the player via controller to keep UI logic thin.
  Future<void> setEqEnabled(PlayerIsolate player, bool enabled) async {
    await player.setEQ(enabled);
  }

  Future<void> launchSession(
    PlayerIsolate player, {
    required AudioState audioState,
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
    required PlaylistService playlistService,
  }) async {
    try {
      // Reset Session
      sessionStore.resetPickerValue();
      sessionStore.resetResult();

      // Load enabled audio clip absolute paths
      final paths = await playlistService.listEnabledClipPaths();
      sessionStore.setPlaylistPaths(paths);

      // If List of Audio clips for Session is Not Empty
      if (sessionStore.playlistPaths.isNotEmpty) {
        // Open First AudioClip
        await player.launch(
          backend: audioState.backend,
          outputDeviceId: audioState.outputDevice?.id,
          path: sessionStore.playlistPaths[0],
        );
      } else {
        // ... else notify the playlist is empty.
        sessionStore.setSessionState(SessionState.playlistEmpty);
        return;
      }

      // Calculate Frequencies required for Session and Graph UI
      await sessionStore.initFrequency(sessionParameter: sessionParameter);

      // Start initialize Session (first round)
      await initSession(
        player,
        sessionStore: sessionStore,
        sessionParameter: sessionParameter,
      );

      // Notify the Session is Ready
      sessionStore.setSessionState(SessionState.ready);
    } catch (e) {
      sessionStore.setSessionState(SessionState.error);
      throw Exception(e.toString());
    }
  }

  // Collective Function for initializing a round.
  Future<void> initSession(
    PlayerIsolate player, {
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
  }) async {
    // Num of Graph
    final int numOfGraph = sessionStore.graphBarDataList.length;

    // Select Random Index of Graph (Correct Answer for Session)
    do {
      _answerGraphIndex = _random.nextInt(numOfGraph);
    } while (_answerGraphIndex == _prevAnswerGraphIndex); // make sure answer is different everytime
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

    // Disable EQ and set new freq/gain in a single isolate round-trip.
    await player.setEQParams(
      enableEQ: false,
      frequency: _answerCenterFreq,
      gainDb: _answerGain,
    );
  }

  /// Re-applies the current answer's EQ parameters to the player (e.g. after track switch).
  Future<void> updatePlayerState(PlayerIsolate player) async {
    await player.setEQFreq(_answerCenterFreq);
    await player.setEQGain(_answerGain);
  }

  Future<SessionSubmitResult> submitAnswer({
    required PlayerIsolate player,
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
    void Function(bool isCorrect, int correctIndex)? onResult,
  }) async {
    // Mark loading
    sessionStore.setSessionState(SessionState.loading);

    // Capture current round's correct answer index before it changes
    final int correctIndex = _answerGraphIndex + 1;
    final bool isCorrect = correctIndex == sessionStore.currentPickerValue;

    // Notify caller (e.g. to show a toast) without coupling to widget layer
    onResult?.call(isCorrect, correctIndex);

    // Apply result to session
    sessionStore.applySubmission(centerFreq: _answerCenterFreq, isCorrect: isCorrect);

    // Band threshold adjustments
    if (sessionStore.currentSessionPoint == sessionParameter.threshold && sessionParameter.startingBand < 25) {
      sessionParameter.startingBand++;
      sessionStore.resetSessionPoint();
      sessionStore.resetPickerValue();
      await sessionStore.initFrequency(sessionParameter: sessionParameter);
    } else if (sessionStore.currentSessionPoint == (0 - sessionParameter.threshold) && sessionParameter.startingBand > 2) {
      sessionParameter.startingBand--;
      sessionStore.resetSessionPoint();
      sessionStore.resetPickerValue();
      await sessionStore.initFrequency(sessionParameter: sessionParameter);
    }

    await initSession(
      player,
      sessionStore: sessionStore,
      sessionParameter: sessionParameter,
    );

    sessionStore.setSessionState(SessionState.ready);
    return SessionSubmitResult(isCorrect: isCorrect, correctIndex: correctIndex);
  }
}