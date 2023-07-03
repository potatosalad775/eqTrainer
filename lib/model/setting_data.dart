import 'package:hive_flutter/hive_flutter.dart';

part 'setting_data.g.dart';

@HiveType(typeId: 1)
class SettingData {
  @HiveField(0)
  AndroidAudioBackend androidAudioBackend;

  SettingData(
    this.androidAudioBackend,
  );
}

@HiveType(typeId: 2)
enum AndroidAudioBackend {
  @HiveField(0)
  aaudio,
  @HiveField(1)
  opensl
}