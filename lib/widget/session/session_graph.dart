import 'package:eq_trainer/main.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/model/session/session_frequency.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';
import 'package:eq_trainer/page/session_page.dart';

class SessionGraph extends StatelessWidget {
  const SessionGraph({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionFrequencyData = context.read<SessionFrequencyData>();
    return ValueListenableBuilder<GraphState>(
        valueListenable: sessionFrequencyData.graphStateNotifier,
        builder: (context, value, _) {
          if(value == GraphState.loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          else if (value == GraphState.error) {
            return AlertDialog(
              title: Text("SESSION_ALERT_ERROR_TITLE".tr()),
              content: Text("SESSION_ALERT_ERROR_CONTENT".tr()),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("SESSION_ALERT_ERROR_BUTTON".tr()),
                )
              ],
            );
          }
          else {
            return Selector<SessionFrequencyData, int>(
              selector: (context, sessionState) => sessionState.currentPickerValue,
              builder: (context, pickerValue, _) {
                return RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildChart(context),
                            if (savedMiscSettingsValue.frequencyToolTip) _freqToolTip(context, constraints),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            );
          }
        }
    );
  }

  Widget _buildChart(BuildContext context) {
    final data = Provider.of<SessionFrequencyData>(context, listen: false);
    return LineChart(
        LineChartData(
          minX: 0, maxX: 60, minY: -3, maxY: 3,
          clipData: const FlClipData.all(),
          lineBarsData: data.graphBarDataList,
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
    );
  }

  Widget _freqToolTip(BuildContext context, BoxConstraints constraints) {
    final freqData = Provider.of<SessionFrequencyData>(context, listen: false);
    final sessionParameter = Provider.of<SessionParameter>(context, listen: false);

    String flattenFreq(int frequency) {
      if(frequency > 10000) {
        String sF = (frequency ~/ 1000).toString();
        return "${sF}kHz";
      }
      else if(frequency > 1000) {
        String sF = (frequency ~/ 1000).toString();
        String sB = ((frequency % 1000) ~/ 100).toString();
        return "${sF}.${sB}kHz";
      }
      else if(frequency > 100) {
        return "${frequency - (frequency % 10)}Hz";
      }
      else {
        return "${frequency}Hz";
      }
    }

    // If Filter is Peak & Dip
    if(sessionParameter.filterType == FilterType.peakDip) {
      final centerIndex = (freqData.currentPickerValue - 1) ~/ 2;
      return Positioned(
        top: (freqData.currentPickerValue % 2 == 1) ? (constraints.maxHeight / 12) - 22 : null,
        bottom: (freqData.currentPickerValue % 2 == 1) ? null : (constraints.maxHeight / 12),
        left: freqData.centerFreqLinearList[centerIndex] * constraints.maxWidth / 60 - 42,
        child: SizedBox(
          width: 84,
          height: 44,
          child: Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            surfaceTintColor: Theme.of(context).colorScheme.onSecondaryContainer,
            elevation: 3,
            child: Center(
              child: Text(
                flattenFreq(freqData.centerFreqLogList[centerIndex].toInt()),
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
    }
    // If Filter is Only Peak or Only Dip
    else {
      return Positioned(
        top: (sessionParameter.filterType == FilterType.peak) ? (constraints.maxHeight / 12) - 22 : null,
        bottom: (sessionParameter.filterType == FilterType.peak) ? null : (constraints.maxHeight / 12),
        left: freqData.centerFreqLinearList[freqData.currentPickerValue - 1] * constraints.maxWidth / 60 - 42,
        child: SizedBox(
          child: SizedBox(
            width: 84,
            height: 44,
            child: Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              surfaceTintColor: Theme.of(context).colorScheme.onSecondaryContainer,
              elevation: 3,
              child: Center(
                child: Text(
                  flattenFreq(freqData.centerFreqLogList[freqData.currentPickerValue - 1].toInt()),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        VerticalLine(x: 7, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),   // 50
        VerticalLine(x: 13, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),   // 100
        VerticalLine(x: 20, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),   // 200
        VerticalLine(x: 27, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),   // 500
        VerticalLine(x: 33, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),  // 1k
        VerticalLine(x: 40, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),  // 2k
        VerticalLine(x: 47, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),  // 5k
        VerticalLine(x: 53, strokeWidth: 0.3, color: Theme.of(context).colorScheme.onSurfaceVariant),  // 10k
      ]
    );
  }
}