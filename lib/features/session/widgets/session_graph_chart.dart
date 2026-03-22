import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionGraphChart extends StatelessWidget {
  const SessionGraphChart({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SessionStore>();
    final selectedIdx = store.currentPickerValue - 1;
    final selectedColor = const Color(0xFF287DCC);
    final unselectedColor = const Color(0xFFD23232);

    return LineChart(
      LineChartData(
        minX: 0, maxX: 60, minY: -3, maxY: 3,
        clipData: const FlClipData.all(),
        lineBarsData: [
          for (int i = 0; i < store.graphBarDataList.length; i++)
            store.graphBarDataList[i].copyWith(
              color: i == selectedIdx ? selectedColor : unselectedColor,
            ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: context.colors.onSurfaceVariant,
            )
        ),
        titlesData: _graphTitleData(context),
        extraLinesData: _graphExtraLineData(context),
      )
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
          interval: 1,
          getTitlesWidget: (value, meta) {
            // These Case Values were pre-calculated. You can get one by...
            // max X axis value / log((Center Frequency / lower bound Frequency), (upper bound Frequency / lower bound Frequency))
            // ... which is 200 / log((Center Frequency / 20(hz)), (20000(hz) / 20(hz))) in this app.
            bool render = false;
            String text = '';
            switch (value) {
              case 0:
                text = '20'; render = true; break;
              case 7:
                text = '50'; render = true; break;
              case 13:
                text = '100'; render = true; break;
              case 20:
                text = '200'; render = true; break;
              case 27:
                text = '500'; render = true; break;
              case 33:
                text = '1K'; render = true; break;
              case 40:
                text = '2K'; render = true; break;
              case 47:
                text = '5K'; render = true; break;
              case 53:
                text = '10K'; render = true; break;
              case 60:
                text = '20K'; render = true; break;
              default:
            }
            if(render) {
              return SideTitleWidget(
                space: 1,
                meta: meta,
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          }
        )
      )
    );
  }

  ExtraLinesData _graphExtraLineData(BuildContext context) {
    return ExtraLinesData(
      extraLinesOnTop: false,
      verticalLines: [
        VerticalLine(x: 7, strokeWidth: 0.3, color: context.colors.onSurfaceVariant),   // 50
        VerticalLine(x: 13, strokeWidth: 0.3, color: context.colors.onSurfaceVariant),   // 100
        VerticalLine(x: 20, strokeWidth: 0.3, color: context.colors.onSurfaceVariant),   // 200
        VerticalLine(x: 27, strokeWidth: 0.3, color: context.colors.onSurfaceVariant),  // 1k
        VerticalLine(x: 40, strokeWidth: 0.3, color: context.colors.onSurfaceVariant),  // 2k
        VerticalLine(x: 47, strokeWidth: 0.3, color: context.colors.onSurfaceVariant),  // 5k
        VerticalLine(x: 53, strokeWidth: 0.3, color: context.colors.onSurfaceVariant),  // 10k
      ]
    );
  }
}