// filepath: /Users/potatosalad/project/eqTrainer/lib/model/state/session_store.dart
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eq_trainer/model/session/session_frequency.dart';
import 'package:eq_trainer/model/state/session_state_data.dart';
import 'package:eq_trainer/model/session/session_result.dart';

/// SessionStore aggregates session-related UI state into a single source of truth.
/// It subscribes to existing notifiers and mirrors their computed values for widgets to select.
class SessionStore extends ChangeNotifier {
  SessionStore({
    required SessionFrequencyData freqData,
    required SessionStateData stateData,
    required SessionResultData resultData,
  }) : _freqData = freqData, _stateData = stateData, _resultData = resultData {
    // Seed initial values
    _syncFromFreq();
    _syncFromState();
    _syncFromResult();
    graphStateNotifier.value = _freqData.graphStateNotifier.value;

    // Subscribe to changes
    _freqData.graphStateNotifier.addListener(_onGraphStateChanged);
    _freqData.addListener(_onFreqChanged);
    _stateData.addListener(_onStateChanged);
    _resultData.addListener(_onResultChanged);
  }

  final SessionFrequencyData _freqData;
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

  void _onGraphStateChanged() {
    graphStateNotifier.value = _freqData.graphStateNotifier.value;
    // Also sync data when graph state changes (e.g., after initSessionFreqData completes)
    if (graphStateNotifier.value == GraphState.ready || graphStateNotifier.value == GraphState.error) {
      _syncFromFreq();
      notifyListeners();
    }
  }

  void _onFreqChanged() {
    _syncFromFreq();
    notifyListeners();
  }

  void _onStateChanged() {
    _syncFromState();
    notifyListeners();
  }

  void _onResultChanged() {
    _syncFromResult();
    notifyListeners();
  }

  void _syncFromFreq() {
    _graphBarDataList = List<LineChartBarData>.from(_freqData.graphBarDataList);
    _centerFreqLogList = List<double>.from(_freqData.centerFreqLogList);
    _centerFreqLinearList = List<double>.from(_freqData.centerFreqLinearList);
    _currentPickerValue = _freqData.currentPickerValue;
  }

  void _syncFromState() {
    _currentSessionPoint = _stateData.currentSessionPoint;
  }

  void _syncFromResult() {
    _resultCorrect = _resultData.resultCorrect;
    _resultIncorrect = _resultData.resultIncorrect;
  }

  @override
  void dispose() {
    _freqData.graphStateNotifier.removeListener(_onGraphStateChanged);
    _freqData.removeListener(_onFreqChanged);
    _stateData.removeListener(_onStateChanged);
    _resultData.removeListener(_onResultChanged);
    super.dispose();
  }
}
