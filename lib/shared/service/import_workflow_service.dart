import 'dart:async';
import 'dart:io';
import 'package:audio_decoder/audio_decoder.dart' as audio_decoder;
import 'package:coast_audio/coast_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:path/path.dart' as p;

class ImportWorkflowService {
  const ImportWorkflowService();

  /// Load audio file into ImportPlayer and wait until duration is available.
  /// Throws TimeoutException on timeout, other errors as Exception.
  Future<AudioTime> loadAudioFile({
    required AudioState audioState,
    required ImportPlayer importPlayer,
    required String filePath,
    Duration pollInterval = const Duration(milliseconds: 100),
    int maxAttempts = 50,
  }) async {
    await importPlayer.launch(
      backend: audioState.backend,
      outputDeviceId: audioState.outputDevice?.id,
      path: filePath,
    );
    importPlayer.filePath = filePath;

    AudioTime? duration;
    int attempts = 0;
    while (duration == null || duration == AudioTime.zero) {
      duration = await importPlayer.getDuration();
      if (duration != null && duration != AudioTime.zero) break;
      await Future.delayed(pollInterval);
      attempts++;
      if (attempts >= maxAttempts) {
        throw TimeoutException('Failed to get audio duration after $maxAttempts attempts');
      }
    }

    return duration;
  }

  /// Convert an unsupported audio file to WAV in a temp directory.
  /// Returns the path to the converted file.
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
