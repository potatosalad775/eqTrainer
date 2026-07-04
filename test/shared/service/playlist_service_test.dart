import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:hive_ce/hive.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/playlist_service.dart';

class MockIAudioClipRepository extends Mock implements IAudioClipRepository {}

class MockAppDirectories extends Mock implements AppDirectories {}

void main() {
  group('PlaylistService', () {
    late MockIAudioClipRepository mockRepo;
    late MockAppDirectories mockDirs;
    late PlaylistService service;
    late Directory tmpClips;
    late Directory tmpHive;
    late Box<AudioClip> box;

    setUp(() async {
      mockRepo = MockIAudioClipRepository();
      mockDirs = MockAppDirectories();
      service = PlaylistService(mockRepo, mockDirs);

      tmpClips = await Directory.systemTemp.createTemp('pls_clips_');
      when(() => mockDirs.getClipsPath()).thenAnswer((_) async => tmpClips.path);
      when(() => mockRepo.deleteByKey(any())).thenAnswer((_) async {});

      // listEnabledClipPaths checks the backing file exists and reconciles
      // missing records via clip.key, which only a real HiveObject-backed
      // instance has — a bare AudioClip(...) not added to a box throws when
      // .key is accessed. Use a real (temp) box so clips carry a valid key,
      // matching how the production repository's getAllClips/watchClips
      // (Box.values) attach one.
      tmpHive = await Directory.systemTemp.createTemp('pls_hive_');
      Hive.init(tmpHive.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AudioClipAdapter());
      }
      box = await Hive.openBox<AudioClip>('pls_test_box');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('pls_test_box', path: tmpHive.path);
      await tmpClips.delete(recursive: true);
      await tmpHive.delete(recursive: true);
    });

    /// Adds [clip] to the real test box (so it carries a valid Hive key) and,
    /// unless [withFile] is false, creates its backing file in the fake clips
    /// directory so File.exists() finds it.
    Future<AudioClip> addClip(AudioClip clip, {bool withFile = true}) async {
      await box.add(clip);
      if (withFile) {
        File(p.join(tmpClips.path, clip.fileName)).createSync(recursive: true);
      }
      return clip;
    }

    // -------------------------------------------------------------------------
    // listEnabledClipPaths
    // -------------------------------------------------------------------------
    group('listEnabledClipPaths', () {
      test('returns empty list when repository has no clips', () async {
        when(() => mockRepo.getAllClips()).thenReturn([]);
        final paths = await service.listEnabledClipPaths();
        expect(paths, isEmpty);
      });

      test('returns empty list when all clips are disabled', () async {
        final a = await addClip(AudioClip('a.flac', 'A', 10.0, false));
        final b = await addClip(AudioClip('b.flac', 'B', 20.0, false));
        when(() => mockRepo.getAllClips()).thenReturn([a, b]);
        final paths = await service.listEnabledClipPaths();
        expect(paths, isEmpty);
      });

      test('returns only enabled clips whose file exists', () async {
        final a = await addClip(AudioClip('a.flac', 'A', 10.0, true));
        final b = await addClip(AudioClip('b.flac', 'B', 20.0, false));
        final c = await addClip(AudioClip('c.flac', 'C', 30.0, true));
        when(() => mockRepo.getAllClips()).thenReturn([a, b, c]);
        final paths = await service.listEnabledClipPaths();
        expect(paths.length, equals(2));
        expect(paths, contains(p.join(tmpClips.path, 'a.flac')));
        expect(paths, contains(p.join(tmpClips.path, 'c.flac')));
        expect(paths, isNot(contains(p.join(tmpClips.path, 'b.flac'))));
      });

      test('joins file names with base clips path correctly', () async {
        final track = await addClip(AudioClip('track.flac', 'Track', 5.0, true));
        when(() => mockRepo.getAllClips()).thenReturn([track]);
        final paths = await service.listEnabledClipPaths();
        expect(paths.single, equals(p.join(tmpClips.path, 'track.flac')));
      });

      test('returns all clips when all are enabled and present', () async {
        final x = await addClip(AudioClip('x.flac', 'X', 1.0, true));
        final y = await addClip(AudioClip('y.flac', 'Y', 2.0, true));
        when(() => mockRepo.getAllClips()).thenReturn([x, y]);
        final paths = await service.listEnabledClipPaths();
        expect(paths.length, equals(2));
      });

      test('filters out an enabled clip whose backing file is missing', () async {
        final present = await addClip(AudioClip('present.flac', 'P', 1.0, true));
        final missing = await addClip(
          AudioClip('missing.flac', 'M', 2.0, true),
          withFile: false,
        );
        when(() => mockRepo.getAllClips()).thenReturn([present, missing]);
        final paths = await service.listEnabledClipPaths();
        expect(paths, equals([p.join(tmpClips.path, 'present.flac')]));
      });

      test('reconciles a dangling record whose file is missing', () async {
        final missing = await addClip(
          AudioClip('missing.flac', 'M', 2.0, true),
          withFile: false,
        );
        when(() => mockRepo.getAllClips()).thenReturn([missing]);
        await service.listEnabledClipPaths();
        verify(() => mockRepo.deleteByKey(missing.key)).called(1);
      });
    });

    // -------------------------------------------------------------------------
    // watchEnabledClipPaths
    // -------------------------------------------------------------------------
    group('watchEnabledClipPaths', () {
      test('emits only enabled clip paths that exist for each repository event', () async {
        final a = await addClip(AudioClip('a.flac', 'A', 10.0, true));
        final b = await addClip(AudioClip('b.flac', 'B', 20.0, false));

        when(() => mockRepo.watchClips())
            .thenAnswer((_) => Stream.fromIterable([
                  [a, b],
                  [a, b..isEnabled = true],
                ]));

        final results = await service.watchEnabledClipPaths().toList();

        expect(results.length, equals(2));
        // First emission: only 'a.flac' is enabled
        expect(results[0], equals([p.join(tmpClips.path, 'a.flac')]));
        // Second emission: both enabled
        expect(results[1], containsAll([
          p.join(tmpClips.path, 'a.flac'),
          p.join(tmpClips.path, 'b.flac'),
        ]));
      });

      test('emits empty list when all clips are disabled', () async {
        final a = await addClip(AudioClip('a.flac', 'A', 10.0, false));
        when(() => mockRepo.watchClips()).thenAnswer((_) => Stream.fromIterable([
          [a],
        ]));

        final results = await service.watchEnabledClipPaths().toList();
        expect(results.single, isEmpty);
      });
    });
  });
}
