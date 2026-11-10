import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/service/wav_pcm.dart';

/// Whether [error] means nothing on this platform can read the file, as opposed
/// to the conversion failing for some other reason. On Linux this is also what a
/// missing FFmpeg looks like. Covers both ways in: the offline decoder behind a
/// conversion or trim, and `loadFile`, which a file that skips conversion reaches
/// first.
bool isUnreadableAudioError(Object error) =>
    error is SoLoudFileLoadFailedException ||
    (error is SoLoudOfflineDecodeCppException &&
        error.result == OfflineDecodeResult.unsupportedFormat);

/// The offline encoder only takes mono and stereo.
///
/// Refused rather than mixed down: channel order depends on the decoder that
/// produced the PCM (Vorbis and Opus put centre second, WAV and FLAC third), so a
/// mixdown here could silently pan the wrong channels.
class UnsupportedChannelCountException implements Exception {
  const UnsupportedChannelCountException(this.channels);

  final int channels;

  @override
  String toString() => 'UnsupportedChannelCountException: $channels channels';
}

/// Encodes clip files into the app's storage formats.
///
/// Decoding goes through SoLoud, which can also write the result: its offline
/// encoder takes float PCM and writes Ogg Opus, FLAC and WAV.
class ClipEncoder {
  ClipEncoder({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;

  final SoLoud _soloud;

  /// Bitrate for Opus output, in bits per second.
  ///
  /// Deliberately generous. These clips are what someone trains their ears
  /// against, and a trim re-encodes an already-encoded source, so the codec
  /// must not be the thing they end up hearing.
  static const int opusBitrate = 192000;

  /// Writes [sourcePath] to [destPath] in the format implied by [destPath]'s
  /// extension.
  ///
  /// The audio goes straight from the decoder to the encoder, so a long file costs
  /// no more memory than a short one, except for formats that SoLoud decodes
  /// through a platform codec, which hold the whole file once.
  ///
  /// Throws [SoLoudOfflineDecodeCppException] if the file cannot be read, and
  /// [UnsupportedChannelCountException] if it has more than two channels. Nothing
  /// is left at [destPath] on failure.
  Future<void> convertFile({
    required String sourcePath,
    required String destPath,
  }) => _convert(sourcePath, destPath);

  /// Writes the range [start] to [end] of [sourcePath] to [destPath], in the
  /// format implied by [destPath]'s extension. Otherwise as [convertFile].
  ///
  /// An editor's untouched selection is the whole file, so this needs the same
  /// memory behaviour as [convertFile] and not just a small range's.
  Future<void> trimFile({
    required String sourcePath,
    required String destPath,
    required Duration start,
    required Duration end,
  }) => _convert(sourcePath, destPath, start: start, end: end);

  Future<void> _convert(
    String sourcePath,
    String destPath, {
    Duration start = Duration.zero,
    Duration? end,
  }) async {
    try {
      await _soloud.convertFile(
        sourcePath,
        destPath,
        format: _formatFor(p.extension(destPath).toLowerCase()),
        bitrate: opusBitrate,
        start: start,
        end: end,
      );
    } on SoLoudOfflineChannelCountCppException catch (e) {
      throw UnsupportedChannelCountException(e.channels);
    }
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
