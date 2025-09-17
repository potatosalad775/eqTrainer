import 'package:flutter/material.dart';

// SessionResultData - Manage results of each session
class SessionResultData extends ChangeNotifier {
  // Variables for recording Result of Each Session
  int elapsedSession = 0;
  List<int> elapsedSessionPerFreq = [0, 0, 0, 0, 0, 0, 0];
  int resultCorrect = 0;
  List<int> correctAnswerPerFreq = [0, 0, 0, 0, 0, 0, 0];
  int resultIncorrect = 0;

  // Reset Session Result
  void resetResult() {
    elapsedSession = 0;
    elapsedSessionPerFreq = [0, 0, 0, 0, 0, 0, 0];
    resultCorrect = 0;
    correctAnswerPerFreq = [0, 0, 0, 0, 0, 0, 0];
    resultIncorrect = 0;
  }

  // Get each session's center frequency, and record each result
  void updateResultFromFreq(double centerFreq, bool isCorrect) {
    int resultIndex = 0;
    // Sub-Bass - 20 ~ 80
    if(20 <= centerFreq && centerFreq < 80) { resultIndex = 0; }
    // Mid-Bass :: 80 ~ 200
    else if(80 <= centerFreq && centerFreq < 200) { resultIndex = 1; }
    // Lower-Midrange :: 200 ~ 800
    else if(200 <= centerFreq && centerFreq < 800) { resultIndex = 2; }
    // Centre-Midrange :: 800 ~ 1.5k
    else if(800 <= centerFreq && centerFreq < 1500) { resultIndex = 3; }
    // Upper-Midrange :: 1.5k ~ 5k
    else if(1500 <= centerFreq && centerFreq < 5000) { resultIndex = 4; }
    // Treble :: 5k ~ 10k
    else if(5000 <= centerFreq && centerFreq < 10000) { resultIndex = 5; }
    // Upper-Treble :: 10k ~ 20k
    else { resultIndex = 6; }

    elapsedSession++;
    elapsedSessionPerFreq[resultIndex]++;

    if(!isCorrect) {
      resultIncorrect++;
    } else {
      resultCorrect++;
      correctAnswerPerFreq[resultIndex]++;
    }
    notifyListeners();
  }

  double get resultPercentage => resultCorrect * 100 / elapsedSession;
  String getResultPercentagePerFreq(int index) {
    if(elapsedSessionPerFreq[index] == 0) {
      return "-";
    } else {
      return "${(correctAnswerPerFreq[index] * 100 / elapsedSessionPerFreq[index]).toStringAsFixed(2)}%";
    }
  }

  List<List<String>> titleList = [
    ["RESULT_FREQ_SUB_BASS", "20Hz ~ 80Hz"],
    ["RESULT_FREQ_MID_BASS", "80Hz ~ 200Hz"],
    ["RESULT_FREQ_LOWER_MIDRANGE", "200Hz ~ 800Hz"],
    ["RESULT_FREQ_CENTRE_MIDRANGE", "800Hz ~ 1.5kHz"],
    ["RESULT_FREQ_UPPER_MIDRANGE", "1.5kHz ~ 5kHz"],
    ["RESULT_FREQ_TREBLE", "5kHz ~ 10kHz"],
    ["RESULT_FREQ_UPPER_TREBLE", "10kHz ~ 20kHz"],
  ];
}