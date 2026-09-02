import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/service/clip_encoder.dart';

import 'fixture_mp3.dart';

/// The audio the integration suites run against, written fresh into a temp
/// directory.
///
/// These used to be checked-in files under `test/fixtures/audio/`, listed in
/// `pubspec.yaml` so `rootBundle` could reach them on a sandboxed device. But
/// everything under `assets:` ships in every release build, so ~360 KB of
/// sine waves rode along in every APK, IPA and DMG. Now the WAVs are
/// synthesised here, the FLAC is encoded from one of them through the app's
/// own [ClipEncoder], and the MP3 (the one format the app cannot write) is an
/// embedded constant that compiles only into the test binary.
///
/// Every fixture is mono, 16-bit, 44.1 kHz, matching what the originals were.
class TestFixtures {
  TestFixtures._(this.dir);

  final Directory dir;

  static const sampleRate = 44100;

  /// Peak of the 1 s tone, as a fraction of full scale: about -2 dBFS, what
  /// the original file was rendered at. It only feeds encode and trim tests,
  /// where level is irrelevant.
  static const sineAmplitude = 0.8;

  /// Peak of the 3 s tone, about -18 dBFS, again matching the original. This
  /// one is what the peaking-EQ suite boosts by up to +15 dB and then
  /// measures, so it needs the headroom: a full-scale tone would hit the
  /// engine's clipper and read back a fraction of the gain.
  static const toneAmplitude3s = 0.125;

  static const sine440hz1sWav = 'sine_440hz_1s.wav';
  static const silence2sWav = 'silence_2s.wav';
  static const sine440hz3sMp3 = 'sine_440hz_3s.mp3';
  static const sine440hz3sFlac = 'sine_440hz_3s.flac';

  /// Writes every fixture and returns a handle to the directory.
  static Future<TestFixtures> create() async {
    final dir = await Directory.systemTemp.createTemp('eqt_fixtures_');
    final f = TestFixtures._(dir);

    await File(f.path(sine440hz1sWav)).writeAsBytes(sineWav(seconds: 1));
    await File(f.path(silence2sWav)).writeAsBytes(silenceWav(seconds: 2));
    await File(f.path(sine440hz3sMp3))
        .writeAsBytes(base64Decode(sine440hz3sMp3Base64));
    // The offline encoder touches no engine state, so this is fine before
    // SoLoud.init() and must stay so: audio_state_integration_test checks
    // device enumeration on a down engine.
    await ClipEncoder().encodeWavBytes(
      wavBytes: sineWav(seconds: 3, amplitude: toneAmplitude3s),
      destPath: f.path(sine440hz3sFlac),
    );
    return f;
  }

  /// Absolute path of the fixture called [name].
  String path(String name) => p.join(dir.path, name);

  Future<void> dispose() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// A mono 16-bit sine, [seconds] long.
  static Uint8List sineWav({
    required double seconds,
    double frequency = 440,
    double amplitude = sineAmplitude,
  }) {
    final frames = (seconds * sampleRate).round();
    final pcm = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      final s = amplitude * sin(2 * pi * frequency * i / sampleRate);
      pcm[i] = (s * 32767).round();
    }
    return _wav(pcm);
  }

  /// A mono 16-bit run of digital silence, [seconds] long.
  static Uint8List silenceWav({required double seconds}) =>
      _wav(Int16List((seconds * sampleRate).round()));

  /// Wraps mono 16-bit PCM in the plain 44-byte RIFF/WAVE header.
  static Uint8List _wav(Int16List pcm) {
    const channels = 1;
    const bitsPerSample = 16;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final dataBytes = pcm.lengthInBytes;

    final out = ByteData(44 + dataBytes);
    void ascii(int offset, String s) {
      for (var i = 0; i < 4; i++) {
        out.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    out.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little); // PCM
    out.setUint16(22, channels, Endian.little);
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, sampleRate * blockAlign, Endian.little);
    out.setUint16(32, blockAlign, Endian.little);
    out.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    out.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < pcm.length; i++) {
      out.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }
}
