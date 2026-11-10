import 'dart:io';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/data/clips/audio_clip_service.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';

import '../../helpers/fake_encoder.dart';
import '../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // mocktail requires a fallback value for custom types used with any()
    registerFallbackValue(AudioClip('', '', 0.0, false));
  });

  group('AudioClipService', () {
    late MockIAudioClipRepository mockRepo;
    late MockAppDirectories mockDirs;
    late ClipLibrary library;
    late AudioClipService service;
    late Directory tmpSrc;
    late Directory tmpClips;

    setUp(() async {
      mockRepo = MockIAudioClipRepository();
      mockDirs = MockAppDirectories();
      library = ClipLibrary(mockRepo, mockDirs);
      service = AudioClipService(library);

      tmpSrc = await Directory.systemTemp.createTemp('acs_src_');
      tmpClips = await Directory.systemTemp.createTemp('acs_clips_');

      when(() => mockDirs.getClipsPath()).thenAnswer((_) async => tmpClips.path);
      when(() => mockRepo.addClip(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
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
          importFormat: ImportFormat.smart,
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
          importFormat: ImportFormat.smart,
        );

        final captured = verify(() => mockRepo.addClip(captureAny())).captured;
        final clip = captured.single as AudioClip;
        // isTrimmed: false copies as-is, preserving the source extension. Any
        // format conversion happened earlier, in ImportWorkflowService, so
        // by the time createClip sees a foreign format it has already been
        // converted to whatever the import-format setting maps it to.
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
          importFormat: ImportFormat.smart,
        );

        final captured = verify(() => mockRepo.addClip(captureAny())).captured;
        final clip = captured.single as AudioClip;
        // Source extension preserved; createClip does not decide formats.
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
          importFormat: ImportFormat.smart,
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
          importFormat: ImportFormat.smart,
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
            importFormat: ImportFormat.smart,
          ),
          throwsException,
        );
        verifyNever(() => mockRepo.addClip(any()));
      });
    });

    // The real decode and encode are covered by the integration tests in
    // integration_test/audio_clip_service_integration_test.dart. This is about
    // which file a trim reads, and what it does when it cannot.
    group('createClip (isTrimmed: true)', () {
      const converted = '/tmp/converted.opus';
      const original = '/tmp/original.m4a';

      Future<FakeClipEncoder> trim({
        Set<String> unreadable = const {},
        String? originalPath = original,
      }) async {
        final encoder = FakeClipEncoder(unreadable: unreadable);
        await AudioClipService(library, encoder: encoder).createClip(
          sourcePath: converted,
          originalPath: originalPath,
          startSec: 1.0,
          endSec: 3.5,
          isTrimmed: true,
          importFormat: ImportFormat.smart,
        );
        return encoder;
      }

      test('reads the original, not the converted file', () async {
        final encoder = await trim();
        expect(encoder.trimmedFrom, [original]);

        final clip = verify(() => mockRepo.addClip(captureAny())).captured.single
            as AudioClip;
        expect(clip.fileName, endsWith('.opus'));
        expect(clip.ogAudioName, 'converted.opus');
        expect(clip.duration, 2.5);
        expect(File(p.join(tmpClips.path, clip.fileName)).existsSync(), isTrue);
      });

      test('reads the source when nothing was converted', () async {
        final encoder = await trim(originalPath: null);
        expect(encoder.trimmedFrom, [converted]);
      });

      test('falls back to the converted file if SoLoud cannot read the original',
          () async {
        final encoder = await trim(unreadable: {original});
        expect(encoder.trimmedFrom, [original, converted]);
        verify(() => mockRepo.addClip(any())).called(1);
      });

      test('fails, and saves nothing, if neither can be read', () async {
        await expectLater(
          trim(unreadable: {original, converted}),
          throwsException,
        );
        verifyNever(() => mockRepo.addClip(any()));
      });

      Future<void> trimFailingWith(Object failure) =>
          AudioClipService(
            library,
            encoder: FakeClipEncoder(trimFailure: failure),
          ).createClip(
            sourcePath: converted,
            startSec: 1.0,
            endSec: 3.5,
            isTrimmed: true,
            importFormat: ImportFormat.smart,
          );

      test('an encode that dies partway leaves no file behind', () async {
        await expectLater(
          trimFailingWith(StateError('disk full')),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Audio trim failed'),
          )),
        );
        expect(tmpClips.listSync(), isEmpty);
        verifyNever(() => mockRepo.addClip(any()));
      });

      test('keeps the reason a retry cannot help', () async {
        const channels = UnsupportedChannelCountException(6);
        await expectLater(trimFailingWith(channels), throwsA(same(channels)));
        expect(tmpClips.listSync(), isEmpty);

        const unreadable = SoLoudOfflineDecodeCppException(
          OfflineDecodeResult.unsupportedFormat,
        );
        await expectLater(
          trimFailingWith(unreadable),
          throwsA(predicate(isUnreadableAudioError)),
        );
        expect(tmpClips.listSync(), isEmpty);
      });
    });
  });
}
