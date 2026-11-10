import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';

/// Single ChangeNotifier owning misc settings (theme, tooltip, import format,
/// volume compensation), replacing the old `savedMiscSettingsValue` global
/// mutable singleton. Widgets watch/read this via Provider instead of each
/// wiring their own setState + parent-rebuild callback per setting.
///
/// Reads go straight to [SharedPreferences], whose cache is in memory, so there
/// is no second copy of the values to keep in step.
class MiscSettingsProvider extends ChangeNotifier {
  MiscSettingsProvider._(this._prefs) {
    _migrateImportFormat();
  }

  static const frequencyToolTipKey = 'frequencyToolTip';
  static const importFormatKey = 'importFormat';
  static const volumeCompensationKey = 'volumeCompensation';
  static const themeModeKey = 'themeMode';

  static Future<MiscSettingsProvider> load() async =>
      MiscSettingsProvider._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  /// Rewrites a retired import-format ordinal to the value it now behaves as.
  ///
  /// allM4a and keepOriginal are read as Smart everywhere already, so this
  /// changes no behavior; it just stops the store from carrying a value the
  /// settings UI cannot display forever. Done once at construction rather than
  /// on every read, and only written when it actually changes, so a launch
  /// with nothing to migrate does not touch the disk.
  void _migrateImportFormat() {
    final normalized = ImportFormat.normalize(importFormat);
    if (normalized == importFormat) return;
    _prefs.setInt(importFormatKey, normalized);
  }

  bool get frequencyToolTip => _prefs.getBool(frequencyToolTipKey) ?? false;
  int get importFormat => _prefs.getInt(importFormatKey) ?? ImportFormat.smart;
  // Defaults to true: compensation is what stops loudness cues leaking the answer.
  bool get volumeCompensation => _prefs.getBool(volumeCompensationKey) ?? true;
  // Stored as a ThemeMode.values index (system=0, light=1, dark=2).
  ThemeMode get themeMode => ThemeMode.values[_prefs.getInt(themeModeKey) ?? 0];

  void setFrequencyToolTip(bool value) {
    _prefs.setBool(frequencyToolTipKey, value);
    notifyListeners();
  }

  void setImportFormat(int value) {
    _prefs.setInt(importFormatKey, value);
    notifyListeners();
  }

  void setVolumeCompensation(bool value) {
    _prefs.setBool(volumeCompensationKey, value);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setInt(themeModeKey, mode.index);
    notifyListeners();
  }

  void toggleTheme() {
    if (themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.system);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}
