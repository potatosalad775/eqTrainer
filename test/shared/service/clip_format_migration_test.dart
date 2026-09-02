import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/service/clip_encoder.dart';
import 'package:eq_trainer/shared/service/clip_format_migration.dart';

class MockIAudioClipRepository extends Mock implements IAudioClipRepository {}

class MockAppDirectories extends Mock implements AppDirectories {}

/// Stands in for the real encoder so these tests stay headless — the native
/// Opus and FLAC encoders are covered by the integration suite and the fork's
/// own tests.
class _FakeEncoder implements ClipEncoder {
  _FakeEncoder({this.outputSize = 128, this.throwOnEncode = false});

  final int outputSize;
  final bool throwOnEncode;
  final List<String> encoded = [];

  @override
  Future<void> convertFile({
    required String sourcePath,
    required String destPath,
  }) async {
    if (throwOnEncode) throw Exception('encoder failed');
    encoded.add(destPath);
    await File(destPath).writeAsBytes(List<int>.filled(outputSize, 0));
  }

  @override
  Future<void> encodeWavBytes({
    required Uint8List wavBytes,
    required String destPath,
  }) async =>
      throw UnimplementedError();
}

/// The one-time conversion of pre-SoLoud `.m4a` clips.
///
/// It deletes files out of the user's library, so the invariant that matters
/// most is the ordering: the record is repointed at the new file *before* the
/// original goes, and nothing is deleted when the conversion did not produce a
/// usable file. The second invariant is that the target tracks the user's
/// import-format setting rather than a constant, so a migrated clip lands
/// where the same file would land if it were imported today.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipFormatMigration', () {
    late MockIAudioClipRepository mockRepo;
    late MockAppDirectories mockDirs;
    late Directory tmpClips;

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
          encoder: encoder ?? _FakeEncoder(),
        );

    setUp(() async {
      mockRepo = MockIAudioClipRepository();
      mockDirs = MockAppDirectories();
      tmpClips = await Directory.systemTemp.createTemp('cfm_clips_');

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
    });

    Future<AudioClip> writeClip(String fileName) async {
      await File(p.join(tmpClips.path, fileName)).writeAsBytes([1, 2, 3, 4]);
      return AudioClip(fileName, 'original.m4a', 12.5, true);
    }

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
      final encoder = _FakeEncoder();

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
      final encoder = _FakeEncoder();

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
      final encoder = _FakeEncoder();

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
          .thenReturn([AudioClip('1000.opus', 'original.m4a', 12.5, true)]);
      final encoder = _FakeEncoder();

      expect(await migrationFor(encoder: encoder).run(), equals(0));
      expect(encoder.encoded, isEmpty);
    });

    test('keeps the original when the conversion fails', () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      expect(
        await migrationFor(encoder: _FakeEncoder(throwOnEncode: true)).run(),
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
        await migrationFor(encoder: _FakeEncoder(outputSize: 10)).run(),
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
        await migrationFor(encoder: _FakeEncoder(outputSize: 128)).run(),
        equals(1),
      );

      expect(File(p.join(tmpClips.path, '1000.opus')).lengthSync(), equals(128));
    });

    test('skips a record whose file is already gone, without touching it',
        () async {
      when(() => mockRepo.getAllClips())
          .thenReturn([AudioClip('missing.m4a', 'original.m4a', 3, true)]);
      final encoder = _FakeEncoder();

      expect(await migrationFor(encoder: encoder).run(), equals(0));

      expect(encoder.encoded, isEmpty);
      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
    });

    test('one failing clip does not stop the others', () async {
      final good = await writeClip('2000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([
        AudioClip('missing.m4a', 'original.m4a', 3, true),
        good,
      ]);

      expect(await migrationFor().run(), equals(1));
      verify(() => mockRepo.updateFileNameByKey(any(), '2000.opus')).called(1);
    });
  });
}
