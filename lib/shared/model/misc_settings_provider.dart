import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';

const String miscSettingsBoxName = "miscSettingsBox";
const String miscSettingsKey = "miscSettingsKey";

/// Single ChangeNotifier owning misc settings (theme, tooltip, import format,
/// volume compensation), replacing the old `savedMiscSettingsValue` global
/// mutable singleton. Widgets watch/read this via Provider instead of each
/// wiring their own setState + parent-rebuild callback per setting.
class MiscSettingsProvider extends ChangeNotifier {
  MiscSettingsProvider()
      : _value = Hive.box<MiscSettings>(miscSettingsBoxName).get(miscSettingsKey) ??
            // volumeCompensation defaults to true, matching the Hive field's own
            // defaultValue — otherwise a fresh install and an upgraded install
            // disagree on the default and get opposite answer-leak protection
            // from loudness cues.
            MiscSettings(false, ImportFormat.smart, true) {
    _migrateImportFormat();
  }

  MiscSettings _value;

  /// Rewrites a retired import-format ordinal to the value it now behaves as.
  ///
  /// allM4a and keepOriginal are read as Smart everywhere already, so this
  /// changes no behavior; it just stops a box from carrying a value the
  /// settings UI cannot display forever. Done once at construction rather than
  /// on every read, and only written when it actually changes, so a launch
  /// with nothing to migrate does not touch the disk.
  void _migrateImportFormat() {
    final normalized = ImportFormat.normalize(_value.importFormat);
    if (normalized == _value.importFormat) return;
    _value = _value.copyWith(inputImportFormat: normalized);
    Hive.box<MiscSettings>(miscSettingsBoxName).put(miscSettingsKey, _value);
  }

  /// The stored import format, read without building a provider.
  ///
  /// `ClipFormatMigration` runs before the widget tree exists and needs the
  /// user's format choice to pick its target; the box is already open by then.
  /// Normalized on the way out for the same reason reads are elsewhere — a box
  /// written before the SoLoud migration can still hold a retired ordinal.
  static int storedImportFormat() => ImportFormat.normalize(
        Hive.box<MiscSettings>(miscSettingsBoxName)
                .get(miscSettingsKey)
                ?.importFormat ??
            ImportFormat.smart,
      );

  bool get frequencyToolTip => _value.frequencyToolTip;
  int get importFormat => _value.importFormat;
  bool get volumeCompensation => _value.volumeCompensation;
  ThemeMode get themeMode => ThemeMode.values[_value.themeMode];

  void setFrequencyToolTip(bool value) => _update(_value.copyWith(inputFrequencyToolTip: value));
  void setImportFormat(int value) => _update(_value.copyWith(inputImportFormat: value));
  void setVolumeCompensation(bool value) => _update(_value.copyWith(inputVolumeCompensation: value));
  void setThemeMode(ThemeMode mode) => _update(_value.copyWith(inputThemeMode: mode.index));

  void toggleTheme() {
    if (themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.system);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  void _update(MiscSettings newValue) {
    _value = newValue;
    Hive.box<MiscSettings>(miscSettingsBoxName).put(miscSettingsKey, newValue);
    notifyListeners();
  }
}
