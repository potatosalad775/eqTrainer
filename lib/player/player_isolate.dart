import 'dart:async';
import 'dart:io';
import 'package:coast_audio/coast_audio.dart';
import 'package:coast_audio/experimental.dart';
import 'package:eq_trainer/player/peaking_eq_filter.dart';
import 'package:eq_trainer/player/peaking_eq_node.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

sealed class PlayerHostRequest {
  const PlayerHostRequest();
}

class PlayerHostRequestStart extends PlayerHostRequest {
  const PlayerHostRequestStart();
}

class PlayerHostRequestPause extends PlayerHostRequest {
  const PlayerHostRequestPause();
}

class PlayerHostRequestSeek extends PlayerHostRequest {
  const PlayerHostRequestSeek({
    required this.position,
  });
  final AudioTime position;
}

class PlayerHostRequestSetVolume extends PlayerHostRequest {
  const PlayerHostRequestSetVolume({
    required this.volume,
  });
  final double volume;
}

class PlayerHostRequestGetPosition extends PlayerHostRequest {
  const PlayerHostRequestGetPosition();
}

class PlayerHostRequestGetDuration extends PlayerHostRequest {
  const PlayerHostRequestGetDuration();
}

class PlayerHostRequestGetState extends PlayerHostRequest {
  const PlayerHostRequestGetState();
}

class PlayerHostRequestSetEQ extends PlayerHostRequest {
  const PlayerHostRequestSetEQ({
    required this.enableEQ,
  });
  final bool enableEQ;
}

class PlayerHostRequestSetEQGain extends PlayerHostRequest {
  const PlayerHostRequestSetEQGain({
    required this.gainDb,
  });
  final double gainDb;
}

class PlayerHostRequestSetEQFreq extends PlayerHostRequest {
  const PlayerHostRequestSetEQFreq({
    required this.frequency,
  });
  final double frequency;
}

class PlayerHostRequestGetEqState extends PlayerHostRequest {
  const PlayerHostRequestGetEqState();
}

class PlayerStateResponse extends Equatable {
  const PlayerStateResponse({
    required this.isPlaying,
    required this.outputFormat,
  });
  final bool isPlaying;
  final AudioFormat outputFormat;

  @override
  List<Object?> get props => [isPlaying, outputFormat.sampleRate, outputFormat.channels, outputFormat.sampleFormat];
}

class PlayerPositionResponse extends Equatable {
  const PlayerPositionResponse({
    required this.position,
    required this.duration,
  });
  final AudioTime position;
  final AudioTime duration;

  @override
  List<Object?> get props => [position, duration];
}

class _PlayerMessage {
  const _PlayerMessage({
    required this.backend,
    required this.outputDeviceId,
    required this.path,
    required this.content,
  });
  final AudioDeviceBackend backend;
  final AudioDeviceId? outputDeviceId;
  final String? path;
  final Uint8List? content;
}

/// A player isolate that plays audio from a file or buffer.
class PlayerIsolate extends ChangeNotifier {
  PlayerIsolate();
  final _isolate = AudioIsolate<_PlayerMessage>(_worker);

  bool get isLaunched => _isolate.isLaunched;

  Future<void> launch({
    required AudioDeviceBackend backend,
    required AudioDeviceId? outputDeviceId,
    required String? path,
  }) async {
    await _isolate.launch(
      initialMessage: _PlayerMessage(
        backend: backend,
        outputDeviceId: outputDeviceId,
        path: path,
        content: null,
      ),
    );
    _startPlayerStateUpdateTimer(milliseconds: 200);
  }

  Future<void> attach() {
    return _isolate.attach();
  }

  Future<void> shutdown() {
    _playerStateUpdateTimer?.cancel();
    return _isolate.shutdown();
  }

  Future<void> play() {
    return _isolate.request(const PlayerHostRequestStart());
  }

  Future<void> pause() {
    return _isolate.request(const PlayerHostRequestPause());
  }

  Future<PlayerPositionResponse?> seek(AudioTime position) {
    return _isolate.request(PlayerHostRequestSeek(position: position));
  }

  Future<void> setVolume(double volume) {
    return _isolate.request(PlayerHostRequestSetVolume(volume: volume));
  }

