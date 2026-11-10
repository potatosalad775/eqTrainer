import 'dart:io';

import 'package:eq_trainer/data/clips/audio_clip_service.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Why an import step failed, as far as the user needs to be told apart.
enum ImportFailure { tooManyChannels, unreadable, other }

/// Sorts a failure from converting, loading or saving into an [ImportFailure].
///
/// A file can play and still be refused by the stricter offline decoder a trim
/// uses, so a retry is not always the right advice.
ImportFailure importFailureOf(Object error) {
  if (error is UnsupportedChannelCountException) {
    return ImportFailure.tooManyChannels;
  }
  if (isUnreadableAudioError(error)) return ImportFailure.unreadable;
  return ImportFailure.other;
}

/// Whether an unreadable file may just mean FFmpeg is not installed. Only Linux
/// leans on a system FFmpeg, for M4A, AAC, AIFF and WMA.
bool ffmpegMayBeMissing({TargetPlatform? platform}) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.linux;

/// One import: from the picked file to the saved clip.
///
/// [prepare] converts the picked file when the format policy says so, and from
/// then on this owns the converted temp file until [dispose]. [save] hands the
/// result to [AudioClipService]. The player that previews the file is not part
/// of this: the page loads what [prepare] returns.
class ClipImport {
  ClipImport({
    required AudioClipService clips,
    required int importFormat,
    ClipEncoder? encoder,
    Future<Directory> Function()? tempDirectory,
  })  : _clips = clips,
        _importFormat = importFormat,
        _encoder = encoder ?? ClipEncoder(),
        _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final AudioClipService _clips;
  final int _importFormat;
  final ClipEncoder _encoder;
  final Future<Directory> Function() _tempDirectory;

  String? _pickedPath;
  String? _sourcePath;
  String? _tempPath;
  bool _disposed = false;

  String? _targetExt(String pickedName) =>
      targetExtForImport(p.extension(pickedName).toLowerCase(), _importFormat);

  /// Whether [pickedName]'s format has to be converted before it can be edited,
  /// so the page can show its converting state before awaiting [prepare].
  bool needsConversion(String pickedName) => _targetExt(pickedName) != null;

  /// Converts the picked file if the format policy says so and returns the path
  /// the editor should load. Owns the converted temp file from here on.
  ///
  /// A failed conversion leaves no partial file and rethrows its error.
  Future<String> prepare({
    required String pickedPath,
    required String pickedName,
  }) async {
    final targetExt = _targetExt(pickedName);
    var sourcePath = pickedPath;

    if (targetExt != null) {
      final tempRoot = await _tempDirectory();
      final tempDir =
          await Directory(p.join(tempRoot.path, 'temp')).create(recursive: true);
      final destPath =
          p.join(tempDir.path, '${p.basenameWithoutExtension(pickedName)}$targetExt');

      try {
        await _encoder.convertFile(sourcePath: pickedPath, destPath: destPath);
      } catch (_) {
        // Never leave a half-written file behind.
        _deleteSyncQuietly(destPath);
        rethrow;
      }

      sourcePath = destPath;
      _tempPath = destPath;
      // A conversion cannot be cancelled, so [dispose] may have run while it
      // did and has found nothing to delete.
      if (_disposed) _deleteSyncQuietly(destPath);
    }

    _pickedPath = pickedPath;
    _sourcePath = sourcePath;
    return sourcePath;
  }

  /// Saves the clip, trimmed if either edge was moved off the full extent.
  Future<void> save({
    required Duration start,
    required Duration end,
    required Duration duration,
  }) {
    final sourcePath = _sourcePath;
    if (sourcePath == null) {
      throw StateError('save called before a successful prepare');
    }
    // Either edge counts. Comparing only the end once discarded a start-only
    // trim and copied the whole file.
    final isTrimmed = start != Duration.zero || end != duration;
    return _clips.createClip(
      sourcePath: sourcePath,
      originalPath: _pickedPath,
      startSec: start.inMicroseconds / 1e6,
      endSec: end.inMicroseconds / 1e6,
      isTrimmed: isTrimmed,
      importFormat: _importFormat,
    );
  }

  /// Deletes the converted temp file, best effort. If a conversion is still in
  /// flight, its output is deleted when it finishes.
  void dispose() {
    _disposed = true;
    final temp = _tempPath;
    if (temp != null) _deleteSyncQuietly(temp);
  }

  /// Best effort: a leftover temp file is a smaller problem than failing to
  /// finish tearing down, and the original error is the one worth reporting.
  void _deleteSyncQuietly(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
