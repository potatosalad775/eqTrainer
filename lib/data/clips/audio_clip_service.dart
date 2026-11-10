import 'dart:io';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/data/app_directories.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';

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
  /// - originalPath: The file [sourcePath] was converted from, if it was. A trim
  ///   reads this instead, so that a lossy import is not encoded a second time on
  ///   top of the first.
  Future<void> createClip({
    required String sourcePath,
    String? originalPath,
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
      final start = Duration(microseconds: (startSec * 1e6).round());
      final end = Duration(microseconds: (endSec * 1e6).round());
      duration = endSec - startSec;
      try {
        await _trim(
          sourcePath: sourcePath,
          originalPath: originalPath,
          destPath: destPath,
          start: start,
          end: end,
        );
      } catch (e) {
        await _deleteQuietly(destPath);
        // The save button tells the user why, since retrying cannot help.
        if (e is UnsupportedChannelCountException ||
            isUnreadableAudioError(e)) {
          rethrow;
        }
        throw Exception('Audio trim failed: $e');
      }
    } else {
      duration = endSec;
      try {
        await File(sourcePath).copy(destPath);
      } catch (e) {
        await _deleteQuietly(destPath);
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

    try {
      await _repository.addClip(clip);
    } catch (_) {
      await _deleteQuietly(destPath);
      rethrow;
    }
  }

  /// Removes a file no record will point at. The original error is the one worth
  /// reporting, so a failure here is ignored.
  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Trims from [originalPath] where possible. The picked file can stop being
  /// readable while the editor is open, on a removable drive for example, in which
  /// case the converted file is what is left, at the cost of the extra generation.
  Future<void> _trim({
    required String sourcePath,
    required String? originalPath,
    required String destPath,
    required Duration start,
    required Duration end,
  }) async {
    if (originalPath != null && originalPath != sourcePath) {
      try {
        await _encoder.trimFile(
          sourcePath: originalPath,
          destPath: destPath,
          start: start,
          end: end,
        );
        return;
      } on SoLoudOfflineDecodeCppException catch (_) {
        // Fall through to the converted file.
      }
    }
    await _encoder.trimFile(
      sourcePath: sourcePath,
      destPath: destPath,
      start: start,
      end: end,
    );
  }
}
