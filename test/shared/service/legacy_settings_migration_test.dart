import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/service/legacy_settings_migration.dart';

class _MockPrefs extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late SharedPreferences prefs;

  // The box and key names are spelled out rather than shared with the
  // implementation: they are what older versions wrote, and must not change.
  Future<void> seedBackend(List<String> list) async {
    final box = await Hive.openBox<BackendData>('backendBox');
    await box.put('backendKey', BackendData(list));
    await box.close();
  }

  Future<void> seedMisc(MiscSettings settings) async {
    final box = await Hive.openBox<MiscSettings>('miscSettingsBox');
    await box.put('miscSettingsKey', settings);
    await box.close();
  }

  File boxFile(String name) => File(p.join(dir.path, '$name.hive'));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('eqt_legacy_settings_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(BackendDataAdapter().typeId)) {
      Hive.registerAdapter(BackendDataAdapter());
    }
    if (!Hive.isAdapterRegistered(MiscSettingsAdapter().typeId)) {
      Hive.registerAdapter(MiscSettingsAdapter());
    }
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('carries every misc setting across', () async {
    await seedMisc(MiscSettings(true, ImportFormat.allWav, false, themeMode: ThemeMode.dark.index));

    await migrateLegacySettings(prefs);

    final provider = await MiscSettingsProvider.load();
    expect(provider.frequencyToolTip, isTrue);
    expect(provider.importFormat, equals(ImportFormat.allWav));
    expect(provider.volumeCompensation, isFalse);
    expect(provider.themeMode, equals(ThemeMode.dark));
  });

  test('a retired import format comes across and is normalized on load', () async {
    await seedMisc(MiscSettings(false, ImportFormat.allM4a, true));

    await migrateLegacySettings(prefs);

    final provider = await MiscSettingsProvider.load();
    expect(provider.importFormat, equals(ImportFormat.smart));
  });

  test('carries the Android backend across', () async {
    await seedBackend(['aaudio']);

    await migrateLegacySettings(prefs);

    expect(androidBackendFromName(prefs.getString('androidBackend')),
        equals(AndroidAudioBackend.aaudio));
  });

  test('a fresh install stores nothing, so the defaults apply', () async {
    await migrateLegacySettings(prefs);

    expect(prefs.getKeys(), equals({legacySettingsMigratedKey}));
    final provider = await MiscSettingsProvider.load();
    expect(provider.volumeCompensation, isTrue);
    expect(provider.themeMode, equals(ThemeMode.system));
  });

  test('deletes the old boxes once the settings are across', () async {
    await seedBackend(['openSLES']);
    await seedMisc(MiscSettings(false, ImportFormat.smart, true));
    expect(boxFile('backendbox').existsSync(), isTrue);
    expect(boxFile('miscsettingsbox').existsSync(), isTrue);

    await migrateLegacySettings(prefs);

    expect(boxFile('backendbox').existsSync(), isFalse);
    expect(boxFile('miscsettingsbox').existsSync(), isFalse);
  });

  test('runs once, and never overwrites a later change', () async {
    await seedMisc(MiscSettings(false, ImportFormat.smart, true));
    await migrateLegacySettings(prefs);
    await prefs.setBool(MiscSettingsProvider.volumeCompensationKey, false);

    // A box reappearing, e.g. after a downgrade and upgrade, must be ignored.
    await seedMisc(MiscSettings(true, ImportFormat.allOpus, true));
    await migrateLegacySettings(prefs);

    expect(prefs.getBool(MiscSettingsProvider.volumeCompensationKey), isFalse);
    expect(prefs.getBool(MiscSettingsProvider.frequencyToolTipKey), isFalse);
  });

  test('an unreadable box means defaults, not a failed startup', () async {
    await boxFile('miscsettingsbox').writeAsBytes(List.filled(64, 0xff));
    await seedBackend(['aaudio']);

    await migrateLegacySettings(prefs);

    expect(prefs.getBool(legacySettingsMigratedKey), isTrue);
    expect(androidBackendFromName(prefs.getString('androidBackend')),
        equals(AndroidAudioBackend.aaudio));
    final provider = await MiscSettingsProvider.load();
    expect(provider.volumeCompensation, isTrue);
  });

  group('when the new store rejects a write', () {
    late _MockPrefs failing;

    setUp(() {
      failing = _MockPrefs();
      when(() => failing.getBool(any())).thenReturn(null);
      when(() => failing.setBool(any(), any())).thenAnswer((_) async => true);
      when(() => failing.setInt(any(), any())).thenAnswer((_) async => true);
      when(() => failing.setString(any(), any())).thenAnswer((_) async => false);
    });

    test('keeps the boxes and leaves the migration to retry', () async {
      await seedBackend(['aaudio']);
      await seedMisc(MiscSettings(true, ImportFormat.smart, true));

      await migrateLegacySettings(failing);

      verifyNever(() => failing.setBool(legacySettingsMigratedKey, any()));
      expect(boxFile('backendbox').existsSync(), isTrue);
      expect(boxFile('miscsettingsbox').existsSync(), isTrue);
    });

    test('does not throw when a write fails outright', () async {
      when(() => failing.setString(any(), any())).thenThrow(Exception('disk full'));
      await seedBackend(['aaudio']);

      await expectLater(migrateLegacySettings(failing), completes);

      expect(boxFile('backendbox').existsSync(), isTrue);
    });
  });

  // eqTrainer has always pinned Android to OpenSL ES. Reading an existing
  // user's list wrong does not fail loudly: it just puts Digital Audio Players
  // back on the AAudio backend they glitch on.
  group('androidBackendFromLegacyList', () {
    test('an empty list gets OpenSL ES', () {
      expect(androidBackendFromLegacyList([]), equals(AndroidAudioBackend.openSles));
    });

    test('the shipped Android default list gets OpenSL ES', () {
      expect(androidBackendFromLegacyList(['openSLES']),
          equals(AndroidAudioBackend.openSles));
    });

    test('a deliberate AAudio-only opt-in is preserved', () {
      expect(androidBackendFromLegacyList(['aaudio']),
          equals(AndroidAudioBackend.aaudio));
    });

    test('AAudio merely enabled alongside OpenSL ES is not an opt-in', () {
      // coast_audio took the first backend that initialized, so this user was
      // on whichever won — not necessarily AAudio. OpenSL ES is the safe read.
      expect(androidBackendFromLegacyList(['aaudio', 'openSLES']),
          equals(AndroidAudioBackend.openSles));
    });

    test('an explicit auto is preserved', () {
      expect(androidBackendFromLegacyList(['auto']),
          equals(AndroidAudioBackend.auto));
    });

    test('an unrelated legacy list (desktop backends) falls back to OpenSL ES', () {
      expect(androidBackendFromLegacyList(['wasapi', 'dummy']),
          equals(AndroidAudioBackend.openSles));
    });
  });
}
