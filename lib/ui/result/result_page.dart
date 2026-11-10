import 'package:eq_trainer/ui/result/widget/result_item_tile.dart';
import 'package:eq_trainer/ui/result/widget/result_summary_tile.dart';
import 'package:eq_trainer/ui/core/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/l10n/l10n.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({ super.key });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.resultAppbarTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppDimens.maxWidgetWidth),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: ResultFrequencyBand.values.length,
                    itemBuilder: (context, index) => ResultItemTile(index: index),
                  ),
                ),
                const ResultSummaryTile(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}