import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/clip_encoder.dart';

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
/// Libraries that went through [ClipFormatMigration] hold WAV copies of what
/// used to be m4a, and a WAV-mode import produces more. FLAC stores the same
/// samples in roughly half the space, and SoLoud decodes it natively, so the
/// only thing given up is disk usage.
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
  ClipRecompressService(this._repository, this._dirs, {ClipEncoder? encoder})
      : _encoder = encoder ?? ClipEncoder();

  final IAudioClipRepository _repository;
  final AppDirectories _dirs;
  final ClipEncoder _encoder;

  /// A FLAC file smaller than its own magic plus STREAMINFO did not encode,
  /// whatever the encoder reported. This is the "verifiably wrote something"
  /// gate before the original is deleted.
  static const _minFlacBytes = 42;

  /// Reports how much a pass would reclaim, without changing anything.
  Future<RecompressEstimate> estimate() async {
    final clipsPath = await _dirs.getClipsPath();
    var count = 0;
    var bytes = 0;

    for (final clip in _candidates()) {
      final file = File(p.join(clipsPath, clip.fileName));
      if (!file.existsSync()) continue;
      count++;
      bytes += file.lengthSync();
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
    if (candidates.isEmpty) {
      return const RecompressResult(converted: 0, failed: 0, bytesSaved: 0);
    }

    final clipsPath = await _dirs.getClipsPath();
    var converted = 0;
    var failed = 0;
    var saved = 0;
    var done = 0;

    for (final clip in candidates) {
      final source = File(p.join(clipsPath, clip.fileName));
      if (!source.existsSync()) {
        done++;
        onProgress?.call(done, candidates.length);
        continue;
      }

      final destName = '${p.basenameWithoutExtension(clip.fileName)}.flac';
      final dest = File(p.join(clipsPath, destName));

      try {
        final sourceBytes = source.lengthSync();

        // A leftover from an interrupted run is a partial file, not a clip.
        if (dest.existsSync()) dest.deleteSync();

        await _encoder.encodeWavBytes(
          wavBytes: await source.readAsBytes(),
          destPath: dest.path,
        );

        if (!dest.existsSync() || dest.lengthSync() < _minFlacBytes) {
          throw const FileSystemException('encoded file is empty or missing');
        }

        final destBytes = dest.lengthSync();

        // If FLAC came out no smaller there is nothing to gain, and swapping
        // would only churn the file. Keep the WAV.
        if (destBytes >= sourceBytes) {
          dest.deleteSync();
          done++;
          onProgress?.call(done, candidates.length);
          continue;
        }

        // Commit before deleting: if the process dies here the worst case is
        // an orphaned .wav beside a working .flac, never a record pointing at
        // a file that is gone.
        await _repository.updateFileNameByKey(clip.key, destName);
        converted++;
        saved += sourceBytes - destBytes;

        try {
          source.deleteSync();
        } catch (e) {
          // The clip may be open in the player. The record already points at
          // the FLAC, so this only leaks the old file's disk space.
          debugPrint('[ClipRecompress] kept ${clip.fileName}: $e');
        }
      } catch (e) {
        failed++;
        debugPrint('[ClipRecompress] failed on ${clip.fileName}: $e');
        try {
          if (dest.existsSync()) dest.deleteSync();
        } catch (_) {
          // Nothing more to do; the original is untouched either way.
        }
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

  List<AudioClip> _candidates() => _repository
      .getAllClips()
      .where((clip) => p.extension(clip.fileName).toLowerCase() == '.wav')
      .toList(growable: false);
}
