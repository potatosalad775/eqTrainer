import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';

/// How much disk a recompress pass would reclaim, and over how many clips.
@immutable
class RecompressEstimate {
  const RecompressEstimate({required this.clipCount, required this.totalBytes});

  /// Number of WAV clips that would be recompressed.
  final int clipCount;

  /// Bytes those clips currently occupy.
  final int totalBytes;

  bool get isEmpty => clipCount == 0;

  /// Rough post-FLAC size. FLAC on real music lands around half of WAV; this
  /// is only ever shown as an approximation, never used to decide anything.
  int get estimatedBytesAfter => totalBytes ~/ 2;
}

/// Result of a completed recompress pass.
@immutable
class RecompressResult {
  const RecompressResult({
    required this.converted,
    required this.failed,
    required this.bytesSaved,
  });

  final int converted;
  final int failed;
  final int bytesSaved;
}

/// Recompresses WAV clips in the library to FLAC, losslessly.
///
/// Libraries migrated back when [ClipFormatMigration] hardcoded WAV hold WAV
/// copies of what used to be m4a, and a WAV-mode import still produces more.
/// FLAC stores the same samples in roughly half the space, and SoLoud decodes
/// it natively, so the only thing given up is disk usage.
///
/// Deliberately user-triggered rather than automatic. It rewrites files the
/// user owns, and a long library costs real time and CPU, so it should be a
/// choice rather than something that happens during a launch.
///
/// It never recompresses to Opus. Opus is a fine *import* target for a source
/// that was already lossy, but re-encoding a user's existing lossless clips
/// into a lossy format would throw away audio they still have, silently and
/// irreversibly — on exactly the material they are training their ears
/// against.
class ClipRecompressService {
  ClipRecompressService(this._library, {ClipEncoder? encoder})
      : _encoder = encoder ?? ClipEncoder();

  final ClipLibrary _library;
  final ClipEncoder _encoder;

  /// Reports how much a pass would reclaim, without changing anything.
  Future<RecompressEstimate> estimate() async {
    var count = 0;
    var bytes = 0;

    for (final clip in _candidates()) {
      final size = await _library.fileSizeOf(clip.id);
      if (size == null) continue;
      count++;
      bytes += size;
    }

    return RecompressEstimate(clipCount: count, totalBytes: bytes);
  }

  /// Recompresses every WAV clip to FLAC.
  ///
  /// Never throws: a clip that fails is left exactly as it was and keeps its
  /// record, so a bad encode costs nothing but the attempt. [onProgress] is
  /// called with (done, total) after each clip.
  Future<RecompressResult> run({void Function(int done, int total)? onProgress}) async {
    final candidates = _candidates();
    var converted = 0;
    var failed = 0;
    var saved = 0;
    var done = 0;

    for (final clip in candidates) {
      final result = await _library.rewrite(
        clip.id,
        extension: '.flac',
        produce: (sourcePath, destPath) async => _encoder.encodeWavBytes(
          wavBytes: await File(sourcePath).readAsBytes(),
          destPath: destPath,
        ),
        // If FLAC came out no smaller there is nothing to gain, and swapping
        // would only churn the file. Keep the WAV.
        keep: (sourceBytes, destBytes) => destBytes < sourceBytes,
      );

      switch (result.status) {
        case RewriteStatus.committed:
          converted++;
          saved += result.sourceBytes - result.destBytes;
        case RewriteStatus.failed:
          failed++;
        case RewriteStatus.declined:
        case RewriteStatus.sourceMissing:
        case RewriteStatus.clipGone:
          break;
      }

      done++;
      onProgress?.call(done, candidates.length);
    }

    return RecompressResult(
      converted: converted,
      failed: failed,
      bytesSaved: saved,
    );
  }

  List<AudioClip> _candidates() => _library.clips
      .where((clip) => p.extension(clip.fileName).toLowerCase() == '.wav')
      .toList(growable: false);
}
