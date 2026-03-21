import 'package:flutter/material.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/shared/widget/max_width_center_box.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({ super.key });

  @override
  Widget build(BuildContext context) {
    double bottomPaddingValue = MediaQuery.of(context).viewPadding.bottom == 0
        ? 20
        : MediaQuery.of(context).viewPadding.bottom - 10;
    double bottomMarginValue = MediaQuery.of(context).viewPadding.bottom == 0 ? 11 : 0;
    final store = context.watch<SessionStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("RESULT_APPBAR_TITLE").tr(),
      ),
      body: MaxWidthCenterBox(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: 7,
                itemBuilder: (context, index) => Padding(
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
                            "${store.correctAnswerPerFreq[index].toString()} / ${store.elapsedSessionPerFreq[index].toString()}",
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            store.getResultPercentagePerFreq(index),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPaddingValue),
              margin: EdgeInsets.only(
                left: bottomMarginValue,
                right: bottomMarginValue,
                bottom: bottomMarginValue,
              ),
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
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: context.colors.onSecondary,
                    ),
                  ),
                  (store.elapsedSession != 0)
                  // if user completed at least one round
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${store.resultPercentage.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.colors.onSecondary,
                        ),
                      ),
                    ],
                  )
                  // ...else
                  : Text(
                    "RESULT_BOTTOM_BAR_ZERO_RESULT".tr(),
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: context.colors.onSecondary,
                    ),
                  )
                ]
                )
            )
          ],
        ),
      ),
    );
  }
}