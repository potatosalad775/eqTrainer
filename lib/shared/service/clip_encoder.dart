import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/service/wav_pcm.dart';

/// Encodes clip files into the app's storage formats.
///
/// A trim decodes through SoLoud, which can also write the result: its offline
/// encoder takes float PCM and writes Ogg Opus, FLAC and WAV.
///
/// A foreign import still goes through `audio_decoder`, which reaches platform
/// codecs and emits WAV: platform decode to WAV bytes, parse to float PCM, encode
/// to the target. WAV targets skip the last step, since the bytes are already
/// what we want.
class ClipEncoder {
  ClipEncoder({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;

  final SoLoud _soloud;

  /// Bitrate for Opus output, in bits per second.
  ///
  /// Deliberately generous. These clips are what someone trains their ears
  /// against, and a trim re-encodes an already-encoded source, so the codec
  /// must not be the thing they end up hearing.
  static const int opusBitrate = 192000;

  /// Decodes [sourcePath] and writes it to [destPath] in the format implied by
  /// [destPath]'s extension.
  ///
  /// [formatHint] is the source extension without the dot, which the platform
  /// decoders need when the container is ambiguous.
  Future<void> convertFile({
    required String sourcePath,
    required String destPath,
  }) async {
    final sourceExt = p.extension(sourcePath).toLowerCase();
    final wavBytes = await AudioDecoder.convertToWavBytes(
      await File(sourcePath).readAsBytes(),
      formatHint: sourceExt.replaceFirst('.', ''),
    );
    await encodeWavBytes(wavBytes: wavBytes, destPath: destPath);
  }

  /// Writes the range [start] to [end] of [sourcePath] to [destPath], in the
  /// format implied by [destPath]'s extension.
  ///
  /// Only the range is held in memory, except for formats that SoLoud decodes
  /// through a platform codec, which hold the whole file while decoding.
  Future<void> trimFile({
    required String sourcePath,
    required String destPath,
    required Duration start,
    required Duration end,
  }) async {
    final pcm = await _soloud.decodeFileToPcm(
      sourcePath,
      start: start,
      end: end,
    );
    await _soloud.encodePcmToFile(
      pcm.samples,
      destPath,
      sampleRate: pcm.sampleRate,
      channels: pcm.channels,
      format: _formatFor(p.extension(destPath).toLowerCase()),
      bitrate: opusBitrate,
    );
  }

  /// Writes already-decoded [wavBytes] to [destPath] in the target format.
  ///
  /// A `.wav` target is written straight through: re-encoding WAV to WAV would
  /// only requantize it for nothing.
  Future<void> encodeWavBytes({
    required Uint8List wavBytes,
    required String destPath,
  }) async {
    final targetExt = p.extension(destPath).toLowerCase();

    if (targetExt == '.wav') {
      await File(destPath).writeAsBytes(wavBytes, flush: true);
      return;
    }

    final pcm = parseWav(wavBytes);
    if (pcm.samples.isEmpty) {
      throw const WavParseException('decoded audio is empty');
    }

    await _soloud.encodePcmToFile(
      pcm.samples,
      destPath,
      sampleRate: pcm.sampleRate,
      channels: pcm.channels,
      format: _formatFor(targetExt),
      bitrate: opusBitrate,
    );
  }

  static MixerOutputFormat _formatFor(String ext) {
    switch (ext) {
      case '.opus':
        return MixerOutputFormat.opus;
      case '.flac':
        return MixerOutputFormat.flac;
      case '.ogg':
      case '.oga':
        return MixerOutputFormat.vorbis;
      case '.wav':
        return MixerOutputFormat.wav;
      default:
        throw ArgumentError('no encoder for target extension "$ext"');
    }
  }
}
