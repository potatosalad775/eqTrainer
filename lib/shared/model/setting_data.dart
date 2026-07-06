import 'package:hive_ce_flutter/hive_flutter.dart';

part 'setting_data.g.dart';

@HiveType(typeId: 1)
class BackendData {
  @HiveField(0, defaultValue: [])
  List<String> backendList;

  BackendData(
    this.backendList,
  );
}

@HiveType(typeId: 2)
class MiscSettings {
  @HiveField(0, defaultValue: false)
  bool frequencyToolTip;

  @HiveField(1, defaultValue: 1) // Default to allM4A
  int importFormat;

  @HiveField(2, defaultValue: true)
  bool volumeCompensation;

  // ThemeMode.values index (system=0, light=1, dark=2). Persisted so the
  // user's choice survives restart instead of resetting to system every launch.
  @HiveField(3, defaultValue: 0)
  int themeMode;

  MiscSettings(
    this.frequencyToolTip,
    this.importFormat,
    this.volumeCompensation, {
    this.themeMode = 0,
  });

  MiscSettings copyWith({
    bool? inputFrequencyToolTip,
    int? inputImportFormat,
    bool? inputVolumeCompensation,
    int? inputThemeMode,
  }) {
    return MiscSettings(
      inputFrequencyToolTip ?? frequencyToolTip,
      inputImportFormat ?? importFormat,
      inputVolumeCompensation ?? volumeCompensation,
      themeMode: inputThemeMode ?? themeMode,
    );
  }
}