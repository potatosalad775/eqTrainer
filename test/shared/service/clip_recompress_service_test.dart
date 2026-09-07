import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/service/clip_recompress_service.dart';

import '../../helpers/fake_encoder.dart';
import '../../helpers/hive_test_box.dart';
import '../../helpers/mocks.dart';

void main() {
  late Directory clipsDir;
  late HiveTestBox hive;
  late MockIAudioClipRepository repo;
  late MockAppDirectories dirs;

  /// A record in the real test box, so it carries a distinct Hive key for the
  /// service to commit against.
  Future<AudioClip> clip(String fileName) => hive.addClip(fileName);

  /// Writes a file of [bytes] length into the clips directory.
  void writeClipFile(String name, int bytes) {
    File(p.join(clipsDir.path, name))
        .writeAsBytesSync(List<int>.filled(bytes, 0));
  }

  setUp(() async {
    clipsDir = Directory.systemTemp.createTempSync('eqt_recompress_');
    hive = await HiveTestBox.open();

    repo = MockIAudioClipRepository();
    dirs = MockAppDirectories();
    when(() => dirs.getClipsPath()).thenAnswer((_) async => clipsDir.path);
    when(() => repo.updateFileNameByKey(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await hive.dispose();
    if (clipsDir.existsSync()) clipsDir.deleteSync(recursive: true);
  });

  group('estimate', () {
    test('counts only WAV clips whose file exists', () async {
      when(repo.getAllClips).thenReturn([
        await clip('a.wav'),
        await clip('b.wav'),
        await clip('c.flac'),
        await clip('d.opus'),
        await clip('missing.wav'), // no file on disk
      ]);
      writeClipFile('a.wav', 1000);
      writeClipFile('b.wav', 2000);
      writeClipFile('c.flac', 500);

      final service = ClipRecompressService(repo, dirs,
          encoder: FakeClipEncoder());

      final estimate = await service.estimate();
      expect(estimate.clipCount, equals(2));
      expect(estimate.totalBytes, equals(3000));
    });

    test('is empty for a library with no WAV clips', () async {
      when(repo.getAllClips).thenReturn([await clip('a.flac'), await clip('b.opus')]);
      final service =
          ClipRecompressService(repo, dirs, encoder: FakeClipEncoder());
      final estimate = await service.estimate();
      expect(estimate.isEmpty, isTrue);
      expect(estimate.clipCount, equals(0));
    });
  });

  group('run', () {
    test('converts WAV clips, updates records and deletes originals', () async {
      when(repo.getAllClips).thenReturn([await clip('a.wav'), await clip('b.wav')]);
      writeClipFile('a.wav', 5000);
      writeClipFile('b.wav', 5000);

      final encoder = FakeClipEncoder(outputSize: 2000);
      final result =
          await ClipRecompressService(repo, dirs, encoder: encoder).run();

      expect(result.converted, equals(2));
      expect(result.failed, equals(0));
      expect(result.bytesSaved, equals(6000)); // 2 x (5000 - 2000)

      expect(File(p.join(clipsDir.path, 'a.flac')).existsSync(), isTrue);
      expect(File(p.join(clipsDir.path, 'a.wav')).existsSync(), isFalse);
      verify(() => repo.updateFileNameByKey(any(), 'a.flac')).called(1);
      verify(() => repo.updateFileNameByKey(any(), 'b.flac')).called(1);
    });

    test('leaves non-WAV clips completely alone', () async {
      when(repo.getAllClips).thenReturn([await clip('a.opus'), await clip('b.flac')]);
      writeClipFile('a.opus', 1000);
      writeClipFile('b.flac', 1000);

      final encoder = FakeClipEncoder();
      final result =
          await ClipRecompressService(repo, dirs, encoder: encoder).run();

      expect(result.converted, equals(0));
      expect(encoder.encoded, isEmpty);
      expect(File(p.join(clipsDir.path, 'a.opus')).existsSync(), isTrue);
      expect(File(p.join(clipsDir.path, 'b.flac')).existsSync(), isTrue);
      verifyNever(() => repo.updateFileNameByKey(any(), any()));
    });

    test('keeps the WAV when FLAC comes out no smaller', () async {
      when(repo.getAllClips).thenReturn([await clip('a.wav')]);
      writeClipFile('a.wav', 1000);

      // Already-compressed or pathological content can encode larger.
      final result = await ClipRecompressService(repo, dirs,
              encoder: FakeClipEncoder(outputSize: 4000))
          .run();

      expect(result.converted, equals(0));
      expect(result.bytesSaved, equals(0));
      expect(File(p.join(clipsDir.path, 'a.wav')).existsSync(), isTrue);
      expect(File(p.join(clipsDir.path, 'a.flac')).existsSync(), isFalse);
      verifyNever(() => repo.updateFileNameByKey(any(), any()));
    });

    test('a failing encode leaves the original untouched', () async {
      when(repo.getAllClips).thenReturn([await clip('a.wav')]);
      writeClipFile('a.wav', 5000);

      final result = await ClipRecompressService(repo, dirs,
              encoder: FakeClipEncoder(throwOnEncode: true))
          .run();

      expect(result.converted, equals(0));
      expect(result.failed, equals(1));
      expect(File(p.join(clipsDir.path, 'a.wav')).existsSync(), isTrue);
      expect(File(p.join(clipsDir.path, 'a.flac')).existsSync(), isFalse);
      verifyNever(() => repo.updateFileNameByKey(any(), any()));
    });

    test('one failure does not stop the others', () async {
      when(repo.getAllClips).thenReturn([await clip('a.wav'), await clip('b.wav')]);
      writeClipFile('a.wav', 5000);
      // b.wav is deliberately absent, so it is skipped rather than converted.

      final result = await ClipRecompressService(repo, dirs,
              encoder: FakeClipEncoder(outputSize: 1000))
          .run();

      expect(result.converted, equals(1));
      expect(File(p.join(clipsDir.path, 'a.flac')).existsSync(), isTrue);
    });

    test('rejects an encode that produced an unusably small file', () async {
      when(repo.getAllClips).thenReturn([await clip('a.wav')]);
      writeClipFile('a.wav', 5000);

      final result = await ClipRecompressService(repo, dirs,
              encoder: FakeClipEncoder(outputSize: 10))
          .run();

      expect(result.failed, equals(1));
      expect(result.converted, equals(0));
      expect(File(p.join(clipsDir.path, 'a.wav')).existsSync(), isTrue);
    });

    test('overwrites a partial file left by an interrupted run', () async {
      when(repo.getAllClips).thenReturn([await clip('a.wav')]);
      writeClipFile('a.wav', 5000);
      writeClipFile('a.flac', 3); // truncated leftover

      final result = await ClipRecompressService(repo, dirs,
              encoder: FakeClipEncoder(outputSize: 1000))
          .run();

      expect(result.converted, equals(1));
      expect(File(p.join(clipsDir.path, 'a.flac')).lengthSync(), equals(1000));
    });

    test('reports progress once per clip', () async {
      when(repo.getAllClips)
          .thenReturn([await clip('a.wav'), await clip('b.wav'), await clip('c.wav')]);
      writeClipFile('a.wav', 5000);
      writeClipFile('b.wav', 5000);
      writeClipFile('c.wav', 5000);

      final seen = <(int, int)>[];
      await ClipRecompressService(repo, dirs,
              encoder: FakeClipEncoder(outputSize: 1000))
          .run(onProgress: (done, total) => seen.add((done, total)));

      expect(seen, equals([(1, 3), (2, 3), (3, 3)]));
    });

    test('does nothing and reports nothing for an empty library', () async {
      when(repo.getAllClips).thenReturn(<AudioClip>[]);
      final result =
          await ClipRecompressService(repo, dirs, encoder: FakeClipEncoder())
              .run();
      expect(result.converted, equals(0));
      expect(result.failed, equals(0));
      expect(result.bytesSaved, equals(0));
    });
  });
}
