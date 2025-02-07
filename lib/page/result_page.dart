import 'package:flutter/material.dart';
import 'package:eq_trainer/model/session/session_result.dart';
import 'package:eq_trainer/widget/common/MaxWidthCenterBox.dart';
import 'package:easy_localization/easy_localization.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.sessionResultData,
  });
  final SessionResultData sessionResultData;

  @override
  Widget build(BuildContext context) {
    double bottomPaddingValue = MediaQuery.of(context).viewPadding.bottom == 0 ? 11 : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("RESULT_APPBAR_TITLE").tr(),
      ),
      body: SafeArea(
        child: MaxWidthCenterBox(
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
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        minVerticalPadding: 10,
                        horizontalTitleGap: 0,
                        title: Text(
                          sessionResultData.titleList[index][0].tr(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          sessionResultData.titleList[index][1],
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${sessionResultData.correctAnswerPerFreq[index].toString()} / ${sessionResultData.elapsedSessionPerFreq[index].toString()}",
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              sessionResultData.getResultPercentagePerFreq(index),
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
                padding: const EdgeInsets.all(20),
                margin: EdgeInsets.only(
                  left: bottomPaddingValue,
                  right: bottomPaddingValue,
                  bottom: bottomPaddingValue,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.all(Radius.circular(10))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      "RESULT_BOTTOM_BAR_TITLE".tr(),
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    (sessionResultData.elapsedSession != 0)
                    // if user completed at least one round
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '${sessionResultData.resultPercentage.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSecondary,
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
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    )
                  ]
                  )
              )
            ],
          ),
        ),
      ),
    );
  }
}