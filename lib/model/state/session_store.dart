import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eq_trainer/model/session/frequency_calculator.dart';
import 'package:eq_trainer/model/session/graph_state.dart';
import 'package:eq_trainer/model/state/session_state_data.dart';
import 'package:eq_trainer/model/session/session_result.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';

/// SessionStore aggregates session-related UI state into a single source of truth.
/// Holds frequency/graph data computed by the pure FrequencyCalculator.
class SessionStore extends ChangeNotifier {
  SessionStore({
    required SessionStateData stateData,
    required SessionResultData resultData,
  })  : _stateData = stateData,
        _resultData = resultData {
    // Seed initial values from state/result
    _syncFromState();
    _syncFromResult();
  }

  final SessionStateData _stateData;
  final SessionResultData _resultData;

  // Graph state (loading/ready/error)
  final ValueNotifier<GraphState> graphStateNotifier = ValueNotifier<GraphState>(GraphState.loading);

  // Graph data snapshot
  List<LineChartBarData> _graphBarDataList = const [];
  List<LineChartBarData> get graphBarDataList => _graphBarDataList;

  List<double> _centerFreqLogList = const [];
  List<double> get centerFreqLogList => _centerFreqLogList;

  List<double> _centerFreqLinearList = const [];
  List<double> get centerFreqLinearList => _centerFreqLinearList;

  // Picker value mirrors SessionStateData.selectedPickerNum, but we keep a cached copy
  int _currentPickerValue = 1;
  int get currentPickerValue => _currentPickerValue;

  // Progress
  int _currentSessionPoint = 0;
  int get currentSessionPoint => _currentSessionPoint;

  // Results
  int _resultCorrect = 0;
  int get resultCorrect => _resultCorrect;

  int _resultIncorrect = 0;
  int get resultIncorrect => _resultIncorrect;

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
    } finally {
      notifyListeners();
    }
  }

  void updatePickerValue(int newValue) {
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

  void resetPickerValue() {
    _currentPickerValue = 1;
  }

  // --- Playlist controls ---
  void setPlaylistPaths(List<String> paths) {
    _playlistPaths = List<String>.from(paths);
    _currentPlayingAudioIndex = 0;
    notifyListeners();
  }

  void clearPlaylist() {
    _playlistPaths = const [];
    _currentPlayingAudioIndex = 0;
    notifyListeners();
  }

  void setCurrentPlayingIndex(int index) {
    if (_playlistPaths.isEmpty) {
      _currentPlayingAudioIndex = 0;
    } else {
      _currentPlayingAudioIndex = index.clamp(0, _playlistPaths.length - 1);
    }
    notifyListeners();
  }

  void nextTrack() {
    if (_playlistPaths.isEmpty) return;
    _currentPlayingAudioIndex = (_currentPlayingAudioIndex + 1) % _playlistPaths.length;
    notifyListeners();
  }

  void previousTrack({Duration threshold = const Duration(seconds: 3), Duration? currentPosition}) {
    if (_playlistPaths.isEmpty) return;
    if (_currentPlayingAudioIndex == 0) {
      _currentPlayingAudioIndex = _playlistPaths.length - 1;
    } else {
      _currentPlayingAudioIndex -= 1;
    }
    notifyListeners();
  }

  // --- Mirror state/result ---
  void _syncFromState() {
    _currentSessionPoint = _stateData.currentSessionPoint;
    _currentPickerValue = _stateData.selectedPickerNum;
  }

  void _syncFromResult() {
    _resultCorrect = _resultData.resultCorrect;
    _resultIncorrect = _resultData.resultIncorrect;
  }

  void attach() {
    // Allow late subscription in main after providers are ready
    _stateData.addListener(_onStateChanged);
    _resultData.addListener(_onResultChanged);
  }

  void _onStateChanged() {
    _syncFromState();
    notifyListeners();
  }

  void _onResultChanged() {
    _syncFromResult();
    notifyListeners();
  }

  @override
  void dispose() {
    _stateData.removeListener(_onStateChanged);
    _resultData.removeListener(_onResultChanged);
    super.dispose();
  }
}
