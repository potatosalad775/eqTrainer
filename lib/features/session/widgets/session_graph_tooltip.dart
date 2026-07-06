import 'package:eq_trainer/features/session/data/session_parameter.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionGraphTooltip extends StatelessWidget {
  const SessionGraphTooltip({
    super.key,
    required this.constraints,
    required this.pickerValue,
  });

  final BoxConstraints constraints;
  final int pickerValue;

  @override
  Widget build(BuildContext context) {
    final store = context.read<SessionStore>();
    final filterType = context.read<SessionParameter>().filterType;
    
    // In peakDip mode, odd picker values are the peak variant and even are
    // dip (mirrors the answer-gain inversion in SessionController). In pure
    // peak/dip mode every graph is that one type regardless of parity.
    final isPeakPick = filterType == FilterType.peak ||
        (filterType == FilterType.peakDip && pickerValue % 2 == 1);
    final isDipPick = filterType == FilterType.dip ||
        (filterType == FilterType.peakDip && pickerValue % 2 == 0);
    final top = isPeakPick ? (constraints.maxHeight / 12) - 22 : null;
    final bottom = isDipPick ? (constraints.maxHeight / 12) : null;
    final leftPx = filterType == FilterType.peakDip
        ? store.centerFreqLinearList[(pickerValue - 1) ~/ 2]
        : store.centerFreqLinearList[pickerValue - 1];
    final left = leftPx * constraints.maxWidth / 60 - 42;
    final text = filterType == FilterType.peakDip
        ? flattenFreq(store.centerFreqLogList[(pickerValue - 1) ~/ 2].toInt())
        : flattenFreq(store.centerFreqLogList[pickerValue - 1].toInt());

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      child: SizedBox(
        width: 84,
        height: 44,
        child: Card(
          color: context.colors.secondaryContainer,
          surfaceTintColor: context.colors.onSecondaryContainer,
          elevation: 3,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String flattenFreq(int frequency) {
    if(frequency > 10000) {
      String sF = (frequency ~/ 1000).toString();
      return "${sF}kHz";
    }
    else if(frequency > 1000) {
      String sF = (frequency ~/ 1000).toString();
      String sB = ((frequency % 1000) ~/ 100).toString();
      return "$sF.${sB}kHz";
    }
    else if(frequency > 100) {
      return "${frequency - (frequency % 10)}Hz";
    }
    else {
      return "${frequency}Hz";
    }
  }
}