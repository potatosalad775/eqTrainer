import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';

import '../../helpers/hive_test_box.dart';

/// The Hive-backed repository against a real (temporary) box.
///
/// Everything here is a thin wrapper except [AudioClipRepository.reorder],
/// which exists because two sequential `putAt` calls let a watcher observe a
/// list with the moved clip at two indices at once — duplicate keys in a
/// `ReorderableListView`, which crashed it. The reorder tests pin the
/// single-write behaviour that fixed that.
void main() {
  late HiveTestBox hive;
  late AudioClipRepository repo;

  setUp(() async {
    hive = await HiveTestBox.open();
    repo = AudioClipRepository(box: hive.box);
  });

  tearDown(() => hive.dispose());

  List<String> names() => repo.getAllClips().map((c) => c.fileName).toList();

  Future<void> seed(List<String> fileNames) async {
    for (final name in fileNames) {
      await repo.addClip(AudioClip(name, name, 1, true));
    }
  }

  group('addClip / getAllClips', () {
    test('returns clips in insertion order', () async {
      await seed(['a', 'b', 'c']);
      expect(names(), equals(['a', 'b', 'c']));
    });

    test('added clips carry a key the other methods can address', () async {
      await seed(['a']);
      expect(repo.getAllClips().single.key, isNotNull);
    });
  });

  group('deleteByKey', () {
    test('removes only the addressed record', () async {
      await seed(['a', 'b', 'c']);
      await repo.deleteByKey(repo.getAllClips()[1].key);
      expect(names(), equals(['a', 'c']));
    });

    test('ignores a key that is already gone', () async {
      await seed(['a']);
      final key = repo.getAllClips().single.key;
      await repo.deleteByKey(key);
      await repo.deleteByKey(key);
      expect(names(), isEmpty);
    });
  });

  group('toggleEnabledByKey', () {
    test('flips the flag and persists it', () async {
      await seed(['a']);
      final key = repo.getAllClips().single.key;

      await repo.toggleEnabledByKey(key);
      expect(hive.box.get(key)!.isEnabled, isFalse);

      await repo.toggleEnabledByKey(key);
      expect(hive.box.get(key)!.isEnabled, isTrue);
    });

    test('is a no-op for an unknown key', () async {
      await seed(['a']);
      await repo.toggleEnabledByKey(9999);
      expect(repo.getAllClips().single.isEnabled, isTrue);
    });
  });

  group('updateFileNameByKey', () {
    test('changes the file name and nothing else', () async {
      await repo.addClip(AudioClip('1000.m4a', 'song.m4a', 12.5, false));
      final key = repo.getAllClips().single.key;

      await repo.updateFileNameByKey(key, '1000.opus');

      final clip = hive.box.get(key)!;
      expect(clip.fileName, equals('1000.opus'));
      expect(clip.ogAudioName, equals('song.m4a'));
      expect(clip.duration, equals(12.5));
      expect(clip.isEnabled, isFalse);
    });

    test('is a no-op for an unknown key', () async {
      await seed(['a']);
      await repo.updateFileNameByKey(9999, 'z');
      expect(names(), equals(['a']));
    });
  });

  group('reorder', () {
    test('moves a clip down the list', () async {
      await seed(['a', 'b', 'c', 'd']);
      await repo.reorder(0, 2);
      expect(names(), equals(['b', 'c', 'a', 'd']));
    });

    test('moves a clip up the list', () async {
      await seed(['a', 'b', 'c', 'd']);
      await repo.reorder(3, 1);
      expect(names(), equals(['a', 'd', 'b', 'c']));
    });

    test('keeps the same set of keys, only the values move', () async {
      await seed(['a', 'b', 'c']);
      final before = hive.box.keys.toList();
      await repo.reorder(0, 2);
      expect(hive.box.keys.toList(), equals(before));
    });

    test('is a no-op when source and target are the same', () async {
      await seed(['a', 'b', 'c']);
      await repo.reorder(1, 1);
      expect(names(), equals(['a', 'b', 'c']));
    });

    test('ignores an out-of-range source index', () async {
      await seed(['a', 'b']);
      await repo.reorder(5, 0);
      await repo.reorder(-1, 0);
      expect(names(), equals(['a', 'b']));
    });

    test('clamps an out-of-range target to the list ends', () async {
      await seed(['a', 'b', 'c']);
      await repo.reorder(0, 99);
      expect(names(), equals(['b', 'c', 'a']));
      await repo.reorder(2, -5);
      expect(names(), equals(['a', 'b', 'c']));
    });

    test('never lets a watcher see the moved clip twice', () async {
      await seed(['a', 'b', 'c', 'd']);
      final snapshots = <List<String>>[];
      final sub = repo.watchClips().listen(
            (clips) => snapshots.add(clips.map((c) => c.fileName).toList()),
          );
      // Let the initial snapshot land before the write.
      await Future<void>.delayed(Duration.zero);

      await repo.reorder(0, 3);
      await Future<void>.delayed(Duration.zero);
      // Not awaited: watchClips is an async* generator parked in `await for`
      // on the box's own stream, and a cancel on such a generator only
      // completes once the body reaches its next yield, i.e. the next box
      // event. Closing the box in tearDown ends it instead.
      unawaited(sub.cancel());

      expect(snapshots.first, equals(['a', 'b', 'c', 'd']));
      expect(snapshots.last, equals(['b', 'c', 'd', 'a']));
      for (final snapshot in snapshots) {
        expect(snapshot.toSet(), hasLength(snapshot.length),
            reason: 'a watcher saw a duplicate: $snapshot');
      }
    });
  });

  group('watchClips', () {
    test('emits the current contents first, then every change', () async {
      await seed(['a']);
      final snapshots = <List<String>>[];
      final sub = repo.watchClips().listen(
            (clips) => snapshots.add(clips.map((c) => c.fileName).toList()),
          );
      await Future<void>.delayed(Duration.zero);

      await repo.addClip(AudioClip('b', 'b', 1, true));
      await Future<void>.delayed(Duration.zero);
      // Not awaited: watchClips is an async* generator parked in `await for`
      // on the box's own stream, and a cancel on such a generator only
      // completes once the body reaches its next yield, i.e. the next box
      // event. Closing the box in tearDown ends it instead.
      unawaited(sub.cancel());

      expect(snapshots.first, equals(['a']));
      expect(snapshots.last, equals(['a', 'b']));
    });
  });
}
