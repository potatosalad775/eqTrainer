import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/model/legacy_audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/legacy_clip_migration.dart';

/// Moving the clip library out of Hive. Getting this wrong loses data the user
/// cannot get back, so the invariant that matters is that nothing is marked done
/// and nothing is removed unless the library is safely in its new home.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File libraryFile;
  late File boxFile;
  late SharedPreferences prefs;
  late AudioClipRepository repo;

  // The box name is spelled out rather than shared with the implementation: it
  // is what older versions wrote, and must not change.
  Future<void> seedBox(List<LegacyAudioClip> clips) async {
    final box = await Hive.openBox<LegacyAudioClip>('audioClipBox');
    await box.addAll(clips);
    await box.close();
  }

  List<String> names() => repo.getAllClips().map((c) => c.fileName).toList();

  Future<void> migrate() =>
      migrateLegacyClips(repo, prefs, boxDirectory: dir.path);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('eqt_legacy_clips_');
    libraryFile = File(p.join(dir.path, 'audio_clips.json'));
    boxFile = File(p.join(dir.path, 'audioclipbox.hive'));
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(LegacyAudioClipAdapter().typeId)) {
      Hive.registerAdapter(LegacyAudioClipAdapter());
    }
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = await AudioClipRepository.open(libraryFile);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('carries every field across and saves it', () async {
    await seedBox([LegacyAudioClip('1000.flac', 'song.flac', 12.5, false)]);

    await migrate();

    final saved = (await AudioClipRepository.open(libraryFile)).getAllClips();
    expect(saved, equals([AudioClip('1000.flac', 'song.flac', 12.5, false, id: '1000')]));
    expect(prefs.getBool(legacyClipsMigratedKey), isTrue);
    expect(repo.hasUnreadableData, isFalse);
  });

  test('keeps the order the user arranged', () async {
    // A reorder rewrote values under fixed keys, so what matters is key order.
    final box = await Hive.openBox<LegacyAudioClip>('audioClipBox');
    await box.put(0, LegacyAudioClip('3.wav', 'c', 1, true));
    await box.put(1, LegacyAudioClip('1.wav', 'a', 1, true));
    await box.put(2, LegacyAudioClip('2.wav', 'b', 1, true));
    await box.close();

    await migrate();

    expect(names(), equals(['3.wav', '1.wav', '2.wav']));
  });

  test('gives clips sharing a basename different ids', () async {
    // The first versions named files by the second, so this can really happen.
    await seedBox([
      LegacyAudioClip('2024115.m4a', 'a', 1, true),
      LegacyAudioClip('2024115.wav', 'b', 1, true),
      LegacyAudioClip('2024115.flac', 'c', 1, true),
    ]);

    await migrate();

    expect(repo.getAllClips().map((c) => c.id),
        equals(['2024115', '2024115-2', '2024115-3']));
  });

  test('a non-finite duration does not fail the whole library', () async {
    await seedBox([LegacyAudioClip('a.wav', 'a', double.nan, true)]);

    await migrate();

    expect(prefs.getBool(legacyClipsMigratedKey), isTrue);
    expect(repo.getAllClips().single.duration, equals(0.0));
  });

  test('keeps the old box file after success', () async {
    await seedBox([LegacyAudioClip('a.wav', 'a', 1, true)]);

    await migrate();

    expect(boxFile.existsSync(), isTrue);
  });

  test('a fresh install is done immediately and creates no box', () async {
    await migrate();

    expect(prefs.getBool(legacyClipsMigratedKey), isTrue);
    expect(boxFile.existsSync(), isFalse);
    expect(repo.hasUnreadableData, isFalse);
  });

  test('an empty box is an empty library, not a failure', () async {
    await seedBox([]);

    await migrate();

    expect(prefs.getBool(legacyClipsMigratedKey), isTrue);
    expect(repo.getAllClips(), isEmpty);
    expect(repo.hasUnreadableData, isFalse);
  });

  test('runs once, and never brings a deleted clip back', () async {
    await seedBox([LegacyAudioClip('1.wav', 'a', 1, true), LegacyAudioClip('2.wav', 'b', 1, true)]);
    await migrate();
    await repo.deleteById('1');

    await migrate();

    expect(names(), equals(['2.wav']));
  });

  group('when the box cannot be read', () {
    /// A record whose field has the wrong type, which fails the box's open
    /// rather than being quietly repaired the way a truncated file is.
    Future<void> seedUnreadableBox() async {
      Hive.resetAdapters();
      Hive.registerAdapter(_WrongFieldsAdapter());
      final box = await Hive.openBox<_WrongFields>('audioClipBox');
      await box.add(_WrongFields());
      await box.close();
      Hive.resetAdapters();
      Hive.registerAdapter(LegacyAudioClipAdapter());
    }

    test('is flagged, not marked done, and the box is left alone', () async {
      await seedUnreadableBox();
      final before = boxFile.readAsBytesSync();

      await migrate();

      expect(repo.hasUnreadableData, isTrue);
      expect(prefs.getBool(legacyClipsMigratedKey), isNull);
      expect(repo.getAllClips(), isEmpty);
      expect(boxFile.readAsBytesSync(), equals(before));
    });

    test('a later success merges in, keeping what was imported meanwhile',
        () async {
      await seedUnreadableBox();
      await migrate();
      await repo.addClip(AudioClip('new.wav', 'new', 1, true));

      // The box has become readable, as with a file another instance had locked.
      await Hive.deleteBoxFromDisk('audioClipBox');
      await seedBox([LegacyAudioClip('old.wav', 'old', 1, true)]);
      final relaunched = await AudioClipRepository.open(libraryFile);
      await migrateLegacyClips(relaunched, prefs, boxDirectory: dir.path);

      expect(relaunched.getAllClips().map((c) => c.fileName),
          equals(['old.wav', 'new.wav']));
      expect(prefs.getBool(legacyClipsMigratedKey), isTrue);
      expect(relaunched.hasUnreadableData, isFalse);
    });
  });

  // Hive's default on a damaged box is to cut the file at the first bad frame
  // and open successfully, which would read here as a library with fewer clips.
  group('when the box is damaged', () {
    File damagedCopy() => File('${boxFile.path}.damaged');

    Future<void> seedThree() => seedBox([
          LegacyAudioClip('1.wav', 'a', 1, true),
          LegacyAudioClip('2.wav', 'b', 1, true),
          LegacyAudioClip('3.wav', 'c', 1, true),
        ]);

    test('a half-written last frame costs none of the good clips', () async {
      await seedThree();
      // What a crash mid-write leaves: a frame claiming more bytes than exist.
      boxFile.writeAsBytesSync([200, 0, 0, 0, 1, 2, 3], mode: FileMode.append);

      await migrate();

      expect(names(), equals(['1.wav', '2.wav', '3.wav']));
      expect(prefs.getBool(legacyClipsMigratedKey), isTrue);
    });

    test('the user is told, and the file is kept as it was', () async {
      await seedThree();
      boxFile.writeAsBytesSync([200, 0, 0, 0, 1, 2, 3], mode: FileMode.append);
      final before = boxFile.readAsBytesSync();

      await migrate();

      expect(repo.hasUnreadableData, isTrue);
      expect(damagedCopy().readAsBytesSync(), equals(before));
    });

    test('a bad frame in the middle keeps the clips before it, and the copy '
        'still holds the rest', () async {
      await seedThree();
      final bytes = boxFile.readAsBytesSync();
      final damaged = Uint8List.fromList(bytes);
      damaged[bytes.length * 2 ~/ 3] ^= 0xff;
      boxFile.writeAsBytesSync(damaged);

      await migrate();

      expect(names(), isNotEmpty);
      expect(names().length, lessThan(3));
      expect(repo.hasUnreadableData, isTrue);
      expect(damagedCopy().readAsBytesSync(), equals(damaged));
    });

    test('a file of garbage never counts as a quiet success', () async {
      boxFile.writeAsBytesSync(List.filled(64, 0xff));
      final before = boxFile.readAsBytesSync();

      await migrate();

      expect(repo.hasUnreadableData, isTrue);
      expect(repo.getAllClips(), isEmpty);
      expect(damagedCopy().readAsBytesSync(), equals(before));
    });

    test('an intact box makes no copy and raises no flag', () async {
      await seedThree();

      await migrate();

      expect(damagedCopy().existsSync(), isFalse);
      expect(repo.hasUnreadableData, isFalse);
    });

    test('if the copy cannot be made, the file is not repaired', () async {
      await seedThree();
      boxFile.writeAsBytesSync([200, 0, 0, 0, 1, 2, 3], mode: FileMode.append);
      final before = boxFile.readAsBytesSync();
      // A directory in the way makes the copy fail, and exists() is false for it.
      await Directory(damagedCopy().path).create();

      await migrate();

      expect(boxFile.readAsBytesSync(), equals(before));
      expect(prefs.getBool(legacyClipsMigratedKey), isNull);
      expect(repo.hasUnreadableData, isTrue);
    });
  });

  test('a library that cannot be saved is not marked done', () async {
    await seedBox([LegacyAudioClip('a.wav', 'a', 1, true)]);
    await Directory(libraryFile.path).create();

    await migrate();

    expect(repo.hasUnreadableData, isTrue);
    expect(prefs.getBool(legacyClipsMigratedKey), isNull);
    expect(boxFile.existsSync(), isTrue);
    expect(repo.getAllClips(), isEmpty);
  });
}

class _WrongFields {}

/// Writes under the real typeId, with a string where a number belongs.
class _WrongFieldsAdapter extends TypeAdapter<_WrongFields> {
  @override
  final int typeId = 0;

  @override
  _WrongFields read(BinaryReader reader) => _WrongFields();

  @override
  void write(BinaryWriter writer, _WrongFields obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(1)
      ..writeByte(1)
      ..write(2)
      ..writeByte(2)
      ..write('not a number')
      ..writeByte(3)
      ..write('not a bool');
  }
}
