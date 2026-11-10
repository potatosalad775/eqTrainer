import 'dart:io';
import 'dart:typed_data';

import 'package:eq_trainer/shared/service/clip_encoder.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Stands in for [ClipEncoder] so the library-rewrite suites stay headless.
///
/// The native Opus and FLAC encoders are covered by the integration suite and
/// the fork's own tests; here the only thing that matters is that a file of a
/// known size appears at the destination, or that the call fails.
class FakeClipEncoder implements ClipEncoder {
  FakeClipEncoder({
    this.outputSize = 128,
    this.throwOnEncode = false,
    this.unreadable = const {},
    this.trimFailure,
  });

  /// Bytes written to every destination.
  final int outputSize;

  /// When true, both entry points throw before writing anything.
  final bool throwOnEncode;

  /// Sources [trimFile] reports it could not decode.
  final Set<String> unreadable;

  /// When set, [trimFile] writes a partial file and then throws this, as an
  /// encode that dies partway does.
  final Object? trimFailure;

  /// Every source [trimFile] was asked to read, in call order.
  final List<String> trimmedFrom = [];

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

  @override
  Future<void> trimFile({
    required String sourcePath,
    required String destPath,
    required Duration start,
    required Duration end,
  }) async {
    trimmedFrom.add(sourcePath);
    if (unreadable.contains(sourcePath)) {
      throw const SoLoudOfflineDecodeCppException(
        OfflineDecodeResult.unsupportedFormat,
      );
    }
    await _write(destPath);
    if (trimFailure case final failure?) throw failure;
  }

  Future<void> _write(String destPath) async {
    if (throwOnEncode) throw Exception('encoder failed');
    encoded.add(destPath);
    await File(destPath).writeAsBytes(List<int>.filled(outputSize, 0));
  }
}
