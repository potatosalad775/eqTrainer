import 'package:flutter/widgets.dart';
import 'package:eq_trainer/l10n/generated/app_localizations.dart';

export 'package:eq_trainer/l10n/generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
