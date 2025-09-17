import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/main.dart';

// Define repository abstraction in repository layer to avoid cyclic deps
abstract class IAudioClipRepository {
  Future<void> addClip(AudioClip clip);
  // Return all clips (synchronous). PlaylistService will filter/map.
  List<AudioClip> getAllClips();
  // Subscribe to changes as a stream, including initial snapshot.
  Stream<List<AudioClip>> watchClips();
  // Delete/update/toggle by index (maintaining current Hive Box index order)
  Future<void> deleteAt(int index);
  Future<void> updateAt(int index, AudioClip clip);
  Future<void> toggleEnabledAt(int index);
}

class AudioClipRepository implements IAudioClipRepository {
  AudioClipRepository({Box<AudioClip>? box})
      : _box = box ?? Hive.box<AudioClip>(audioClipBoxName);

  final Box<AudioClip> _box;

  @override
  Future<void> addClip(AudioClip clip) async {
    await _box.add(clip);
  }

  @override
  List<AudioClip> getAllClips() {
    return _box.values.toList(growable: false);
  }

  @override
  Stream<List<AudioClip>> watchClips() async* {
    // 최초 스냅샷
    yield _box.values.toList(growable: false);
    // 변경 이벤트 발생 시 전체 목록을 다시 방출
    await for (final _ in _box.watch()) {
      yield _box.values.toList(growable: false);
    }
  }

  @override
  Future<void> deleteAt(int index) async {
    await _box.deleteAt(index);
  }

  @override
  Future<void> updateAt(int index, AudioClip clip) async {
    await _box.putAt(index, clip);
  }

  @override
  Future<void> toggleEnabledAt(int index) async {
    final clip = _box.getAt(index);
    if (clip == null) return;
    clip.isEnabled = !clip.isEnabled;
    await _box.putAt(index, clip);
  }
}
