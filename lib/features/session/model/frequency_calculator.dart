import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';

class FrequencyGraphData {
  FrequencyGraphData({
    required this.centerFreqLogList,
    required this.centerFreqLinearList,
    required this.graphBarDataList,
  });
  final List<double> centerFreqLogList;
  final List<double> centerFreqLinearList;
  final List<LineChartBarData> graphBarDataList;
}

/// Pure calculator for session frequency graph data.
class FrequencyCalculator {
  static FrequencyGraphData compute({required SessionParameter sessionParameter}) {
    // Center frequencies (log scale) for filter
    final centerFreqLogList = <double>[];
    num multiplier = pow(1000, 1 / (2 * sessionParameter.startingBand));
    double centerFreqLog = 20 * multiplier.toDouble();
    for (int i = 0; i < sessionParameter.startingBand; ++i) {
      centerFreqLogList.add(centerFreqLog);
      centerFreqLog *= pow(multiplier, 2);
    }

    // Center frequencies (linear scale) for UI
    final centerFreqLinearList = <double>[];
    num adder = 30 / sessionParameter.startingBand;
    double centerFreqLinear = adder.toDouble();
    for (int i = 0; i < sessionParameter.startingBand; ++i) {
      centerFreqLinearList.add(centerFreqLinear);
      centerFreqLinear += (2 * adder);
    }

    // Build Gaussian curves per band
    final graphBarDataList = <LineChartBarData>[];
    double a = 2;
    double c = (-0.28 * sessionParameter.startingBand + 8.56).toDouble();

    for (int i = 0; i < sessionParameter.startingBand; ++i) {
      final b = centerFreqLinearList[i];
      final peakGraphSpotList = <FlSpot>[];
      final dipGraphSpotList = <FlSpot>[];

      if (sessionParameter.filterType != FilterType.dip) {
        for (int j = 0; j <= 60; ++j) {
          final e = (0 - ((pow((j - b), 2) / (2 * pow(c, 2)))));
          final h = a * exp(e);
          peakGraphSpotList.add(FlSpot(j.toDouble(), h));
        }
        graphBarDataList.add(
          LineChartBarData(
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            spots: peakGraphSpotList,
          ),
        );
      }

      if (sessionParameter.filterType != FilterType.peak) {
        for (int j = 0; j <= 60; ++j) {
          final e = (0 - ((pow((j - b), 2) / (2 * pow(c, 2)))));
          final h = 0 - a * exp(e);
          dipGraphSpotList.add(FlSpot(j.toDouble(), h));
        }
        graphBarDataList.add(
          LineChartBarData(
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            spots: dipGraphSpotList,
          ),
        );
      }
    }

    if (graphBarDataList.isNotEmpty) {
      graphBarDataList[0] = graphBarDataList[0].copyWith(color: Colors.blueAccent);
    }

    return FrequencyGraphData(
      centerFreqLogList: centerFreqLogList,
      centerFreqLinearList: centerFreqLinearList,
      graphBarDataList: graphBarDataList,
    );
  }
}
