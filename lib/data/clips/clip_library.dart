import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/data/app_directories.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/domain/audio_clip.dart';

/// How a [ClipLibrary.rewrite] ended.
enum RewriteStatus {
  /// The record points at the new file and the old one is gone, or at worst
  /// left behind.
  committed,

  /// The new file was produced but [ClipLibrary.rewrite]'s `keep` refused it.
  declined,

  /// The clip's file is not there. Its record is left alone.
  sourceMissing,

  /// The clip has no record, or lost it while the new file was produced.
  clipGone,

  /// Something went wrong. The clip is exactly as it was.
  failed,
}

@immutable
class RewriteResult {
  const RewriteResult(
    this.status, {
    this.sourceBytes = 0,
    this.destBytes = 0,
    this.error,
  });

  final RewriteStatus status;

  /// Size of the old file. 0 unless known.
  final int sourceBytes;

  /// Size of the new file. 0 unless known.
  final int destBytes;

  /// What went wrong, when [status] is [RewriteStatus.failed].
  final Object? error;
}

/// The clip library as the glossary defines it: records and files together.
///
/// Whatever needs a clip's file asks here, so nothing else joins a file name
/// onto the clips directory, and nothing else has to know that the two halves
/// can disagree. The records themselves live in the [IAudioClipRepository],
/// which plain edits (reorder, enable, watch) keep using directly.
///
/// Every lookup is by id against the library as it stands now, because a clip's
/// file can change under a caller that is holding an older copy of its record.
class ClipLibrary {
  ClipLibrary(this._repository, this._dirs);

  final IAudioClipRepository _repository;
  final AppDirectories _dirs;

  /// An output file this small carries no audio in any container we write: a
  /// WAV header is 44 bytes, FLAC's magic plus STREAMINFO 42 (the smallest),
  /// and an Ogg Opus page header plus OpusHead 46. Whatever the producer
  /// reported, a file under this did not encode. It is the "verifiably wrote
  /// something" gate before an original is deleted, and needs no audio engine.
  static const _minOutputBytes = 42;

  /// The records as they stand now.
  List<AudioClip> get clips => _repository.getAllClips();

  /// The clip's file, or null if there is no such clip or its file is missing.
  Future<String?> pathOf(String clipId) async {
    final clip = _clipById(clipId);
    if (clip == null) return null;
    final path = await _pathFor(clip);
    return await File(path).exists() ? path : null;
  }

  /// The size of the clip's file in bytes, or null as for [pathOf].
  Future<int?> fileSizeOf(String clipId) async {
    final path = await pathOf(clipId);
    return path == null ? null : File(path).length();
  }

  /// The ids of the clips whose file cannot be found.
  ///
  /// This is derived by looking at the disk each time it is asked and is never
  /// saved, so a clip whose file comes back stops being missing, and nothing is
  /// removed on the strength of one failed check (ADR 0003). Only the user
  /// deletes a missing clip.
  Future<Set<String>> missingClipIds() async {
    final missing = <String>{};
    for (final clip in clips) {
      if (!await File(await _pathFor(clip)).exists()) missing.add(clip.id);
    }
    return missing;
  }

  /// Paths of the enabled clips whose file exists, in library order.
  ///
  /// A missing clip is skipped and its record is kept: one failed existence
  /// check must not cost the user a record (ADR 0003).
  Future<List<String>> enabledClipPaths() async {
    final paths = <String>[];
    for (final clip in clips) {
      if (!clip.isEnabled) continue;
      final path = await _pathFor(clip);
      if (await File(path).exists()) paths.add(path);
    }
    return paths;
  }

  /// Re-resolves [path] against the library as it stands now, or returns null
  /// if that clip is gone.
  ///
  /// A session captures its paths once at launch and plays from that snapshot
  /// for its whole run, but a rewrite can change the extension underneath it.
  /// A rewrite keeps the record and the file's basename, so a stale snapshot
  /// entry is followed by basename. It matches on the file name's stem rather
  /// than the id, because a clip migrated from Hive can have an id that differs
  /// from its basename.
  Future<String?> resolvePath(String path) async {
    if (await File(path).exists()) return path;

    final stem = p.basenameWithoutExtension(path);
    for (final clip in clips) {
      if (p.basenameWithoutExtension(clip.fileName) != stem) continue;
      final current = await _pathFor(clip);
      return await File(current).exists() ? current : null;
    }
    return null;
  }

