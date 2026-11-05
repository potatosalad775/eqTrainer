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

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('clip_encoder_');
    soloud = _MockSoLoud();
    when(() => soloud.decodeFileToPcm(any())).thenThrow(
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
}
