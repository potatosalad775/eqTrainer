import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// AppDirectories centralizes filesystem paths used by the app.
/// It lazily resolves and creates necessary directories.
class AppDirectories {
  Directory? _appSupportDir;
  Directory? _clipsDir;

  /// Returns the application support directory (platform-specific safe location).
  Future<Directory> getAppSupportDir() async {
    if (_appSupportDir != null) return _appSupportDir!;
    _appSupportDir = await getApplicationSupportDirectory();
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

