import 'dart:ffi';

import 'package:coast_audio/coast_audio.dart';
import 'package:coast_audio/src/interop/internal/generated/bindings.dart';
import 'package:coast_audio/src/interop/internal/ma_extension.dart';

class PeakingEQFilter {
  PeakingEQFilter({
    required this.format,
    required double gainDb,
    required double q,
    required double frequency,
  }) : _gainDb = gainDb,
       _q = q,
       _frequency = frequency
  {
    final config = _interop.bindings.ma_peak2_config_init(format.sampleFormat.maFormat, format.channels, format.sampleRate, _gainDb, _q, _frequency);
    _pConfig.ref = config;

    _interop.bindings.ma_peak2_init(_pConfig, nullptr, _pFilter).throwMaResultIfNeeded();

    _interop.onInitialized();
  }

  final _interop = CoastAudioInterop();

  late final _pConfig = _interop.allocateManaged<ma_peak2_config>(sizeOf<ma_peak2_config>());
  late final _pFilter = _interop.allocateManaged<ma_peak2>(sizeOf<ma_peak2>());

  final AudioFormat format;

  double _gainDb;
  double get gainDb => _gainDb;

  double _q;
  double get q => _q;

  double _frequency;
  double get frequency => _frequency;

  late AudioTime _latency;
  AudioTime get latency => _latency;

  void process(AudioBuffer bufferIn, AudioBuffer bufferOut) {
    //assert(bufferOut.sizeInFrames > bufferIn.sizeInFrames);
    _interop.bindings.ma_peak2_process_pcm_frames(_pFilter, bufferOut.pBuffer.cast(), bufferIn.pBuffer.cast(), bufferIn.sizeInFrames).throwMaResultIfNeeded();
  }

  /// Reinit the filter parameters while keeping internal state.
  void update({double? gainDb, double? q, double? frequency}) {
    final config = _interop.bindings.ma_peak2_config_init(
      format.sampleFormat.maFormat,
      format.channels,
      format.sampleRate,
      gainDb ?? this.gainDb,
      q ?? this.q,
      frequency ?? this.frequency,
    );

    late final pNewConfig = _interop.allocateManaged<ma_peak2_config>(sizeOf<ma_peak2_config>());
    pNewConfig.ref = config;
    _interop.bindings.ma_peak2_reinit(pNewConfig, _pFilter).throwMaResultIfNeeded();

    _gainDb = gainDb ?? this.gainDb;
    _q = q ?? this.q;
    _frequency = frequency ?? this.frequency;
    _updateLatency();
  }

  void _updateLatency() {
    final frameCount = _interop.bindings.ma_peak2_get_latency(_pFilter);
    _latency = AudioTime.fromFrames(frameCount, format: format);
  }

  void dispose() {
    _interop.bindings.ma_peak2_uninit(_pFilter, nullptr);
  }
}