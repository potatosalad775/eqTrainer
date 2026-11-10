import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';

import '../../helpers/fake_encoder.dart';
import '../../helpers/mocks.dart';

/// The one-time conversion of pre-SoLoud `.m4a`/`.aac` clips.
///
/// This is about which clips it picks, which format they land in, and that it
/// yields to playback and never throws. The rewrite itself, with its commit
/// before delete ordering, is `ClipLibrary.rewrite` and is tested there. The
/// other thing that matters here is that the target tracks the user's
/// import-format setting rather than a constant, so a migrated clip lands
/// where the same file would land if it were imported today.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipFormatMigration', () {
    late Directory root;
    late Directory tmpClips;
    late AudioClipRepository repo;
    late ClipLibrary library;

    /// Builds a migration for [importFormat] over [encoder].
    ClipFormatMigration migrationFor({
      int importFormat = ImportFormat.smart,
      ClipEncoder? encoder,
    }) =>
        ClipFormatMigration(
          library,
          importFormat: importFormat,
          encoder: encoder ?? FakeClipEncoder(),
        );

    setUp(() async {
      root = await Directory.systemTemp.createTemp('cfm_');
      tmpClips = await Directory(p.join(root.path, 'clips')).create();
      repo = await AudioClipRepository.open(
        File(p.join(root.path, 'audio_clips.json')),
      );
      final dirs = MockAppDirectories();
      when(() => dirs.getClipsPath()).thenAnswer((_) async => tmpClips.path);
      library = ClipLibrary(repo, dirs);
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    /// A record with no file behind it.
    Future<void> addRecord(String fileName) =>
        repo.addClip(AudioClip(fileName, 'original.m4a', 12.5, true));

    /// A record plus its backing file on disk.
    Future<void> writeClip(String fileName) async {
      await File(p.join(tmpClips.path, fileName)).writeAsBytes([1, 2, 3, 4]);
      await addRecord(fileName);
    }

    List<String> fileNames() => [for (final c in repo.getAllClips()) c.fileName];

    bool onDisk(String fileName) =>
        File(p.join(tmpClips.path, fileName)).existsSync();

    test(
        'converts an m4a clip to Opus, repoints the record and removes the '
        'original', () async {
      await writeClip('1000.m4a');

      expect(await migrationFor().run(), equals(1));

      expect(fileNames(), ['1000.opus']);
      expect(onDisk('1000.opus'), isTrue);
      expect(onDisk('1000.m4a'), isFalse);
      // The lossy source must not be inflated into a lossless container.
      expect(onDisk('1000.wav'), isFalse);
    });

    test('converts .aac the same way as .m4a', () async {
      await writeClip('1000.aac');

      expect(await migrationFor().run(), equals(1));

      expect(fileNames(), ['1000.opus']);
    });

    test('honours an explicit All-FLAC setting', () async {
      await writeClip('1000.m4a');
      final encoder = FakeClipEncoder();

      expect(
        await migrationFor(
          importFormat: ImportFormat.allFlac,
          encoder: encoder,
        ).run(),
        equals(1),
      );

      expect(fileNames(), ['1000.flac']);
      expect(encoder.encoded.single, endsWith('1000.flac'));
    });

    test('honours an explicit All-WAV setting', () async {
      await writeClip('1000.m4a');
      final encoder = FakeClipEncoder();

      expect(
        await migrationFor(
          importFormat: ImportFormat.allWav,
          encoder: encoder,
        ).run(),
        equals(1),
      );

      expect(fileNames(), ['1000.wav']);
      expect(encoder.encoded.single, endsWith('1000.wav'));
    });

    test('maps a retired stored ordinal onto Smart rather than falling through',
        () async {
      await writeClip('1000.m4a');

      expect(
        await migrationFor(importFormat: ImportFormat.keepOriginal).run(),
        equals(1),
      );

      expect(fileNames(), ['1000.opus']);
    });

    test('leaves formats the engine reads natively completely alone', () async {
      final names = ['a.wav', 'b.mp3', 'c.flac', 'd.ogg', 'e.opus'];
      for (final name in names) {
        await writeClip(name);
      }
      final encoder = FakeClipEncoder();

      expect(await migrationFor(encoder: encoder).run(), equals(0));

      expect(encoder.encoded, isEmpty);
      expect(fileNames(), names);
      for (final name in names) {
        expect(onDisk(name), isTrue);
      }
    });

    test('is idempotent — a second run has nothing left to do', () async {
      await writeClip('1000.m4a');
      await migrationFor().run();
      final encoder = FakeClipEncoder();

      expect(await migrationFor(encoder: encoder).run(), equals(0));
      expect(encoder.encoded, isEmpty);
    });

    test('keeps the original when the conversion fails', () async {
      await writeClip('1000.m4a');

      expect(
        await migrationFor(encoder: FakeClipEncoder(throwOnEncode: true)).run(),
        equals(0),
      );

      expect(fileNames(), ['1000.m4a']);
      expect(onDisk('1000.m4a'), isTrue);
    });

    test('skips a record whose file is already gone, without touching it',
        () async {
      await addRecord('missing.m4a');
      final encoder = FakeClipEncoder();

      expect(await migrationFor(encoder: encoder).run(), equals(0));

      expect(encoder.encoded, isEmpty);
      expect(fileNames(), ['missing.m4a']);
    });

    test('one failing clip does not stop the others', () async {
      await addRecord('missing.m4a');
      await writeClip('2000.m4a');

      expect(await migrationFor().run(), equals(1));
      expect(fileNames(), ['missing.m4a', '2000.opus']);
    });

    test('refuses a concurrent run rather than racing itself over the same '
        'files', () async {
      await writeClip('1000.m4a');
      final migration = migrationFor();

      final first = migration.run();
      expect(await migration.run(), equals(0));
      expect(await first, equals(1));

      expect(fileNames(), ['1000.opus']);
    });

    group('pausing for playback', () {
      test('holds the run at a clip boundary until resumed', () async {
        await writeClip('1000.m4a');
        final migration = migrationFor();

        migration.pause();
        final run = migration.run();
        // Let the loop reach its first checkpoint and park there.
        await pumpEventQueue();

        expect(migration.isPaused, isTrue);
        expect(migration.isRunning, isTrue);
        expect(fileNames(), ['1000.m4a']);

        migration.resume();
        expect(await run, equals(1));
        expect(fileNames(), ['1000.opus']);
      });

      test('stays held until every nested pause is released', () async {
        await writeClip('1000.m4a');
        final migration = migrationFor();

        // A playlist preview opened over a session page: closing only the
        // preview must not resume the run while the session still plays.
        migration.pause();
        migration.pause();
        final run = migration.run();
        await pumpEventQueue();

        migration.resume();
        await pumpEventQueue();
        expect(migration.isPaused, isTrue);
        expect(fileNames(), ['1000.m4a']);

        migration.resume();
        expect(await run, equals(1));
      });

      test('ignores an unbalanced resume rather than un-pausing a live '
          'session', () async {
        await writeClip('1000.m4a');
        final migration = migrationFor();

        // A double dispose. The extra resume must not bank credit against
        // the pause that comes after it.
        migration.resume();
        migration.pause();
        final run = migration.run();
        await pumpEventQueue();

        expect(migration.isPaused, isTrue);
        expect(fileNames(), ['1000.m4a']);

        migration.resume();
        expect(await run, equals(1));
      });

      test('reports progress over the run and clears it when idle', () async {
        await writeClip('1000.m4a');
        await writeClip('2000.m4a');
        final migration = migrationFor();

        expect(migration.isRunning, isFalse);
        expect(migration.total, equals(0));

        migration.pause();
        final run = migration.run();
        await pumpEventQueue();

        expect(migration.total, equals(2));
        expect(migration.done, equals(0));

        migration.resume();
        expect(await run, equals(2));

        // Idle again: nothing outstanding for a progress indicator to show.
        expect(migration.isRunning, isFalse);
        expect(migration.done, equals(0));
        expect(migration.total, equals(0));
      });
    });
  });
}
