import 'dart:io';
import 'dart:typed_data';

import 'package:eq_trainer/shared/service/clip_encoder.dart';

/// Stands in for [ClipEncoder] so the library-rewrite suites stay headless.
///
/// The native Opus and FLAC encoders are covered by the integration suite and
/// the fork's own tests; here the only thing that matters is that a file of a
/// known size appears at the destination, or that the call fails.
class FakeClipEncoder implements ClipEncoder {
  FakeClipEncoder({this.outputSize = 128, this.throwOnEncode = false});

  /// Bytes written to every destination.
  final int outputSize;

  /// When true, both entry points throw before writing anything.
  final bool throwOnEncode;

  /// Every destination path this encoder wrote, in call order — from either
  /// entry point. A test that expects a target to bypass the encoder asserts
  /// this stays empty.
  final List<String> encoded = [];

  @override
  Future<void> convertFile({
    required String sourcePath,
    required String destPath,
  }) =>
      _write(destPath);

  @override
  Future<void> encodeWavBytes({
    required Uint8List wavBytes,
    required String destPath,
  }) =>
      _write(destPath);

  Future<void> _write(String destPath) async {
    if (throwOnEncode) throw Exception('encoder failed');
    encoded.add(destPath);
    await File(destPath).writeAsBytes(List<int>.filled(outputSize, 0));
  }
}
