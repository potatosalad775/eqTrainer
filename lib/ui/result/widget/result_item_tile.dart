import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';

String _bandName(AppLocalizations l10n, ResultBand band) => switch (band) {
  ResultBand.subBass        => l10n.resultFreqSubBass,
  ResultBand.midBass        => l10n.resultFreqMidBass,
  ResultBand.lowerMidrange  => l10n.resultFreqLowerMidrange,
  ResultBand.centreMidrange => l10n.resultFreqCentreMidrange,
  ResultBand.upperMidrange  => l10n.resultFreqUpperMidrange,
  ResultBand.treble         => l10n.resultFreqTreble,
  ResultBand.upperTreble    => l10n.resultFreqUpperTreble,
};

/// A band's range as the result page writes it, for example `800Hz ~ 1.5kHz`.
String resultBandRange(ResultBand band) =>
    '${_formatHz(band.lowerHz)} ~ ${_formatHz(band.upperHz)}';

String _formatHz(int hz) {
  if (hz < 1000) return '${hz}Hz';
  // Dart prints 1500 / 1000 as 1.5 and 5000 / 1000 as 5.0, so whole
  // thousands are written as integers.
  return hz % 1000 == 0 ? '${hz ~/ 1000}kHz' : '${hz / 1000}kHz';
}

class ResultItemTile extends StatelessWidget {
  const ResultItemTile({
    super.key,
    required this.band,
    required this.results,
  });

  final ResultBand band;
  final SessionResults results;

  @override
  Widget build(BuildContext context) {
    final percentage = results.percentageIn(band);

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
            _bandName(context.l10n, band),
            style: TextStyle(
              color: context.colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            resultBandRange(band),
            style: TextStyle(
              color: context.colors.onSurface,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${results.correctIn(band)} / ${results.roundsIn(band)}",
                style: context.textTheme.bodyMedium,
              ),
              Text(
                percentage == null ? "-" : "${percentage.toStringAsFixed(2)}%",
                style: context.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
