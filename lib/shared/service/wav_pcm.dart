import 'dart:typed_data';

/// Interleaved float PCM plus the format it came in, as read from a RIFF/WAVE
/// buffer.
class WavPcm {
  const WavPcm({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });

  /// Interleaved samples in [-1.0, 1.0].
  final Float32List samples;

  final int sampleRate;
  final int channels;

  /// Number of frames, i.e. samples per channel.
  int get frameCount => channels == 0 ? 0 : samples.length ~/ channels;
}

/// Thrown when a buffer is not WAV, or is a WAV this app cannot read.
class WavParseException implements Exception {
  const WavParseException(this.message);

  final String message;

  @override
  String toString() => 'WavParseException: $message';
}

/// Parses a RIFF/WAVE buffer into interleaved float PCM.
///
/// This exists because the offline encoder takes float PCM, while
/// `audio_decoder` hands back WAV bytes — so every foreign-format import and
/// every trim that targets FLAC or Opus has to cross that gap.
///
/// Chunks are walked rather than assumed to sit at fixed offsets: real files
/// carry `LIST`/`fact`/`bext` chunks before `data`, and the 44-byte layout is
/// only the simplest case. Supports 8/16/24/32-bit integer and 32/64-bit float
/// PCM, which covers everything the platform decoders emit.
WavPcm parseWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);

  if (bytes.length < 12) {
    throw const WavParseException('buffer is too short to be a WAV');
  }
  if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
    throw const WavParseException('missing RIFF/WAVE header');
  }

  int? format;
  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  int? dataStart;
  int? dataLength;

  // Walk the chunk list. Chunks are word-aligned, so an odd size is followed
  // by a pad byte that is not counted in the size field.
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(bytes, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;

    if (id == 'fmt ') {
      if (body + 16 > bytes.length) {
        throw const WavParseException('truncated fmt chunk');
      }
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bitsPerSample = data.getUint16(body + 14, Endian.little);

      // WAVE_FORMAT_EXTENSIBLE keeps the real format in its subformat GUID,
      // whose first two bytes are the format tag.
      if (format == 0xFFFE && body + 26 <= bytes.length) {
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      dataStart = body;
      // A streamed WAV can carry a placeholder size; trust the buffer instead.
      final available = bytes.length - body;
      dataLength = size == 0 || size > available ? available : size;
    }

    offset = body + size + (size.isOdd ? 1 : 0);
  }

  if (format == null || channels == null || sampleRate == null ||
      bitsPerSample == null) {
    throw const WavParseException('no fmt chunk');
  }
  if (dataStart == null || dataLength == null || dataLength <= 0) {
    throw const WavParseException('no data chunk');
  }
  if (channels < 1) {
    throw WavParseException('invalid channel count: $channels');
  }

  const wavFormatPcm = 1;
  const wavFormatFloat = 3;
  if (format != wavFormatPcm && format != wavFormatFloat) {
    throw WavParseException('unsupported WAV format tag: $format');
  }

  final bytesPerSample = bitsPerSample ~/ 8;
  if (bytesPerSample == 0) {
    throw WavParseException('invalid bit depth: $bitsPerSample');
  }

  final count = dataLength ~/ bytesPerSample;
  final out = Float32List(count);
  final view = ByteData.sublistView(bytes, dataStart, dataStart + dataLength);

  if (format == wavFormatFloat) {
    switch (bitsPerSample) {
      case 32:
        for (var i = 0; i < count; i++) {
          out[i] = view.getFloat32(i * 4, Endian.little);
        }
      case 64:
        for (var i = 0; i < count; i++) {
          out[i] = view.getFloat64(i * 8, Endian.little).toDouble();
        }
      default:
        throw WavParseException('unsupported float bit depth: $bitsPerSample');
    }
  } else {
    switch (bitsPerSample) {
      case 8:
        // 8-bit WAV is unsigned, centred on 128, unlike every wider depth.
        for (var i = 0; i < count; i++) {
          out[i] = (view.getUint8(i) - 128) / 128.0;
        }
      case 16:
        for (var i = 0; i < count; i++) {
          out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
        }
      case 24:
        for (var i = 0; i < count; i++) {
          final b = i * 3;
          // Sign-extend the 24-bit little-endian value into 32 bits.
          var v = view.getUint8(b) |
              (view.getUint8(b + 1) << 8) |
              (view.getUint8(b + 2) << 16);
          if ((v & 0x800000) != 0) v |= ~0xFFFFFF;
          out[i] = v / 8388608.0;
        }
      case 32:
        for (var i = 0; i < count; i++) {
          out[i] = view.getInt32(i * 4, Endian.little) / 2147483648.0;
        }
      default:
        throw WavParseException('unsupported bit depth: $bitsPerSample');
    }
  }

  // Trim any partial trailing frame so the buffer is a whole number of frames;
  // the encoder rejects anything else.
  final usable = (out.length ~/ channels) * channels;
  return WavPcm(
    samples: usable == out.length ? out : Float32List.sublistView(out, 0, usable),
    sampleRate: sampleRate,
    channels: channels,
  );
}

String _tag(Uint8List bytes, int offset) {
  if (offset + 4 > bytes.length) return '';
  return String.fromCharCodes(bytes, offset, offset + 4);
}
