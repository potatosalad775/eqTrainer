import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            SessionStore.resultFrequencyLabelList[index][0].tr(),
            style: TextStyle(
              color: context.colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            SessionStore.resultFrequencyLabelList[index][1],
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