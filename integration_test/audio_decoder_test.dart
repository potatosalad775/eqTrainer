import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:audio_decoder/audio_decoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  // Fixture files live at test/fixtures/audio/ relative to the project root.
  // When `flutter test integration_test/` is run from the project root,
  // Directory.current.path is the project root on all desktop platforms.
  String fixture(String name) =>
      p.join(Directory.current.path, 'test', 'fixtures', 'audio', name);

  String tempOut(String name) => p.join(tempDir.path, name);

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('eqt_integ_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ---------------------------------------------------------------------------
  // convertToWav
  // ---------------------------------------------------------------------------
  group('AudioDecoder.convertToWav', () {
    testWidgets('MP3 → WAV produces a valid WAV file', (tester) async {
      final inputPath = fixture('sine_440hz_3s.mp3');
      final outputPath = tempOut('mp3_to_wav.wav');

      final resultPath = await AudioDecoder.convertToWav(inputPath, outputPath);

      final outFile = File(resultPath);
      expect(outFile.existsSync(), isTrue);

      final bytes = outFile.readAsBytesSync();
      // WAV files start with the RIFF magic bytes
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      expect(bytes.length, greaterThan(1000));
    });

    testWidgets('FLAC → WAV produces a valid WAV file', (tester) async {
      final inputPath = fixture('sine_440hz_3s.flac');
      final outputPath = tempOut('flac_to_wav.wav');

      final resultPath = await AudioDecoder.convertToWav(inputPath, outputPath);

      final bytes = File(resultPath).readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
      expect(bytes.length, greaterThan(1000));
    });

    testWidgets('WAV → WAV (idempotent) still produces a valid WAV file', (tester) async {
      final inputPath = fixture('sine_440hz_1s.wav');
      final outputPath = tempOut('wav_to_wav.wav');

      final resultPath = await AudioDecoder.convertToWav(inputPath, outputPath);

      final bytes = File(resultPath).readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
      expect(bytes.length, greaterThan(100));
    });

    testWidgets('non-existent file throws AudioConversionException', (tester) async {
      await expectLater(
        AudioDecoder.convertToWav(
          p.join(Directory.systemTemp.path, 'no_such_file.mp3'),
          tempOut('should_not_exist.wav'),
        ),
        throwsA(isA<AudioConversionException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getAudioInfo
  // ---------------------------------------------------------------------------
  group('AudioDecoder.getAudioInfo', () {
    testWidgets('returns correct duration for 1s WAV', (tester) async {
      final info = await AudioDecoder.getAudioInfo(fixture('sine_440hz_1s.wav'));
      expect(info.duration.inMilliseconds, greaterThan(800));
      expect(info.duration.inMilliseconds, lessThan(1200));
      expect(info.sampleRate, greaterThan(0));
      expect(info.channels, anyOf(1, 2));
    });

    testWidgets('returns correct duration for 3s MP3', (tester) async {
      final info = await AudioDecoder.getAudioInfo(fixture('sine_440hz_3s.mp3'));
      expect(info.duration.inMilliseconds, greaterThan(2500));
      expect(info.duration.inMilliseconds, lessThan(3500));
    });

    testWidgets('returns correct duration for 3s FLAC', (tester) async {
      final info = await AudioDecoder.getAudioInfo(fixture('sine_440hz_3s.flac'));
      expect(info.duration.inMilliseconds, greaterThan(2500));
      expect(info.duration.inMilliseconds, lessThan(3500));
    });

    testWidgets('returns correct duration for 2s silence WAV', (tester) async {
      final info = await AudioDecoder.getAudioInfo(fixture('silence_2s.wav'));
      expect(info.duration.inMilliseconds, greaterThan(1800));
      expect(info.duration.inMilliseconds, lessThan(2200));
    });
  });

  // ---------------------------------------------------------------------------
  // trimAudio
  // ---------------------------------------------------------------------------
  group('AudioDecoder.trimAudio', () {
    testWidgets('trimmed file is shorter than source', (tester) async {
      final inputPath = fixture('sine_440hz_1s.wav');
      final outputPath = tempOut('trimmed_half.wav');

      await AudioDecoder.trimAudio(
        inputPath,
        outputPath,
        Duration.zero,
        const Duration(milliseconds: 500),
      );

      final outFile = File(outputPath);
      expect(outFile.existsSync(), isTrue);

      final trimmedInfo = await AudioDecoder.getAudioInfo(outputPath);
      final sourceInfo = await AudioDecoder.getAudioInfo(inputPath);
      expect(
        trimmedInfo.duration.inMilliseconds,
        lessThan(sourceInfo.duration.inMilliseconds),
      );
    });

    testWidgets('trimmed duration is approximately the requested window', (tester) async {
      final inputPath = fixture('silence_2s.wav');
      final outputPath = tempOut('trimmed_1s_window.wav');

      await AudioDecoder.trimAudio(
        inputPath,
        outputPath,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1500),
      );

      final info = await AudioDecoder.getAudioInfo(outputPath);
      // Expect ~1000ms window, allow ±200ms tolerance for codec framing
      expect(info.duration.inMilliseconds, greaterThan(800));
      expect(info.duration.inMilliseconds, lessThan(1200));
    });

    testWidgets('trim from MP3 source produces valid WAV output', (tester) async {
      final inputPath = fixture('sine_440hz_3s.mp3');
      final outputPath = tempOut('mp3_trimmed.wav');

      await AudioDecoder.trimAudio(
        inputPath,
        outputPath,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 2000),
      );

      final bytes = File(outputPath).readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));

      final info = await AudioDecoder.getAudioInfo(outputPath);
      expect(info.duration.inMilliseconds, greaterThan(1000));
      expect(info.duration.inMilliseconds, lessThan(2000));
    });
  });
}
