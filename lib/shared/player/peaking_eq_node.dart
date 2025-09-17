import 'package:coast_audio/coast_audio.dart';
import 'package:eq_trainer/shared/player/peaking_eq_filter.dart';

class PeakingEQNode extends AudioFilterNode {
  PeakingEQNode({
    required this.format,
    required this.filter,
  });

  final AudioFormat format;
  final PeakingEQFilter filter;

  @override
  late final inputBus = AudioInputBus(node: this, formatResolver: (_) => format);

  @override
  late final outputBus = AudioOutputBus(node: this, formatResolver: (_) => format);

  @override
  AudioReadResult process(AudioBuffer buffer, bool isEnd) {
    filter.process(buffer, buffer);
    return AudioReadResult(frameCount: buffer.sizeInFrames, isEnd: false);
  }
}