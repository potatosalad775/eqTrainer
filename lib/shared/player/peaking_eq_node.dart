import 'package:coast_audio/coast_audio.dart';
import 'package:eq_trainer/shared/player/peaking_eq_filter.dart';

class PeakingEQNode extends AudioFilterNode {
  PeakingEQNode({
    required this.format,
    required this.filter,
    this.fadeSamples = 128,
  }) : _desiredFrequency = filter.frequency;

  final AudioFormat format;
  final PeakingEQFilter filter;

  /// Total samples for a full fade-through-zero (half fade-out + half fade-in).
  /// 128 samples ≈ 2.9 ms at 44.1 kHz.
  final int fadeSamples;

  /// Native scratch frames for the wet output (bypass discard / fade source).
  /// Lazily allocated on first use; reused across all subsequent calls.
  AllocatedAudioFrames? _scratchFrames;

  bool _bypassed = true;

  /// The gain the caller wants applied when the filter is active.
  /// During bypass the filter runs at 0 dB; this value is restored on un-bypass.
  double _desiredGainDb = 0;

  /// The frequency the caller wants. During bypass, deferred until un-bypass.
  double _desiredFrequency;

  /// Fade position: 0.0 = fully dry (bypassed), 1.0 = fully wet (active).
  double _wet = 0.0;

  bool get bypassed => _bypassed;
  set bypassed(bool value) {
    if (value == _bypassed) return;
    _bypassed = value;
    if (_bypassed) {
      // Run filter at 0 dB during bypass → clean IIR state.
      filter.update(gainDb: 0);
    } else {
      // Restore active gain and frequency before the fade starts.
      filter.update(gainDb: _desiredGainDb, frequency: _desiredFrequency);
    }
  }

  /// Update the desired gain. During bypass the filter stays at 0 dB;
  /// the gain is deferred and applied when bypass is turned off.
  void setGain(double gainDb) {
    _desiredGainDb = gainDb;
    if (!_bypassed) {
      filter.update(gainDb: gainDb);
    }
  }

  /// Update the desired frequency. During bypass the update is deferred
  /// and applied atomically with gain when bypass is turned off.
  void setFrequency(double frequency) {
    _desiredFrequency = frequency;
    if (!_bypassed) {
      filter.update(frequency: frequency);
    }
  }

  @override
  late final inputBus = AudioInputBus(node: this, formatResolver: (_) => format);

  @override
  late final outputBus = AudioOutputBus(node: this, formatResolver: (_) => format);

  bool get _isFading =>
      (_bypassed && _wet > 0.0) || (!_bypassed && _wet < 1.0);

  AudioBuffer _lockScratch(int frames) {
    if (_scratchFrames == null || _scratchFrames!.sizeInFrames < frames) {
      _scratchFrames = AllocatedAudioFrames(length: frames, format: format);
    }
    return _scratchFrames!.lock();
  }

  @override
  AudioReadResult process(AudioBuffer buffer, bool isEnd) {
    if (_isFading) {
      _processFade(buffer);
    } else if (_bypassed) {
      // Zero-copy bypass: filter reads from buffer (IIR state updated),
      // wet output goes to scratch (discarded). Buffer passes through.
      final scratch = _lockScratch(buffer.sizeInFrames);
      try {
        filter.process(buffer, scratch);
      } finally {
        _scratchFrames!.unlock();
      }
    } else {
      filter.process(buffer, buffer);
      buffer.clamp();
    }
    return AudioReadResult(frameCount: buffer.sizeInFrames, isEnd: isEnd);
  }

  /// Smoothstep: zero slope at both ends, ideal for fade envelopes.
  static double _smoothstep(double u) => u * u * (3.0 - 2.0 * u);

  /// Compute the fade-through-zero envelope at the current [_wet] position.
  /// Returns (signal source is dry, envelope gain).
  /// The smoothstep shape gives zero derivative at all transition boundaries
  /// (start, zero-crossing, end), eliminating the slope discontinuity that
  /// a linear ramp produces at the midpoint.
  double _envelope() {
    if (_wet < 0.5) {
      return 1.0 - _smoothstep(_wet * 2.0);
    } else {
      return _smoothstep(_wet * 2.0 - 1.0);
    }
  }

  /// Fade-through-zero with smoothstep envelope: fade the current signal to
  /// silence, then fade the new signal from silence. The two signals are never
  /// mixed, and the envelope slope is zero at every boundary.
  void _processFade(AudioBuffer buffer) {
    final frames = buffer.sizeInFrames;
    final channels = format.channels;
    final scratch = _lockScratch(frames);
    try {
      // buffer = dry (untouched), scratch = wet.
      filter.process(buffer, scratch);
      scratch.clamp(); // Prevent EQ-boosted samples from overflowing during fade.

      final step = 1.0 / fadeSamples;
      final dir = _bypassed ? -step : step;

      switch (format.sampleFormat) {
        case SampleFormat.float32:
          final dry = buffer.asFloat32ListView();
          final wet = scratch.asFloat32ListView();
          var idx = 0;
          for (var f = 0; f < frames; f++) {
            _wet = (_wet + dir).clamp(0.0, 1.0);
            final env = _envelope();
            final src = _wet < 0.5 ? dry : wet;
            for (var c = 0; c < channels; c++) {
              dry[idx] = src[idx] * env;
              idx++;
            }
          }
        case SampleFormat.int16:
          final dry = buffer.asInt16ListView();
          final wet = scratch.asInt16ListView();
          var idx = 0;
          for (var f = 0; f < frames; f++) {
            _wet = (_wet + dir).clamp(0.0, 1.0);
            final env = _envelope();
            final src = _wet < 0.5 ? dry : wet;
            for (var c = 0; c < channels; c++) {
              dry[idx] = (src[idx] * env).round();
              idx++;
            }
          }
        default:
          // Unsupported sample format: snap to target without fade.
          _wet = _bypassed ? 0.0 : 1.0;
          if (!_bypassed) {
            buffer.asUint8ListViewBytes().setRange(
                0, buffer.sizeInBytes, scratch.asUint8ListViewBytes());
          }
      }
      buffer.clamp(); // Safety clamp after fade envelope application.
    } finally {
      _scratchFrames!.unlock();
    }
  }
}
