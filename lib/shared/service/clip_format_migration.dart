import 'dart:io';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';

/// Converts library clips that SoLoud cannot decode into WAV, once.
///
/// eqTrainer used to prefer `.m4a` for imports because coast_audio decoded it
/// fastest under rapid filter switching. That reason is gone — the filter
/// switch is now a dry/wet fade on an already-running stream and never touches
/// the decoder — and `.m4a` is the one common format SoLoud *cannot* read, so
/// it went from the fast path to the only format needing a decode on every
/// load. New imports are converted at import time
/// (`audio_format_helper.dart`); this handles libraries that already exist.
///
/// It runs as a migration rather than a per-load conversion because clips are
/// app-owned copies: converting once at startup costs one GStreamer /
/// MediaCodec pass per clip ever, while converting at load time would pay that
/// delay on every session launch and every track switch, forever.
///
/// Safe to run on every launch. It is idempotent — a library with nothing to
/// convert costs one in-memory scan — and each clip is committed
/// independently, so an interrupted run simply resumes on the next launch.
class ClipFormatMigration {
  ClipFormatMigration(this._repository, this._dirs);

  final IAudioClipRepository _repository;
  final AppDirectories _dirs;

  /// Extensions to convert away from. Everything SoLoud reads natively
  /// (wav/mp3/flac/ogg) is left alone, including the lossy ones — re-encoding
  /// those would only lose a generation.
  static const _legacyExts = {'.m4a', '.aac'};

  /// A WAV file smaller than its own 44-byte header did not decode, whatever
  /// the converter reported. This is the "verifiably loads" gate before the
  /// original is deleted: cheap, and it needs no audio engine, which is not
  /// necessarily up when this runs.
  static const _minWavBytes = 44;

  /// Converts every legacy clip it can and returns how many it converted.
  ///
  /// Never throws: a clip that fails is left exactly as it was, keeps its
  /// record, and still plays through [PlayerService]'s decode-on-load
  /// fallback. A broken converter must not cost the user their library.
  Future<int> run() async {
    final legacy = _repository
        .getAllClips()
        .where((clip) => _legacyExts.contains(p.extension(clip.fileName).toLowerCase()))
        .toList(growable: false);
    if (legacy.isEmpty) return 0;

    final clipsPath = await _dirs.getClipsPath();
    var converted = 0;

    for (final clip in legacy) {
      final source = File(p.join(clipsPath, clip.fileName));
      if (!await source.exists()) {
        // A record whose file is already gone. Deleting the record here would
        // be a surprising side effect of a format migration, so leave it for
        // the playlist to surface as it does today.
        continue;
      }

      final destName = '${p.basenameWithoutExtension(clip.fileName)}.wav';
      final dest = File(p.join(clipsPath, destName));

      try {
        // A leftover from a run interrupted between converting and committing
        // is a partial file, not a usable clip.
        if (await dest.exists()) await dest.delete();

        await AudioDecoder.convertToWav(source.path, dest.path);

        if (!await dest.exists() || await dest.length() < _minWavBytes) {
          throw const FileSystemException('converted file is empty or missing');
        }

        // Commit before deleting: if the process dies here the worst case is
        // an orphaned .m4a next to a working .wav, never a record pointing at
        // a file that no longer exists.
        await _repository.updateFileNameByKey(clip.key, destName);
        converted++;

        try {
          await source.delete();
        } catch (e) {
          // The clip may be open in the player. The record already points at
          // the WAV, so this only leaks the old file's disk space.
          debugPrint('[ClipFormatMigration] kept ${clip.fileName}: $e');
        }
      } catch (e) {
        debugPrint('[ClipFormatMigration] failed on ${clip.fileName}: $e');
        try {
          if (await dest.exists()) await dest.delete();
        } catch (_) {}
      }
    }

    return converted;
  }
}
