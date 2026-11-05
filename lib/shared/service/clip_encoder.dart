import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/service/wav_pcm.dart';

/// Whether [error] means nothing on this platform can read the file, as opposed
/// to the conversion failing for some other reason. On Linux this is also what a
/// missing FFmpeg looks like.
bool isUnreadableAudioError(Object error) =>
    error is SoLoudOfflineDecodeCppException &&
    error.result == OfflineDecodeResult.unsupportedFormat;

/// Encodes clip files into the app's storage formats.
///
/// Decoding goes through SoLoud, which can also write the result: its offline
/// encoder takes float PCM and writes Ogg Opus, FLAC and WAV.
///
/// `audio_decoder` is only left as a fallback on Linux, where SoLoud reads M4A and
/// AAC through a system FFmpeg that may not be there. Elsewhere it reads nothing
/// SoLoud cannot, and falling back would bring back what it does to a file neither
/// can read: on a FiiO JM21, an ALAC M4A sometimes crashes the whole process
/// inside `MediaExtractor`, which Dart cannot catch.
class ClipEncoder {
  ClipEncoder({SoLoud? soloud, bool? platformCodecFallback})
      : _soloud = soloud ?? SoLoud.instance,
        _platformCodecFallback = platformCodecFallback ?? Platform.isLinux;

  final SoLoud _soloud;
  final bool _platformCodecFallback;

  /// Bitrate for Opus output, in bits per second.
  ///
  /// Deliberately generous. These clips are what someone trains their ears
  /// against, and a trim re-encodes an already-encoded source, so the codec
  /// must not be the thing they end up hearing.
  static const int opusBitrate = 192000;

  /// Decodes [sourcePath] and writes it to [destPath] in the format implied by
  /// [destPath]'s extension.
  ///
  /// Throws [SoLoudOfflineDecodeCppException] if the file cannot be read, and the
  /// caller's existing failure handling takes it from there.
  Future<void> convertFile({
    required String sourcePath,
    required String destPath,
  }) async {
    final DecodedPcm pcm;
    try {
      pcm = await _soloud.decodeFileToPcm(sourcePath);
    } on SoLoudOfflineDecodeCppException {
      if (!_platformCodecFallback) rethrow;
      await _convertThroughPlatformCodec(sourcePath, destPath);
      return;
    }
    await _soloud.encodePcmToFile(
      pcm.samples,
      destPath,
      sampleRate: pcm.sampleRate,
      channels: pcm.channels,
      format: _formatFor(p.extension(destPath).toLowerCase()),
      bitrate: opusBitrate,
    );
  }

  Future<void> _convertThroughPlatformCodec(
    String sourcePath,
    String destPath,
  ) async {
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
