import 'package:hive_ce_flutter/hive_flutter.dart';

part 'audio_clip.g.dart';

@HiveType(typeId: 0)
class AudioClip {
  @HiveField(0)
  String fileName;    // Actual File name
  @HiveField(1)
  String ogAudioName; // Original Audio File name
  @HiveField(2)
  double duration;    // Duration of Audio Clip
  @HiveField(3)
  bool isEnabled;     //

  AudioClip(
    this.fileName,
    this.ogAudioName,
    this.duration,
    this.isEnabled,
  );
}