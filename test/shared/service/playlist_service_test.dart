import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
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

    const String baseClipsPath = '/test/clips';

    setUp(() {
      mockRepo = MockIAudioClipRepository();
      mockDirs = MockAppDirectories();
      service = PlaylistService(mockRepo, mockDirs);

      when(() => mockDirs.getClipsPath()).thenAnswer((_) async => baseClipsPath);
    });

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
        when(() => mockRepo.getAllClips()).thenReturn([
          AudioClip('a.flac', 'A', 10.0, false),
          AudioClip('b.flac', 'B', 20.0, false),
        ]);
        final paths = await service.listEnabledClipPaths();
        expect(paths, isEmpty);
      });

      test('returns only enabled clips', () async {
        when(() => mockRepo.getAllClips()).thenReturn([
          AudioClip('a.flac', 'A', 10.0, true),
          AudioClip('b.flac', 'B', 20.0, false),
          AudioClip('c.flac', 'C', 30.0, true),
        ]);
        final paths = await service.listEnabledClipPaths();
        expect(paths.length, equals(2));
        expect(paths, contains(p.join(baseClipsPath, 'a.flac')));
        expect(paths, contains(p.join(baseClipsPath, 'c.flac')));
        expect(paths, isNot(contains(p.join(baseClipsPath, 'b.flac'))));
      });

      test('joins file names with base clips path correctly', () async {
        when(() => mockRepo.getAllClips()).thenReturn([
          AudioClip('track.flac', 'Track', 5.0, true),
        ]);
        final paths = await service.listEnabledClipPaths();
        expect(paths.single, equals(p.join(baseClipsPath, 'track.flac')));
      });

      test('returns all clips when all are enabled', () async {
        when(() => mockRepo.getAllClips()).thenReturn([
          AudioClip('x.flac', 'X', 1.0, true),
          AudioClip('y.flac', 'Y', 2.0, true),
        ]);
        final paths = await service.listEnabledClipPaths();
        expect(paths.length, equals(2));
      });
    });

    // -------------------------------------------------------------------------
    // watchEnabledClipPaths
    // -------------------------------------------------------------------------
    group('watchEnabledClipPaths', () {
      test('emits only enabled clip paths for each repository event', () async {
        final clips1 = [
          AudioClip('a.flac', 'A', 10.0, true),
          AudioClip('b.flac', 'B', 20.0, false),
        ];
        final clips2 = [
          AudioClip('a.flac', 'A', 10.0, true),
          AudioClip('b.flac', 'B', 20.0, true),
        ];

        when(() => mockRepo.watchClips())
            .thenAnswer((_) => Stream.fromIterable([clips1, clips2]));

        final results = await service.watchEnabledClipPaths().toList();

        expect(results.length, equals(2));
        // First emission: only 'a.flac' is enabled
        expect(results[0], equals([p.join(baseClipsPath, 'a.flac')]));
        // Second emission: both enabled
        expect(results[1], containsAll([
          p.join(baseClipsPath, 'a.flac'),
          p.join(baseClipsPath, 'b.flac'),
        ]));
      });

      test('emits empty list when all clips are disabled', () async {
        when(() => mockRepo.watchClips()).thenAnswer((_) => Stream.fromIterable([
          [AudioClip('a.flac', 'A', 10.0, false)],
        ]));

        final results = await service.watchEnabledClipPaths().toList();
        expect(results.single, isEmpty);
      });
    });
  });
}
