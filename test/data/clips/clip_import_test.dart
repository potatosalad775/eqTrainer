import 'dart:async';
import 'dart:io';

import 'package:eq_trainer/data/clips/audio_clip_service.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/data/clips/clip_import.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fake_encoder.dart';

class _MockClipService extends Mock implements AudioClipService {}

/// One import, headless: the format policy, the converted temp file and what
/// the save hands to `AudioClipService`.
void main() {
  late Directory tmp;
  late _MockClipService clips;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('eqt_clip_import_');
    clips = _MockClipService();
    when(() => clips.createClip(
          sourcePath: any(named: 'sourcePath'),
          originalPath: any(named: 'originalPath'),
          startSec: any(named: 'startSec'),
          endSec: any(named: 'endSec'),
          isTrimmed: any(named: 'isTrimmed'),
          importFormat: any(named: 'importFormat'),
        )).thenAnswer((_) async {});
  });

  tearDown(() => tmp.delete(recursive: true));

  ClipImport make({
    FakeClipEncoder? encoder,
    int importFormat = ImportFormat.smart,
  }) =>
      ClipImport(
        clips: clips,
        importFormat: importFormat,
        encoder: encoder ?? FakeClipEncoder(),
        tempDirectory: () async => tmp,
      );

  File converted(String name) => File(p.join(tmp.path, 'temp', name));

  group('needsConversion', () {
    test('follows the format policy for the picked name', () {
      final import = make();
      expect(import.needsConversion('song.m4a'), isTrue);
      expect(import.needsConversion('song.AIFF'), isTrue);
      expect(import.needsConversion('song.ogg'), isFalse);
      expect(import.needsConversion('song.flac'), isFalse);
    });

    test('an explicit format converts what is not already in it', () {
      final import = make(importFormat: ImportFormat.allOpus);
      expect(import.needsConversion('song.flac'), isTrue);
      expect(import.needsConversion('song.opus'), isFalse);
    });
  });

  group('prepare', () {
    test('without conversion returns the picked path and owns nothing',
        () async {
      final encoder = FakeClipEncoder();
      final import = make(encoder: encoder);

      final path =
          await import.prepare(pickedPath: '/picked/a.ogg', pickedName: 'a.ogg');
      import.dispose();

      expect(path, '/picked/a.ogg');
      expect(encoder.encoded, isEmpty);
      expect(Directory(p.join(tmp.path, 'temp')).existsSync(), isFalse);
    });

    test('with conversion writes under temp/ and dispose deletes it',
        () async {
      final encoder = FakeClipEncoder();
      final import = make(encoder: encoder);

      final path = await import.prepare(
          pickedPath: '/picked/Song.m4a', pickedName: 'Song.m4a');

      expect(path, p.join(tmp.path, 'temp', 'Song.opus'));
      expect(encoder.encoded, [path]);
      expect(File(path).existsSync(), isTrue);

      import.dispose();
      expect(File(path).existsSync(), isFalse);
    });

    test('a lossless source converts to flac', () async {
      final path = await make().prepare(
          pickedPath: '/picked/a.aiff', pickedName: 'a.aiff');
      expect(p.extension(path), '.flac');
    });

    test('a failed conversion leaves no file and rethrows the error',
        () async {
      final import = make(encoder: FakeClipEncoder(throwOnEncode: true));
      // What an encoder that died mid-write would leave behind.
      final partial = converted('a.opus')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);

      await expectLater(
        import.prepare(pickedPath: '/picked/a.m4a', pickedName: 'a.m4a'),
        throwsException,
      );
      expect(partial.existsSync(), isFalse);
    });

    test('dispose during a conversion deletes the output once it lands',
        () async {
      final landing = Completer<void>();
      final import = make(
        encoder: FakeClipEncoder(onWrite: () => landing.future),
      );

      final prepared = import.prepare(
          pickedPath: '/picked/long.m4a', pickedName: 'long.m4a');
      await pumpEventQueue();

      import.dispose();
      landing.complete();
      await prepared;

      expect(converted('long.opus').existsSync(), isFalse);
    });

    test('dispose twice is harmless', () async {
      final import = make();
      await import.prepare(pickedPath: '/p/a.m4a', pickedName: 'a.m4a');
      import.dispose();
      import.dispose();
      expect(converted('a.opus').existsSync(), isFalse);
    });
  });

  group('save', () {
    const full = Duration(seconds: 10);

    Future<void> saveWith(
      ClipImport import, {
      Duration start = Duration.zero,
      Duration end = full,
    }) =>
        import.save(start: start, end: end, duration: full);

    bool? trimmed() => verify(() => clips.createClip(
          sourcePath: any(named: 'sourcePath'),
          originalPath: any(named: 'originalPath'),
          startSec: any(named: 'startSec'),
          endSec: any(named: 'endSec'),
          isTrimmed: captureAny(named: 'isTrimmed'),
          importFormat: any(named: 'importFormat'),
        )).captured.single as bool;

    Future<ClipImport> prepared() async {
      final import = make();
      await import.prepare(pickedPath: '/p/a.ogg', pickedName: 'a.ogg');
      return import;
    }

    test('is not trimmed when neither edge moved', () async {
      await saveWith(await prepared());
      expect(trimmed(), isFalse);
    });

    test('is trimmed when only the start moved', () async {
      await saveWith(await prepared(), start: const Duration(seconds: 1));
      expect(trimmed(), isTrue);
    });

    test('is trimmed when only the end moved', () async {
      await saveWith(await prepared(), end: const Duration(seconds: 9));
      expect(trimmed(), isTrue);
    });

    test('passes the edges in seconds and the import format', () async {
      final import = make(importFormat: ImportFormat.allWav);
      await import.prepare(pickedPath: '/p/a.wav', pickedName: 'a.wav');
      await saveWith(
        import,
        start: const Duration(milliseconds: 1500),
        end: const Duration(microseconds: 8250000),
      );
      verify(() => clips.createClip(
            sourcePath: '/p/a.wav',
            originalPath: '/p/a.wav',
            startSec: 1.5,
            endSec: 8.25,
            isTrimmed: true,
            importFormat: ImportFormat.allWav,
          )).called(1);
    });

    test('the converted file is the source and the picked file the original',
        () async {
      final import = make();
      final path = await import.prepare(
          pickedPath: '/picked/a.m4a', pickedName: 'a.m4a');
      await saveWith(import, start: const Duration(seconds: 1));
      verify(() => clips.createClip(
            sourcePath: path,
            originalPath: '/picked/a.m4a',
            startSec: 1.0,
            endSec: 10.0,
            isTrimmed: true,
            importFormat: ImportFormat.smart,
          )).called(1);
    });

    test('before a prepare is a StateError', () async {
      expect(() => saveWith(make()), throwsStateError);
      verifyNever(() => clips.createClip(
            sourcePath: any(named: 'sourcePath'),
            originalPath: any(named: 'originalPath'),
            startSec: any(named: 'startSec'),
            endSec: any(named: 'endSec'),
            isTrimmed: any(named: 'isTrimmed'),
            importFormat: any(named: 'importFormat'),
          ));
    });

    test('after a failed prepare is a StateError', () async {
      final import = make(encoder: FakeClipEncoder(throwOnEncode: true));
      await expectLater(
        import.prepare(pickedPath: '/p/a.m4a', pickedName: 'a.m4a'),
        throwsException,
      );
      expect(() => saveWith(import), throwsStateError);
    });

    test('a failure from the service reaches the caller', () async {
      when(() => clips.createClip(
            sourcePath: any(named: 'sourcePath'),
            originalPath: any(named: 'originalPath'),
            startSec: any(named: 'startSec'),
            endSec: any(named: 'endSec'),
            isTrimmed: any(named: 'isTrimmed'),
            importFormat: any(named: 'importFormat'),
          )).thenAnswer(
          (_) async => throw const UnsupportedChannelCountException(6));
      await expectLater(
        saveWith(await prepared()),
        throwsA(isA<UnsupportedChannelCountException>()),
      );
    });
  });

  group('importFailureOf', () {
    test('too many channels', () {
      expect(importFailureOf(const UnsupportedChannelCountException(6)),
          ImportFailure.tooManyChannels);
    });

    test('a file nothing can read', () {
      expect(importFailureOf(const SoLoudFileLoadFailedException()),
          ImportFailure.unreadable);
      expect(
          importFailureOf(const SoLoudOfflineDecodeCppException(
              OfflineDecodeResult.unsupportedFormat)),
          ImportFailure.unreadable);
    });

    test('anything else', () {
      expect(importFailureOf(const SoLoudFileNotFoundException()),
          ImportFailure.other);
      expect(importFailureOf(Exception('boom')), ImportFailure.other);
    });
  });
}
