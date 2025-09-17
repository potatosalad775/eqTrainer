import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/service/app_directories.dart';

abstract class IAudioClipRepository {
  Future<void> addClip(AudioClip clip);
  // Return all clips (synchronous). PlaylistService will filter/map.
  List<AudioClip> getAllClips();
  // Subscribe to changes as a stream, including initial snapshot.
  Stream<List<AudioClip>> watchClips();
  // Delete/update/toggle by index (maintaining current Hive Box index order)
  Future<void> deleteAt(int index);
  Future<void> updateAt(int index, AudioClip clip);
  Future<void> toggleEnabledAt(int index);
}

class AudioClipService {
  AudioClipService(this._repository, this._dirs);

  final IAudioClipRepository _repository;
  final AppDirectories _dirs;

  /// Generate Audio Clip from Source File
  /// - sourcePath: Original File Path
  /// - startSec/endSec: start/end time in seconds (only used when isEdit is true)
  /// - isEdit: If true, trim the source file to create a clip;
  Future<void> createClip({
    required String sourcePath,
    required double startSec,
    required double endSec,
    required bool isEdit,
  }) async {
    // Prepare Paths
    final String fileBase = DateTime.now().microsecondsSinceEpoch.toString();
    final audioClipPath = await _dirs.getClipsPath();
    String ext = p.extension(sourcePath).toLowerCase();
    if (ext != '.wav' && ext != '.mp3' && ext != '.flac') {
      ext = '.flac';
    }
    final String destPath = '$audioClipPath${Platform.pathSeparator}$fileBase$ext';

    // Generate Clip File
    late final double duration;
    if ((Platform.isAndroid || Platform.isIOS || Platform.isMacOS) && isEdit) {
      final int startMs = (startSec * 1000).toInt();
      final int durMs = (endSec * 1000).toInt() - startMs;
      duration = endSec - startSec;
      final args = [
        '-y',
        '-vn',
        '-ss',
        '${startMs}ms',
        '-i',
        sourcePath,
        '-to',
        '${durMs}ms',
        destPath,
      ];
      try {
        await FFmpegKit.executeWithArguments(args);
      } catch (e) {
        throw Exception('FFmpeg execution failed: $e');
      }
    } else {
      duration = endSec;
      try {
        await File(sourcePath).copy(destPath);
      } catch (e) {
        throw Exception('File copy failed: $e');
      }
    }

    // Save Metadata to DB
    final originalName = p.basename(sourcePath);
    final clip = AudioClip(
      '$fileBase$ext',
      originalName,
      duration,
      true,
    );

    await _repository.addClip(clip);
  }
}
