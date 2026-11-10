import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/data/playback_hold.dart';

/// Converts a library's legacy `.m4a` and `.aac` clips, which the app does not
/// play through SoLoud, into a format it does, once.
///
/// eqTrainer used to prefer `.m4a` for imports because coast_audio decoded it
/// fastest under rapid filter switching. That reason is gone — the filter
/// switch is now a dry/wet fade on an already-running stream and never touches
/// the decoder — and neither extension is in the natively playable set
/// (AGENTS.md > Clip Formats), so these clips need a decode on every load. New
/// imports are converted at import time (`audio_format_helper.dart`); this
/// handles libraries that already exist.
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
/// can be heard. Every [PlayerService] [pause]s it when built and [resume]s it
/// when disposed; the checkpoint is between clips, which the per-clip commit makes
/// free. Blocking the user instead was considered and rejected: a large
/// library on a slow device is minutes of a dead Start button, and legacy
/// clips still play through [PlayerService]'s decode-on-load fallback in the
/// meantime, so there is nothing to wait for.
class ClipFormatMigration extends ChangeNotifier implements PlaybackHold {
  ClipFormatMigration(
    this._library, {
    required int importFormat,
    ClipEncoder? encoder,
  })  : _importFormat = importFormat,
        _encoder = encoder ?? ClipEncoder();

  final ClipLibrary _library;
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
  @override
  void pause() {
    _pauseDepth++;
    _resumed ??= Completer<void>();
    if (_pauseDepth == 1) _notifyOffFrame();
  }

  /// Releases one [pause]. Unbalanced calls are ignored rather than driving
  /// the depth negative, so a double dispose cannot un-pause a live session.
  @override
  void resume() {
    if (_pauseDepth == 0) return;
    _pauseDepth--;
    if (_pauseDepth > 0) return;
    _resumed?.complete();
    _resumed = null;
    _notifyOffFrame();
  }

  /// [pause] and [resume] are called from `initState` and `dispose`, which run
  /// inside the build phase. Notifying there marks this provider's element
  /// dirty while the framework is already building it, which is an assertion
  /// in debug and a dropped rebuild in release, so the notification waits for
  /// the end of the frame. The pause itself still takes effect immediately —
  /// only the listeners are deferred.
  void _notifyOffFrame() {
    switch (SchedulerBinding.instance.schedulerPhase) {
      case SchedulerPhase.persistentCallbacks:
      case SchedulerPhase.midFrameMicrotasks:
        SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
      case SchedulerPhase.idle:
      case SchedulerPhase.transientCallbacks:
      case SchedulerPhase.postFrameCallbacks:
        notifyListeners();
    }
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
    final legacy = _library.clips
        .where((clip) => _legacyExts.contains(p.extension(clip.fileName).toLowerCase()))
        .toList(growable: false);
    if (legacy.isEmpty) return 0;

    _running = true;
    _done = 0;
    _total = legacy.length;
    notifyListeners();

    try {
      return await _convertAll(legacy);
    } finally {
      _running = false;
      _done = 0;
      _total = 0;
      notifyListeners();
    }
  }

  Future<int> _convertAll(List<AudioClip> legacy) async {
    var converted = 0;

    for (final clip in legacy) {
      // Between clips, never mid-clip: the file being converted has to reach
      // either "committed" or "untouched" before anything else looks at it.
      await _waitWhilePaused();

      if (await _convertOne(clip)) converted++;

      _done++;
      notifyListeners();
    }

    return converted;
  }

  /// Converts one clip, returning whether it was committed.
  Future<bool> _convertOne(AudioClip clip) async {
    final sourceExt = p.extension(clip.fileName).toLowerCase();
    final targetExt = targetExtForImport(sourceExt, _importFormat);
    if (targetExt == null) {
      // Unreachable for _legacyExts, which no format setting maps to null.
      // Skipping beats converting to an extension we did not choose.
      return false;
    }

    // A record whose file is already gone comes back as sourceMissing and is
    // left for the playlist to show, not deleted by a format migration.
    final result = await _library.rewrite(
      clip.id,
      extension: targetExt,
      produce: (sourcePath, destPath) =>
          _encoder.convertFile(sourcePath: sourcePath, destPath: destPath),
    );
    return result.status == RewriteStatus.committed;
  }
}