  Future<void> setEQ(bool enableEQ) {
    return _isolate.request(PlayerHostRequestSetEQ(enableEQ: enableEQ));
  }

  Future<void> setEQGain(double gainDb) {
    return _isolate.request(PlayerHostRequestSetEQGain(gainDb: gainDb));
  }

  Future<void> setEQFreq(double frequency) {
    return _isolate.request(PlayerHostRequestSetEQFreq(frequency: frequency));
  }

  Future<PlayerStateResponse?> getState() {
    return _isolate.request(const PlayerHostRequestGetState());
  }

  Future<AudioTime?> getPosition() {
    return _isolate.request(const PlayerHostRequestGetPosition());
  }

  Future<AudioTime?> getDuration() {
    return _isolate.request(const PlayerHostRequestGetDuration());
  }

  Future<bool?> getEqState() {
    return _isolate.request(const PlayerHostRequestGetEqState());
  }

  Timer? _playerStateUpdateTimer;

  void _startPlayerStateUpdateTimer({required int milliseconds}) {
    _playerStateUpdateTimer = Timer.periodic(Duration(milliseconds: milliseconds), (_) {
      _playerStateUpdate();
    });
  }

  PlayerStateResponse? _lastState;
  AudioTime? _lastPosition;
  AudioTime? _lastDuration;
  bool? _lastEQState;

  void _playerStateUpdate() async {
    if(!isLaunched) return;
    final results = await Future.wait([
      getState(),
      getPosition(),
      getDuration(),
      getEqState(),
    ]);

    if(results[0] != null && results[0] != _lastState) _lastState = results[0] as PlayerStateResponse?;
    if(results[1] != null && results[1] != _lastPosition) _lastPosition = results[1] as AudioTime?;
    if(results[2] != null && results[2] != _lastDuration) _lastDuration = results[2] as AudioTime?;
    if(results[3] != null && results[3] != _lastEQState) _lastEQState = results[3] as bool?;

    notifyListeners();
  }

  PlayerStateResponse get fetchPlayerState => _lastState ?? const PlayerStateResponse(
      isPlaying: false,
      outputFormat: AudioFormat(sampleRate: 0, channels: 0)
  );
  AudioTime get fetchPosition => _lastPosition ?? AudioTime.zero;
  AudioTime get fetchDuration => _lastDuration ?? AudioTime.zero;
  bool get fetchEQState => _lastEQState ?? false;

  // The worker function used to initialize the audio player in the isolate
  static Future<void> _worker(dynamic initialMessage, AudioIsolateWorkerMessenger messenger) async {
    AudioResourceManager.isDisposeLogEnabled = true;

    final message = initialMessage as _PlayerMessage;

    // Initialize the audio player with the specified file or buffer
    final AudioInputDataSource dataSource;
    if (message.path != null) {
      dataSource = AudioFileDataSource(file: File(message.path!), mode: FileMode.read);
    } else {
      dataSource = AudioMemoryDataSource(buffer: message.content!);
    }

    final player = AudioPlayer(
      context: AudioDeviceContext(backends: [message.backend]),
      decoder: MaAudioDecoder(dataSource: dataSource),
      initialDeviceId: message.outputDeviceId,
    );

    messenger.listenRequest<PlayerHostRequest>(
          (request) {
        switch (request) {
          case PlayerHostRequestStart():
            player.play();
          case PlayerHostRequestPause():
            player.pause();
          case PlayerHostRequestSetVolume():
            player.volume = request.volume;
          case PlayerHostRequestSeek():
            player.position = request.position;
            return player.getPosition();
          case PlayerHostRequestGetState():
            return player.getState();
          case PlayerHostRequestGetPosition():
            return player.position;
          case PlayerHostRequestGetDuration():
            return player.duration;
          case PlayerHostRequestSetEQ():
            player.setEQ(request.enableEQ);
          case PlayerHostRequestSetEQGain():
            player.setEQGain(request.gainDb);
          case PlayerHostRequestSetEQFreq():
            player.setEQFreq(request.frequency);
          case PlayerHostRequestGetEqState():
            return player.getEqState();
        }
      },
    );

    // Wait for the isolate to be shutdown
    await messenger.listenShutdown();
  }
}

