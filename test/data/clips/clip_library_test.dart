import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/domain/audio_clip.dart';

import '../../helpers/mocks.dart';

/// Records and files together, over the real repository and a real directory.
///
/// A rewrite deletes files out of the user's library, so the cases that matter
/// most are the ones where something goes wrong half way: the clip must come
/// out as it went in, with no stray file beside it.
void main() {
  late Directory root;
  late Directory clipsDir;
  late File libraryFile;
  late AudioClipRepository repo;
  late MockAppDirectories dirs;
  late ClipLibrary library;

  String path(String name) => p.join(clipsDir.path, name);
  bool exists(String name) => File(path(name)).existsSync();

  /// Writes [name] with [bytes] bytes and, unless [record] is false, a record
  /// for it. The id is the basename unless given.
  Future<AudioClip> addClip(
    String name, {
    int bytes = 100,
    bool enabled = true,
    bool file = true,
    String? id,
  }) async {
    if (file) File(path(name)).writeAsBytesSync(List<int>.filled(bytes, 1));
    final clip = AudioClip(name, 'song-$name', 12.5, enabled, id: id);
    await repo.addClip(clip);
    return clip;
  }

  /// A producer that writes [bytes] bytes, as an encoder would.
  Future<void> Function(String, String) writer(int bytes) =>
      (source, dest) => File(dest).writeAsBytes(List<int>.filled(bytes, 2));

  /// Makes the next record save fail: a directory cannot be renamed over.
  Future<void> breakSaving() async {
    if (libraryFile.existsSync()) await libraryFile.delete();
    await Directory(libraryFile.path).create();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('clip_library_');
    clipsDir = await Directory(p.join(root.path, 'clips')).create();
    libraryFile = File(p.join(root.path, 'audio_clips.json'));
    repo = await AudioClipRepository.open(libraryFile);
    dirs = MockAppDirectories();
    when(() => dirs.getClipsPath()).thenAnswer((_) async => clipsDir.path);
    library = ClipLibrary(repo, dirs);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  group('clips', () {
    test('are the records as they stand now', () async {
      expect(library.clips, isEmpty);
      final clip = await addClip('1000.flac');
      expect(library.clips, [clip]);
    });
  });

  group('pathOf and fileSizeOf', () {
    test('give the clip\'s file and its size', () async {
      await addClip('1000.flac', bytes: 77);

      expect(await library.pathOf('1000'), path('1000.flac'));
      expect(await library.fileSizeOf('1000'), 77);
    });

    test('are null for a clip that does not exist', () async {
      expect(await library.pathOf('nope'), isNull);
      expect(await library.fileSizeOf('nope'), isNull);
    });

    test('are null for a clip whose file is missing', () async {
      await addClip('1000.flac', file: false);

      expect(await library.pathOf('1000'), isNull);
      expect(await library.fileSizeOf('1000'), isNull);
    });

    test('follow the record to the file it points at now', () async {
      await addClip('1000.wav');
      File(path('1000.flac')).writeAsBytesSync(List<int>.filled(30, 1));
      await repo.updateFileNameById('1000', '1000.flac');

      expect(await library.pathOf('1000'), path('1000.flac'));
      expect(await library.fileSizeOf('1000'), 30);
    });
  });

  group('missingClipIds', () {
    test('is empty for an empty library', () async {
      expect(await library.missingClipIds(), isEmpty);
    });

    test('is empty when every clip has its file', () async {
      await addClip('1000.flac');
      await addClip('2000.wav', enabled: false);

      expect(await library.missingClipIds(), isEmpty);
    });

    test('names the clips whose file is not there, enabled or not', () async {
      await addClip('present.flac');
      await addClip('gone.flac', file: false);
      await addClip('off.wav', file: false, enabled: false);

      expect(await library.missingClipIds(), {'gone', 'off'});
    });

    test('goes by the id, which can differ from the file name', () async {
      await addClip('1000.opus', file: false, id: '1000-2');

      expect(await library.missingClipIds(), {'1000-2'});
    });

    test('follows the file as it stands now', () async {
      await addClip('1000.flac');
      expect(await library.missingClipIds(), isEmpty);

      File(path('1000.flac')).deleteSync();
      expect(await library.missingClipIds(), {'1000'});

      File(path('1000.flac')).writeAsBytesSync([1]);
      expect(await library.missingClipIds(), isEmpty);
    });

    test('leaves the record of a missing clip alone, in memory and on disk',
        () async {
      await addClip('present.flac');
      final missing = await addClip('gone.flac', file: false);

      await library.missingClipIds();

      expect(library.clips, contains(missing));
      final saved = (await AudioClipRepository.open(libraryFile)).getAllClips();
      expect(saved, contains(missing));
    });
  });

  group('enabledClipPaths', () {
    test('is empty for an empty library', () async {
      expect(await library.enabledClipPaths(), isEmpty);
    });

    test('lists enabled clips whose file exists, in library order', () async {
      await addClip('c.flac');
      await addClip('b.flac', enabled: false);
      await addClip('a.flac');

      expect(
        await library.enabledClipPaths(),
        [path('c.flac'), path('a.flac')],
      );
    });

    test('skips a missing clip and keeps its record', () async {
      await addClip('present.flac');
      final missing = await addClip('missing.flac', file: false);

      expect(await library.enabledClipPaths(), [path('present.flac')]);

      expect(library.clips, contains(missing));
      final saved = (await AudioClipRepository.open(libraryFile)).getAllClips();
      expect(saved, contains(missing));
    });
  });

  group('resolvePath', () {
    test('returns the path unchanged while the file is still there', () async {
      await addClip('1000.opus');

      expect(await library.resolvePath(path('1000.opus')), path('1000.opus'));
    });

    test('follows a clip that was rewritten to another format', () async {
      await addClip('1000.opus');

      expect(await library.resolvePath(path('1000.m4a')), path('1000.opus'));
    });

    test('resolves a disabled clip too, since the snapshot outranks a toggle '
        'made mid-session', () async {
      await addClip('1000.opus', enabled: false);

      expect(await library.resolvePath(path('1000.m4a')), path('1000.opus'));
    });

    test('matches the file name, not the id', () async {
      // A clip migrated from Hive can have an id that differs from its basename.
      await addClip('1000.opus', id: '1000-2');

      expect(await library.resolvePath(path('1000.m4a')), path('1000.opus'));
    });

    test('is null when the clip has no record left', () async {
      expect(await library.resolvePath(path('1000.m4a')), isNull);
    });

    test('is null when the record survived but its file did not', () async {
      await addClip('1000.opus', file: false);

      expect(await library.resolvePath(path('1000.m4a')), isNull);
    });

    test('does not confuse one clip for another', () async {
      await addClip('2000.opus');

      expect(await library.resolvePath(path('1000.m4a')), isNull);
    });
  });

  group('add', () {
    test('has produce write the file, then saves the record', () async {
      String? producedAt;
      await library.add(
        extension: '.flac',
        originalName: 'track.wav',
        duration: 5.5,
        produce: (dest) async {
          producedAt = dest;
          await File(dest).writeAsBytes([1, 2, 3]);
        },
      );

      final clip = library.clips.single;
      expect(clip.fileName, endsWith('.flac'));
      expect(producedAt, path(clip.fileName));
      expect(clip.id, p.basenameWithoutExtension(clip.fileName));
      expect(clip.ogAudioName, 'track.wav');
      expect(clip.duration, 5.5);
      expect(clip.isEnabled, isTrue);
      expect(File(producedAt!).existsSync(), isTrue);
    });

    test('names each clip after the time, so two clips never share a file',
        () async {
      Future<void> addOne() => library.add(
            extension: '.wav',
            originalName: 'a.wav',
            duration: 1,
            produce: (dest) => File(dest).writeAsBytes([1]),
          );
      await addOne();
      await addOne();

      expect(library.clips.map((c) => c.fileName).toSet(), hasLength(2));
    });

    test('removes the partial file and rethrows the same error if produce '
        'fails', () async {
      final error = StateError('disk full');

      await expectLater(
        library.add(
          extension: '.opus',
          originalName: 'a.wav',
          duration: 1,
          produce: (dest) async {
            await File(dest).writeAsBytes([1, 2, 3]);
            throw error;
          },
        ),
        throwsA(same(error)),
      );

      expect(clipsDir.listSync(), isEmpty);
      expect(library.clips, isEmpty);
    });

    test('removes the file and rethrows if the record cannot be saved',
        () async {
      await breakSaving();

      await expectLater(
        library.add(
          extension: '.opus',
          originalName: 'a.wav',
          duration: 1,
          produce: (dest) => File(dest).writeAsBytes([1, 2, 3]),
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(clipsDir.listSync(), isEmpty);
      expect(library.clips, isEmpty);
    });
  });

  group('delete', () {
    test('removes the file and the record', () async {
      await addClip('1000.flac');
      await addClip('2000.flac');

      await library.delete('1000');

      expect(exists('1000.flac'), isFalse);
      expect(exists('2000.flac'), isTrue);
      expect(library.clips.map((c) => c.id), ['2000']);
    });

    test('removes the file the record points at now, not the one it did when '
        'the caller saw it', () async {
      // A tile built before a rewrite still holds the .wav record.
      await addClip('1000.wav');
      File(path('1000.flac')).writeAsBytesSync(List<int>.filled(60, 1));
      await repo.updateFileNameById('1000', '1000.flac');

      await library.delete('1000');

      expect(exists('1000.flac'), isFalse);
      expect(library.clips, isEmpty);
    });

    test('still removes the record of a missing clip', () async {
      await addClip('1000.flac', file: false);

      await library.delete('1000');

      expect(library.clips, isEmpty);
    });

    test('does nothing for a clip that is already gone', () async {
      await addClip('1000.flac');

      await library.delete('nope');

      expect(library.clips, hasLength(1));
      expect(exists('1000.flac'), isTrue);
    });
  });

  group('rewrite', () {
    test('repoints the record, removes the source and reports both sizes',
        () async {
      await addClip('1000.wav', bytes: 500);

      final result = await library.rewrite(
        '1000',
        extension: '.flac',
        produce: writer(200),
      );

      expect(result.status, RewriteStatus.committed);
      expect(result.sourceBytes, 500);
      expect(result.destBytes, 200);
      expect(result.error, isNull);
      expect(exists('1000.wav'), isFalse);
      expect(exists('1000.flac'), isTrue);
    });

    test('reaches the disk and keeps the rest of the record', () async {
      await addClip('1000.wav', enabled: false);

      await library.rewrite('1000', extension: '.flac', produce: writer(100));

      final saved = (await AudioClipRepository.open(libraryFile)).getAllClips();
      expect(
        saved,
        [AudioClip('1000.flac', 'song-1000.wav', 12.5, false, id: '1000')],
      );
    });

    test('hands produce the source and a destination beside it', () async {
      await addClip('1000.wav');
      String? gotSource, gotDest;

      await library.rewrite(
        '1000',
        extension: '.opus',
        produce: (source, dest) {
          gotSource = source;
          gotDest = dest;
          return writer(100)(source, dest);
        },
      );

      expect(gotSource, path('1000.wav'));
      expect(gotDest, path('1000.opus'));
    });

    test('names the destination after the file, not an id that differs from it',
        () async {
      await addClip('1000.m4a', id: '1000-2');

      final result = await library.rewrite(
        '1000-2',
        extension: '.opus',
        produce: writer(100),
      );

      expect(result.status, RewriteStatus.committed);
      expect(library.clips.single.fileName, '1000.opus');
      expect(library.clips.single.id, '1000-2');
    });

    test('is clipGone for a clip with no record', () async {
      var produced = false;

      final result = await library.rewrite(
        'nope',
        extension: '.flac',
        produce: (s, d) async => produced = true,
      );

      expect(result.status, RewriteStatus.clipGone);
      expect(produced, isFalse);
    });

    test('is sourceMissing for a missing file, and leaves the record alone',
        () async {
      final clip = await addClip('1000.m4a', file: false);
      var produced = false;

      final result = await library.rewrite(
        '1000',
        extension: '.opus',
        produce: (s, d) async => produced = true,
      );

      expect(result.status, RewriteStatus.sourceMissing);
      expect(produced, isFalse);
      expect(library.clips, [clip]);
    });

    test('refuses to produce into the source', () async {
      final clip = await addClip('1000.flac');
      var produced = false;

      final result = await library.rewrite(
        '1000',
        extension: '.flac',
        produce: (s, d) async => produced = true,
      );

      expect(result.status, RewriteStatus.failed);
      expect(result.error, isA<ArgumentError>());
      expect(produced, isFalse);
      expect(exists('1000.flac'), isTrue);
      expect(library.clips, [clip]);
    });

    test('replaces a partial file left by an interrupted run', () async {
      await addClip('1000.wav');
      File(path('1000.flac')).writeAsBytesSync([9]);
      bool? leftoverSeen;

      final result = await library.rewrite(
        '1000',
        extension: '.flac',
        produce: (source, dest) {
          leftoverSeen = File(dest).existsSync();
          return writer(128)(source, dest);
        },
      );

      expect(result.status, RewriteStatus.committed);
      expect(leftoverSeen, isFalse);
      expect(File(path('1000.flac')).lengthSync(), 128);
    });

    test('never writes over the file of another clip', () async {
      // Records migrated from Hive can share a stem under different ids.
      final a = await addClip('1000.wav', bytes: 500);
      final b = await addClip('1000.flac', bytes: 77, id: '1000-2');
      var produced = false;

      final result = await library.rewrite(
        '1000',
        extension: '.flac',
        produce: (s, d) {
          produced = true;
          return writer(100)(s, d);
        },
      );

      expect(result.status, RewriteStatus.failed);
      expect(result.error, isA<StateError>());
      expect(produced, isFalse);
      expect(File(path('1000.flac')).lengthSync(), 77);
      expect(File(path('1000.wav')).lengthSync(), 500);
      expect(library.clips, [a, b]);
    });

    test('fails on an output too small to hold audio, and leaves the source',
        () async {
      final clip = await addClip('1000.m4a');

      final result = await library.rewrite(
        '1000',
        extension: '.opus',
        produce: writer(10),
      );

      expect(result.status, RewriteStatus.failed);
      expect(result.error, isA<FileSystemException>());
      expect(exists('1000.m4a'), isTrue);
      expect(exists('1000.opus'), isFalse);
      expect(library.clips, [clip]);
    });

    test('accepts the smallest valid output, a FLAC header of 42 bytes',
        () async {
      await addClip('1000.wav');
      expect(
        (await library.rewrite('1000', extension: '.flac', produce: writer(41)))
            .status,
        RewriteStatus.failed,
      );
      expect(
        (await library.rewrite('1000', extension: '.flac', produce: writer(42)))
            .status,
        RewriteStatus.committed,
      );
    });

    test('fails when produce writes nothing', () async {
      await addClip('1000.m4a');

      final result = await library.rewrite(
        '1000',
        extension: '.opus',
        produce: (s, d) async {},
      );

      expect(result.status, RewriteStatus.failed);
      expect(exists('1000.m4a'), isTrue);
    });

    test('keeps the source and record and removes the partial if produce '
        'throws', () async {
      final clip = await addClip('1000.m4a');
      final error = StateError('encoder failed');

      final result = await library.rewrite(
        '1000',
        extension: '.opus',
        produce: (source, dest) async {
          await File(dest).writeAsBytes(List<int>.filled(100, 0));
          throw error;
        },
      );

      expect(result.status, RewriteStatus.failed);
      expect(result.error, same(error));
      expect(exists('1000.m4a'), isTrue);
      expect(exists('1000.opus'), isFalse);
      expect(library.clips, [clip]);
    });

    test('keeps the source and removes the destination if the record cannot '
        'be saved', () async {
      await addClip('1000.m4a');
      await breakSaving();

      final result = await library.rewrite(
        '1000',
        extension: '.opus',
        produce: writer(100),
      );

      expect(result.status, RewriteStatus.failed);
      expect(library.clips.single.fileName, '1000.m4a');
      expect(exists('1000.m4a'), isTrue);
      expect(exists('1000.opus'), isFalse);
    });

    test('drops a file whose clip was deleted while it was produced',
        () async {
      await addClip('1000.m4a');
      await addClip('2000.flac');

      final result = await library.rewrite(
        '1000',
        extension: '.opus',
        produce: (source, dest) async {
          await writer(100)(source, dest);
          await repo.deleteById('1000');
        },
      );

      expect(result.status, RewriteStatus.clipGone);
      expect(exists('1000.opus'), isFalse);
      expect(library.clips.map((c) => c.id), ['2000']);
    });

    test('removes the destination and reports both sizes when keep refuses',
        () async {
      final clip = await addClip('1000.wav', bytes: 300);
      int? keptSource, keptDest;

      final result = await library.rewrite(
        '1000',
        extension: '.flac',
        produce: writer(400),
        keep: (source, dest) {
          keptSource = source;
          keptDest = dest;
          return false;
        },
      );

      expect(result.status, RewriteStatus.declined);
      expect(result.sourceBytes, 300);
      expect(result.destBytes, 400);
      expect([keptSource, keptDest], [300, 400]);
      expect(exists('1000.flac'), isFalse);
      expect(exists('1000.wav'), isTrue);
      expect(library.clips, [clip]);
    });

    test('commits when keep accepts', () async {
      await addClip('1000.wav', bytes: 300);

      final result = await library.rewrite(
        '1000',
        extension: '.flac',
        produce: writer(100),
        keep: (source, dest) => dest < source,
      );

      expect(result.status, RewriteStatus.committed);
    });

    test('still commits when the source cannot be deleted', () async {
      await addClip('1000.m4a');

      final result = await library.rewrite(
        '1000',
        extension: '.opus',
        produce: (source, dest) async {
          await writer(100)(source, dest);
          // A directory where the file was, so deleting it fails on every
          // platform, as it does for a file the player has open.
          File(source).deleteSync();
          Directory(source).createSync();
        },
      );

      expect(result.status, RewriteStatus.committed);
      expect(library.clips.single.fileName, '1000.opus');
      expect(exists('1000.opus'), isTrue);
    });

    test('never throws, even if the clips directory cannot be found',
        () async {
      await addClip('1000.m4a');
      when(() => dirs.getClipsPath()).thenThrow(StateError('no directory'));

      final result = await library.rewrite(
        '1000',
        extension: '.opus',
        produce: writer(100),
      );

      expect(result.status, RewriteStatus.failed);
      expect(result.error, isA<StateError>());
    });
  });
}
