import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eq_trainer/features/session/model/frequency_calculator.dart';
import 'package:eq_trainer/features/session/data/index.dart';

/// SessionStore aggregates session-related UI state into a single source of truth.
/// Holds frequency/graph data computed by the pure FrequencyCalculator.
class SessionStore extends ChangeNotifier {
  SessionStore();

  // Session state management (replaces SessionStateData)
  SessionState _sessionState = SessionState.init;
  SessionState get sessionState => _sessionState;

  void setSessionState(SessionState state) {
    _sessionState = state;
    notifyListeners();
  }

  // Graph state (loading/ready/error)
  final ValueNotifier<GraphState> graphStateNotifier = ValueNotifier<GraphState>(GraphState.loading);

  // Graph data snapshot
  List<LineChartBarData> _graphBarDataList = const [];
  List<LineChartBarData> get graphBarDataList => _graphBarDataList;

  List<double> _centerFreqLogList = const [];
  List<double> get centerFreqLogList => _centerFreqLogList;

  List<double> _centerFreqLinearList = const [];
  List<double> get centerFreqLinearList => _centerFreqLinearList;

  // Picker value - single source of truth (replaces SessionStateData.selectedPickerNum)
  int _currentPickerValue = 1;
  int get currentPickerValue => _currentPickerValue;

  void setPickerValue(int newValue) {
    if (newValue == _currentPickerValue) return;
    if (_graphBarDataList.isEmpty) return;
    if (newValue < 1 || newValue > _graphBarDataList.length) return;

    final updated = List<LineChartBarData>.from(_graphBarDataList);
    // Previous selection to red
    updated[_currentPickerValue - 1] = updated[_currentPickerValue - 1].copyWith(color: Colors.redAccent);
    // New selection to blue
    updated[newValue - 1] = updated[newValue - 1].copyWith(color: Colors.blueAccent);

    _graphBarDataList = updated;
    _currentPickerValue = newValue;

    notifyListeners();
  }

  // Progress (replaces SessionStateData.currentSessionPoint)
  int _currentSessionPoint = 0;
  int get currentSessionPoint => _currentSessionPoint;

  void setCurrentSessionPoint(int point) {
    _currentSessionPoint = point;
  }

  void incrementSessionPoint() {
    setCurrentSessionPoint(_currentSessionPoint + 1);
  }

  void decrementSessionPoint() {
    setCurrentSessionPoint(_currentSessionPoint - 1);
  }

  void resetSessionPoint() {
    setCurrentSessionPoint(0);
  }

  // Session Results (replaces SessionResultData functionality)
  int _elapsedSession = 0;
  int get elapsedSession => _elapsedSession;

  List<int> _elapsedSessionPerFreq = [0, 0, 0, 0, 0, 0, 0];
  List<int> get elapsedSessionPerFreq => List<int>.from(_elapsedSessionPerFreq);

  int _resultCorrect = 0;
  int get resultCorrect => _resultCorrect;

  List<int> _correctAnswerPerFreq = [0, 0, 0, 0, 0, 0, 0];
  List<int> get correctAnswerPerFreq => List<int>.from(_correctAnswerPerFreq);

  Object resultObj = {
    'correct': 0,
    'incorrect': 0,
  };

  int _resultIncorrect = 0;
  int get resultIncorrect => _resultIncorrect;

  // Reset Session Results
  void resetResult() {
    _elapsedSession = 0;
    _elapsedSessionPerFreq = [0, 0, 0, 0, 0, 0, 0];
    _resultCorrect = 0;
    _correctAnswerPerFreq = [0, 0, 0, 0, 0, 0, 0];
    _resultIncorrect = 0;
  }

  // Consolidated submission update to minimize intermediate rebuilds
  void applySubmission({required double centerFreq, required bool isCorrect}) {
    final idx = _getFrequencyBandIndex(centerFreq);
    _elapsedSession++;
    _elapsedSessionPerFreq[idx]++;
    if (isCorrect) {
      _resultCorrect++;
      _correctAnswerPerFreq[idx]++;
      _currentSessionPoint += 1;
    } else {
      _resultIncorrect++;
      _currentSessionPoint -= 1;
    }
    notifyListeners();
  }

