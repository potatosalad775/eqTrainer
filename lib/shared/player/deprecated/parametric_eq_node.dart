import 'dart:math';
import 'package:coast_audio/coast_audio.dart';

/*
* DEPRECATED PEAKING EQ NODE
* REPLACED BY MINIAUDIO BUILT-IN FILTER
*/

class ParametricEQNode extends AudioFilterNode {
  ParametricEQNode({
    required this.format,
    required this.gain,
    required this.centerFreq,
    required this.qFactor,
  });

  final AudioFormat format;

  @override
  late final inputBus = AudioInputBus(node: this, formatResolver: (_) => format);

  @override
  late final outputBus = AudioOutputBus(node: this, formatResolver: (_) => format);

  int gain;
  double centerFreq;
  double qFactor;

  double w0 = 0;
  double alpha = 0;
  double A = 0;
  double b0 = 0;
  double b1 = 0;
  double b2 = 0;
  double a0 = 0;
  double a1 = 0;
  double a2 = 0;
  double x = 0;
  double y = 0;
  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;
  double gainRatio = 1.0;

  @override
  AudioReadResult process(AudioBuffer buffer, bool isEnd) {
    final floatList = buffer.asFloat32ListView();

    // Calculating filter coefficients
    // Following Coefficients and Transfer Functions are adapted from Audio-EQ-Cookbook.
    // Learn more at https://www.w3.org/TR/audio-eq-cookbook/
    w0 = 2 * pi * centerFreq / format.sampleRate;
    alpha = sin(w0) / (2 * qFactor);
    A = pow(10.0, (gain / 40)).toDouble();

    b0 = 1 + (alpha * A);
    b1 = -2 * cos(w0);
    b2 = 1 - (alpha * A);
    a0 = 1 + (alpha / A);
    a1 = b1;
    a2 = 1 - (alpha / A);

    // Gain Ratio Variable for preventing Clipping.
    //gainRatio = pow(10.0, (gain.abs() / 20)).toDouble();

    // Process each sample
    for(int frame = 0; frame < buffer.sizeInFrames; frame++) {
      for (var channel = 0; format.channels > channel; channel++) {
        final inputBufferIndex = (frame * format.channels) + channel;

        // Dividing by gainRatio to prevent clipping.
        //x = floatList[inputBufferIndex] / gainRatio;

        // Calculate output sample
        y = (b0/a0)*x + (b1/a0)*_x1 + (b2/a0)*_x2 - (a1/a0)*_y1 - (a2/a0)*_y2;

        // Update the state variables
        _x2 = _x1;
        _x1 = x;
        _y2 = _y1;
        _y1 = y;

        // Update the buffer data
        floatList[inputBufferIndex] = y;
      }
    }

    return AudioReadResult(frameCount: buffer.sizeInFrames, isEnd: false);
  }
}