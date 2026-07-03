import 'dart:io';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';

class AudioClipService {
  AudioClipService(this._repository, this._dirs);

  final IAudioClipRepository _repository;
  final AppDirectories _dirs;

  /// Generate Audio Clip from Source File
  /// - sourcePath: Original File Path
  /// - startSec/endSec: start/end time in seconds
  /// - isTrimmed: If true, trim the source file; otherwise copy as-is.
  Future<void> createClip({
    required String sourcePath,
    required double startSec,
    required double endSec,
    required bool isTrimmed,
  }) async {
    // Prepare Paths
    final String fileBase = DateTime.now().microsecondsSinceEpoch.toString();
    final audioClipPath = await _dirs.getClipsPath();
    final sourceExt = p.extension(sourcePath).toLowerCase();

    // trimAudio() only outputs .wav or .m4a — pick based on lossless/lossy
    final String ext = isTrimmed ? trimOutputExt(sourceExt) : sourceExt;
    final String destPath = '$audioClipPath${Platform.pathSeparator}$fileBase$ext';

    // Generate Clip File
    late final double duration;
    if (isTrimmed) {
      final start = Duration(milliseconds: (startSec * 1000).toInt());
      final end = Duration(milliseconds: (endSec * 1000).toInt());
      duration = endSec - startSec;
      try {
        await AudioDecoder.trimAudio(
          sourcePath,
          destPath,
          start,
          end,
        );
      } catch (e) {
        throw Exception('Audio trim failed: $e');
      }
    } else {
      duration = endSec;
      try {
        await File(sourcePath).copy(destPath);
      } catch (e) {
        throw Exception('Audio copy failed: $e');
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

  /// Delete a clip's backing audio file and its DB record.
  ///
  /// The file is removed best-effort first (an orphaned file is a smaller
  /// problem than a record that outlives its file), then the record is
  /// removed at [index]. Without this the file was left on disk forever,
  /// leaking storage on every deletion.
  Future<void> deleteClip(AudioClip clip, int index) async {
    final clipsPath = await _dirs.getClipsPath();
    final file = File(p.join(clipsPath, clip.fileName));
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignore: still remove the record so the entry doesn't dangle.
    }
    await _repository.deleteAt(index);
  }
}
