import 'dart:typed_data';
import 'package:coast_audio/coast_audio.dart';
import 'package:eq_trainer/shared/player/peaking_eq_filter.dart';

class PeakingEQNode extends AudioFilterNode {
  PeakingEQNode({
    required this.format,
    required this.filter,
  });

  final AudioFormat format;
  final PeakingEQFilter filter;

  /// Pre-allocated scratch buffer for storing dry samples during bypass.
  /// Sized lazily on first use; reused across all subsequent process() calls.
  Float32List? _scratchBuffer;

  bool _bypassed = true;

  /// When true the node outputs the original (dry) signal, but the filter
  /// keeps processing in the background so its IIR state never goes stale.
  bool get bypassed => _bypassed;
  set bypassed(bool value) {
    if (value == _bypassed) return;
    _bypassed = value;
  }

  @override
  late final inputBus = AudioInputBus(node: this, formatResolver: (_) => format);

  @override
  late final outputBus = AudioOutputBus(node: this, formatResolver: (_) => format);

  @override
  AudioReadResult process(AudioBuffer buffer, bool isEnd) {
    if (_bypassed) {
      final samples = buffer.asFloat32ListView();
      final len = samples.length;
      // Lazily allocate scratch buffer; reuse across calls (zero GC pressure).
      if (_scratchBuffer == null || _scratchBuffer!.length < len) {
        _scratchBuffer = Float32List(len);
      }
      _scratchBuffer!.setRange(0, len, samples);
      filter.process(buffer, buffer);
      samples.setRange(0, len, _scratchBuffer!);
    } else {
      filter.process(buffer, buffer);
    }
    return AudioReadResult(frameCount: buffer.sizeInFrames, isEnd: isEnd);
  }
}
