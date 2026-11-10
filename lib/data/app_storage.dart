import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/app_directories.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/data/legacy/legacy_clip_migration.dart';
import 'package:eq_trainer/data/legacy/legacy_settings_migration.dart';
import 'package:eq_trainer/data/locale_provider.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/data/output_selection.dart';

/// The clip library's file inside the data directory.
const String audioClipFileName = "audio_clips.json";

/// Everything loaded from disk before the app starts, in the one order that works.
class AppStorage {
  const AppStorage({
    required this.locale,
    required this.miscSettings,
    required this.outputSelection,
    required this.clipRepository,
    required this.clipLibrary,
  });

  final LocaleProvider locale;
  final MiscSettingsProvider miscSettings;
  final OutputSelection outputSelection;
  final AudioClipRepository clipRepository;
  final ClipLibrary clipLibrary;
}

/// Opens the app's storage and migrates what older versions kept in Hive.
///
/// [dataDirectory], [separateDebugData] and [devices] are for tests; each
/// defaults to the real platform.
Future<AppStorage> openAppStorage({
  Directory? dataDirectory,
  bool? separateDebugData,
  OutputDevices? devices,
}) async {
  // Everything below lives in, or is keyed to, this directory
  final dir = dataDirectory ?? await resolveAppDataDir();

  // shared_preferences has one file per app, so debug gets its own keys instead.
  // Must come before the first getInstance.
  if (separateDebugData ?? usesSeparateDebugData) {
    SharedPreferences.setPrefix('debug.');
  }

  // Load Hive - only ever read now, to migrate what older versions stored in it.
  // Must come before either migration opens a box.
  await Hive.initFlutter(dir.path);

  // Load Settings - older versions kept these in Hive, so move them first.
  // Must come before the three below read them: it writes what they read,
  // including the Android backend.
  final prefs = await SharedPreferences.getInstance();
  await migrateLegacySettings(prefs);
  final locale = await LocaleProvider.load();
  final miscSettings = await MiscSettingsProvider.load();

  // The one instance everything shares: the engine reads it at each launch
  final outputSelection = OutputSelection(prefs: prefs, devices: devices);

  // Load Playlist Data - the one instance everything shares, see AudioClipRepository
  final clipRepository = await AudioClipRepository.open(
    File(p.join(dir.path, audioClipFileName)),
  );
  // Must come before anything uses the library: it fills the repository
  await migrateLegacyClips(clipRepository, prefs, boxDirectory: dir.path);
  // Records and files together, over that one repository
  final clipLibrary = ClipLibrary(
    clipRepository,
    AppDirectories(dataDirectory: dir),
  );

  return AppStorage(
    locale: locale,
    miscSettings: miscSettings,
    outputSelection: outputSelection,
    clipRepository: clipRepository,
    clipLibrary: clipLibrary,
  );
}
