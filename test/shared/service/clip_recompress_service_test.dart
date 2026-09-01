import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:hive_ce/hive.dart';

import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/clip_encoder.dart';
import 'package:eq_trainer/shared/service/clip_recompress_service.dart';

class _MockRepository extends Mock implements IAudioClipRepository {}

class _MockAppDirectories extends Mock implements AppDirectories {}

/// Stands in for the real encoder so these tests stay headless — the native
/// encoder is covered by the integration suite and the fork's own tests.
class _FakeEncoder implements ClipEncoder {
  _FakeEncoder({this.outputSize = 100, this.throwOnEncode = false});

  final int outputSize;
  final bool throwOnEncode;
  final List<String> encoded = [];

  @override
  Future<void> encodeWavBytes({
    required Uint8List wavBytes,
    required String destPath,
  }) async {
    if (throwOnEncode) throw Exception('encoder failed');
    encoded.add(destPath);
    await File(destPath).writeAsBytes(List<int>.filled(outputSize, 0));
  }

  @override
  Future<void> convertFile({
    required String sourcePath,
    required String destPath,
  }) async =>
      throw UnimplementedError();
}

void main() {
  late Directory clipsDir;
  late Directory hiveDir;
  late Box<AudioClip> box;
  late _MockRepository repo;
  late _MockAppDirectories dirs;

  /// Clips must live in a real box: the service reconciles records through
  /// clip.key, and a bare AudioClip that was never added to one throws when
  /// .key is read.
  Future<AudioClip> clip(String fileName) async {
    final c = AudioClip(fileName, fileName, 1, true);
    await box.add(c);
    return c;
  }

  /// Writes a file of [bytes] length into the clips directory.
  void writeClipFile(String name, int bytes) {
    File(p.join(clipsDir.path, name))
        .writeAsBytesSync(List<int>.filled(bytes, 0));
  }

  setUp(() async {
    clipsDir = Directory.systemTemp.createTempSync('eqt_recompress_');
    hiveDir = Directory.systemTemp.createTempSync('eqt_recompress_hive_');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(AudioClipAdapter().typeId)) {
      Hive.registerAdapter(AudioClipAdapter());
    }
    box = await Hive.openBox<AudioClip>('recompress_test_box');

    repo = _MockRepository();
    dirs = _MockAppDirectories();
    when(() => dirs.getClipsPath()).thenAnswer((_) async => clipsDir.path);
    when(() => repo.updateFileNameByKey(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('recompress_test_box', path: hiveDir.path);
    if (clipsDir.existsSync()) clipsDir.deleteSync(recursive: true);
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
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
          encoder: _FakeEncoder());

      final estimate = await service.estimate();
      expect(estimate.clipCount, equals(2));
      expect(estimate.totalBytes, equals(3000));
    });

    test('is empty for a library with no WAV clips', () async {
      when(repo.getAllClips).thenReturn([await clip('a.flac'), await clip('b.opus')]);
      final service =
          ClipRecompressService(repo, dirs, encoder: _FakeEncoder());
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

      final encoder = _FakeEncoder(outputSize: 2000);
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

      final encoder = _FakeEncoder();
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
              encoder: _FakeEncoder(outputSize: 4000))
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
              encoder: _FakeEncoder(throwOnEncode: true))
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
              encoder: _FakeEncoder(outputSize: 1000))
          .run();

      expect(result.converted, equals(1));
      expect(File(p.join(clipsDir.path, 'a.flac')).existsSync(), isTrue);
    });

    test('rejects an encode that produced an unusably small file', () async {
      when(repo.getAllClips).thenReturn([await clip('a.wav')]);
      writeClipFile('a.wav', 5000);

      final result = await ClipRecompressService(repo, dirs,
              encoder: _FakeEncoder(outputSize: 10))
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
              encoder: _FakeEncoder(outputSize: 1000))
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
              encoder: _FakeEncoder(outputSize: 1000))
          .run(onProgress: (done, total) => seen.add((done, total)));

      expect(seen, equals([(1, 3), (2, 3), (3, 3)]));
    });

    test('does nothing and reports nothing for an empty library', () async {
      when(repo.getAllClips).thenReturn(<AudioClip>[]);
      final result =
          await ClipRecompressService(repo, dirs, encoder: _FakeEncoder())
              .run();
      expect(result.converted, equals(0));
      expect(result.failed, equals(0));
      expect(result.bytesSaved, equals(0));
    });
  });
}
