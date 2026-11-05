import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/service/clip_encoder.dart';

// ignore: missing_override_of_must_be_overridden
class _MockSoLoud extends Mock implements SoLoud {}

/// The real decode and encode are in the integration suite. This is about when
/// `audio_decoder` may be reached, because reaching it can crash the process.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('audio_decoder');
  late Directory dir;
  late _MockSoLoud soloud;
  late int pluginCalls;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('clip_encoder_');
    soloud = _MockSoLoud();
    pluginCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      pluginCalls++;
      throw PlatformException(code: 'stubbed');
    });
    when(() => soloud.decodeFileToPcm(any())).thenThrow(
      const SoLoudOfflineDecodeCppException(
        OfflineDecodeResult.unsupportedFormat,
      ),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await dir.delete(recursive: true);
  });

  Future<void> convert(bool fallback) async {
    final source = File(p.join(dir.path, 'a.m4a'))..writeAsBytesSync([1, 2, 3]);
    await ClipEncoder(soloud: soloud, platformCodecFallback: fallback)
        .convertFile(
      sourcePath: source.path,
      destPath: p.join(dir.path, 'a.opus'),
    );
  }

  test('an unreadable file never reaches audio_decoder by default', () async {
    await expectLater(
      convert(false),
      throwsA(isA<SoLoudOfflineDecodeCppException>()),
    );
    expect(pluginCalls, 0);
  });

  test('with the fallback on, audio_decoder gets the file', () async {
    await expectLater(convert(true), throwsA(isA<Exception>()));
    expect(pluginCalls, 1);
  });

  test('only an unsupported format counts as unreadable', () {
    for (final result in OfflineDecodeResult.values) {
      expect(
        isUnreadableAudioError(SoLoudOfflineDecodeCppException(result)),
        result == OfflineDecodeResult.unsupportedFormat,
        reason: result.name,
      );
    }
    expect(isUnreadableAudioError(Exception('disk full')), isFalse);
  });
}
