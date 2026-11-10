import 'package:eq_trainer/data/clips/clip_import.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:flutter/foundation.dart';

/// What to tell the user about a failed import step.
///
/// [other] is the text for a failure that needs no explaining, which differs
/// between the page's dialog and the save button's snackbar. [platform] is for
/// tests.
String importFailureMessage(
  AppLocalizations l10n,
  ImportFailure failure, {
  required String other,
  TargetPlatform? platform,
}) =>
    switch (failure) {
      ImportFailure.tooManyChannels => l10n.importAlertTooManyChannelsContent,
      ImportFailure.unreadable => ffmpegMayBeMissing(platform: platform)
          ? l10n.importAlertUnsupportedContentLinux
          : l10n.importAlertUnsupportedContent,
      ImportFailure.other => other,
    };
