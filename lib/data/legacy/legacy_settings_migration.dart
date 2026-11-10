import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/data/legacy/setting_data.dart';

const String _backendBoxName = 'backendBox';
const String _backendKey = 'backendKey';
const String _miscSettingsBoxName = 'miscSettingsBox';
const String _miscSettingsKey = 'miscSettingsKey';

@visibleForTesting
const String legacySettingsMigratedKey = 'legacySettingsMigrated';

/// Moves settings out of the two Hive boxes they used to live in.
///
/// Must finish before anything reads the settings, so `main()` awaits it. That
/// also means the user cannot have changed anything yet, so a run that died
/// halfway can simply start over. The boxes are only deleted once the marker
/// is written; until then a failed run loses nothing and retries next launch.
///
/// An unreadable box counts as an empty one. The app used to recreate these
/// boxes in that case, so a corrupt settings file already meant defaults.
///
/// Never throws: a settings migration must not stop the app from starting.
Future<void> migrateLegacySettings(SharedPreferences prefs) async {
  if (prefs.getBool(legacySettingsMigratedKey) ?? false) return;

  try {
    if (!Hive.isAdapterRegistered(BackendDataAdapter().typeId)) {
      Hive.registerAdapter(BackendDataAdapter());
    }
    if (!Hive.isAdapterRegistered(MiscSettingsAdapter().typeId)) {
      Hive.registerAdapter(MiscSettingsAdapter());
    }

    final backend = await _readAndClose<BackendData>(_backendBoxName, _backendKey);
    final misc = await _readAndClose<MiscSettings>(_miscSettingsBoxName, _miscSettingsKey);

    final writes = await Future.wait([
      if (backend != null)
        saveAndroidBackend(prefs, androidBackendFromLegacyList(backend.backendList)),
      if (misc != null) ...[
        prefs.setBool(MiscSettingsProvider.frequencyToolTipKey, misc.frequencyToolTip),
        prefs.setInt(MiscSettingsProvider.importFormatKey, misc.importFormat),
        prefs.setBool(MiscSettingsProvider.volumeCompensationKey, misc.volumeCompensation),
        prefs.setInt(MiscSettingsProvider.themeModeKey, misc.themeMode),
      ],
    ]);
    if (writes.contains(false)) return;
    if (!await prefs.setBool(legacySettingsMigratedKey, true)) return;
  } catch (e) {
    debugPrint('[Settings] Legacy migration failed ($e); retrying next launch.');
    return;
  }

  // The settings are safe by now, so a leftover file is only untidy.
  for (final name in [_backendBoxName, _miscSettingsBoxName]) {
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (e) {
      debugPrint('[Settings] Could not delete legacy box "$name" ($e).');
    }
  }
}

Future<T?> _readAndClose<T>(String boxName, String key) async {
  try {
    final box = await Hive.openBox<T>(boxName);
    final value = box.get(key);
    await box.close();
    return value;
  } catch (e) {
    debugPrint('[Settings] Legacy box "$boxName" failed to open ($e).');
    return null;
  }
}

/// Reads the Android backend choice out of the saved coast_audio backend list.
///
/// Only two of those lists mean anything now: a user who deliberately enabled
/// AAudio *and* turned OpenSL ES off keeps AAudio, and `auto` is what the
/// settings page wrote after coast_audio. Everyone else gets OpenSL ES, for the
/// reason given on [androidBackendFromName]. A wrong answer here silently moves
/// the Digital Audio Players that override exists for back onto AAudio.
@visibleForTesting
AndroidAudioBackend androidBackendFromLegacyList(List<String> backendList) {
  if (backendList.contains('auto')) return AndroidAudioBackend.auto;
  if (backendList.contains('aaudio') && !backendList.contains('openSLES')) {
    return AndroidAudioBackend.aaudio;
  }
  return AndroidAudioBackend.openSles;
}
