import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:eq_trainer/player/parametric_eq_node.dart';
import 'package:eq_trainer/main.dart';

class MusicPlayer extends MabAudioPlayer {
  static const _pEQNodeId = 'PRMTRC_EQ_NODE';

  MusicPlayer({
    super.format,
    super.bufferFrameSize = 4096,
    this.onRerouted,
  }) {
    notificationStream.listen((notification) {
      if (notification.type == MabDeviceNotificationType.rerouted) {
        onRerouted?.call();
      }
    });
  }

  VoidCallback? onRerouted;

  Future<void> openFile(File file) async {
    final disposableBag = DisposableBag();
    final dataSource = AudioFileDataSource(file: file, mode: FileMode.read)..disposeOn(disposableBag);
    final decoder = MabAudioDecoder(
      dataSource: dataSource,
      outputFormat: format,
    );

    await open(decoder, disposableBag);
    _filePath = file.path;
  }

  @override
  void connectDecoderToVolume(
    AudioGraphBuilder builder, {
    required String decoderNodeId,
    required int decoderNodeBusIndex,
    required String volumeNodeId,
    required int volumeNodeBusIndex,
  }) {
    builder
      ..addNode(id: _pEQNodeId, node: pEQNode)
      ..connect(outputNodeId: decoderNodeId, outputBusIndex: decoderNodeBusIndex, inputNodeId: _pEQNodeId, inputBusIndex: 0)
      ..connect(outputNodeId: _pEQNodeId, outputBusIndex: 0, inputNodeId: volumeNodeId, inputBusIndex: volumeNodeBusIndex);
  }

  void setEQ(bool value) {
    pEQNode.pEQNodeRunState = value;
    return;
  }

  void setEQGain(int gain) {
    pEQNode.gain = gain;
    return;
  }

  void setEQCenterFreq(double centerFreq) {
    pEQNode.centerFreq = centerFreq;
    return;
  }

  String? _filePath;
  String? get filePath => _filePath;

  var pEQNode = ParametricEQNode(
    format: mainFormat,
    gain: 6,
    centerFreq: 20,
    pEQNodeRunState: false,
  );

  bool get pEQState => pEQNode.pEQNodeRunState;
}