import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Whether this build keeps all its data apart from an installed copy's.
///
/// The single-instance guard is release-only, so on desktop a debug run can sit
/// beside an open release copy. Sharing data would let them overwrite each
/// other's library. It would also let a debug run consume release data for good:
/// the legacy migrations delete boxes and record that they ran, and the format
/// migration deletes clip files. Mobile runs one copy at a time, and testing an
/// upgrade there relies on a debug build finding the existing data.
bool get usesSeparateDebugData =>
    kDebugMode && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Where the app's data lives inside the platform's [supportPath].
@visibleForTesting
String appDataPath(String supportPath) =>
    usesSeparateDebugData ? p.join(supportPath, 'debug') : supportPath;

/// The directory holding all of the app's files, created if needed.
Future<Directory> resolveAppDataDir() async {
  final support = await getApplicationSupportDirectory();
  return Directory(appDataPath(support.path)).create(recursive: true);
}

/// AppDirectories centralizes filesystem paths used by the app.
/// It lazily resolves and creates necessary directories.
class AppDirectories {
  Directory? _appSupportDir;
  Directory? _clipsDir;

  /// Returns the application support directory (platform-specific safe location).
  Future<Directory> getAppSupportDir() async {
    if (_appSupportDir != null) return _appSupportDir!;
    _appSupportDir = await resolveAppDataDir();
    return _appSupportDir!;
  }

  /// Returns the directory that stores imported audio clips, creating it if needed.
  Future<Directory> getClipsDir() async {
    if (_clipsDir != null) return _clipsDir!;
    final base = await getAppSupportDir();
    final clipsPath = p.join(base.path, 'audioclip');
    _clipsDir = await Directory(clipsPath).create(recursive: true);
    return _clipsDir!;
  }

  /// Convenience: returns the absolute path of the clips directory.
  Future<String> getClipsPath() async => (await getClipsDir()).path;
}

