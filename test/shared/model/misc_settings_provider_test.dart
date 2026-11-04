import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Re-reads from the store rather than the in-memory cache a set just updated.
  Future<SharedPreferences> stored() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  group('MiscSettingsProvider', () {
    test('defaults match fresh-install values when nothing is stored', () async {
      final provider = await MiscSettingsProvider.load();
      expect(provider.frequencyToolTip, isFalse);
      // A fresh install starts on Smart. It used to start on the retired
      // allM4a ordinal, which read as Smart anyway.
      expect(provider.importFormat, equals(ImportFormat.smart));
      expect(provider.volumeCompensation, isTrue);
      expect(provider.themeMode, equals(ThemeMode.system));
    });

    test('loads a previously persisted value instead of defaults', () async {
      SharedPreferences.setMockInitialValues({
        MiscSettingsProvider.frequencyToolTipKey: true,
        MiscSettingsProvider.importFormatKey: ImportFormat.allWav,
        MiscSettingsProvider.volumeCompensationKey: false,
        MiscSettingsProvider.themeModeKey: ThemeMode.dark.index,
      });

      final provider = await MiscSettingsProvider.load();
      expect(provider.frequencyToolTip, isTrue);
      expect(provider.importFormat, equals(ImportFormat.allWav));
      expect(provider.volumeCompensation, isFalse);
      expect(provider.themeMode, equals(ThemeMode.dark));
    });

    test('setFrequencyToolTip updates value, persists it and notifies', () async {
      final provider = await MiscSettingsProvider.load();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.setFrequencyToolTip(true);

      expect(provider.frequencyToolTip, isTrue);
      expect(notified, isTrue);
      expect((await stored()).getBool(MiscSettingsProvider.frequencyToolTipKey), isTrue);
    });

    test('setImportFormat updates value and persists it', () async {
      final provider = await MiscSettingsProvider.load();
      provider.setImportFormat(ImportFormat.allOpus);

      expect(provider.importFormat, equals(ImportFormat.allOpus));
      expect(
        (await stored()).getInt(MiscSettingsProvider.importFormatKey),
        equals(ImportFormat.allOpus),
      );
    });

    test('setVolumeCompensation updates value and persists it', () async {
      final provider = await MiscSettingsProvider.load();
      provider.setVolumeCompensation(false);

      expect(provider.volumeCompensation, isFalse);
      expect((await stored()).getBool(MiscSettingsProvider.volumeCompensationKey), isFalse);
    });

    test('setThemeMode updates value and persists it', () async {
      final provider = await MiscSettingsProvider.load();
      provider.setThemeMode(ThemeMode.light);

      expect(provider.themeMode, equals(ThemeMode.light));
      expect(
        (await stored()).getInt(MiscSettingsProvider.themeModeKey),
        equals(ThemeMode.light.index),
      );
    });

    test('changing one setting does not clobber other persisted settings', () async {
      final provider = await MiscSettingsProvider.load();
      provider.setFrequencyToolTip(true);
      provider.setVolumeCompensation(false);

      expect(provider.frequencyToolTip, isTrue);
      expect(provider.volumeCompensation, isFalse);
      expect(provider.importFormat, equals(ImportFormat.smart));
    });

    test('migrates a retired import-format ordinal on load', () async {
      SharedPreferences.setMockInitialValues({
        MiscSettingsProvider.importFormatKey: ImportFormat.allM4a,
      });

      final provider = await MiscSettingsProvider.load();
      expect(provider.importFormat, equals(ImportFormat.smart));

      // Rewritten in the store, not merely normalized on read, so the settings
      // UI never has to display a value it has no item for.
      expect(
        (await stored()).getInt(MiscSettingsProvider.importFormatKey),
        equals(ImportFormat.smart),
      );
    });

    test('migrates keepOriginal the same way', () async {
      SharedPreferences.setMockInitialValues({
        MiscSettingsProvider.importFormatKey: ImportFormat.keepOriginal,
      });
      final provider = await MiscSettingsProvider.load();
      expect(provider.importFormat, equals(ImportFormat.smart));
    });

    test('leaves a still-supported stored value untouched', () async {
      for (final format in ImportFormat.selectable) {
        SharedPreferences.setMockInitialValues({
          MiscSettingsProvider.importFormatKey: format,
        });
        final provider = await MiscSettingsProvider.load();
        expect(provider.importFormat, equals(format));
      }
    });

    group('toggleTheme', () {
      test('system -> light', () async {
        final provider = await MiscSettingsProvider.load();
        expect(provider.themeMode, equals(ThemeMode.system));
        provider.toggleTheme();
        expect(provider.themeMode, equals(ThemeMode.light));
      });

      test('light -> dark', () async {
        final provider = await MiscSettingsProvider.load();
        provider.setThemeMode(ThemeMode.light);
        provider.toggleTheme();
        expect(provider.themeMode, equals(ThemeMode.dark));
      });

      test('dark -> system', () async {
        final provider = await MiscSettingsProvider.load();
        provider.setThemeMode(ThemeMode.dark);
        provider.toggleTheme();
        expect(provider.themeMode, equals(ThemeMode.system));
      });
    });
  });
}
