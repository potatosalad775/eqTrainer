import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

class AudioClip extends Equatable {
  /// [id] defaults to the file's basename, which every format rewrite preserves.
  AudioClip(
    this.fileName,
    this.ogAudioName,
    this.duration,
    this.isEnabled, {
    String? id,
  }) : id = id ?? p.basenameWithoutExtension(fileName);

  factory AudioClip.fromJson(Map<String, dynamic> json) => AudioClip(
        json['fileName'] as String,
        json['ogAudioName'] as String,
        (json['duration'] as num).toDouble(),
        json['isEnabled'] as bool,
        id: json['id'] as String,
      );

  final String id;
  final String fileName;    // Actual File name
  final String ogAudioName; // Original Audio File name
  final double duration;    // Duration of Audio Clip
  final bool isEnabled;

  AudioClip copyWith({String? fileName, bool? isEnabled}) => AudioClip(
        fileName ?? this.fileName,
        ogAudioName,
        duration,
        isEnabled ?? this.isEnabled,
        id: id,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'ogAudioName': ogAudioName,
        // JSON has no NaN or Infinity, and one bad value must not stop the
        // whole library from saving.
        'duration': duration.isFinite ? duration : 0.0,
        'isEnabled': isEnabled,
      };

  @override
  List<Object?> get props => [id, fileName, ogAudioName, duration, isEnabled];
}
