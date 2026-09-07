import 'dart:io';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:path/path.dart' as p;


/// PlaylistService
/// - Seek AudioClips from Repository and return list of enabled absolute paths
class PlaylistService {
  const PlaylistService(this._repository, this._dirs);

  final IAudioClipRepository _repository;
  final AppDirectories _dirs;

  /// Return a list of absolute paths of enabled audio clips whose backing
  /// file still exists. A missing file (deleted externally, or an orphan
  /// record left behind by an earlier bug) would otherwise reach
  /// PlayerIsolate.launch() and fail with no user-visible error, so it's
  /// filtered out here and its dangling record is reconciled away.
  Future<List<String>> listEnabledClipPaths() async {
    final List<AudioClip> all = _repository.getAllClips();
    final base = await _dirs.getClipsPath();

    final paths = <String>[];
    for (final clip in all) {
      if (!clip.isEnabled) continue;
      final path = p.join(base, clip.fileName);
      if (await File(path).exists()) {
        paths.add(path);
      } else {
        await _repository.deleteByKey(clip.key);
      }
    }
    return paths;
  }

  /// Re-resolves [path] against the library as it stands now, or returns null
  /// if that clip is gone.
  ///
  /// A session captures its paths once at launch and plays from that snapshot
  /// for its whole run, but the file behind a clip can be rewritten underneath
  /// it — `ClipFormatMigration` converting a legacy `.m4a`, or
  /// `ClipRecompressService` recompressing a WAV. Both keep the record and the
  /// basename and change only the extension, so a stale snapshot entry would
  /// otherwise fail to load and take the session down with it.
  ///
  /// The basename is the clip's identity: `AudioClipService` names imports
  /// after `microsecondsSinceEpoch`, so it is unique per clip and survives
  /// every format change we make.
  Future<String?> resolveClipPath(String path) async {
    if (await File(path).exists()) return path;

    final base = await _dirs.getClipsPath();
    final stem = p.basenameWithoutExtension(path);
    for (final clip in _repository.getAllClips()) {
      if (p.basenameWithoutExtension(clip.fileName) != stem) continue;
      final current = p.join(base, clip.fileName);
      return await File(current).exists() ? current : null;
    }
    return null;
  }

  /// Stream of enabled clip absolute paths; updates on repository changes
  Stream<List<String>> watchEnabledClipPaths() async* {
    await for (final clips in _repository.watchClips()) {
      final base = await _dirs.getClipsPath();
      final paths = <String>[];
      for (final clip in clips) {
        if (!clip.isEnabled) continue;
        final path = p.join(base, clip.fileName);
        if (await File(path).exists()) paths.add(path);
      }
      yield paths;
    }
  }
}