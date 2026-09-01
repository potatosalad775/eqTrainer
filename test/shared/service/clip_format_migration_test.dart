import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/clip_format_migration.dart';

class MockIAudioClipRepository extends Mock implements IAudioClipRepository {}

class MockAppDirectories extends Mock implements AppDirectories {}

/// The one-time conversion of pre-SoLoud `.m4a` clips.
///
/// It deletes files out of the user's library, so the invariant that matters
/// most is the ordering: the record is repointed at the WAV *before* the
/// original goes, and nothing is deleted when the conversion did not produce a
/// usable file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipFormatMigration', () {
    late MockIAudioClipRepository mockRepo;
    late MockAppDirectories mockDirs;
    late ClipFormatMigration migration;
    late Directory tmpClips;

    /// What the mocked converter writes. Bigger than the 44-byte WAV header
    /// the migration uses as its "did this decode?" gate.
    var convertedBytes = List<int>.filled(128, 0);
    var convertShouldThrow = false;
    var convertCalls = <String>[];

    setUp(() async {
      mockRepo = MockIAudioClipRepository();
      mockDirs = MockAppDirectories();
      migration = ClipFormatMigration(mockRepo, mockDirs);
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

    test('converts an m4a clip, repoints the record and removes the original',
        () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      expect(await migration.run(), equals(1));

      verify(() => mockRepo.updateFileNameByKey(any(), '1000.wav')).called(1);
      expect(File(p.join(tmpClips.path, '1000.wav')).existsSync(), isTrue);
      expect(File(p.join(tmpClips.path, '1000.m4a')).existsSync(), isFalse);
    });

    test('leaves formats the engine reads natively completely alone', () async {
      final clips = [
        await writeClip('a.wav'),
        await writeClip('b.mp3'),
        await writeClip('c.flac'),
        await writeClip('d.ogg'),
      ];
      when(() => mockRepo.getAllClips()).thenReturn(clips);

      expect(await migration.run(), equals(0));

      expect(convertCalls, isEmpty);
      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
      for (final clip in clips) {
        expect(File(p.join(tmpClips.path, clip.fileName)).existsSync(), isTrue);
      }
    });

    test('is idempotent — a second run has nothing left to do', () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);
      await migration.run();

      // The record now points at the WAV, which is what a relaunch would read.
      when(() => mockRepo.getAllClips())
          .thenReturn([AudioClip('1000.wav', 'original.m4a', 12.5, true)]);
      convertCalls.clear();

      expect(await migration.run(), equals(0));
      expect(convertCalls, isEmpty);
    });

    test('keeps the original when the conversion fails', () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);
      convertShouldThrow = true;

      expect(await migration.run(), equals(0));

      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
      expect(File(p.join(tmpClips.path, '1000.m4a')).existsSync(), isTrue);
    });

    test('keeps the original when the conversion produces an unusable file',
        () async {
      final clip = await writeClip('1000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([clip]);
      // Shorter than a WAV header: the converter claimed success but wrote
      // nothing playable.
      convertedBytes = List<int>.filled(10, 0);

      expect(await migration.run(), equals(0));

      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
      expect(File(p.join(tmpClips.path, '1000.m4a')).existsSync(), isTrue);
      // The stub output must not be left behind as a "converted" clip.
      expect(File(p.join(tmpClips.path, '1000.wav')).existsSync(), isFalse);
    });

    test('overwrites a partial file left by an interrupted run', () async {
      final clip = await writeClip('1000.m4a');
      await File(p.join(tmpClips.path, '1000.wav')).writeAsBytes([9]);
      when(() => mockRepo.getAllClips()).thenReturn([clip]);

      expect(await migration.run(), equals(1));

      expect(
        File(p.join(tmpClips.path, '1000.wav')).lengthSync(),
        equals(convertedBytes.length),
      );
    });

    test('skips a record whose file is already gone, without touching it',
        () async {
      when(() => mockRepo.getAllClips())
          .thenReturn([AudioClip('missing.m4a', 'original.m4a', 3, true)]);

      expect(await migration.run(), equals(0));

      expect(convertCalls, isEmpty);
      verifyNever(() => mockRepo.updateFileNameByKey(any(), any()));
    });

    test('one failing clip does not stop the others', () async {
      final good = await writeClip('2000.m4a');
      when(() => mockRepo.getAllClips()).thenReturn([
        AudioClip('missing.m4a', 'original.m4a', 3, true),
        good,
      ]);

      expect(await migration.run(), equals(1));
      verify(() => mockRepo.updateFileNameByKey(any(), '2000.wav')).called(1);
    });
  });
}
