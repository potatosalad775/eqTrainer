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

  /// Return a list of absolute paths of enabled audio clips
  Future<List<String>> listEnabledClipPaths() async {
    final List<AudioClip> all = _repository.getAllClips();
    final base = await _dirs.getClipsPath();

    return all
        .where((c) => c.isEnabled)
        .map((c) => p.join(base, c.fileName))
        .toList(growable: false);
  }

  /// Stream of enabled clip absolute paths; updates on repository changes
  Stream<List<String>> watchEnabledClipPaths() async* {
    await for (final clips in _repository.watchClips()) {
      final base = await _dirs.getClipsPath();
      yield clips
          .where((c) => c.isEnabled)
          .map((c) => p.join(base, c.fileName))
          .toList(growable: false);
    }
  }
}