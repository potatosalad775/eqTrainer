import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('misc_settings_test_');
    Hive.init(tmpDir.path);
    if (!Hive.isAdapterRegistered(MiscSettingsAdapter().typeId)) {
      Hive.registerAdapter(MiscSettingsAdapter());
    }
    await Hive.openBox<MiscSettings>(miscSettingsBoxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tmpDir.delete(recursive: true);
  });

  group('MiscSettingsProvider', () {
    test('defaults match fresh-install values when box is empty', () {
      final provider = MiscSettingsProvider();
      expect(provider.frequencyToolTip, isFalse);
      expect(provider.importFormat, equals(ImportFormat.allM4a));
      expect(provider.volumeCompensation, isTrue);
      expect(provider.themeMode, equals(ThemeMode.system));
    });

    test('loads a previously persisted value instead of defaults', () async {
      await Hive.box<MiscSettings>(miscSettingsBoxName).put(
        miscSettingsKey,
        MiscSettings(true, ImportFormat.allWav, false, themeMode: ThemeMode.dark.index),
      );

      final provider = MiscSettingsProvider();
      expect(provider.frequencyToolTip, isTrue);
      expect(provider.importFormat, equals(ImportFormat.allWav));
      expect(provider.volumeCompensation, isFalse);
      expect(provider.themeMode, equals(ThemeMode.dark));
    });

    test('setFrequencyToolTip updates value, persists it and notifies', () {
      final provider = MiscSettingsProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.setFrequencyToolTip(true);

      expect(provider.frequencyToolTip, isTrue);
      expect(notified, isTrue);
      expect(
        Hive.box<MiscSettings>(miscSettingsBoxName).get(miscSettingsKey)!.frequencyToolTip,
        isTrue,
      );
    });

    test('setImportFormat updates value and persists it', () {
      final provider = MiscSettingsProvider();
      provider.setImportFormat(ImportFormat.keepOriginal);

      expect(provider.importFormat, equals(ImportFormat.keepOriginal));
      expect(
        Hive.box<MiscSettings>(miscSettingsBoxName).get(miscSettingsKey)!.importFormat,
        equals(ImportFormat.keepOriginal),
      );
    });

    test('setVolumeCompensation updates value and persists it', () {
      final provider = MiscSettingsProvider();
      provider.setVolumeCompensation(false);

      expect(provider.volumeCompensation, isFalse);
      expect(
        Hive.box<MiscSettings>(miscSettingsBoxName).get(miscSettingsKey)!.volumeCompensation,
        isFalse,
      );
    });

    test('setThemeMode updates value and persists it', () {
      final provider = MiscSettingsProvider();
      provider.setThemeMode(ThemeMode.light);

      expect(provider.themeMode, equals(ThemeMode.light));
      expect(
        Hive.box<MiscSettings>(miscSettingsBoxName).get(miscSettingsKey)!.themeMode,
        equals(ThemeMode.light.index),
      );
    });

    test('changing one setting does not clobber other persisted settings', () {
      final provider = MiscSettingsProvider();
      provider.setFrequencyToolTip(true);
      provider.setVolumeCompensation(false);

      expect(provider.frequencyToolTip, isTrue);
      expect(provider.volumeCompensation, isFalse);
      expect(provider.importFormat, equals(ImportFormat.allM4a));
    });

    group('toggleTheme', () {
      test('system -> light', () {
        final provider = MiscSettingsProvider();
        expect(provider.themeMode, equals(ThemeMode.system));
        provider.toggleTheme();
        expect(provider.themeMode, equals(ThemeMode.light));
      });

      test('light -> dark', () {
        final provider = MiscSettingsProvider();
        provider.setThemeMode(ThemeMode.light);
        provider.toggleTheme();
        expect(provider.themeMode, equals(ThemeMode.dark));
      });

      test('dark -> system', () {
        final provider = MiscSettingsProvider();
        provider.setThemeMode(ThemeMode.dark);
        provider.toggleTheme();
        expect(provider.themeMode, equals(ThemeMode.system));
      });
    });
  });
}
