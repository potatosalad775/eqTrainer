import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/model/session_data.dart';

class SessionGraph extends StatefulWidget {
  const SessionGraph({super.key});

  @override
  State<SessionGraph> createState() => _SessionGraphState();
}

class _SessionGraphState extends State<SessionGraph> {

  @override
  Widget build(BuildContext context) {
    final sessionFreqData = context.watch<SessionFrequencyData>();

    return ValueListenableBuilder<GraphState>(
      valueListenable: sessionFreqData.graphStateNotifier,
      builder: (context, value, _) {
        if(value == GraphState.loading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        else {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
            child: LineChart(
              LineChartData(
                minX: 0, maxX: 200, minY: -3, maxY: 3,
                clipData: const FlClipData.all(),
                lineBarsData: sessionFreqData.graphBarDataList,
                lineTouchData: const LineTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                ),
                titlesData: _graphTitleData(context),
                extraLinesData: _graphExtraLineData(context),
              )
            ),
          );
        }
      }
    );
  }

  FlTitlesData _graphTitleData (BuildContext context) {
    return FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: 0.5,
                getTitlesWidget: (value, meta) {
                  // These Case Values were pre-calculated. You can get one by...
                  // max X axis value / log((Center Frequency / lower bound Frequency), (upper bound Frequency / lower bound Frequency))
                  // ... which is 200 / log((Center Frequency / 20(hz)), (20000(hz) / 20(hz))) in this app.
                  String text = '';
                  switch (value) {
                    case 0:
                      text = '20'; break;
                    case 26:
                      text = '50'; break;
                    case 46:
                      text = '100'; break;
                    case 66:
                      text = '200'; break;
                    case 93:
                      text = '500'; break;
                    case 113:
                      text = '1K'; break;
                    case 133:
                      text = '2K'; break;
                    case 159:
                      text = '5K'; break;
                    case 179:
                      text = '10K'; break;
                    case 200:
                      text = '20K'; break;
                    default:
                  }
                  return SideTitleWidget(
                    space: 1,
                    axisSide: meta.axisSide,
                    child: Text(
                      text,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
            )
        )
    );
  }


  ExtraLinesData _graphExtraLineData(BuildContext context) {
    return ExtraLinesData(
        extraLinesOnTop: false,
        verticalLines: [
          VerticalLine(x: 26, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),   // 50
          VerticalLine(x: 46, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),   // 100
          VerticalLine(x: 66, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),   // 200
          VerticalLine(x: 93, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),   // 500
          VerticalLine(x: 113, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),  // 1k
          VerticalLine(x: 133, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),  // 2k
          VerticalLine(x: 159, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),  // 5k
          VerticalLine(x: 179, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),  // 10k
        ]
    );
  }
}