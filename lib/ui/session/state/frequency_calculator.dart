import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';

class FrequencyGraphData {
  FrequencyGraphData({
    required this.centerFreqLinearList,
    required this.graphBarDataList,
  });

  /// Where each band sits on the chart's 0 to 60 axis, one per band.
  final List<double> centerFreqLinearList;

  /// One curve per graph, in the layout's graph order.
  final List<LineChartBarData> graphBarDataList;
}

/// Pure calculator for the session chart. What the graphs mean (which band,
/// peak or dip, how many Hz) is the [BandLayout]'s; this only draws them.
class FrequencyCalculator {
  static FrequencyGraphData compute(BandLayout layout) {
    final bandCount = layout.bandCount;

    // Center frequencies (linear scale) for UI
    final centerFreqLinearList = <double>[];
    num adder = 30 / bandCount;
    double centerFreqLinear = adder.toDouble();
    for (int i = 0; i < bandCount; ++i) {
      centerFreqLinearList.add(centerFreqLinear);
      centerFreqLinear += (2 * adder);
    }

    // Build Gaussian curves per graph
    final graphBarDataList = <LineChartBarData>[];
    double a = 2;
    double c = (-0.28 * bandCount + 8.56).toDouble();

    for (int graph = 0; graph < layout.graphCount; ++graph) {
      final b = centerFreqLinearList[layout.bandOf(graph)];
      final isDip = layout.isDip(graph);
      final spotList = <FlSpot>[];

      for (int j = 0; j <= 60; ++j) {
        final e = (0 - ((pow((j - b), 2) / (2 * pow(c, 2)))));
        final h = isDip ? 0 - a * exp(e) : a * exp(e);
        spotList.add(FlSpot(j.toDouble(), h));
      }
      graphBarDataList.add(
        LineChartBarData(
          isCurved: true,
          color: Colors.redAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          spots: spotList,
        ),
      );
    }

    return FrequencyGraphData(
      centerFreqLinearList: centerFreqLinearList,
      graphBarDataList: graphBarDataList,
    );
  }
}
