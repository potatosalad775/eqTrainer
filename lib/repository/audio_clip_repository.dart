import 'package:hive_flutter/hive_flutter.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/service/audio_clip_service.dart';

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
}
