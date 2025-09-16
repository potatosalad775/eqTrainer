import 'dart:async';
import 'dart:io';
import 'package:coast_audio/coast_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/player/import_player.dart';

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

  /// Convert an unsupported audio file to flac in a temp directory.
  /// Returns the path to the converted file.
  Future<String> convertToFlac({
    required String fileNameWithoutExt,
    required String sourcePath,
  }) async {
    final Directory appTempDir = await getTemporaryDirectory();
    final Directory tempClipDir = await Directory(
      "${appTempDir.path}${Platform.pathSeparator}temp",
    ).create(recursive: true);
    final String newFilePath =
        "${tempClipDir.path}${Platform.pathSeparator}$fileNameWithoutExt.flac";

    final String cmd = "-y -vn -i $sourcePath -c:a flac $newFilePath";
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final failStack = await session.getFailStackTrace();
      throw Exception('FFmpeg convert failed: $failStack');
    }
    return newFilePath;
  }
}