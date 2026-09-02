import 'dart:io';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/service/clip_encoder.dart';

/// Converts library clips that SoLoud cannot decode into a format it can, once.
///
/// eqTrainer used to prefer `.m4a` for imports because coast_audio decoded it
/// fastest under rapid filter switching. That reason is gone — the filter
/// switch is now a dry/wet fade on an already-running stream and never touches
/// the decoder — and `.m4a` is the one common format SoLoud *cannot* read, so
/// it went from the fast path to the only format needing a decode on every
/// load. New imports are converted at import time
/// (`audio_format_helper.dart`); this handles libraries that already exist.
///
/// The target comes from [targetExtForImport] against the user's stored
/// import-format setting, so an old clip lands where the same file would land
/// if it were imported today. It used to hardcode WAV, which meant the same
/// `.m4a` became `.wav` or `.opus` depending only on *when* it was imported,
/// and cost roughly six times the source's disk space to store a decode of an
/// already-lossy file. Under Smart these sources are lossy, so the target is
/// Opus at [ClipEncoder.opusBitrate] — a second lossy generation, but a
/// transparent one, and far below the multi-dB EQ boost the user is being
/// asked to identify. Anyone who would rather keep the decoded signal intact
/// can set All-FLAC or All-WAV, which this honours.
///
/// It runs as a migration rather than a per-load conversion because clips are
/// app-owned copies: converting once at startup costs one platform decode per
/// clip ever, while converting at load time would pay that delay on every
/// session launch and every track switch, forever.
///
/// Safe to run on every launch. It is idempotent — a library with nothing to
/// convert costs one in-memory scan — and each clip is committed
/// independently, so an interrupted run simply resumes on the next launch.
class ClipFormatMigration {
  ClipFormatMigration(
    this._repository,
    this._dirs, {
    required int importFormat,
    ClipEncoder? encoder,
  })  : _importFormat = importFormat,
        _encoder = encoder ?? ClipEncoder();

  final IAudioClipRepository _repository;
  final AppDirectories _dirs;
  final int _importFormat;
  final ClipEncoder _encoder;

  /// Extensions to convert away from. Everything SoLoud reads natively
  /// (wav/mp3/flac/ogg/opus) is left alone, including the lossy ones —
  /// re-encoding those would only lose a generation.
  static const _legacyExts = {'.m4a', '.aac'};

  /// An output file this small carries no audio in any container we write:
  /// a WAV header is 44 bytes, FLAC's magic plus STREAMINFO 42, and an Ogg
  /// Opus page header plus OpusHead 46. Whatever the converter reported, a
  /// file under this did not decode. This is the "verifiably produced
  /// something" gate before the original is deleted: cheap, and it needs no
  /// audio engine, which is not necessarily up when this runs.
  static const _minOutputBytes = 64;

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

      final sourceExt = p.extension(clip.fileName).toLowerCase();
      final targetExt = targetExtForImport(sourceExt, _importFormat);
      if (targetExt == null) {
        // Unreachable for _legacyExts, which no format setting maps to null.
        // Skipping beats converting to an extension we did not choose.
        continue;
      }

      final destName = '${p.basenameWithoutExtension(clip.fileName)}$targetExt';
      final dest = File(p.join(clipsPath, destName));

      try {
        // A leftover from a run interrupted between converting and committing
        // is a partial file, not a usable clip.
        if (await dest.exists()) await dest.delete();

        await _convert(source.path, dest.path, targetExt);

        if (!await dest.exists() || await dest.length() < _minOutputBytes) {
          throw const FileSystemException('converted file is empty or missing');
        }

        // Commit before deleting: if the process dies here the worst case is
        // an orphaned .m4a next to a working clip, never a record pointing at
        // a file that no longer exists.
        await _repository.updateFileNameByKey(clip.key, destName);
        converted++;

        try {
          await source.delete();
        } catch (e) {
          // The clip may be open in the player. The record already points at
          // the new file, so this only leaks the old file's disk space.
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

  /// Writes [sourcePath] to [destPath] in the format [targetExt] names.
  ///
  /// WAV goes through audio_decoder's file-based path, which is what it writes
  /// natively and never holds the clip in memory. Every other target has to go
  /// through [ClipEncoder] — audio_decoder is the only thing that can open a
  /// foreign container, and SoLoud's offline encoder the only thing that can
  /// write Opus or FLAC. That path does buffer the whole clip as float PCM,
  /// which is why this stays a background task rather than blocking startup.
  Future<void> _convert(String sourcePath, String destPath, String targetExt) {
    if (targetExt == '.wav') {
      return AudioDecoder.convertToWav(sourcePath, destPath);
    }
    return _encoder.convertFile(sourcePath: sourcePath, destPath: destPath);
  }
}
