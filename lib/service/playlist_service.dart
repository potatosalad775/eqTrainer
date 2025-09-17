import 'dart:io';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/service/audio_clip_service.dart';

/// PlaylistService
/// - Seek AudioClips from Repository and return list of enabled absolute paths
class PlaylistService {
  const PlaylistService(this._repository);

  final IAudioClipRepository _repository;

  /// Return a list of absolute paths of enabled audio clips
  Future<List<String>> listEnabledClipPaths() async {
    final List<AudioClip> all = _repository.getAllClips();
    final String sep = Platform.pathSeparator;
    final base = audioClipDir.path;

    return all
        .where((c) => c.isEnabled)
        .map((c) => "$base$sep${c.fileName}")
        .toList(growable: false);
  }
}