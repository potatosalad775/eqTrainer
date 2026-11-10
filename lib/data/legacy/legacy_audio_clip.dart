import 'package:hive_ce_flutter/hive_flutter.dart';

part 'legacy_audio_clip.g.dart';

// Read-only history: the clip library lives in a JSON file now. This exists so
// migrateLegacyClips can read boxes written by older versions. The typeId and
// field numbers are what those boxes hold, so they must not change.

@HiveType(typeId: 0)
class LegacyAudioClip {
  @HiveField(0)
  String fileName;
  @HiveField(1)
  String ogAudioName;
  @HiveField(2)
  double duration;
  @HiveField(3)
  bool isEnabled;

  LegacyAudioClip(
    this.fileName,
    this.ogAudioName,
    this.duration,
    this.isEnabled,
  );
}
