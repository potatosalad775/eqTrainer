import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language the user picked in settings; `null` follows the device.
///
/// Stored under the key, and through the legacy `SharedPreferences` API, that
/// easy_localization used, so a choice made before the move to gen_l10n
/// survives it. SharedPreferencesAsync would read a different store on Android.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider._(this._prefs) : _locale = _parse(_prefs.getString(_key));

  static const _key = 'locale';

  static Future<LocaleProvider> load() async =>
      LocaleProvider._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  Locale? _locale;

  Locale? get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    _prefs.setString(_key, locale.languageCode);
    notifyListeners();
  }

  // Older versions could save a region too (`ko_KR`). Only the language is
  // meaningful: every translation is language-only.
  static Locale? _parse(String? saved) =>
      saved == null ? null : Locale(saved.split('_').first);
}
