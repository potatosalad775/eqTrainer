import 'dart:math';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/session/session_frequency.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';
import 'package:eq_trainer/model/session/session_result.dart';
import 'package:eq_trainer/model/state/session_state_data.dart';
import 'package:eq_trainer/player/player_isolate.dart';
import 'package:eq_trainer/model/state/session_store.dart';
import 'package:eq_trainer/service/playlist_service.dart';

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
  late int _answerGraphIndex;
  int _prevAnswerGraphIndex = -1;
  late int _answerFreqIndex;
  late double _answerCenterFreq;
  late double _answerGain;

  // Expose read-only for debugging/tests if needed
  int get answerGraphIndex => _answerGraphIndex;
  double get answerCenterFreq => _answerCenterFreq;

  Future<void> launchSession(
    PlayerIsolate player, {
    required AudioState audioState,
    required SessionStateData sessionState,
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
    required SessionResultData sessionResult,
    required SessionFrequencyData sessionFreqData,
    required PlaylistService playlistService,
  }) async {
    try {
      // Reset Session
      sessionResult.resetResult();
      sessionFreqData.resetPickerValue();

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
        sessionState.sessionState = SessionState.playlistEmpty;
        return;
      }

      // Calculate Frequencies required for Session and Graph UI
      await sessionFreqData.initSessionFreqData(sessionParameter: sessionParameter);

      // Start initialize Session (first round)
      await initSession(
        player,
        audioState: audioState,
        sessionState: sessionState,
        sessionStore: sessionStore,
        sessionParameter: sessionParameter,
        sessionResult: sessionResult,
        sessionFreqData: sessionFreqData,
      );

      // Notify the Session is Ready
      sessionState.sessionState = SessionState.ready;
    } catch (e) {
      sessionState.sessionState = SessionState.error;
      throw Exception(e.toString());
    }
  }

  // Collective Function for initializing a round.
  Future<void> initSession(
    PlayerIsolate player, {
    required AudioState audioState,
    required SessionStateData sessionState,
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
    required SessionResultData sessionResult,
    required SessionFrequencyData sessionFreqData,
  }) async {
    // Reset pEQ Status
    player.setEQ(false);

    // Num of Graph
    final int numOfGraph = sessionFreqData.graphBarDataList.length;

    // Select Random Index of Graph (Correct Answer for Session)
    do {
      final random = Random();
      _answerGraphIndex = random.nextInt(numOfGraph);
    } while (_answerGraphIndex == _prevAnswerGraphIndex); // make sure answer is different everytime
    _prevAnswerGraphIndex = _answerGraphIndex;

    if (sessionParameter.filterType == FilterType.peakDip) {
      _answerFreqIndex = (_answerGraphIndex / 2).floor();
    } else {
      _answerFreqIndex = _answerGraphIndex;
    }
    _answerCenterFreq = sessionFreqData.centerFreqLogList[_answerFreqIndex];

    // Determine Appropriate Gain Value
    // if chosen graph is dip graph, invert gain value of session.
    if (sessionParameter.filterType == FilterType.dip ||
        (sessionParameter.filterType == FilterType.peakDip && _answerGraphIndex % 2 == 1)) {
      _answerGain = 0 - sessionParameter.gain.toDouble();
    } else {
      _answerGain = sessionParameter.gain.toDouble();
    }

    await updatePlayerState(player);
  }

  Future<void> updatePlayerState(PlayerIsolate player) async {
    // debugPrint("Updating Player EQ with Freq: $_answerCenterFreq, Gain: $_answerGain");
    player.setEQFreq(_answerCenterFreq);
    player.setEQGain(_answerGain);
  }

  Future<SessionSubmitResult> submitAnswer({
    required PlayerIsolate player,
    required AudioState audioState,
    required SessionFrequencyData freqData,
    required SessionStateData stateData,
    required SessionResultData resultData,
    required SessionStore sessionStore,
    required SessionParameter sessionParameter,
  }) async {
    // Mark loading
    stateData.sessionState = SessionState.loading;

    // Capture current round's correct answer index before it changes
    final int correctIndex = _answerGraphIndex + 1;

    // Judge answer
    final bool isCorrect = (correctIndex == freqData.currentPickerValue);

    if (isCorrect) {
      stateData.currentSessionPoint++;
      resultData.updateResultFromFreq(_answerCenterFreq, true);
    } else {
      stateData.currentSessionPoint--;
      resultData.updateResultFromFreq(_answerCenterFreq, false);
    }

    // Band threshold adjustments
    if (stateData.currentSessionPoint == sessionParameter.threshold && sessionParameter.startingBand < 25) {
      stateData.currentSessionPoint = 0;
      stateData.selectedPickerNum = 1;
      sessionParameter.startingBand++;
      await freqData.initSessionFreqData(sessionParameter: sessionParameter);
    } else if (stateData.currentSessionPoint == (0 - sessionParameter.threshold) && sessionParameter.startingBand > 2) {
      stateData.currentSessionPoint = 0;
      stateData.selectedPickerNum = 1;
      sessionParameter.startingBand--;
      await freqData.initSessionFreqData(sessionParameter: sessionParameter);
    }

    // Initialize next round
    await initSession(
      player,
      audioState: audioState,
      sessionState: stateData,
      sessionStore: sessionStore,
      sessionParameter: sessionParameter,
      sessionResult: resultData,
      sessionFreqData: freqData,
    );

    // Ready
    stateData.sessionState = SessionState.ready;

    return SessionSubmitResult(isCorrect: isCorrect, correctIndex: correctIndex);
  }
}