  /// Adds a clip. [produce] writes its file to the path it is given, which is
  /// named after the current time plus [extension] (with its dot).
  ///
  /// If [produce] or the record save fails, the file is removed and the
  /// original error propagates, so a failed import leaves nothing behind.
  Future<void> add({
    required String extension,
    required String originalName,
    required double duration,
    required Future<void> Function(String destPath) produce,
  }) async {
    final fileName = '${DateTime.now().microsecondsSinceEpoch}$extension';
    final destPath = p.join(await _dirs.getClipsPath(), fileName);
    try {
      await produce(destPath);
      await _repository.addClip(AudioClip(fileName, originalName, duration, true));
    } catch (_) {
      // The original error is the one worth reporting, so this is quiet.
      await _deleteQuietly(destPath);
      rethrow;
    }
  }

  /// Deletes a clip: its file, then its record. No-op if the clip is gone.
  ///
  /// The clip is looked up by [clipId] now, not taken from the caller, whose
  /// copy of the record can name a file a rewrite has since replaced.
  ///
  /// The file goes first and best-effort: an orphaned file is a smaller problem
  /// than a record that outlives its file.
  Future<void> delete(String clipId) async {
    final clip = _clipById(clipId);
    if (clip == null) return;
    await _deleteQuietly(await _pathFor(clip));
    await _repository.deleteById(clipId);
  }

  /// Replaces a clip's file with another produced from it, keeping the record
  /// and the basename and changing the extension to [extension] (with its dot).
  ///
  /// [produce] writes the new file from the old. [keep], if given, can refuse
  /// the result once both sizes are known.
  ///
  /// Never throws. Whatever goes wrong, the clip is left exactly as it was and
  /// the half-made file is removed.
  Future<RewriteResult> rewrite(
    String clipId, {
    required String extension,
    required Future<void> Function(String sourcePath, String destPath) produce,
    bool Function(int sourceBytes, int destBytes)? keep,
  }) async {
    final clip = _clipById(clipId);
    if (clip == null) return const RewriteResult(RewriteStatus.clipGone);

    String? destPath;
    try {
      final clipsPath = await _dirs.getClipsPath();
      final sourcePath = p.join(clipsPath, clip.fileName);
      if (!await File(sourcePath).exists()) {
        // Deleting the record here would be a surprising side effect of a
        // format change, so leave it for the playlist to show as missing.
        return const RewriteResult(RewriteStatus.sourceMissing);
      }

      final destName = '${p.basenameWithoutExtension(clip.fileName)}$extension';
      final candidate = p.join(clipsPath, destName);
      if (p.equals(candidate, sourcePath)) {
        // Producing into the source would destroy it.
        return RewriteResult(
          RewriteStatus.failed,
          error: ArgumentError.value(
            extension,
            'extension',
            'is the extension the clip already has',
          ),
        );
      }
      destPath = candidate;

      // A leftover from a run interrupted between producing and committing is
      // a partial file, not a usable clip.
      final leftover = File(destPath);
      if (await leftover.exists()) await leftover.delete();

      final sourceBytes = await File(sourcePath).length();
      await produce(sourcePath, destPath);

      final dest = File(destPath);
      if (!await dest.exists() || await dest.length() < _minOutputBytes) {
        throw const FileSystemException('produced file is empty or missing');
      }
      final destBytes = await dest.length();

      if (keep != null && !keep(sourceBytes, destBytes)) {
        await dest.delete();
        return RewriteResult(
          RewriteStatus.declined,
          sourceBytes: sourceBytes,
          destBytes: destBytes,
        );
      }

      // The clip can be deleted while its file is being produced.
      // updateFileNameById no-ops on an id that is gone, so without this the
      // new file would stay on disk with no record pointing at it.
      if (_clipById(clipId) == null) {
        await dest.delete();
        return const RewriteResult(RewriteStatus.clipGone);
      }

      // Commit before deleting: if the process dies here the worst case is an
      // orphaned source beside a working clip, never a record pointing at a
      // file that is gone.
      await _repository.updateFileNameById(clipId, destName);

      try {
        await File(sourcePath).delete();
      } catch (e) {
        // The clip may be open in the player. The record already points at the
        // new file, so this only leaks the old file's disk space.
        debugPrint('[ClipLibrary] kept ${clip.fileName}: $e');
      }
      return RewriteResult(
        RewriteStatus.committed,
        sourceBytes: sourceBytes,
        destBytes: destBytes,
      );
    } catch (e) {
      debugPrint('[ClipLibrary] rewrite of ${clip.fileName} failed: $e');
      if (destPath != null) await _deleteQuietly(destPath);
      return RewriteResult(RewriteStatus.failed, error: e);
    }
  }

  AudioClip? _clipById(String id) {
    for (final clip in clips) {
      if (clip.id == id) return clip;
    }
    return null;
  }

  Future<String> _pathFor(AudioClip clip) async =>
      p.join(await _dirs.getClipsPath(), clip.fileName);

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
