import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/service/clip_encoder.dart';
import 'package:eq_trainer/shared/service/clip_format_migration.dart';

import '../../helpers/fake_encoder.dart';
import '../../helpers/hive_test_box.dart';
import '../../helpers/mocks.dart';

/// The one-time conversion of pre-SoLoud `.m4a`/`.aac` clips.
///
/// It deletes files out of the user's library, so the invariant that matters
/// most is the ordering: the record is repointed at the new file *before* the
/// original goes, and nothing is deleted when the conversion did not produce a
/// usable file. The second invariant is that the target tracks the user's
/// import-format setting rather than a constant, so a migrated clip lands
/// where the same file would land if it were imported today.
///
/// Clips live in a real Hive box so each carries a distinct key: the
/// "was this record deleted while I converted it?" check compares keys, and
/// bare clips would all share a null one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipFormatMigration', () {
    late MockIAudioClipRepository mockRepo;
    late MockAppDirectories mockDirs;
    late Directory tmpClips;
    late HiveTestBox hive;

    /// What the mocked WAV converter writes. Bigger than the 64-byte gate the
    /// migration uses as its "did this decode?" check.
    var convertedBytes = List<int>.filled(128, 0);
    var convertShouldThrow = false;
    var convertCalls = <String>[];

    /// Builds a migration for [importFormat] over [encoder].
    ClipFormatMigration migrationFor({
      int importFormat = ImportFormat.smart,
      ClipEncoder? encoder,
    }) =>
        ClipFormatMigration(
          mockRepo,
          mockDirs,
          importFormat: importFormat,
          encoder: encoder ?? FakeClipEncoder(),
        );

    setUp(() async {
      mockRepo = MockIAudioClipRepository();
      mockDirs = MockAppDirectories();
      tmpClips = await Directory.systemTemp.createTemp('cfm_clips_');
      hive = await HiveTestBox.open();

      convertedBytes = List<int>.filled(128, 0);
      convertShouldThrow = false;
      convertCalls = <String>[];

      when(() => mockDirs.getClipsPath()).thenAnswer((_) async => tmpClips.path);
      when(() => mockRepo.updateFileNameByKey(any(), any()))
          .thenAnswer((_) async {});

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('audio_decoder'),
        (MethodCall call) async {
          if (call.method != 'convertToWav') return null;
          final args = call.arguments as Map;
          final output = args['outputPath'] as String;
          convertCalls.add(args['inputPath'] as String);
          if (convertShouldThrow) {
            throw PlatformException(code: 'CONVERSION_FAILED');
          }
          await File(output).writeAsBytes(convertedBytes);
          return output;
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('audio_decoder'), null);
      await tmpClips.delete(recursive: true);
      await hive.dispose();
    });

    /// A record in the box plus its backing file on disk.
    Future<AudioClip> writeClip(String fileName) async {
      await File(p.join(tmpClips.path, fileName)).writeAsBytes([1, 2, 3, 4]);
      return hive.addClip(fileName, ogAudioName: 'original.m4a', duration: 12.5);
    }

    /// A record in the box with no file behind it.
    Future<AudioClip> orphanClip(String fileName) =>
        hive.addClip(fileName, ogAudioName: 'original.m4a', duration: 3);

    test(
        'converts an m4a clip to Opus, repoints the record and removes the '
        'original', () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      expect(await migrationFor().run(), equals(1));

      verify(() => mockRepo.updateFileNameByKey(any(), '1000.opus')).called(1);
      expect(File(p.join(tmpClips.path, '1000.opus')).existsSync(), isTrue);
      expect(File(p.join(tmpClips.path, '1000.m4a')).existsSync(), isFalse);
      // The lossy source must not be inflated into a lossless container.
      expect(File(p.join(tmpClips.path, '1000.wav')).existsSync(), isFalse);
    });

    test('converts .aac the same way as .m4a', () async {
      final clip = await writeClip('1000.aac');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      expect(await migrationFor().run(), equals(1));

      verify(() => mockRepo.updateFileNameByKey(any(), '1000.opus')).called(1);
    });

    test('honours an explicit All-FLAC setting', () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);
      final encoder = FakeClipEncoder();

      expect(
        await migrationFor(
          importFormat: ImportFormat.allFlac,
          encoder: encoder,
        ).run(),
        equals(1),
      );

      verify(() => mockRepo.updateFileNameByKey(any(), '1000.flac')).called(1);
      expect(encoder.encoded.single, endsWith('1000.flac'));
    });

    test('honours an explicit All-WAV setting, through the file-based path',
        () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);
      final encoder = FakeClipEncoder();

      expect(
        await migrationFor(
          importFormat: ImportFormat.allWav,
          encoder: encoder,
        ).run(),
        equals(1),
      );

      verify(() => mockRepo.updateFileNameByKey(any(), '1000.wav')).called(1);
      // WAV must not go through the encoder: audio_decoder already writes it,
      // and its file-based path never buffers the clip in memory.
      expect(encoder.encoded, isEmpty);
      expect(convertCalls, hasLength(1));
    });

    test('maps a retired stored ordinal onto Smart rather than falling through',
        () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      expect(
        await migrationFor(importFormat: ImportFormat.keepOriginal).run(),
        equals(1),
      );

      verify(() => mockRepo.updateFileNameByKey(any(), '1000.opus')).called(1);
    });

    test('leaves formats the engine reads natively completely alone', () async {
      final clips = [
        await writeClip('a.wav'),
        await writeClip('b.mp3'),
        await writeClip('c.flac'),
        await writeClip('d.ogg'),
        await writeClip('e.opus'),
      ];
      when(() => mockRepo.getAllClips()).thenReturn(clips);
      final encoder = FakeClipEncoder();

      expect(await migrationFor(encoder: encoder).run(), equals(0));

      expect(convertCalls, isEmpty);
      expect(encoder.encoded, isEmpty);
      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
      for (final clip in clips) {
        expect(File(p.join(tmpClips.path, clip.fileName)).existsSync(), isTrue);
      }
    });

    test('is idempotent — a second run has nothing left to do', () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);
      await migrationFor().run();

      // The record now points at the Opus file, which is what a relaunch reads.
      when(() => mockRepo.getAllClips())
          .thenReturn([await orphanClip('1000.opus')]);
      final encoder = FakeClipEncoder();

      expect(await migrationFor(encoder: encoder).run(), equals(0));
      expect(encoder.encoded, isEmpty);
    });

    test('keeps the original when the conversion fails', () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      expect(
        await migrationFor(encoder: FakeClipEncoder(throwOnEncode: true)).run(),
        equals(0),
      );

      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
      expect(File(p.join(tmpClips.path, '1000.m4a')).existsSync(), isTrue);
    });

    test('keeps the original when the conversion produces an unusable file',
        () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      // Shorter than any container header: the encoder claimed success but
      // wrote nothing playable.
      expect(
        await migrationFor(encoder: FakeClipEncoder(outputSize: 10)).run(),
        equals(0),
      );

      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
      expect(File(p.join(tmpClips.path, '1000.m4a')).existsSync(), isTrue);
      // The stub output must not be left behind as a "converted" clip.
      expect(File(p.join(tmpClips.path, '1000.opus')).existsSync(), isFalse);
    });

    test('overwrites a partial file left by an interrupted run', () async {
      final clip = await writeClip('1000.m4a');
      await File(p.join(tmpClips.path, '1000.opus')).writeAsBytes([9]);
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      expect(
        await migrationFor(encoder: FakeClipEncoder(outputSize: 128)).run(),
        equals(1),
      );

      expect(File(p.join(tmpClips.path, '1000.opus')).lengthSync(), equals(128));
    });

    test('skips a record whose file is already gone, without touching it',
        () async {
      when(() => mockRepo.getAllClips())
          .thenReturn([await orphanClip('missing.m4a')]);
      final encoder = FakeClipEncoder();

      expect(await migrationFor(encoder: encoder).run(), equals(0));

      expect(encoder.encoded, isEmpty);
      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
    });

    test('one failing clip does not stop the others', () async {
      final good = await writeClip('2000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([
        await orphanClip('missing.m4a'),
        good,
      ]);

      expect(await migrationFor().run(), equals(1));
      verify(() => mockRepo.updateFileNameByKey(any(), '2000.opus')).called(1);
    });

    test('refuses a concurrent run rather than racing itself over the same '
        'files', () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);
      final migration = migrationFor();

      final first = migration.run();
      expect(await migration.run(), equals(0));
      expect(await first, equals(1));

      verify(() => mockRepo.updateFileNameByKey(any(), '1000.opus')).called(1);
    });

    test('drops a conversion whose record was deleted while it ran, leaving '
        'no orphan file', () async {
      final clip = await writeClip('1000.m4a');
      // The scan sees the clip; by the time the conversion is committed the
      // user has deleted it from the playlist, so the record is gone. Another
      // record survives, so the check has to compare keys, not just count.
      final other = await writeClip('2000.flac');
      var call = 0;
      when(() => mockRepo.getAllClips())
          .thenAnswer((_) => call++ == 0 ? [clip, other] : [other]);

      expect(await migrationFor().run(), equals(0));

      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
      // updateFileNameByKey would have no-opped on the missing key, so
      // without the check this file would sit on disk unreferenced forever.
      expect(File(p.join(tmpClips.path, '1000.opus')).existsSync(), isFalse);
    });

    group('pausing for playback', () {
      test('holds the run at a clip boundary until resumed', () async {
        final clip = await writeClip('1000.m4a');
        when(() => mockRepo.getAllClips()).thenReturn([clip]);
        final migration = migrationFor();

        migration.pause();
        final run = migration.run();
        // Let the loop reach its first checkpoint and park there.
        await pumpEventQueue();

        expect(migration.isPaused, isTrue);
        expect(migration.isRunning, isTrue);
        verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));

        migration.resume();
        expect(await run, equals(1));
        verify(() => mockRepo.updateFileNameByKey(any(), '1000.opus')).called(1);
      });

      test('stays held until every nested pause is released', () async {
        final clip = await writeClip('1000.m4a');
        when(() => mockRepo.getAllClips()).thenReturn([clip]);
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
        verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));

        migration.resume();
        expect(await run, equals(1));
      });

      test('ignores an unbalanced resume rather than un-pausing a live '
          'session', () async {
        final clip = await writeClip('1000.m4a');
        when(() => mockRepo.getAllClips()).thenReturn([clip]);
        final migration = migrationFor();

        // A double dispose. The extra resume must not bank credit against
        // the pause that comes after it.
        migration.resume();
        migration.pause();
        final run = migration.run();
        await pumpEventQueue();

        expect(migration.isPaused, isTrue);
        verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));

        migration.resume();
        expect(await run, equals(1));
      });

      test('reports progress over the run and clears it when idle', () async {
        when(() => mockRepo.getAllClips()).thenReturn([
          await writeClip('1000.m4a'),
          await writeClip('2000.m4a'),
        ]);
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
