import 'dart:async';
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
    void Function(String path)? deleteFile,
  })  : _clips = clips,
        _importFormat = importFormat,
        _encoder = encoder ?? ClipEncoder(),
        _tempDirectory = tempDirectory ?? getTemporaryDirectory,
        _deleteFile = deleteFile ?? _deleteIfPresent;

  final AudioClipService _clips;
  final int _importFormat;
  final ClipEncoder _encoder;
  final Future<Directory> Function() _tempDirectory;

  /// Deletes one file, throwing if it cannot. A parameter so a test can make
  /// it fail the way a file that is still open does on Windows.
  final void Function(String path) _deleteFile;

  /// How long a failed delete keeps being retried: 8 times, 250 ms apart.
  static const int _deleteRetries = 8;
  static const Duration _deleteRetryDelay = Duration(milliseconds: 250);

  /// Temp paths that a live import is converting to or still owns. Static
  /// because it is what one import's retry asks about another.
  static final Set<String> _claimed = {};

  static void _deleteIfPresent(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }

  String? _pickedPath;
  String? _sourcePath;
  String? _tempPath;
  bool _disposed = false;
  int _savesRunning = 0;

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

      _claimed.add(destPath);
      try {
        await _encoder.convertFile(sourcePath: pickedPath, destPath: destPath);
      } catch (_) {
        // Never leave a half-written file behind.
        _deleteQuietly(destPath);
        rethrow;
      }

      sourcePath = destPath;
      _tempPath = destPath;
      // A conversion cannot be cancelled, so [dispose] may have run while it
      // did and has found nothing to delete.
      if (_disposed) _deleteQuietly(destPath);
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
    _savesRunning++;
    return _clips
        .createClip(
          sourcePath: sourcePath,
          originalPath: _pickedPath,
          startSec: start.inMicroseconds / 1e6,
          endSec: end.inMicroseconds / 1e6,
          isTrimmed: isTrimmed,
          importFormat: _importFormat,
        )
        .whenComplete(() {
      // The save may be reading the temp file, so a dispose that came while it
      // ran left the file for it to delete.
      if (--_savesRunning == 0 && _disposed) _deleteTemp();
    });
  }

  /// Deletes the converted temp file, best effort. If a conversion is still in
  /// flight, its output is deleted when it finishes; if a save is, the file is
  /// deleted once the save has settled, since the save may be reading it.
  void dispose() {
    _disposed = true;
    if (_savesRunning == 0) _deleteTemp();
  }

  void _deleteTemp() {
    final temp = _tempPath;
    if (temp != null) _deleteQuietly(temp);
  }

  /// Best effort: a leftover temp file is a smaller problem than failing to
  /// finish tearing down, and the original error is the one worth reporting.
  ///
  /// One attempt at once, and if that fails, more in the background. The page
  /// disposes its player just before this and does not wait for it, and
  /// Windows will not delete a file that is still open. Nothing else clears
  /// the temp folder, so a file left here stays.
  void _deleteQuietly(String path) {
    _claimed.remove(path);
    try {
      _deleteFile(path);
    } catch (_) {
      unawaited(_retryDelete(path));
    }
  }

  Future<void> _retryDelete(String path) async {
    for (var i = 0; i < _deleteRetries; i++) {
      await Future<void>.delayed(_deleteRetryDelay);
      // The same file picked again converts to the same path, and that file
      // is the newer import's to delete.
      if (_claimed.contains(path)) return;
      try {
        _deleteFile(path);
        return;
      } catch (_) {}
    }
  }
}
