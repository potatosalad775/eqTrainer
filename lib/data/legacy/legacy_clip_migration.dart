import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/data/legacy/legacy_audio_clip.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';

const String _audioClipBoxName = 'audioClipBox';

@visibleForTesting
const String legacyClipsMigratedKey = 'legacyClipsMigrated';

/// Moves the clip library out of the Hive box it used to live in.
///
/// Stricter than `migrateLegacySettings`, because losing this loses data the
/// user cannot get back: their files are named by timestamp, so without a record
/// a clip's original name and place in the list are gone.
///
/// A box that cannot be read does not count as empty. The migration is left to
/// retry on the next launch and the repository is flagged, so the user is told
/// rather than shown a library that is quietly empty. Anything imported meanwhile
/// is merged in when a retry succeeds.
///
/// A damaged box gets more care, because Hive's default on opening one is to cut
/// the file at the first bad frame, which reads as a success with fewer clips. So
/// it is opened strictly first. If that fails, the file is copied aside untouched
/// to [boxDirectory] before Hive repairs it, what survives is migrated, and the
/// user is told once. A half-written last frame from a crash therefore costs
/// nobody their good clips, and whatever the repair dropped still exists.
///
/// The box is never deleted here, even after success. It is a backup for a bug
/// found after release, and it lets a downgraded app still find its library.
/// Removing it belongs with removing Hive itself.
///
/// Never throws: a failed migration must not stop the app from starting.
Future<void> migrateLegacyClips(
  AudioClipRepository repository,
  SharedPreferences prefs, {
  required String boxDirectory,
}) async {
  if (prefs.getBool(legacyClipsMigratedKey) ?? false) return;

  try {
    var repaired = false;
    // Checked first so a fresh install never creates a box just to read it.
    if (await Hive.boxExists(_audioClipBoxName)) {
      if (!Hive.isAdapterRegistered(LegacyAudioClipAdapter().typeId)) {
        Hive.registerAdapter(LegacyAudioClipAdapter());
      }
      List<LegacyAudioClip> legacy;
      try {
        legacy = await _readBox(crashRecovery: false);
      } catch (e) {
        debugPrint('[Clips] Legacy box failed a strict open ($e).');
        await _copyDamagedBox(boxDirectory);
        legacy = await _readBox(crashRecovery: true);
        repaired = true;
      }
      await repository.mergeLegacy(_convert(legacy));
    }
    await prefs.setBool(legacyClipsMigratedKey, true);
    if (repaired) repository.markUnreadable();
  } catch (e) {
    debugPrint('[Clips] Legacy migration failed ($e); retrying next launch.');
    repository.markUnreadable();
  }
}

Future<List<LegacyAudioClip>> _readBox({required bool crashRecovery}) async {
  final box = await Hive.openBox<LegacyAudioClip>(
    _audioClipBoxName,
    crashRecovery: crashRecovery,
  );
  final clips = box.values.toList(growable: false);
  await box.close();
  return clips;
}

/// Throws if the copy fails, which stops the repair: without a copy, cutting the
/// file would destroy whatever it could not read.
Future<void> _copyDamagedBox(String boxDirectory) async {
  final box = p.join(boxDirectory, '${_audioClipBoxName.toLowerCase()}.hive');
  final copy = File('$box.damaged');
  // A retry finds the file as the first attempt left it, so keep the first copy.
  if (!await copy.exists()) await File(box).copy(copy.path);
}

/// A box lists its clips in key order, which is the order the user arranged.
List<AudioClip> _convert(List<LegacyAudioClip> legacy) {
  final seen = <String>{};
  return [
    for (final clip in legacy)
      AudioClip(
        clip.fileName,
        clip.ogAudioName,
        clip.duration.isFinite ? clip.duration : 0.0,
        clip.isEnabled,
        id: _uniqueId(p.basenameWithoutExtension(clip.fileName), seen),
      ),
  ];
}

/// The basename identifies a clip, but the first versions named files by the
/// date and time to the second, so two clips can share one. A suffix keeps them
/// apart, and comes out the same on a retry, so nothing gets duplicated.
String _uniqueId(String stem, Set<String> seen) {
  var id = stem;
  for (var n = 2; !seen.add(id); n++) {
    id = '$stem-$n';
  }
  return id;
}
