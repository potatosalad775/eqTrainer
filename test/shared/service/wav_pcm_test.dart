import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/shared/service/wav_pcm.dart';

/// Builds a RIFF/WAVE buffer. [extraChunks] are inserted between `fmt ` and
/// `data`, which is where real files put LIST/fact/bext and where a parser
/// that assumes the 44-byte layout breaks.
Uint8List buildWav({
  required List<int> dataBytes,
  int channels = 2,
  int sampleRate = 44100,
  int bitsPerSample = 16,
  int formatTag = 1,
  List<int> extraChunks = const [],
  int? declaredDataSize,
}) {
  final fmt = BytesBuilder();
  fmt.add(_ascii('fmt '));
  fmt.add(_u32(16));
  fmt.add(_u16(formatTag));
  fmt.add(_u16(channels));
  fmt.add(_u32(sampleRate));
  fmt.add(_u32(sampleRate * channels * (bitsPerSample ~/ 8))); // byte rate
  fmt.add(_u16(channels * (bitsPerSample ~/ 8))); // block align
  fmt.add(_u16(bitsPerSample));

  final body = BytesBuilder()
    ..add(_ascii('WAVE'))
    ..add(fmt.toBytes())
    ..add(extraChunks)
    ..add(_ascii('data'))
    ..add(_u32(declaredDataSize ?? dataBytes.length))
    ..add(dataBytes);

  final out = BytesBuilder()
    ..add(_ascii('RIFF'))
    ..add(_u32(body.length))
    ..add(body.toBytes());
  return out.toBytes();
}

List<int> _ascii(String s) => s.codeUnits;

