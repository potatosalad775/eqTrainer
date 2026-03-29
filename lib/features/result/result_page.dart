import 'package:eq_trainer/features/result/widget/result_item_tile.dart';
import 'package:eq_trainer/features/result/widget/result_summary_tile.dart';
import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:easy_localization/easy_localization.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({ super.key });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RESULT_APPBAR_TITLE").tr(),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppDimens.maxWidgetWidth),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: SessionStore.resultFrequencyLabelList.length,
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