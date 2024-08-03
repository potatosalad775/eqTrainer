import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';

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
      // == Find Center Frequencies of Each Graphs (with LOGARITHMIC Scale for Filter) ==
      // * Center Frequencies in LOGARITHMIC Scale = applied to Audio Filter
      //
      // Originally Frequency Graph has Logarithmic Scale.
      // Let's say Every Graph's Center Frequency are evenly distributed from 20hz to 20kHz (20000hz).
      // If we think Multiplier m = 1000^(1 / (2 * # of Center Frequencies)), then...
      // Center Frequency C(i + 1) equals(=) m^2 * C(i), and C(0) equals(=) 20 * m , while 0 <= i < '# of Center Frequency'.
      // Think about Space-Around Alignment in Flutter or CSS, but in Logarithmic Horizon Scale. :) Got it?
      _centerFreqLogList.clear();
      num multiplier = pow(1000, 1 / (2 * sessionParameter.startingBand));
      double centerFreqLog = 20 * multiplier.toDouble();
      for(int i = 0; i < sessionParameter.startingBand; ++i) {
        _centerFreqLogList.add(centerFreqLog);
        centerFreqLog *= pow(multiplier, 2);
      }

      // == Find Center Frequencies of Each Graphs (with LINEAR Scale for Filter) ==
      // * Center Frequencies in LINEAR Scale = applied to Graph UI
      //
      // The Gaussian Graph that is shown to User does not follow Logarithmic Scale (just like OG Harman How to Listen)
      // For Aesthetic Reason, I believe. Let's say our graph is 0 to 200 in Horizon Scale.
      _centerFreqLinearList.clear();
      num adder = 30 / sessionParameter.startingBand;
      double centerFreqLinear = adder.toDouble();
      for(int i = 0; i < sessionParameter.startingBand; ++i) {
        _centerFreqLinearList.add(centerFreqLinear);
        centerFreqLinear += (2 * adder);
      }

      // == Calculate Spots as UI Graph (Gaussian Function) ==
      // https://en.wikipedia.org/wiki/Gaussian_function
      //
      // a : height of Gaussian Graph
      // b : center frequency of graph
      // c : standard deviation of Graph
      // e : exponential of Gaussian Function
      // h : calculated result of Gaussian Function = height of graph
      //
      // There's no specific c value, I just chose what looks great on this app.
      double a = 2;
      double b;
      double c = (8 - (sessionParameter.startingBand / 2)).toDouble();
      double e;
      double h;
      _graphBarDataList.clear();

      for(int i = 0; i < sessionParameter.startingBand; ++i) {
        b = _centerFreqLinearList[i];
        List<FlSpot> peakGraphSpotList = [];
        List<FlSpot> dipGraphSpotList = [];

        // if Filter Type includes Peak Filter
        if(sessionParameter.filterType != FilterType.dip) {
          for(int j = 0; j <= 60; ++j) {
            e = (0 - ((pow((j - b), 2) / (2 * pow(c, 2)))));
            h = a * exp(e);
            peakGraphSpotList.add(FlSpot(j.toDouble(), h));
          }
          _graphBarDataList.add(
              LineChartBarData(
                isCurved: true,
                color: Colors.redAccent,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
                spots: peakGraphSpotList,
              )
          );
        }

        // if Filter Type includes Dip Filter
        if(sessionParameter.filterType != FilterType.peak) {
          for(int j = 0; j <= 60; ++j) {
            e = (0 - ((pow((j - b), 2) / (2 * pow(c, 2)))));
            h = 0 - a * exp(e);
            dipGraphSpotList.add(FlSpot(j.toDouble(), h));
          }
          _graphBarDataList.add(
              LineChartBarData(
                isCurved: true,
                color: Colors.redAccent,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
                spots: dipGraphSpotList,
              )
          );
        }
      }
      _graphBarDataList[0] = _graphBarDataList[0].copyWith(color: Colors.blueAccent);

      // Reset Number Picker Value
      resetPickerValue();

      // Notify Graph data is ready
      graphStateNotifier.value = GraphState.ready;
    } catch (e) {
      graphStateNotifier.value = GraphState.error;
      throw Exception(e.toString());
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