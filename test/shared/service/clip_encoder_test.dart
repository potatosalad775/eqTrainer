import 'dart:io';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/service/clip_encoder.dart';

// ignore: missing_override_of_must_be_overridden
class _MockSoLoud extends Mock implements SoLoud {}

/// The real decode and encode are in the integration suite. This is about what
/// happens to a file SoLoud cannot read.
void main() {
  late Directory dir;
  late _MockSoLoud soloud;

  /// The call [convertFile] and [trimFile] make, for any arguments.
  Future<void> convertCall() => soloud.convertFile(
        any(),
        any(),
        format: any(named: 'format'),
        bitrate: any(named: 'bitrate'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      );

  setUpAll(() {
    registerFallbackValue(MixerOutputFormat.flac);
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('clip_encoder_');
    soloud = _MockSoLoud();
    when(convertCall).thenThrow(
      const SoLoudOfflineDecodeCppException(
        OfflineDecodeResult.unsupportedFormat,
      ),
    );
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('an unreadable file reaches the caller, which refuses it', () async {
    final source = File(p.join(dir.path, 'a.m4a'))..writeAsBytesSync([1, 2, 3]);
    final dest = p.join(dir.path, 'a.opus');

    await expectLater(
      ClipEncoder(soloud: soloud).convertFile(
        sourcePath: source.path,
        destPath: dest,
      ),
      throwsA(predicate(isUnreadableAudioError)),
    );
    expect(File(dest).existsSync(), isFalse);
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

  test('a failed load counts as unreadable, a missing file or engine does not',
      () {
    expect(isUnreadableAudioError(const SoLoudFileLoadFailedException()), isTrue);
    expect(isUnreadableAudioError(const SoLoudFileNotFoundException()), isFalse);
    expect(
      isUnreadableAudioError(const SoLoudNotInitializedException()),
      isFalse,
    );
  });

  test('more than two channels reaches the caller as its own exception', () async {
    when(convertCall).thenThrow(const SoLoudOfflineChannelCountCppException(6));
    final dest = p.join(dir.path, 'a.wav');

    await expectLater(
      ClipEncoder(soloud: soloud).convertFile(sourcePath: 'a.flac', destPath: dest),
      throwsA(isA<UnsupportedChannelCountException>()
          .having((e) => e.channels, 'channels', 6)),
    );
    expect(File(dest).existsSync(), isFalse);
  });

  test('a trim passes its range and the format its extension implies', () async {
    when(convertCall).thenAnswer((_) async {});

    await ClipEncoder(soloud: soloud).trimFile(
      sourcePath: 'a.flac',
      destPath: 'b.OPUS',
      start: const Duration(seconds: 1),
      end: const Duration(seconds: 2),
    );

    verify(
      () => soloud.convertFile(
        'a.flac',
        'b.OPUS',
        format: MixerOutputFormat.opus,
        bitrate: ClipEncoder.opusBitrate,
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 2),
      ),
    ).called(1);
  });

  test('a conversion covers the whole file', () async {
    when(convertCall).thenAnswer((_) async {});

    await ClipEncoder(soloud: soloud).convertFile(
      sourcePath: 'a.m4a',
      destPath: 'a.flac',
    );

    verify(
      () => soloud.convertFile(
        'a.m4a',
        'a.flac',
        format: MixerOutputFormat.flac,
        bitrate: ClipEncoder.opusBitrate,
        // ignore: avoid_redundant_argument_values
        start: Duration.zero,
        // ignore: avoid_redundant_argument_values
        end: null,
      ),
    ).called(1);
  });

  test('an unknown target extension is refused before anything is read', () {
    expect(
      () => ClipEncoder(soloud: soloud).convertFile(
        sourcePath: 'a.m4a',
        destPath: 'a.xyz',
      ),
      throwsArgumentError,
    );
    verifyNever(convertCall);
  });
}
