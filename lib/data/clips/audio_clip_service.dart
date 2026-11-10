import 'dart:io';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';

class AudioClipService {
  AudioClipService(this._library, {ClipEncoder? encoder})
      : _encoder = encoder ?? ClipEncoder();

  final ClipLibrary _library;
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
    final sourceExt = p.extension(sourcePath).toLowerCase();

    // A trim always re-encodes, so its target follows the format setting
    // rather than the source's container. An untrimmed clip is a byte copy,
    // so it keeps whatever it already was.
    final String ext =
        isTrimmed ? trimOutputExt(sourceExt, importFormat) : sourceExt;

    // The library names the file, removes it if either step fails, and saves
    // the record. What is decided here is what produces the file and how its
    // failure is reported.
    await _library.add(
      extension: ext,
      originalName: p.basename(sourcePath),
      duration: isTrimmed ? endSec - startSec : endSec,
      produce: (destPath) async {
        if (isTrimmed) {
          try {
            await _trim(
              sourcePath: sourcePath,
              originalPath: originalPath,
              destPath: destPath,
              start: Duration(microseconds: (startSec * 1e6).round()),
              end: Duration(microseconds: (endSec * 1e6).round()),
            );
          } catch (e) {
            // The save button tells the user why, since retrying cannot help.
            if (e is UnsupportedChannelCountException ||
                isUnreadableAudioError(e)) {
              rethrow;
            }
            throw Exception('Audio trim failed: $e');
          }
        } else {
          try {
            await File(sourcePath).copy(destPath);
          } catch (e) {
            throw Exception('Audio copy failed: $e');
          }
        }
      },
    );
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
