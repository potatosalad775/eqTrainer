import 'dart:async';
import 'dart:io';
import 'package:audio_decoder/audio_decoder.dart' as audio_decoder;
import 'package:path_provider/path_provider.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/service/clip_encoder.dart';

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

  /// Convert an audio file to [targetExt] in a temp directory, returning the
  /// path to the converted file.
  ///
  /// WAV goes through audio_decoder directly, since that is what it already
  /// writes. Every other target is decoded to WAV bytes first and then handed
  /// to the offline encoder — audio_decoder is the only thing that can open a
  /// foreign container, and the encoder is the only thing that can write Opus
  /// or FLAC, so both are needed and neither can be skipped.
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
      if (targetExt == '.wav') {
        await audio_decoder.AudioDecoder.convertToWav(sourcePath, newFilePath);
      } else {
        await _encoder.convertFile(
          sourcePath: sourcePath,
          destPath: newFilePath,
        );
      }
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
