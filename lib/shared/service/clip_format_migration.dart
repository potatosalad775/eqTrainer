import 'dart:async';
import 'dart:io';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/model/audio_clip.dart';
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
///
/// It yields to playback. A decode-plus-encode is CPU-seconds per clip on the
/// hardware this app is most used on — a phone or a DAP, where the library is
/// also largest — so a run competing with a live session is the one way this
/// can be heard. Screens that play audio [pause] it on entry and [resume] it
/// on exit; the checkpoint is between clips, which the per-clip commit makes
/// free. Blocking the user instead was considered and rejected: a large
/// library on a slow device is minutes of a dead Start button, and the
/// `.m4a` clips still play through [PlayerService]'s decode-on-load fallback
/// in the meantime, so there is nothing to wait for.
class ClipFormatMigration extends ChangeNotifier {
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

  bool _running = false;
  int _done = 0;
  int _total = 0;

  /// Nesting depth, not a flag: a playlist preview opened over a session page
  /// would otherwise resume the run while the session is still playing.
  int _pauseDepth = 0;
  Completer<void>? _resumed;

  /// Whether a run is in flight. Stays true across a pause — the work is
  /// outstanding either way.
  bool get isRunning => _running;

  /// Clips finished so far in this run, out of [total]. Both are 0 when idle.
  int get done => _done;
  int get total => _total;

  bool get isPaused => _pauseDepth > 0;

  /// Holds the run at the next clip boundary. Balance every call with
  /// [resume]; a clip already in flight finishes first.
  void pause() {
    _pauseDepth++;
    _resumed ??= Completer<void>();
    if (_pauseDepth == 1) notifyListeners();
  }

  /// Releases one [pause]. Unbalanced calls are ignored rather than driving
  /// the depth negative, so a double dispose cannot un-pause a live session.
  void resume() {
    if (_pauseDepth == 0) return;
    _pauseDepth--;
    if (_pauseDepth > 0) return;
    _resumed?.complete();
    _resumed = null;
    notifyListeners();
  }

  Future<void> _waitWhilePaused() async {
    while (_pauseDepth > 0) {
      await _resumed!.future;
    }
  }

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
  ///
  /// Concurrent runs are refused rather than queued — two passes over the same
  /// library would race each other for the same source files.
  Future<int> run() async {
    if (_running) return 0;

    // The scan is synchronous, so this whole prologue runs before the first
    // await. _running has to be set inside it: yielding first would let a
    // second run() past the guard and race this one over the same files.
    final legacy = _repository
        .getAllClips()
        .where((clip) => _legacyExts.contains(p.extension(clip.fileName).toLowerCase()))
        .toList(growable: false);
    if (legacy.isEmpty) return 0;

    _running = true;
    _done = 0;
    _total = legacy.length;
    notifyListeners();

    try {
      return await _convertAll(legacy, await _dirs.getClipsPath());
    } finally {
      _running = false;
      _done = 0;
      _total = 0;
      notifyListeners();
    }
  }

  Future<int> _convertAll(List<AudioClip> legacy, String clipsPath) async {
    var converted = 0;

    for (final clip in legacy) {
      // Between clips, never mid-clip: the file being converted has to reach
      // either "committed" or "untouched" before anything else looks at it.
      await _waitWhilePaused();

      if (await _convertOne(clip, clipsPath)) converted++;

      _done++;
      notifyListeners();
    }

    return converted;
  }

  /// Converts one clip, returning whether it was committed.
  Future<bool> _convertOne(AudioClip clip, String clipsPath) async {
    final source = File(p.join(clipsPath, clip.fileName));
    if (!await source.exists()) {
      // A record whose file is already gone. Deleting the record here would
      // be a surprising side effect of a format migration, so leave it for
      // the playlist to surface as it does today.
      return false;
    }

    final sourceExt = p.extension(clip.fileName).toLowerCase();
    final targetExt = targetExtForImport(sourceExt, _importFormat);
    if (targetExt == null) {
      // Unreachable for _legacyExts, which no format setting maps to null.
      // Skipping beats converting to an extension we did not choose.
      return false;
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

      // The clip can be deleted from the playlist while we are converting it.
      // updateFileNameByKey no-ops on a key that is gone, so without this the
      // file we just wrote would stay on disk with no record pointing at it.
      if (!_repository.getAllClips().any((c) => c.key == clip.key)) {
        await dest.delete();
        return false;
      }

      // Commit before deleting: if the process dies here the worst case is
      // an orphaned .m4a next to a working clip, never a record pointing at
      // a file that no longer exists.
      await _repository.updateFileNameByKey(clip.key, destName);

      try {
        await source.delete();
      } catch (e) {
        // The clip may be open in the player. The record already points at
        // the new file, so this only leaks the old file's disk space.
        debugPrint('[ClipFormatMigration] kept ${clip.fileName}: $e');
      }
      return true;
    } catch (e) {
      debugPrint('[ClipFormatMigration] failed on ${clip.fileName}: $e');
      try {
        if (await dest.exists()) await dest.delete();
      } catch (_) {}
      return false;
    }
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
