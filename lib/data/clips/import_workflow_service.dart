import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:eq_trainer/data/import_player.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/data/clips/clip_encoder.dart';

class ImportWorkflowService {
  ImportWorkflowService({ClipEncoder? encoder})
      : _encoder = encoder ?? ClipEncoder();

  final ClipEncoder _encoder;

  /// Loads an audio file into [importPlayer] and returns its duration.
  ///
  /// No polling loop any more: SoLoud knows a source's length as soon as it is
  /// loaded, so [ImportPlayer.launch] already has it by the time it returns.
  /// A zero duration means the file decoded to nothing and there is nothing to
  /// trim, so it is an error rather than a "not ready yet" to wait out.
  Future<Duration> loadAudioFile({
    required ImportPlayer importPlayer,
    required String filePath,
    String? originalPath,
  }) async {
    importPlayer.originalPath = originalPath;
    await importPlayer.launch(
      path: filePath,
    );

    final duration = importPlayer.fetchDuration;
    if (duration == Duration.zero) {
      throw Exception('Audio file reported a zero duration: $filePath');
    }
    return duration;
  }

  /// Convert an audio file to [targetExt] in a temp directory, returning the
  /// path to the converted file.
  Future<String> convertTo({
    required String fileNameWithoutExt,
    required String sourcePath,
    required String targetExt,
  }) async {
    final Directory appTempDir = await getTemporaryDirectory();
    final Directory tempClipDir = await Directory(
      p.join(appTempDir.path, 'temp')
    ).create(recursive: true);
    final String newFilePath =
        p.join(tempClipDir.path, "$fileNameWithoutExt$targetExt");

    try {
      await _encoder.convertFile(
        sourcePath: sourcePath,
        destPath: newFilePath,
      );
    } catch (_) {
      // Never leave a half-written file behind for the importer to pick up as
      // if it were a finished conversion.
      final partial = File(newFilePath);
      if (partial.existsSync()) {
        try {
          partial.deleteSync();
        } catch (_) {
          // Best effort; the original error is the one worth reporting.
        }
      }
      rethrow;
    }

    return newFilePath;
  }
}
