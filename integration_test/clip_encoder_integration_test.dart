import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:integration_test/integration_test.dart';

import 'package:eq_trainer/shared/service/clip_encoder.dart';
import 'package:eq_trainer/shared/service/wav_pcm.dart';

import 'helpers/fixtures.dart';

/// End-to-end coverage for the Opus/FLAC clip path.
///
/// This drives the real offline encoder in the native library, so it is not
/// something CI can run — GitHub-hosted runners have no audio hardware, and an
/// engine that comes up there proves nothing about a user's machine. Run it on
/// a real desktop or a connected phone:
///
///   flutter test integration_test/clip_encoder_integration_test.dart \
///     --device-id macos|windows|linux
///
/// Note that the encoder itself needs no audio *device* — it touches no engine
/// state — but loading the result back to check it plays does.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestFixtures fixtures;
  late ClipEncoder encoder;

  /// Fixtures and encoder output share one scratch directory.
  String fixture(String name) => fixtures.path(name);

  setUpAll(() async {
    fixtures = await TestFixtures.create();
    encoder = ClipEncoder();

    // The encoder needs no engine, but loading its output back to check that
    // it decodes does.
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
  });

  tearDownAll(() async {
    if (SoLoud.instance.isInitialized) {
      await SoLoud.instance.disposeAllSources();
      SoLoud.instance.deinit();
    }
    await fixtures.dispose();
  });

  group('ClipEncoder produces files SoLoud can load', () {
    for (final target in ['.opus', '.flac', '.wav']) {
      test('converts a WAV source to $target', () async {
        final dest = fixture('out_from_wav$target');
        await encoder.convertFile(
          sourcePath: fixture('sine_440hz_1s.wav'),
          destPath: dest,
        );

        final file = File(dest);
        expect(file.existsSync(), isTrue, reason: 'no output written');
        expect(file.lengthSync(), greaterThan(0));

        // The real assertion: the engine can open what we just wrote.
        final source = await SoLoud.instance.loadFile(dest, mode: LoadMode.disk);
        final length = SoLoud.instance.getLength(source);
        expect(
          length.inMilliseconds,
          closeTo(1000, 120),
          reason: 'decoded length should match the 1 s source',
        );
        await SoLoud.instance.disposeSource(source);
      });
    }

    test('converts an MP3 source to Opus', () async {
      final dest = fixture('out_from_mp3.opus');
      await encoder.convertFile(
        sourcePath: fixture('sine_440hz_3s.mp3'),
        destPath: dest,
      );

      final source = await SoLoud.instance.loadFile(dest, mode: LoadMode.disk);
      expect(SoLoud.instance.getLength(source).inMilliseconds,
          closeTo(3000, 200));
      await SoLoud.instance.disposeSource(source);
    });

    test('Opus output is much smaller than the WAV it came from', () async {
      final dest = fixture('size_check.opus');
      await encoder.convertFile(
        sourcePath: fixture('sine_440hz_1s.wav'),
        destPath: dest,
      );
      final sourceSize = File(fixture('sine_440hz_1s.wav')).lengthSync();
      final destSize = File(dest).lengthSync();
      expect(destSize, lessThan(sourceSize));
    });

    test('FLAC output is lossless but smaller than WAV', () async {
      final dest = fixture('size_check.flac');
      await encoder.convertFile(
        sourcePath: fixture('sine_440hz_1s.wav'),
        destPath: dest,
      );
      final sourceSize = File(fixture('sine_440hz_1s.wav')).lengthSync();
      expect(File(dest).lengthSync(), lessThan(sourceSize));
    });
  });

  group('encodeWavBytes', () {
    test('writes a WAV target through untouched', () async {
      final wavBytes = await File(fixture('sine_440hz_1s.wav')).readAsBytes();
      final dest = fixture('passthrough.wav');
      await encoder.encodeWavBytes(wavBytes: wavBytes, destPath: dest);
      expect(File(dest).readAsBytesSync(), equals(wavBytes));
    });

    test('keeps the clip length through an Opus round-trip', () async {
      final wavBytes = await File(fixture('sine_440hz_1s.wav')).readAsBytes();
      final original = parseWav(wavBytes);
      final originalMs = original.frameCount * 1000 ~/ original.sampleRate;

      final dest = fixture('roundtrip.opus');
      await encoder.encodeWavBytes(wavBytes: wavBytes, destPath: dest);

      // Opus always decodes at 48 kHz regardless of the input rate, and
      // SoLoud does not expose a source's channel count, so duration is the
      // one property of the input that can be checked against the output.
      final source = await SoLoud.instance.loadFile(dest, mode: LoadMode.disk);
      expect(SoLoud.instance.getLength(source).inMilliseconds,
          closeTo(originalMs, 120));
      await SoLoud.instance.disposeSource(source);
    });

    test('rejects a target extension it has no encoder for', () async {
      final wavBytes = await File(fixture('sine_440hz_1s.wav')).readAsBytes();
      expect(
        () => encoder.encodeWavBytes(
          wavBytes: wavBytes,
          destPath: fixture('nope.m4a'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('seeking an encoded Opus clip', () {
    test('lands close to the requested position', () async {
      final dest = fixture('seek_target.opus');
      await encoder.convertFile(
        sourcePath: fixture('sine_440hz_3s.mp3'),
        destPath: dest,
      );

      final source = await SoLoud.instance.loadFile(dest, mode: LoadMode.disk);
      final handle = SoLoud.instance.play(source, volume: 0);
      SoLoud.instance.seek(handle, const Duration(milliseconds: 2000));
      final position = SoLoud.instance.getPosition(handle);
      expect(
        position.inMilliseconds,
        closeTo(2000, 150),
        reason: 'seek should land near the requested point',
      );
      await SoLoud.instance.stop(handle);
      await SoLoud.instance.disposeSource(source);
    });
  });
}
