import 'dart:math';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:eq_trainer/main.dart';

class ParametricEQNode extends AutoFormatSingleInoutNode with ProcessorNodeMixin, BypassNodeMixin {
  ParametricEQNode({
    required this.format,
    required this.pEQNodeRunState,
    required this.gain,
    required this.centerFreq,
  });

  final AudioFormat format;
  bool pEQNodeRunState;
  int gain;
  double centerFreq;

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
  List<SampleFormat> get supportedSampleFormats => const [SampleFormat.float32];

  @override
  int process(AudioBuffer buffer) {
    final inputData = buffer.asFloat32ListView();

    // Calculating filter coefficients
    // Following Coefficients and Transfer Functions are adapted from Audio-EQ-Cookbook.
    // Learn more at https://www.w3.org/TR/audio-eq-cookbook/
    w0 = 2 * pi * centerFreq / format.sampleRate;
    alpha = sin(w0) / (2 * mainSessionData.qFactor);
    A = pow(10.0, (gain / 40)).toDouble();

    b0 = 1 + (alpha * A);
    b1 = -2 * cos(w0);
    b2 = 1 - (alpha * A);
    a0 = 1 + (alpha / A);
    a1 = b1;
    a2 = 1 - (alpha / A);

    // Gain Ratio Variable for preventing Clipping.
    gainRatio = pow(10.0, (gain.abs() / 20)).toDouble();

    if(pEQNodeRunState) {
      // Process each sample
      for(int frame = 0; frame < buffer.sizeInFrames; frame++) {
        for (var channel = 0; format.channels > channel; channel++) {
          final inputBufferIndex = (frame * format.channels) + channel;

          // Dividing by gainRatio to prevent clipping.
          x = inputData[inputBufferIndex] / gainRatio;

          // Calculate output sample
          y = (b0/a0)*x + (b1/a0)*_x1 + (b2/a0)*_x2 - (a1/a0)*_y1 - (a2/a0)*_y2;

          // Update the state variables
          _x2 = _x1;
          _x1 = x;
          _y2 = _y1;
          _y1 = y;

          // Update the buffer data
          inputData[inputBufferIndex] = y;
        }
      }
    }
    else {
      // Process each sample
      for(int frame = 0; frame < buffer.sizeInFrames; frame++) {
        for (var channel = 0; format.channels > channel; channel++) {
          final inputBufferIndex = (frame * format.channels) + channel;

          // Dividing by gainRatio to prevent clipping.
          x = inputData[inputBufferIndex] / gainRatio;

          // Update the buffer data
          inputData[inputBufferIndex] = x;
        }
      }
    }
    return buffer.sizeInFrames;
  }
}