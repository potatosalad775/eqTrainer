import 'package:flutter/foundation.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'isolated_player_state.freezed.dart';

@freezed
class IsolatedPlayerState with _$IsolatedPlayerState {
  const factory IsolatedPlayerState({
    required AudioFormat format,
    required String? filePath,
    required double volume,
    required AudioTime duration,
    required AudioTime position,
    required MabAudioPlayerState state,
    required bool pEQState,
  }) = _IsolatedPlayerState;
}

class IsolatedPlayerReroutedState {
  const IsolatedPlayerReroutedState(this.deviceInfo);
  final DeviceInfo<dynamic>? deviceInfo;
}

class IsolatedPlayerDeviceState {
  const IsolatedPlayerDeviceState(this.deviceInfo);
  final DeviceInfo<dynamic>? deviceInfo;
}