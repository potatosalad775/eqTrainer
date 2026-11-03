import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';

/// The JSON-backed repository against a real temporary file.
///
/// `ClipFormatMigration` deletes a clip's source file straight after repointing
/// its record, so what matters most is that a finished write is on disk, and a
/// failed one leaves the library as it was.
void main() {
  late Directory dir;
  late File file;
  late AudioClipRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('eqt_clip_repo_');
    file = File(p.join(dir.path, 'audio_clips.json'));
    repo = await AudioClipRepository.open(file);
  });

  tearDown(() => dir.delete(recursive: true));

  List<String> names() => repo.getAllClips().map((c) => c.fileName).toList();

  Future<void> seed(List<String> fileNames) async {
    for (final name in fileNames) {
      await repo.addClip(AudioClip(name, name, 1, true));
    }
  }

  /// What a relaunch would load, as opposed to what is in memory.
  Future<List<AudioClip>> onDisk() async =>
      (await AudioClipRepository.open(file)).getAllClips();

  /// Makes every later save fail: a directory cannot be renamed over.
  Future<void> breakSaves() async {
    await file.delete();
    await Directory(file.path).create();
  }

  group('open', () {
    test('a missing file is an empty library, not a problem', () {
      expect(repo.getAllClips(), isEmpty);
      expect(repo.hasUnreadableData, isFalse);
    });

    test('loads every field back as it was saved', () async {
      final clip = AudioClip('1000.m4a', 'song.m4a', 12.5, false, id: 'custom');
      await repo.addClip(clip);

      expect((await onDisk()).single, equals(clip));
    });

    test('reads a whole-number duration back as a double', () async {
      await file.writeAsString('{"clips":[{"id":"a","fileName":"a.wav",'
          '"ogAudioName":"a","duration":12,"isEnabled":true}]}');

      expect((await onDisk()).single.duration, equals(12.0));
    });

    for (final (name, content) in [
      ('invalid JSON', '{"clips":[{"id"'),
      ('an empty file', ''),
      ('the wrong shape', '[1, 2, 3]'),
      ('a record with a missing field', '{"clips":[{"id":"a"}]}'),
    ]) {
      test('$name opens empty, flagged, with the file copied aside', () async {
        await file.writeAsString(content);

        final opened = await AudioClipRepository.open(file);

        expect(opened.getAllClips(), isEmpty);
        expect(opened.hasUnreadableData, isTrue);
        final copies = dir.listSync().whereType<File>().where(
            (f) => p.basename(f.path).startsWith('audio_clips.json.corrupt-'));
        expect(copies.single.readAsStringSync(), equals(content));
      });
    }

    test('ignores a partial temp file left by a crash mid-save', () async {
      await seed(['a']);
      await File('${file.path}.tmp').writeAsString('{"clips":[{"id"');

      final opened = await AudioClipRepository.open(file);

      expect(opened.getAllClips().single.fileName, equals('a'));
      expect(opened.hasUnreadableData, isFalse);
    });

    test('saving over a partial temp file still works', () async {
      await File('${file.path}.tmp').writeAsString('{"clips":[{"id"');
      await seed(['a']);
      expect((await onDisk()).single.fileName, equals('a'));
    });
  });

  group('addClip / getAllClips', () {
    test('returns clips in insertion order', () async {
      await seed(['a', 'b', 'c']);
      expect(names(), equals(['a', 'b', 'c']));
    });

    test('a saved clip is on disk once the write completes', () async {
      await seed(['a']);
      expect((await onDisk()).single.fileName, equals('a'));
    });

    test('hands out a list that cannot be changed behind its back', () async {
      await seed(['a']);
      expect(() => repo.getAllClips().clear(), throwsUnsupportedError);
    });
  });

  group('deleteById', () {
    test('removes only the addressed record', () async {
      await seed(['a', 'b', 'c']);
      await repo.deleteById(repo.getAllClips()[1].id);
      expect(names(), equals(['a', 'c']));
      expect((await onDisk()).map((c) => c.fileName), equals(['a', 'c']));
    });

    test('ignores an id that is already gone', () async {
      await seed(['a']);
      final id = repo.getAllClips().single.id;
      await repo.deleteById(id);
      await repo.deleteById(id);
      expect(names(), isEmpty);
    });
  });

  group('toggleEnabledById', () {
    test('flips the flag and persists it', () async {
      await seed(['a']);
      final id = repo.getAllClips().single.id;

      await repo.toggleEnabledById(id);
      expect((await onDisk()).single.isEnabled, isFalse);

      await repo.toggleEnabledById(id);
      expect((await onDisk()).single.isEnabled, isTrue);
    });

    test('is a no-op for an unknown id', () async {
      await seed(['a']);
      await repo.toggleEnabledById('nope');
      expect(repo.getAllClips().single.isEnabled, isTrue);
    });
  });

  group('updateFileNameById', () {
    test('changes the file name and nothing else, keeping the id', () async {
      await repo.addClip(AudioClip('1000.m4a', 'song.m4a', 12.5, false));

      await repo.updateFileNameById('1000', '1000.opus');

      final clip = (await onDisk()).single;
      expect(clip.id, equals('1000'));
      expect(clip.fileName, equals('1000.opus'));
      expect(clip.ogAudioName, equals('song.m4a'));
      expect(clip.duration, equals(12.5));
      expect(clip.isEnabled, isFalse);
    });

    test('is a no-op for an unknown id', () async {
      await seed(['a']);
      await repo.updateFileNameById('nope', 'z');
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

    test('the new order survives a relaunch', () async {
      await seed(['a', 'b', 'c']);
      await repo.reorder(0, 2);
      expect((await onDisk()).map((c) => c.fileName), equals(['b', 'c', 'a']));
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
      await Future<void>.delayed(Duration.zero);

      await repo.reorder(0, 3);
      await sub.cancel();

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
      await sub.cancel();

      expect(snapshots.first, equals(['a']));
      expect(snapshots.last, equals(['a', 'b']));
    });

    test('shows a change before its save finishes', () async {
      await seed(['a', 'b']);
      final write = repo.reorder(0, 1);
      await Future<void>.delayed(Duration.zero);

      // A dragged clip must not snap back while the file is being written.
      expect(names(), equals(['b', 'a']));
      await write;
    });
  });

  group('when a save fails', () {
    test('the write throws and the change is rolled back', () async {
      await seed(['a']);
      await breakSaves();

      await expectLater(repo.addClip(AudioClip('b', 'b', 1, true)), throwsA(anything));

      expect(names(), equals(['a']));
    });

    test('watchers are told about the rollback', () async {
      await seed(['a']);
      await breakSaves();
      final snapshots = <List<String>>[];
      final sub = repo.watchClips().listen(
            (clips) => snapshots.add(clips.map((c) => c.fileName).toList()),
          );

      await expectLater(repo.addClip(AudioClip('b', 'b', 1, true)), throwsA(anything));
      // A subscription gets one queued event per microtask.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(snapshots.last, equals(['a']));
    });

    test('later writes still run', () async {
      await seed(['a']);
      await breakSaves();
      await expectLater(repo.addClip(AudioClip('b', 'b', 1, true)), throwsA(anything));

      await Directory(file.path).delete();
      await repo.addClip(AudioClip('c', 'c', 1, true));

      expect((await onDisk()).map((c) => c.fileName), equals(['a', 'c']));
    });
  });

  test('overlapping writes all land, in the order they were made', () async {
    await Future.wait([
      for (var i = 0; i < 20; i++) repo.addClip(AudioClip('$i', '$i', 1, true)),
    ]);

    final expected = [for (var i = 0; i < 20; i++) '$i'];
    expect(names(), equals(expected));
    expect((await onDisk()).map((c) => c.fileName), equals(expected));
  });

  test('a non-finite duration does not stop the library saving', () async {
    await repo.addClip(AudioClip('a', 'a', double.nan, true));
    expect((await onDisk()).single.duration, equals(0.0));
  });

  group('mergeLegacy', () {
    test('adds old clips in their order and saves them', () async {
      final legacy = [AudioClip('b.wav', 'b', 1, true), AudioClip('a.wav', 'a', 2, false)];

      await repo.mergeLegacy(legacy);

      expect(await onDisk(), equals(legacy));
    });

    test('repeating it duplicates nothing', () async {
      final legacy = [AudioClip('a.wav', 'a', 1, true)];
      await repo.mergeLegacy(legacy);
      await repo.mergeLegacy(legacy);
      expect(names(), equals(['a.wav']));
    });

    test('keeps a clip imported since, after the old ones', () async {
      await repo.addClip(AudioClip('new.wav', 'new', 1, true));

      await repo.mergeLegacy([AudioClip('old.wav', 'old', 1, true)]);

      expect(names(), equals(['old.wav', 'new.wav']));
    });

    test('a clip converted since wins over its stale old record', () async {
      await repo.addClip(AudioClip('1000.opus', 'song', 1, true));

      await repo.mergeLegacy([AudioClip('1000.m4a', 'song', 1, true)]);

      expect(names(), equals(['1000.opus']));
    });
  });
}
