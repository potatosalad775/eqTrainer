import 'package:eq_trainer/shared/themes/app_colors.dart';
import 'package:flutter/material.dart';

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
  static final lightMediumContrastTheme = theme(AppColors.lightMediumContrastScheme);
  static final lightHighContrastTheme = theme(AppColors.lightHighContrastScheme);
  static final darkTheme = theme(AppColors.darkScheme);
  static final darkMediumContrastTheme = theme(AppColors.darkMediumContrastScheme);
  static final darkHighContrastTheme = theme(AppColors.darkHighContrastScheme);
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
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