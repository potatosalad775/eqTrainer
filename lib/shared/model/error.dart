import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/main.dart';

Future<void> logError(String failLog) async {
  File file = await File("${appSupportDir.path}${Platform.pathSeparator}log${Platform.pathSeparator}recentLog.txt").create(recursive: true);
  await file.writeAsString(failLog);
}

Future<void> showPlayerErrorDialog(BuildContext context, { Function? action, Object? error }) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text("${context.l10n.errorPlayerAlertContent} : $error"),
      actions: [
        TextButton(
          onPressed: () {
            if (action != null) {
              action();
            }
          },
          child: Text(context.l10n.errorPlayerAlertExitButton),
        ),
      ],
    )
  );
}