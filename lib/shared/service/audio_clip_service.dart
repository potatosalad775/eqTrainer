import 'dart:io';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/clip_encoder.dart';

class AudioClipService {
  AudioClipService(this._repository, this._dirs, {ClipEncoder? encoder})
      : _encoder = encoder ?? ClipEncoder();

  final IAudioClipRepository _repository;
  final AppDirectories _dirs;
  final ClipEncoder _encoder;

  /// Generate Audio Clip from Source File
  /// - sourcePath: Original File Path
  /// - startSec/endSec: start/end time in seconds
  /// - isTrimmed: If true, trim the source file; otherwise copy as-is.
  Future<void> createClip({
    required String sourcePath,
    required double startSec,
    required double endSec,
    required bool isTrimmed,
    required int importFormat,
  }) async {
    // Prepare Paths
    final String fileBase = DateTime.now().microsecondsSinceEpoch.toString();
    final audioClipPath = await _dirs.getClipsPath();
    final sourceExt = p.extension(sourcePath).toLowerCase();

    // A trim always re-encodes, so its target follows the format setting
    // rather than the source's container. An untrimmed clip is a byte copy,
    // so it keeps whatever it already was.
    final String ext =
        isTrimmed ? trimOutputExt(sourceExt, importFormat) : sourceExt;
    final String destPath = '$audioClipPath${Platform.pathSeparator}$fileBase$ext';

    // Generate Clip File
    late final double duration;
    if (isTrimmed) {
      final start = Duration(milliseconds: (startSec * 1000).toInt());
      final end = Duration(milliseconds: (endSec * 1000).toInt());
      duration = endSec - startSec;
      try {
        if (ext == '.wav') {
          // trimAudio() writes WAV directly, so nothing else is needed.
          await AudioDecoder.trimAudio(sourcePath, destPath, start, end);
        } else {
          // trimAudio() can only write .wav or .m4a, so a FLAC or Opus target
          // trims to a temporary WAV first and encodes from that. The temp
          // file is removed whether or not the encode succeeds.
          final tempWav = '$destPath.trim.wav';
          try {
            await AudioDecoder.trimAudio(sourcePath, tempWav, start, end);
            await _encoder.encodeWavBytes(
              wavBytes: await File(tempWav).readAsBytes(),
              destPath: destPath,
            );
          } finally {
            final temp = File(tempWav);
            if (temp.existsSync()) {
              try {
                temp.deleteSync();
              } catch (_) {
                // A leftover temp file is not worth failing the import over.
              }
            }
          }
        }
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
  /// removed by its Hive key (stable even if the box changed while a
  /// confirmation dialog was open). Without the file removal this left the
  /// file on disk forever, leaking storage on every deletion.
  Future<void> deleteClip(AudioClip clip) async {
    final clipsPath = await _dirs.getClipsPath();
    final file = File(p.join(clipsPath, clip.fileName));
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignore: still remove the record so the entry doesn't dangle.
    }
    await _repository.deleteByKey(clip.key);
  }
}
