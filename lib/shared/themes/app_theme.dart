import 'package:eq_trainer/shared/themes/app_colors.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';
import 'package:eq_trainer/main.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

class AppTheme {
  AppTheme._();

  static ThemeData theme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      fontFamily: 'PretendardVariable',
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
    );
  }

  static final lightTheme = theme(AppColors.lightScheme);
  static final darkTheme = theme(AppColors.darkScheme);
}

class ThemeProvider extends ChangeNotifier {
  // Load the persisted choice so theme mode survives restart instead of
  // resetting to system every launch.
  ThemeMode _themeMode = ThemeMode.values[savedMiscSettingsValue.themeMode];
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    // savedMiscSettingsValue is `late final` — mutate its field in place
    // (matches the convention used by the other settings cards) and persist
    // a copy to Hive.
    savedMiscSettingsValue.themeMode = mode.index;
    Hive.box<MiscSettings>(miscSettingsBoxName).put(
      miscSettingsKey,
      savedMiscSettingsValue.copyWith(inputThemeMode: mode.index),
    );
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.system);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}

extension BuildContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colors => theme.colorScheme;
}