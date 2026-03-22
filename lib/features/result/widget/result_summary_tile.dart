import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ResultSummaryTile extends StatelessWidget {
  const ResultSummaryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<SessionStore>();

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
            "RESULT_BOTTOM_BAR_TITLE".tr(),
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSecondary,
            ),
          ),
          if (store.elapsedSession != 0)
            Text(
              '${store.resultPercentage.toStringAsFixed(2)}%',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSecondary,
              ),
            )
          else
            Text(
              "RESULT_BOTTOM_BAR_ZERO_RESULT".tr(),
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