List<int> _u32(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

List<int> _int16le(List<int> values) {
  final b = BytesBuilder();
  for (final v in values) {
    b.add(_u16(v & 0xFFFF));
  }
  return b.toBytes();
}

/// A named chunk with an arbitrary payload, for the chunk-walking tests.
List<int> chunk(String id, List<int> payload) => [
      ..._ascii(id),
      ..._u32(payload.length),
      ...payload,
      if (payload.length.isOdd) 0,
    ];

void main() {
  group('parseWav header', () {
    test('reads rate and channel count out of the fmt chunk', () {
      final wav = buildWav(
        dataBytes: _int16le([0, 0, 0, 0]),
        channels: 2,
        sampleRate: 48000,
      );
      final pcm = parseWav(wav);
      expect(pcm.sampleRate, equals(48000));
      expect(pcm.channels, equals(2));
      expect(pcm.frameCount, equals(2));
    });

    test('handles mono', () {
      final pcm = parseWav(buildWav(
        dataBytes: _int16le([1, 2, 3]),
        channels: 1,
        sampleRate: 22050,
      ));
      expect(pcm.channels, equals(1));
      expect(pcm.sampleRate, equals(22050));
      expect(pcm.frameCount, equals(3));
    });
  });

  group('parseWav chunk walking', () {
    test('skips LIST and fact chunks sitting before data', () {
      final wav = buildWav(
        dataBytes: _int16le([32767, -32768]),
        channels: 1,
        extraChunks: [
          ...chunk('LIST', _ascii('INFOsome metadata here')),
          ...chunk('fact', _u32(2)),
        ],
      );
      final pcm = parseWav(wav);
      expect(pcm.frameCount, equals(2));
      expect(pcm.samples[0], closeTo(1.0, 0.001));
      expect(pcm.samples[1], closeTo(-1.0, 0.001));
    });

    test('handles an odd-sized chunk and its pad byte', () {
      // An odd-length chunk is followed by a pad byte that the size field does
      // not count. Mishandling it puts every later chunk one byte out.
      final wav = buildWav(
        dataBytes: _int16le([1000, 2000]),
        channels: 1,
        extraChunks: chunk('note', _ascii('odd')),
      );
      final pcm = parseWav(wav);
      expect(pcm.frameCount, equals(2));
      expect(pcm.samples[0], closeTo(1000 / 32768.0, 1e-6));
    });

    test('falls back to the real length when data declares a size of zero', () {
      final wav = buildWav(
        dataBytes: _int16le([100, 200, 300, 400]),
        channels: 1,
        declaredDataSize: 0,
      );
      expect(parseWav(wav).frameCount, equals(4));
    });

    test('clamps a declared size larger than the buffer', () {
      final wav = buildWav(
        dataBytes: _int16le([100, 200]),
        channels: 1,
        declaredDataSize: 999999,
      );
      expect(parseWav(wav).frameCount, equals(2));
    });
  });

  group('parseWav sample conversion', () {
    test('16-bit maps full scale to +/-1.0', () {
      final pcm = parseWav(buildWav(
        dataBytes: _int16le([0, 32767, -32768, 16384]),
        channels: 1,
      ));
      expect(pcm.samples[0], closeTo(0.0, 1e-9));
      expect(pcm.samples[1], closeTo(1.0, 1e-4));
      expect(pcm.samples[2], closeTo(-1.0, 1e-9));
      expect(pcm.samples[3], closeTo(0.5, 1e-4));
    });

    test('8-bit is unsigned and centred on 128', () {
      final pcm = parseWav(
        buildWav(dataBytes: [128, 255, 0, 192], channels: 1, bitsPerSample: 8),
      );
      expect(pcm.samples[0], closeTo(0.0, 1e-9));
      expect(pcm.samples[1], closeTo(0.9921875, 1e-6));
      expect(pcm.samples[2], closeTo(-1.0, 1e-9));
      expect(pcm.samples[3], closeTo(0.5, 1e-6));
    });

    test('24-bit sign-extends negative values', () {
      // 0x800000 is the most negative 24-bit value; 0x7FFFFF the most positive.
      final data = <int>[
        0x00, 0x00, 0x00, // 0
        0xFF, 0xFF, 0x7F, // +max
        0x00, 0x00, 0x80, // -max
      ];
      final pcm =
          parseWav(buildWav(dataBytes: data, channels: 1, bitsPerSample: 24));
      expect(pcm.samples[0], closeTo(0.0, 1e-9));
      expect(pcm.samples[1], closeTo(1.0, 1e-6));
      expect(pcm.samples[2], closeTo(-1.0, 1e-9));
    });

    test('32-bit float passes through unchanged', () {
      final f = Float32List.fromList([0.0, 0.5, -0.25, 1.0]);
      final pcm = parseWav(buildWav(
        dataBytes: f.buffer.asUint8List(),
        channels: 1,
        bitsPerSample: 32,
        formatTag: 3,
      ));
      expect(pcm.samples[0], closeTo(0.0, 1e-9));
      expect(pcm.samples[1], closeTo(0.5, 1e-9));
      expect(pcm.samples[2], closeTo(-0.25, 1e-9));
      expect(pcm.samples[3], closeTo(1.0, 1e-9));
    });

    test('interleaving is preserved across channels', () {
      // L=+full, R=-full, twice over.
      final pcm = parseWav(buildWav(
        dataBytes: _int16le([32767, -32768, 32767, -32768]),
        channels: 2,
      ));
      expect(pcm.frameCount, equals(2));
      expect(pcm.samples[0], greaterThan(0.9));
      expect(pcm.samples[1], lessThan(-0.9));
      expect(pcm.samples[2], greaterThan(0.9));
      expect(pcm.samples[3], lessThan(-0.9));
    });

    test('drops a partial trailing frame', () {
      // Three samples across two channels is one and a half frames. The
      // encoder rejects a non-whole frame count, so the half must be dropped.
      final pcm = parseWav(buildWav(
        dataBytes: _int16le([1, 2, 3]),
        channels: 2,
      ));
      expect(pcm.samples.length, equals(2));
      expect(pcm.frameCount, equals(1));
    });
  });

  group('parseWav rejects what it cannot read', () {
    test('a buffer that is too short', () {
      expect(() => parseWav(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<WavParseException>()));
    });

    test('a buffer that is not RIFF/WAVE', () {
      final notWav = Uint8List.fromList([
        ..._ascii('RIFF'),
        ..._u32(4),
        ..._ascii('AVI '),
        0, 0, 0, 0,
      ]);
      expect(() => parseWav(notWav), throwsA(isA<WavParseException>()));
    });

    test('a WAV with no fmt chunk', () {
      final noFmt = Uint8List.fromList([
        ..._ascii('RIFF'),
        ..._u32(20),
        ..._ascii('WAVE'),
        ...chunk('data', _int16le([1, 2])),
      ]);
      expect(() => parseWav(noFmt), throwsA(isA<WavParseException>()));
    });

    test('a WAV with no data chunk', () {
      final noData = buildWav(dataBytes: const [], channels: 1);
      expect(() => parseWav(noData), throwsA(isA<WavParseException>()));
    });

    test('a compressed format tag it cannot decode', () {
      // 0x0055 is MPEG Layer 3 inside a WAV container.
      expect(
        () => parseWav(buildWav(
          dataBytes: _int16le([1, 2]),
          channels: 1,
          formatTag: 0x0055,
        )),
        throwsA(isA<WavParseException>()),
      );
    });
  });
}
