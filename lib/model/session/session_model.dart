import 'dart:math';
import 'package:flutter/material.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/session/session_frequency.dart';
import 'package:eq_trainer/model/session/session_result.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';
import 'package:eq_trainer/model/state/session_state_data.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/player/player_isolate.dart';
import 'package:eq_trainer/model/state/session_store.dart';
import 'package:eq_trainer/service/playlist_service.dart';

class SessionModel extends ChangeNotifier {
  // Random Answer for Session Round - in Graph Index
  late int answerGraphIndex;
  int prevAnswerGraphIndex = -1;
  // Random Answer for Session Round - in Center Frequency
  late int answerFreqIndex;
  // center frequency applied to EQ
  late double answerCenterFreq;
  // gain applied to EQ
  late double answerGain;

  final sessionResultData = SessionResultData();

  Future<void> launchSession(PlayerIsolate player, {
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
      sessionResultData.resetResult();
      sessionFreqData.resetPickerValue();
      // Load enabled audio clip absolute paths
      final paths = await playlistService.listEnabledClipPaths();
      sessionStore.setPlaylistPaths(paths);
      // If List of Audio clips for Session is Not Empty
      if(sessionStore.playlistPaths.isNotEmpty) {
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
      // Start initialize Session
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

  // Collective Function for initializing Session.
  Future<void> initSession(PlayerIsolate player, {
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
    int numOfGraph = sessionFreqData.graphBarDataList.length;

    // Select Random Index of Graph
    // = Correct Answer for Session
    do {
      final random = Random();
      answerGraphIndex = random.nextInt(numOfGraph);
    } while (answerGraphIndex == prevAnswerGraphIndex); // make sure answer is different everytime
    prevAnswerGraphIndex = answerGraphIndex;

    if(sessionParameter.filterType == FilterType.peakDip) {
      answerFreqIndex = (answerGraphIndex / 2).floor();
    } else {
      answerFreqIndex = answerGraphIndex;
    }
    answerCenterFreq = sessionFreqData.centerFreqLogList[answerFreqIndex];

    // Determine Appropriate Gain Value
    // if chosen graph is dip graph, invert gain value of session.
    if(sessionParameter.filterType == FilterType.dip
      || (sessionParameter.filterType == FilterType.peakDip && answerGraphIndex % 2 == 1))
    {
      answerGain = 0 - sessionParameter.gain.toDouble();
    } else {
      answerGain = sessionParameter.gain.toDouble();
    }

    updatePlayerState(player);
  }

  Future<void> updatePlayerState(PlayerIsolate player) async {
    debugPrint("Updating Player EQ with Freq: $answerCenterFreq, Gain: $answerGain");
    player.setEQFreq(answerCenterFreq);
    player.setEQGain(answerGain);
  }
}