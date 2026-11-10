import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';

/// [path] is the file being loaded, if that is what failed, so the dialog can say
/// when it may need FFmpeg.
Future<void> showPlayerErrorDialog(BuildContext context, { Function? action, Object? error, String? path }) async {
  final hint = path != null && mayNeedFfmpeg(path)
      ? "\n\n${context.l10n.importAlertUnsupportedContentLinux}"
      : "";
  return showDialog(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text("${context.l10n.errorPlayerAlertContent} : $error$hint"),
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