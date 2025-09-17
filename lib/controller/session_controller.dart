import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/session/session_frequency.dart';
import 'package:eq_trainer/model/session/session_model.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';
import 'package:eq_trainer/model/session/session_playlist.dart';
import 'package:eq_trainer/model/session/session_result.dart';
import 'package:eq_trainer/model/state/session_state_data.dart';
import 'package:eq_trainer/player/player_isolate.dart';

class SessionSubmitResult {
  const SessionSubmitResult({
    required this.isCorrect,
    required this.correctIndex,
  });
  final bool isCorrect;
  // 1-based index as shown to the user
  final int correctIndex;
}

/// SessionController centralizes session round submission and next-round init.
class SessionController {
  const SessionController();

  Future<SessionSubmitResult> submitAnswer({
    required PlayerIsolate player,
    required AudioState audioState,
    required SessionModel sessionModel,
    required SessionFrequencyData freqData,
    required SessionStateData stateData,
    required SessionResultData resultData,
    required SessionPlaylist sessionPlaylist,
    required SessionParameter sessionParameter,
  }) async {
    // Mark loading
    stateData.sessionState = SessionState.loading;

    // Capture current round's correct answer index before it changes
    final int correctIndex = sessionModel.answerGraphIndex + 1;

    // Judge answer
    final bool isCorrect = (correctIndex == freqData.currentPickerValue);

    if (isCorrect) {
      stateData.currentSessionPoint++;
      resultData.updateResultFromFreq(sessionModel.answerCenterFreq, true);
    } else {
      stateData.currentSessionPoint--;
      resultData.updateResultFromFreq(sessionModel.answerCenterFreq, false);
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
    await sessionModel.initSession(
      player,
      audioState: audioState,
      sessionState: stateData,
      sessionPlaylist: sessionPlaylist,
      sessionParameter: sessionParameter,
      sessionResult: resultData,
      sessionFreqData: freqData,
    );

    // Ready
    stateData.sessionState = SessionState.ready;

    return SessionSubmitResult(isCorrect: isCorrect, correctIndex: correctIndex);
  }
}
