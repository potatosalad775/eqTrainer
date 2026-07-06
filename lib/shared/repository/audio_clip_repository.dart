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
  // Delete/toggle by Hive key rather than list index: the index a widget was
  // built with can go stale across an `await` (e.g. a confirmation dialog)
  // if the box changes in the meantime, silently acting on the wrong record.
  Future<void> deleteByKey(dynamic key);
  Future<void> toggleEnabledByKey(dynamic key);
  // Move the clip at [oldIndex] to [newIndex] in a single batched write.
  Future<void> reorder(int oldIndex, int newIndex);
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
  Future<void> deleteByKey(dynamic key) async {
    await _box.delete(key);
  }

  @override
  Future<void> toggleEnabledByKey(dynamic key) async {
    final clip = _box.get(key);
    if (clip == null) return;
    clip.isEnabled = !clip.isEnabled;
    await _box.put(key, clip);
  }

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {
    final values = _box.values.toList();
    if (oldIndex < 0 || oldIndex >= values.length) return;
    final target = newIndex.clamp(0, values.length - 1);
    if (oldIndex == target) return;

    // Compute the fully reordered list, then rewrite the affected contiguous
    // range in a single putAll. Doing it as one batched write (rather than two
    // sequential putAt calls with an await between them) means watchers only
    // ever observe the final ordering — never an intermediate state where the
    // moved clip occupies two indices, which produced duplicate ReorderableList
    // keys and crashed the list.
    final keys = _box.keys.toList();
    final item = values.removeAt(oldIndex);
    values.insert(target, item);

    final lo = oldIndex < target ? oldIndex : target;
    final hi = oldIndex < target ? target : oldIndex;
    final updates = <dynamic, AudioClip>{};
    for (var i = lo; i <= hi; i++) {
      updates[keys[i]] = values[i];
    }
    await _box.putAll(updates);
  }
}
