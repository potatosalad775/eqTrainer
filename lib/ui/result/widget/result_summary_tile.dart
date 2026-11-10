import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';

class ResultSummaryTile extends StatelessWidget {
  const ResultSummaryTile({super.key, required this.results});

  final SessionResults results;

  @override
  Widget build(BuildContext context) {
    final percentage = results.percentage;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      margin: const EdgeInsets.only(),
      decoration: BoxDecoration(
        color: context.colors.secondary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            context.l10n.resultBottomBarTitle,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSecondary,
            ),
          ),
          if (percentage != null)
            Text(
              '${percentage.toStringAsFixed(2)}%',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSecondary,
              ),
            )
          else
            Text(
              context.l10n.resultBottomBarZeroResult,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
