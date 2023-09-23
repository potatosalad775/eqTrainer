import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/setting_data.dart';
import 'package:eq_trainer/player/isolated_player_command.dart';
import 'package:eq_trainer/player/isolated_player_state.dart';
import 'package:eq_trainer/player/music_player.dart';

class _IsolatedPlayerInitialMessage {
  _IsolatedPlayerInitialMessage({
    required this.format,
    required this.sendPort,
    required this.rootIsolateToken,
    required this.androidAudioBackend,
  });
  final AudioFormat format;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;
  final AndroidAudioBackend androidAudioBackend;
}

void _playerRunner(_IsolatedPlayerInitialMessage message) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(message.rootIsolateToken);
  MabLibrary.initialize();
  if(message.androidAudioBackend == AndroidAudioBackend.opensl) {
    MabDeviceContext.enableSharedInstance(backends: backendsOPENSL);
  }
  else {
    MabDeviceContext.enableSharedInstance(backends: backendsAAUDIO);
  }

  final sendPort = message.sendPort;

  late final VoidCallback sendState;

  late final MusicPlayer player;
  try {
    player = MusicPlayer(
      format: message.format,
      onRerouted: () {
        sendPort.send(IsolatedPlayerReroutedState(player.device));
      },
      onOutput: (_, __) {
        sendState();
      }
    );
  } on Object catch (e) {
    debugPrint(e.toString());
    rethrow;
  }

  sendState = () {
    sendPort.send(
      IsolatedPlayerState(
        format: player.format,
        filePath: player.filePath,
        position: player.position,
        duration: player.duration,
        volume: player.volume,
        state: player.state,
        pEQState: player.pEQState,
      ),
    );
  };

  player.stateStream.listen((_) {
    sendState();
  });

  player.notificationStream.listen((_) {
    sendState();
  });

  final receivePort = ReceivePort();
  message.sendPort.send(receivePort.sendPort);

  receivePort.listen((command) async {
    final cmd = command as IsolatedPlayerCommand;
    return cmd.when<FutureOr<void>>(
      open: (filePath) async {
        await player.openFile(File(filePath));
        sendPort.send(IsolatedPlayerDeviceState(player.device));
        sendState();
      },
      play: () {
        player.play();
        sendState();
      },
      pause: () {
        player.pause();
        sendState();
      },
      stop: () {
        player.stop();
        sendState();
      },
      setVolume: (v) {
        player.volume = v;
        sendState();
      },
      setPosition: (p) {
        player.position = p;
        sendState();
      },
      setDevice: (d) {
        player.device = d;
        sendPort.send(IsolatedPlayerDeviceState(player.device));
        sendState();
      },
      dispose: () {
        player.stop();
        player.dispose();
        MabDeviceContext.sharedInstance.dispose();
        receivePort.close();
      },
      setEQ: (value) {
        player.setEQ(value);
      },
      setEQGain: (gain) {
        player.setEQGain(gain);
      },
      setEQCenterFreq: (centerFreq) {
        player.setEQCenterFreq(centerFreq);
      },
    );
  });
}

class IsolatedMusicPlayer extends ChangeNotifier {
  IsolatedMusicPlayer({
    required this.format,
    this.onRerouted,
  }) {
    Isolate.spawn<_IsolatedPlayerInitialMessage>(
      _playerRunner,
      _IsolatedPlayerInitialMessage(
        format: format,
        sendPort: _receivePort.sendPort,
        rootIsolateToken: ServicesBinding.rootIsolateToken!,
        androidAudioBackend: (androidAudioBackend == null) ? AndroidAudioBackend.opensl : androidAudioBackend!,
      ),
      errorsAreFatal: false,
    );

    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort.complete(message);
      } else if (message is IsolatedPlayerState) {
        _lastState = message;
        notifyListeners();
      } else if (message is IsolatedPlayerDeviceState) {
        _device = message.deviceInfo;
        notifyListeners();
      } else if (message is IsolatedPlayerReroutedState) {
        onRerouted?.call();
        _device = message.deviceInfo;
        notifyListeners();
      }
    });
  }

  final _receivePort = ReceivePort();
  final _sendPort = Completer<SendPort>();

  IsolatedPlayerState? _lastState;
  DeviceInfo? _device;

  VoidCallback? onRerouted;

  AudioTime? get duration => _lastState?.duration;

  String? get filePath => _lastState?.filePath;

  final AudioFormat format;

  set device(DeviceInfo<dynamic>? device) {
    _sendPort.future.then((port) => port.send(IsolatedPlayerCommand.setDevice(deviceInfo: device)));
  }

  set position(AudioTime position) {
    _sendPort.future.then((port) => port.send(IsolatedPlayerCommand.setPosition(position: position)));
  }

  set volume(double volume) {
    _sendPort.future.then((port) => port.send(IsolatedPlayerCommand.setVolume(volume: volume)));
  }

  DeviceInfo<dynamic>? get device => _device;

  AudioTime get position => _lastState?.position ?? AudioTime.zero;

  double get volume => _lastState?.volume ?? 1;

  MabAudioPlayerState get state => _lastState?.state ?? MabAudioPlayerState.stopped;

  bool get pEQState => _lastState?.pEQState ?? false;

  Future<void> open(String filePath) async {
    final sendPort = await _sendPort.future;
    sendPort.send(IsolatedPlayerCommand.open(filePath: filePath));
  }

  Future<void> play() async {
    if (Platform.isIOS || Platform.isAndroid) {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        ),
      );
      await session.setActive(true);
    }

    final sendPort = await _sendPort.future;
    sendPort.send(const IsolatedPlayerCommand.play());
  }

  Future<void> pause() async {
    final sendPort = await _sendPort.future;
    sendPort.send(const IsolatedPlayerCommand.pause());
  }

  Future<void> stop() async {
    final sendPort = await _sendPort.future;
    sendPort.send(const IsolatedPlayerCommand.stop());
  }

  Future<void> setEQ(bool value) async {
    final sendPort = await _sendPort.future;
    sendPort.send(IsolatedPlayerCommand.setEQ(value: value));
  }

  Future<void> setEQGain(double gain) async {
    final sendPort = await _sendPort.future;
    sendPort.send(IsolatedPlayerCommand.setEQGain(gain: gain));
  }

  Future<void> setEQCenterFreq(double centerFreq) async {
    final sendPort = await _sendPort.future;
    sendPort.send(IsolatedPlayerCommand.setEQCenterFreq(centerFreq: centerFreq));
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    final sendPort = await _sendPort.future;
    sendPort.send(const IsolatedPlayerCommand.dispose());
    _receivePort.close();
  }
}
