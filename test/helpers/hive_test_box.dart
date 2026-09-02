import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';

/// A throwaway [AudioClip] box in its own temp directory.
///
/// The services reconcile records through `clip.key`, and a bare
/// `AudioClip(...)` that was never added to a box has a null key. Two such
/// clips therefore compare equal by key, which lets a "was this record
/// deleted while I worked?" check pass for the wrong reason. Adding clips
/// through [addClip] gives each one a real key, matching what the production
/// repository's `Box.values` hands out.
class HiveTestBox {
  HiveTestBox._(this.dir, this.box);

  final Directory dir;
  final Box<AudioClip> box;

  /// Opens a fresh box. Call once per test, in `setUp`.
  static Future<HiveTestBox> open() async {
    final dir = await Directory.systemTemp.createTemp('eqt_hive_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(AudioClipAdapter().typeId)) {
      Hive.registerAdapter(AudioClipAdapter());
    }
    // The directory name is unique, so it doubles as a unique box name and
    // two suites running in parallel cannot collide on disk.
    final box = await Hive.openBox<AudioClip>(p.basename(dir.path));
    return HiveTestBox._(dir, box);
  }

  /// Adds a clip to the box and returns it, now carrying a real Hive key.
  Future<AudioClip> addClip(
    String fileName, {
    String? ogAudioName,
    double duration = 1,
    bool isEnabled = true,
  }) async {
    final clip = AudioClip(fileName, ogAudioName ?? fileName, duration, isEnabled);
    await box.add(clip);
    return clip;
  }

  /// Closes the box and removes everything it wrote. Call in `tearDown`.
  Future<void> dispose() async {
    await box.close();
    await Hive.deleteBoxFromDisk(box.name, path: dir.path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
