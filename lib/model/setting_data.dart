import 'package:hive_flutter/hive_flutter.dart';

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
  
  MiscSettings(
    this.frequencyToolTip,
  );

  MiscSettings copyWith({
    bool? inputFrequencyToolTip
  }) {
    return MiscSettings(
      inputFrequencyToolTip ?? frequencyToolTip
    );
  }
}