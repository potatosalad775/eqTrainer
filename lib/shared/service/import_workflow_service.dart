import 'dart:async';
import 'dart:io';
import 'package:audio_decoder/audio_decoder.dart' as audio_decoder;
import 'package:path_provider/path_provider.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:path/path.dart' as p;

class ImportWorkflowService {
  const ImportWorkflowService();

  /// Loads an audio file into [importPlayer] and returns its duration.
  ///
  /// No polling loop any more: SoLoud knows a source's length as soon as it is
  /// loaded, so [ImportPlayer.launch] already has it by the time it returns.
  /// A zero duration means the file decoded to nothing and there is nothing to
  /// trim, so it is an error rather than a "not ready yet" to wait out.
  Future<Duration> loadAudioFile({
    required AudioState audioState,
    required ImportPlayer importPlayer,
    required String filePath,
  }) async {
    await importPlayer.launch(
      androidBackend: audioState.androidBackend,
      outputDevice: audioState.outputDevice,
      path: filePath,
    );

    final duration = importPlayer.fetchDuration;
    if (duration == Duration.zero) {
      throw Exception('Audio file reported a zero duration: $filePath');
    }
    return duration;
  }

  /// Convert an audio file to WAV in a temp directory.
  /// Returns the path to the converted file.
  ///
  /// WAV is the only conversion target: SoLoud plays it natively as a raw PCM
  /// stream, and it avoids the generation loss of re-encoding a lossy source
  /// into AAC the way the retired m4a path did.
  Future<String> convertToWav({
    required String fileNameWithoutExt,
    required String sourcePath,
  }) async {
    final Directory appTempDir = await getTemporaryDirectory();
    final Directory tempClipDir = await Directory(
      p.join(appTempDir.path, 'temp')
    ).create(recursive: true);
    final String newFilePath = p.join(tempClipDir.path, "$fileNameWithoutExt.wav");

    await audio_decoder.AudioDecoder.convertToWav(sourcePath, newFilePath);
    return newFilePath;
  }
}
