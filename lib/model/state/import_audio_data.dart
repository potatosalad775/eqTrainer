import 'package:flutter/foundation.dart';
import 'package:coast_audio/coast_audio.dart';

class ImportAudioData extends ChangeNotifier {
  AudioTime _clipStartTime = AudioTime.zero;
  AudioTime _clipEndTime = const AudioTime(double.maxFinite);

  AudioTime get clipStartTime => _clipStartTime;
  AudioTime get clipEndTime => _clipEndTime;

  set clipStartTime(AudioTime value) {
    _clipStartTime = value;
    notifyListeners();
  }

  set clipEndTime(AudioTime value) {
    _clipEndTime = value;
    notifyListeners();
  }

  void initEndTime(AudioTime value) {
    _clipEndTime = value;
  }
}

