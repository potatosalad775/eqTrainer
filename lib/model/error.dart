import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';

Future<void> logError(String failLog) async {
  File file = await File("${appSupportDir.path}${Platform.pathSeparator}log${Platform.pathSeparator}recentLog.txt").create(recursive: true);
  await file.writeAsString(failLog);
}

Future<void> showPlayerErrorDialog(BuildContext context, { Function? action, Object? error }) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text("${"ERROR_PLAYER_ALERT_CONTENT".tr()} : $error"),
      actions: [
        TextButton(
          onPressed: () {
            if (action != null) {
              action();
            }
          },
          child: Text("ERROR_PLAYER_ALERT_EXIT_BUTTON".tr()),
        ),
      ],
    )
  );
}