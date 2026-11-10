import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/data/clips/clip_recompress_service.dart';

import '../../helpers/fake_encoder.dart';
import '../../helpers/mocks.dart';

/// Which clips the pass picks, what it counts, and that it never throws. The
/// rewrite of each clip, with its ordering and cleanup, is `ClipLibrary.rewrite`
/// and is tested there.
void main() {
  late Directory root;
  late Directory clipsDir;
  late AudioClipRepository repo;
  late ClipLibrary library;

  /// A record for [fileName], and unless [file] is false, a file of [bytes].
  Future<void> addClip(String fileName, {int bytes = 5000, bool file = true}) async {
    if (file) {
      File(p.join(clipsDir.path, fileName))
          .writeAsBytesSync(List<int>.filled(bytes, 0));
    }
    await repo.addClip(AudioClip(fileName, fileName, 1, true));
  }

  List<String> fileNames() => [for (final c in repo.getAllClips()) c.fileName];

  bool onDisk(String name) => File(p.join(clipsDir.path, name)).existsSync();

  ClipRecompressService serviceWith(FakeClipEncoder encoder) =>
      ClipRecompressService(library, encoder: encoder);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('eqt_recompress_');
    clipsDir = Directory(p.join(root.path, 'clips'))..createSync();
    repo = await AudioClipRepository.open(
        File(p.join(root.path, 'audio_clips.json')));
    final dirs = MockAppDirectories();
    when(() => dirs.getClipsPath()).thenAnswer((_) async => clipsDir.path);
    library = ClipLibrary(repo, dirs);
  });

  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('estimate', () {
    test('counts only WAV clips whose file exists', () async {
      await addClip('a.wav', bytes: 1000);
      await addClip('b.wav', bytes: 2000);
      await addClip('c.flac', bytes: 500);
      await addClip('d.opus', file: false);
      await addClip('missing.wav', file: false);

      final estimate = await serviceWith(FakeClipEncoder()).estimate();

      expect(estimate.clipCount, equals(2));
      expect(estimate.totalBytes, equals(3000));
    });

    test('is empty for a library with no WAV clips', () async {
      await addClip('a.flac');
      await addClip('b.opus');

      final estimate = await serviceWith(FakeClipEncoder()).estimate();

      expect(estimate.isEmpty, isTrue);
      expect(estimate.clipCount, equals(0));
    });
  });

  group('run', () {
    test('converts WAV clips, updates records and deletes originals', () async {
      await addClip('a.wav');
      await addClip('b.wav');

      final result = await serviceWith(FakeClipEncoder(outputSize: 2000)).run();

      expect(result.converted, equals(2));
      expect(result.failed, equals(0));
      expect(result.bytesSaved, equals(6000)); // 2 x (5000 - 2000)
      expect(fileNames(), ['a.flac', 'b.flac']);
      expect(onDisk('a.flac'), isTrue);
      expect(onDisk('a.wav'), isFalse);
    });

    test('leaves non-WAV clips completely alone', () async {
      await addClip('a.opus', bytes: 1000);
      await addClip('b.flac', bytes: 1000);
      final encoder = FakeClipEncoder();

      final result = await serviceWith(encoder).run();

      expect(result.converted, equals(0));
      expect(encoder.encoded, isEmpty);
      expect(fileNames(), ['a.opus', 'b.flac']);
    });

    test('keeps the WAV when FLAC comes out no smaller', () async {
      await addClip('a.wav', bytes: 1000);

      // Already-compressed or pathological content can encode larger.
      final result = await serviceWith(FakeClipEncoder(outputSize: 4000)).run();

      expect(result.converted, equals(0));
      expect(result.failed, equals(0));
      expect(result.bytesSaved, equals(0));
      expect(fileNames(), ['a.wav']);
      expect(onDisk('a.wav'), isTrue);
      expect(onDisk('a.flac'), isFalse);
    });

    test('a failing encode leaves the original untouched and counts as failed',
        () async {
      await addClip('a.wav');

      final result =
          await serviceWith(FakeClipEncoder(throwOnEncode: true)).run();

      expect(result.converted, equals(0));
      expect(result.failed, equals(1));
      expect(fileNames(), ['a.wav']);
      expect(onDisk('a.wav'), isTrue);
      expect(onDisk('a.flac'), isFalse);
    });

    test('a clip with no file is skipped, and the others still convert',
        () async {
      await addClip('a.wav', file: false);
      await addClip('b.wav');

      final result = await serviceWith(FakeClipEncoder(outputSize: 1000)).run();

      expect(result.converted, equals(1));
      expect(result.failed, equals(0));
      expect(fileNames(), ['a.wav', 'b.flac']);
    });

    test('drops a clip deleted while its encode was in flight', () async {
      await addClip('a.wav');
      await addClip('b.wav');

      final result = await serviceWith(
        FakeClipEncoder(
          outputSize: 2000,
          onWrite: () => repo.deleteById('a'),
        ),
      ).run();

      // Only the clip that survived counts, and nothing is left for the other.
      expect(result.converted, equals(1));
      expect(result.failed, equals(0));
      expect(result.bytesSaved, equals(3000));
      expect(onDisk('a.flac'), isFalse);
      expect(fileNames(), ['b.flac']);
    });

    test('reports progress once per clip', () async {
      await addClip('a.wav');
      await addClip('b.wav');
      await addClip('c.wav');

      final seen = <(int, int)>[];
      await serviceWith(FakeClipEncoder(outputSize: 1000))
          .run(onProgress: (done, total) => seen.add((done, total)));

      expect(seen, equals([(1, 3), (2, 3), (3, 3)]));
    });

    test('does nothing and reports nothing for an empty library', () async {
      final result = await serviceWith(FakeClipEncoder()).run();

      expect(result.converted, equals(0));
      expect(result.failed, equals(0));
      expect(result.bytesSaved, equals(0));
    });
  });
}
