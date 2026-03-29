import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/audio_clip_service.dart';

class MockIAudioClipRepository extends Mock implements IAudioClipRepository {}

class MockAppDirectories extends Mock implements AppDirectories {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // mocktail requires a fallback value for custom types used with any()
    registerFallbackValue(AudioClip('', '', 0.0, false));
  });

  group('AudioClipService', () {
    late MockIAudioClipRepository mockRepo;
    late MockAppDirectories mockDirs;
    late AudioClipService service;
    late Directory tmpSrc;
    late Directory tmpClips;

    setUp(() async {
      mockRepo = MockIAudioClipRepository();
      mockDirs = MockAppDirectories();
      service = AudioClipService(mockRepo, mockDirs);

      tmpSrc = await Directory.systemTemp.createTemp('acs_src_');
      tmpClips = await Directory.systemTemp.createTemp('acs_clips_');

      when(() => mockDirs.getClipsPath()).thenAnswer((_) async => tmpClips.path);
      when(() => mockRepo.addClip(any())).thenAnswer((_) async {});

      // Mock the audio_decoder platform channel so convertToWav works in unit
      // tests by simply copying the source file to the destination.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('audio_decoder'),
        (MethodCall call) async {
          if (call.method == 'convertToWav') {
            final args = call.arguments as Map;
            final input = args['inputPath'] as String;
            final output = args['outputPath'] as String;
            await File(input).copy(output);
            return output;
          }
          return null;
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('audio_decoder'),
        null,
      );
      await tmpSrc.delete(recursive: true);
      await tmpClips.delete(recursive: true);
    });

    // -------------------------------------------------------------------------
    // createClip — isTrimmed: false (copy as-is)
    // -------------------------------------------------------------------------
    group('createClip (isTrimmed: false)', () {
      test('copies file and saves correct metadata', () async {
        final srcFile = File(p.join(tmpSrc.path, 'track.wav'))
          ..writeAsBytesSync(List.filled(100, 0));

        await service.createClip(
          sourcePath: srcFile.path,
          startSec: 0.0,
          endSec: 5.5,
          isTrimmed: false,
        );

        final captured = verify(() => mockRepo.addClip(captureAny())).captured;
        final clip = captured.single as AudioClip;

        expect(clip.fileName, endsWith('.wav'));
        expect(clip.ogAudioName, equals('track.wav'));
        expect(clip.duration, equals(5.5));
        expect(clip.isEnabled, isTrue);

        // Verify the file was created in the clips directory
        final destFile = File(p.join(tmpClips.path, clip.fileName));
        expect(destFile.existsSync(), isTrue);
        expect(destFile.lengthSync(), equals(100));
      });

      test('preserves source extension when not trimmed', () async {
        final srcFile = File(p.join(tmpSrc.path, 'song.mp3'))
          ..writeAsBytesSync(List.filled(50, 0));

        await service.createClip(
          sourcePath: srcFile.path,
          startSec: 0.0,
          endSec: 180.0,
          isTrimmed: false,
        );

        final captured = verify(() => mockRepo.addClip(captureAny())).captured;
        final clip = captured.single as AudioClip;
        // isTrimmed: false copies as-is, preserving source extension
        // (conversion to m4a/wav happens at import time, not in createClip)
        expect(clip.fileName, endsWith('.mp3'));
      });

      test('preserves unsupported extension when not trimmed', () async {
        final srcFile = File(p.join(tmpSrc.path, 'audio.aac'))
          ..writeAsBytesSync(List.filled(50, 0));

        await service.createClip(
          sourcePath: srcFile.path,
          startSec: 0.0,
          endSec: 10.0,
          isTrimmed: false,
        );

        final captured = verify(() => mockRepo.addClip(captureAny())).captured;
        final clip = captured.single as AudioClip;
        // Source extension preserved; conversion happens at import time
        expect(clip.fileName, endsWith('.aac'));
      });

      test('ogAudioName is basename of sourcePath', () async {
        final srcFile = File(p.join(tmpSrc.path, 'my_favourite_track.wav'))
          ..writeAsBytesSync(List.filled(50, 0));

        await service.createClip(
          sourcePath: srcFile.path,
          startSec: 0.0,
          endSec: 3.0,
          isTrimmed: false,
        );

        final captured = verify(() => mockRepo.addClip(captureAny())).captured;
        final clip = captured.single as AudioClip;
        expect(clip.ogAudioName, equals('my_favourite_track.wav'));
      });

      test('duration equals endSec when isTrimmed is false', () async {
        final srcFile = File(p.join(tmpSrc.path, 'long.wav'))
          ..writeAsBytesSync(List.filled(50, 0));

        await service.createClip(
          sourcePath: srcFile.path,
          startSec: 5.0, // startSec is ignored in the convert-to-wav path
          endSec: 42.7,
          isTrimmed: false,
        );

        final captured = verify(() => mockRepo.addClip(captureAny())).captured;
        final clip = captured.single as AudioClip;
        expect(clip.duration, equals(42.7));
      });

      test('throws when source file does not exist', () async {
        await expectLater(
          service.createClip(
            sourcePath: p.join(tmpSrc.path, 'nonexistent.wav'),
            startSec: 0.0,
            endSec: 1.0,
            isTrimmed: false,
          ),
          throwsException,
        );
        verifyNever(() => mockRepo.addClip(any()));
      });
    });

    // Note: createClip (isTrimmed: true) invokes AudioDecoder.trimAudio() which
    // is a native platform channel and cannot run in a unit test environment.
    // The full trim+persist pipeline is covered by the integration tests in
    // integration_test/audio_clip_service_integration_test.dart.
  });
}