  // Get frequency band index based on center frequency
  int _getFrequencyBandIndex(double centerFreq) {
    // Sub-Bass - 20 ~ 80
    if (20 <= centerFreq && centerFreq < 80) { return 0; }
    // Mid-Bass :: 80 ~ 200
    else if (80 <= centerFreq && centerFreq < 200) { return 1; }
    // Lower-Midrange :: 200 ~ 800
    else if (200 <= centerFreq && centerFreq < 800) { return 2; }
    // Centre-Midrange :: 800 ~ 1.5k
    else if (800 <= centerFreq && centerFreq < 1500) { return 3; }
    // Upper-Midrange :: 1.5k ~ 5k
    else if (1500 <= centerFreq && centerFreq < 5000) { return 4; }
    // Treble :: 5k ~ 10k
    else if (5000 <= centerFreq && centerFreq < 10000) { return 5; }
    // Upper-Treble :: 10k ~ 20k
    else { return 6; }
  }

  // Calculate overall result percentage
  double get resultPercentage => _elapsedSession > 0 ? _resultCorrect * 100 / _elapsedSession : 0;

  // Get result percentage for specific frequency band
  String getResultPercentagePerFreq(int index) {
    if (index < 0 || index >= _elapsedSessionPerFreq.length) return "-";
    if (_elapsedSessionPerFreq[index] == 0) {
      return "-";
    } else {
      return "${(_correctAnswerPerFreq[index] * 100 / _elapsedSessionPerFreq[index]).toStringAsFixed(2)}%";
    }
  }

  // Frequency band titles (static data from SessionResultData)
  static const List<List<String>> resultFrequencyLabelList = [
    ["RESULT_FREQ_SUB_BASS", "20Hz ~ 80Hz"],
    ["RESULT_FREQ_MID_BASS", "80Hz ~ 200Hz"],
    ["RESULT_FREQ_LOWER_MIDRANGE", "200Hz ~ 800Hz"],
    ["RESULT_FREQ_CENTRE_MIDRANGE", "800Hz ~ 1.5kHz"],
    ["RESULT_FREQ_UPPER_MIDRANGE", "1.5kHz ~ 5kHz"],
    ["RESULT_FREQ_TREBLE", "5kHz ~ 10kHz"],
    ["RESULT_FREQ_UPPER_TREBLE", "10kHz ~ 20kHz"],
  ];

  // Playlist paths and index
  List<String> _playlistPaths = const [];
  List<String> get playlistPaths => _playlistPaths;

  int _currentPlayingAudioIndex = 0;
  int get currentPlayingAudioIndex => _currentPlayingAudioIndex;

  String? get currentClipPath =>
      (_playlistPaths.isNotEmpty && _currentPlayingAudioIndex >= 0 && _currentPlayingAudioIndex < _playlistPaths.length)
          ? _playlistPaths[_currentPlayingAudioIndex]
          : null;

  // --- Frequency/Graph lifecycle ---
  Future<void> initFrequency({required SessionParameter sessionParameter}) async {
    graphStateNotifier.value = GraphState.loading;
    try {
      final computed = FrequencyCalculator.compute(sessionParameter: sessionParameter);

      _centerFreqLogList = List<double>.from(computed.centerFreqLogList);
      _centerFreqLinearList = List<double>.from(computed.centerFreqLinearList);
      _graphBarDataList = List<LineChartBarData>.from(computed.graphBarDataList);

      // Reset picker to 1 and ensure first graph highlighted (blue) by calculator
      resetPickerValue();

      graphStateNotifier.value = GraphState.ready;
    } catch (_) {
      graphStateNotifier.value = GraphState.error;
      rethrow;
    }
  }

  void updatePickerValue(int newValue) {
    setPickerValue(newValue);
  }

  void resetPickerValue() {
    setPickerValue(1);
  }

  // --- Playlist controls ---
  void setPlaylistPaths(List<String> paths) {
    _playlistPaths = List<String>.from(paths);
    _currentPlayingAudioIndex = 0;
  }

  void clearPlaylist() {
    _playlistPaths = const [];
    _currentPlayingAudioIndex = 0;
  }

  void setCurrentPlayingIndex(int index) {
    if (_playlistPaths.isEmpty) {
      _currentPlayingAudioIndex = 0;
    } else {
      _currentPlayingAudioIndex = index.clamp(0, _playlistPaths.length - 1);
    }
  }

  void nextTrack() {
    if (_playlistPaths.isEmpty) return;
    _currentPlayingAudioIndex = (_currentPlayingAudioIndex + 1) % _playlistPaths.length;
  }

  void previousTrack({Duration threshold = const Duration(seconds: 3), Duration? currentPosition}) {
    if (_playlistPaths.isEmpty) return;
    if (_currentPlayingAudioIndex == 0) {
      _currentPlayingAudioIndex = _playlistPaths.length - 1;
    } else {
      _currentPlayingAudioIndex -= 1;
    }
  }
}