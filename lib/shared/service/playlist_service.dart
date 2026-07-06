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