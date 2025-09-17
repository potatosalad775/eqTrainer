import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';
import 'package:eq_trainer/model/session/frequency_calculator.dart';

// SessionFrequencyData - Manage Audio Frequency Data required for Session
class SessionFrequencyData extends ChangeNotifier {
  SessionFrequencyData();

  final graphStateNotifier = ValueNotifier<GraphState>(GraphState.loading);

  // List of Center Frequencies of Each Graph in Log Scale (for Filter)
  final List<double> _centerFreqLogList = List.empty(growable: true);
  List<double> get centerFreqLogList => _centerFreqLogList;
  // List of Center Frequencies of Each Graph in Linear Scale (for UI)
  final List<double> _centerFreqLinearList = List.empty(growable: true);
  List<double> get centerFreqLinearList => _centerFreqLinearList;
  // List of Graph Bar Data
  List<LineChartBarData> _graphBarDataList = List.empty(growable: true);
  List<LineChartBarData> get graphBarDataList => _graphBarDataList;

  // Number Picker values for session Number Picker Slider
  int _currentPickerValue = 1;
  int get currentPickerValue => _currentPickerValue;

  int _previousPickerValue = 1;
  int get previousPickerValue => _previousPickerValue;

  // --- initSessionFreqData Function ---
  // Collective Function for Initializing Frequency Data for Session.
  Future<void> initSessionFreqData({required SessionParameter sessionParameter}) async {
    graphStateNotifier.value = GraphState.loading;

    try {
      // Compute graph data via pure calculator
      final computed = FrequencyCalculator.compute(sessionParameter: sessionParameter);

      _centerFreqLogList
        ..clear()
        ..addAll(computed.centerFreqLogList);

      _centerFreqLinearList
        ..clear()
        ..addAll(computed.centerFreqLinearList);

      _graphBarDataList = List<LineChartBarData>.from(computed.graphBarDataList);

      // Reset Number Picker Value
      resetPickerValue();

      // Notify Graph data is ready
      graphStateNotifier.value = GraphState.ready;
    } catch (e) {
      graphStateNotifier.value = GraphState.error;
      throw Exception(e.toString());
    } finally {
      // Ensure external subscribers (e.g., SessionStore) can sync initial data immediately
      notifyListeners();
    }
  }

  // TODO: Properly mitigate unnecessary request
  Timer? _debounce;
  void updatePickerValue(int newValue) {
    if(_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), () {
      if (newValue != _currentPickerValue) {
        final updatedGraphBarDataList = List<LineChartBarData>.from(_graphBarDataList);
        updatedGraphBarDataList[_currentPickerValue - 1] = updatedGraphBarDataList[_currentPickerValue - 1].copyWith(color: Colors.redAccent);
        updatedGraphBarDataList[newValue - 1] = updatedGraphBarDataList[newValue - 1].copyWith(color: Colors.blueAccent);

        _graphBarDataList = updatedGraphBarDataList;
        _currentPickerValue = newValue;
        _previousPickerValue = _currentPickerValue;

        // Update the state and notify listeners
        notifyListeners();
      }
    });
  }

  void resetPickerValue() {
    _currentPickerValue = 1;
    _previousPickerValue = 1;
  }
}

enum GraphState { loading, ready, error }