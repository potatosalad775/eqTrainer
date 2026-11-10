import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

String _bandName(AppLocalizations l10n, ResultFrequencyBand band) => switch (band) {
  ResultFrequencyBand.subBass        => l10n.resultFreqSubBass,
  ResultFrequencyBand.midBass        => l10n.resultFreqMidBass,
  ResultFrequencyBand.lowerMidrange  => l10n.resultFreqLowerMidrange,
  ResultFrequencyBand.centreMidrange => l10n.resultFreqCentreMidrange,
  ResultFrequencyBand.upperMidrange  => l10n.resultFreqUpperMidrange,
  ResultFrequencyBand.treble         => l10n.resultFreqTreble,
  ResultFrequencyBand.upperTreble    => l10n.resultFreqUpperTreble,
};

class ResultItemTile extends StatelessWidget {
  const ResultItemTile({
    super.key,
    required this.index,
  });

  final int index;

  @override
  Widget build(BuildContext context) {
    final store = context.read<SessionStore>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: context.colors.surfaceContainerHigh,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          minVerticalPadding: 10,
          horizontalTitleGap: 0,
          title: Text(
            _bandName(context.l10n, ResultFrequencyBand.values[index]),
            style: TextStyle(
              color: context.colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            ResultFrequencyBand.values[index].range,
            style: TextStyle(
              color: context.colors.onSurface,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${store.correctAnswerPerFreq[index]} / ${store.elapsedSessionPerFreq[index]}",
                style: context.textTheme.bodyMedium,
              ),
              Text(
                store.getResultPercentagePerFreq(index),
                style: context.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}