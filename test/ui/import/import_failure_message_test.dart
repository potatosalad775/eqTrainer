import 'package:eq_trainer/data/clips/clip_import.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/import/import_failure_message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  String message(ImportFailure failure, {TargetPlatform? platform}) =>
      importFailureMessage(l10n, failure,
          other: 'the other text', platform: platform);

  test('too many channels', () {
    expect(message(ImportFailure.tooManyChannels),
        l10n.importAlertTooManyChannelsContent);
  });

  test('other is whatever the caller says', () {
    expect(message(ImportFailure.other), 'the other text');
    expect(
      importFailureMessage(l10n, ImportFailure.other,
          other: l10n.importEditorSaveError),
      l10n.importEditorSaveError,
    );
  });

  test('unreadable says to install FFmpeg on Linux only', () {
    expect(message(ImportFailure.unreadable, platform: TargetPlatform.linux),
        l10n.importAlertUnsupportedContentLinux);
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      expect(message(ImportFailure.unreadable, platform: platform),
          l10n.importAlertUnsupportedContent);
    }
  });
}
