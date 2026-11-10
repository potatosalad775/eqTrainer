import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionGraphTooltip extends StatelessWidget {
  const SessionGraphTooltip({
    super.key,
    required this.constraints,
    required this.graphIndex,
  });

  final BoxConstraints constraints;

  /// 0-based, as the domain counts graphs.
  final int graphIndex;

  @override
  Widget build(BuildContext context) {
    final store = context.read<SessionStore>();
    final layout = store.layout;

    // A peak's label sits above the axis and a dip's below it.
    final isDip = layout.isDip(graphIndex);
    final top = !isDip ? (constraints.maxHeight / 12) - 22 : null;
    final bottom = isDip ? (constraints.maxHeight / 12) : null;
    final leftPx = store.centerFreqLinearList[layout.bandOf(graphIndex)];
    final left = leftPx * constraints.maxWidth / 60 - 42;
    final text = flattenFreq(layout.frequencyOf(graphIndex).toInt());

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