class AudioPlayer {
  AudioPlayer({
    required this.context,
    required AudioDecoder decoder,
    this.bufferDuration = const AudioTime(1.0),
    AudioDeviceId? initialDeviceId,
  })  : _decoderNode = DecoderNode(decoder: decoder),
        _peakingEQNode = PeakingEQNode(
            format: decoder.outputFormat,
            filter: PeakingEQFilter(
                format: decoder.outputFormat,
                gainDb: 6,
                q: 1,
                frequency: 300
            )
        ),
        _playbackNode = PlaybackNode(
          device: context.createPlaybackDevice(
            format: decoder.outputFormat,
            bufferFrameSize: bufferDuration.computeFrames(decoder.outputFormat),
            deviceId: initialDeviceId,
          ),
        ) {
    _decoderNode.outputBus.connect(_peakingEQNode.inputBus);
    _peakingEQNode.outputBus.connect(_playbackNode.inputBus);
    _peakingEQNode.bypass = true;
    _playbackNode.device.notification.listen((notification) {
      //print('[AudioPlayer#${_playbackNode.device.resourceId}] Notification(type: ${notification.type.name}, state: ${notification.state.name})');
    });
  }

  // The AudioDeviceContext is used to create the playback device on the specified backend(platform)
  final AudioDeviceContext context;

  final AudioTime bufferDuration;

  final DecoderNode _decoderNode;

  final PeakingEQNode _peakingEQNode;

  final PlaybackNode _playbackNode;

  bool get isPlaying => _playbackNode.device.isStarted;

  double get volume => _playbackNode.device.volume;

  set volume(double value) {
    _playbackNode.device.volume = value;
  }

  /// Get the current playback time
  AudioTime get position {
    return AudioTime.fromFrames(
      _decoderNode.decoder.cursorInFrames - _playbackNode.device.availableReadFrames,
      format: _decoderNode.decoder.outputFormat,
    );
  }

  /// Set the current playback time
  set position(AudioTime value) {
    // Set the cursor in the decoder to the specified position
    _decoderNode.decoder.cursorInFrames = value.computeFrames(_decoderNode.decoder.outputFormat);

    // Clear the playback device's buffer to prevent old audio data from being played
    _playbackNode.device.clearBuffer();
  }

  AudioTime get duration {
    return AudioTime.fromFrames(
      _decoderNode.decoder.lengthInFrames!,
      format: _decoderNode.decoder.outputFormat
    );
  }

  // Get the current playback state
  PlayerStateResponse getState() {
    return PlayerStateResponse(
      isPlaying: isPlaying,
      outputFormat: _decoderNode.decoder.outputFormat,
    );
  }

  PlayerPositionResponse getPosition() {
    return PlayerPositionResponse(
      position: position,
      duration: AudioTime.fromFrames(_decoderNode.decoder.lengthInFrames!, format: _decoderNode.decoder.outputFormat),
    );
  }

  void play() {
    if (isPlaying) {
      return;
    }

    _playbackNode.device.start();

    // runWithBuffer is a helper method that runs the specified callback with the audio buffer
    // This code will run the callback every 0.9 seconds and read the audio data from the decoder
    AudioIntervalClock(AudioTime(bufferDuration.seconds * 0.9)).runWithBuffer(
      frames: AllocatedAudioFrames(
        length: bufferDuration.computeFrames(_decoderNode.decoder.outputFormat),
        format: _decoderNode.decoder.outputFormat,
      ),
      onTick: (_, buffer) {
        final result = _playbackNode.outputBus.read(buffer);
        if (result.isEnd) {
          return false;
        }

        if (!_playbackNode.device.isStarted) {
          return false;
        }

        return true;
      },
    );
  }

  void pause() {
    _playbackNode.device.stop();
  }

  void setEQ(bool value) {
    _peakingEQNode.bypass = !value;
  }

  void setEQGain(double value) {
    _peakingEQNode.filter.update(gainDb: value);
  }

  void setEQFreq(double value) {
    _peakingEQNode.filter.update(frequency: value);
  }

  bool getEqState() {
    return !_peakingEQNode.bypass;
  }
}