import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_soloud/flutter_soloud.dart' show AndroidAudioBackend;
import 'package:eq_trainer/data/app_storage.dart';
import 'package:eq_trainer/data/legacy/legacy_audio_clip.dart';
import 'package:eq_trainer/data/legacy/setting_data.dart';
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';

import '../helpers/fake_output_devices.dart';

/// The order `openAppStorage` loads things in, and that it is wired to the
/// directory it was given. What each migration does in detail is tested beside
/// them, in test/data/legacy/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  Future<AppStorage> open({
    bool separateDebugData = false,
    bool? isAndroid,
  }) =>
      openAppStorage(
        dataDirectory: dir,
        separateDebugData: separateDebugData,
        devices: FakeOutputDevices(),
        isAndroid: isAndroid,
      );

  // Written the way older versions did. The names are spelled out because they
  // are what is on users' disks.
  Future<void> seedLegacy() async {
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(BackendDataAdapter().typeId)) {
      Hive.registerAdapter(BackendDataAdapter());
    }
    if (!Hive.isAdapterRegistered(MiscSettingsAdapter().typeId)) {
      Hive.registerAdapter(MiscSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(LegacyAudioClipAdapter().typeId)) {
      Hive.registerAdapter(LegacyAudioClipAdapter());
    }
    final backend = await Hive.openBox<BackendData>('backendBox');
    await backend.put('backendKey', BackendData(['aaudio']));
    await backend.close();
    final misc = await Hive.openBox<MiscSettings>('miscSettingsBox');
    await misc.put(
      'miscSettingsKey',
      MiscSettings(true, ImportFormat.allWav, false, themeMode: ThemeMode.dark.index),
    );
    await misc.close();
    final clips = await Hive.openBox<LegacyAudioClip>('audioClipBox');
    await clips.addAll([
      LegacyAudioClip('1000.flac', 'one.flac', 12.5, true),
      LegacyAudioClip('2000.wav', 'two.wav', 3, false),
    ]);
    await clips.close();
    await Hive.close();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('eqt_app_storage_');
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await Hive.close();
    SharedPreferences.resetStatic();
    await dir.delete(recursive: true);
  });

  test('a fresh install opens with defaults and an empty library in the directory',
      () async {
    final storage = await open();

    expect(storage.locale.locale, isNull);
    expect(storage.miscSettings.themeMode, ThemeMode.system);
    expect(storage.miscSettings.importFormat, ImportFormat.smart);
    expect(storage.clipLibrary.clips, isEmpty);
    expect(storage.clipRepository.hasUnreadableData, isFalse);

    await storage.clipRepository.addClip(AudioClip('5.wav', 'five.wav', 1, true));
    expect(File(p.join(dir.path, audioClipFileName)).existsSync(), isTrue);
  });

  test('the library resolves its clip files inside the injected directory',
      () async {
    final storage = await open();
    await storage.clipRepository.addClip(AudioClip('5.wav', 'five.wav', 1, true));
    final clipFile = File(p.join(dir.path, 'audioclip', '5.wav'))
      ..createSync(recursive: true);

    expect(await storage.clipLibrary.pathOf('5'), clipFile.path);
  });

  test('what comes back already holds the migrated settings and clips', () async {
    await seedLegacy();

    final storage = await open(isAndroid: true);

    expect(storage.miscSettings.themeMode, ThemeMode.dark);
    expect(storage.miscSettings.importFormat, ImportFormat.allWav);
    expect(storage.miscSettings.frequencyToolTip, isTrue);
    expect(storage.miscSettings.volumeCompensation, isFalse);
    // The one value read once at construction, so the one that proves the
    // settings migration ran before its reader was built.
    expect(storage.outputSelection.androidBackend, AndroidAudioBackend.aaudio);

    final names = storage.clipRepository.getAllClips().map((c) => c.fileName);
    expect(names, ['1000.flac', '2000.wav']);
    expect(storage.clipLibrary.clips.map((c) => c.id), ['1000', '2000']);
  });

  test('opening again after a first run sees the same library, not a second copy',
      () async {
    await seedLegacy();
    await open();
    await Hive.close();
    SharedPreferences.resetStatic();
    // Same on-disk preferences as the first run left, which the mock stands in for
    final prefs = await SharedPreferences.getInstance();
    final kept = {for (final k in prefs.getKeys()) k: prefs.get(k)!};
    SharedPreferences.setMockInitialValues(kept);

    final again = await open();

    expect(again.clipRepository.getAllClips().map((c) => c.fileName),
        ['1000.flac', '2000.wav']);
    expect(again.miscSettings.themeMode, ThemeMode.dark);
  });

  // Leaves the store holding only debug.-prefixed keys, then puts the prefix
  // back to the default, as it is when main() starts.
  void seedDebugStore(Map<String, Object> values) {
    SharedPreferences.setPrefix('debug.');
    SharedPreferences.setMockInitialValues(values);
    SharedPreferences.resetStatic();
  }

  test('separateDebugData reads and writes under the debug. prefix', () async {
    seedDebugStore({'locale': 'ko'});

    final storage = await open(separateDebugData: true);

    expect(storage.locale.locale, const Locale('ko'));
    storage.miscSettings.setImportFormat(ImportFormat.allWav);

    SharedPreferences.resetStatic();
    SharedPreferences.setPrefix('debug.');
    final written = await SharedPreferences.getInstance();
    expect(written.getInt('importFormat'), ImportFormat.allWav);
    SharedPreferences.resetStatic();
    final plain = await SharedPreferences.getInstance();
    expect(plain.getInt('importFormat'), isNull);
  });

  test('without separateDebugData the debug. keys are not seen', () async {
    seedDebugStore({'locale': 'ko'});

    final storage = await open();

    expect(storage.locale.locale, isNull);
  });
}
