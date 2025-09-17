import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:coast_audio/experimental.dart';
import 'package:eq_trainer/shared/player/peaking_eq_filter.dart';
import 'package:eq_trainer/shared/player/peaking_eq_node.dart';

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
  List<Object?> get props => [
        isPlaying,
        outputFormat.sampleRate,
        outputFormat.channels,
        outputFormat.sampleFormat
      ];
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
  // Add a constant for the state update interval
  static const int _stateUpdateIntervalMs = 500;

  PlayerIsolate();
  final _isolate = AudioIsolate<_PlayerMessage>(_worker);

  bool get isLaunched => _isolate.isLaunched;
  Timer? _playerStateUpdateTimer;

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
    // Use the defined constant for timer interval
    _startPlayerStateUpdateTimer(milliseconds: _stateUpdateIntervalMs);
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

  void _startPlayerStateUpdateTimer({required int milliseconds}) {
    _playerStateUpdateTimer?.cancel();
    _playerStateUpdateTimer =
        Timer.periodic(Duration(milliseconds: milliseconds), (_) {
      _playerStateUpdate();
    });
  }

  PlayerStateResponse? _lastState;
  AudioTime? _lastPosition;
  AudioTime? _lastDuration;
  bool? _lastEQState;

  void _playerStateUpdate() async {
    if (!isLaunched) return;
    final results = await Future.wait([
      getState(),
      getPosition(),
      getDuration(),
      getEqState(),
    ]);

    bool shouldNotify = false;

    if (results[0] != null && results[0] != _lastState) {
      _lastState = results[0] as PlayerStateResponse?;
      shouldNotify = true;
    }
    if (results[1] != null && results[1] != _lastPosition) {
      _lastPosition = results[1] as AudioTime?;
      shouldNotify = true;
    }
    if (results[2] != null && results[2] != _lastDuration) {
      _lastDuration = results[2] as AudioTime?;
      shouldNotify = true;
    }
    if (results[3] != null && results[3] != _lastEQState) {
      _lastEQState = results[3] as bool?;
      shouldNotify = true;
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  PlayerStateResponse get fetchPlayerState =>
      _lastState ??
      const PlayerStateResponse(
          isPlaying: false,
          outputFormat: AudioFormat(sampleRate: 0, channels: 0));
  AudioTime get fetchPosition => _lastPosition ?? AudioTime.zero;
  AudioTime get fetchDuration => _lastDuration ?? AudioTime.zero;
  bool get fetchEQState => _lastEQState ?? false;

  // The worker function used to initialize the audio player in the isolate
  static Future<void> _worker(
      dynamic initialMessage, AudioIsolateWorkerMessenger messenger) async {
    AudioResourceManager.isDisposeLogEnabled = true;

    final message = initialMessage as _PlayerMessage;

    // Initialize the audio player with the specified file or buffer
    final AudioInputDataSource dataSource;
    dataSource =
        AudioFileDataSource(file: File(message.path!), mode: FileMode.read);

    final player = AudioPlayer.findDecoder(
      backend: message.backend,
      dataSource: dataSource,
      deviceId: message.outputDeviceId,
    );

    messenger.listenRequest<PlayerHostRequest>(
      (request) {
        switch (request) {
          case PlayerHostRequestStart():
            player.play();
            break;
          case PlayerHostRequestPause():
            player.pause();
            break;
          case PlayerHostRequestSetVolume():
            player.volume = request.volume;
            break;
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
            break;
          case PlayerHostRequestSetEQGain():
            player.setEQGain(request.gainDb);
            break;
          case PlayerHostRequestSetEQFreq():
            player.setEQFreq(request.frequency);
            break;
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
    this.bufferDuration = const AudioTime(0.25),
    // Chunk size for adaptive feeding (tunable: 2048~8192)
    this.chunkFrames = 4096,
    AudioDeviceId? initialDeviceId,
  })  : _decoderNode = DecoderNode(decoder: decoder),
        _volumeNode = VolumeNode(volume: 0.9),
        _peakingEQNode = PeakingEQNode(
            format: decoder.outputFormat,
            filter: PeakingEQFilter(
                format: decoder.outputFormat, gainDb: 6, q: 1, frequency: 300)),
        _playbackNode = PlaybackNode(
          device: context.createPlaybackDevice(
            format: decoder.outputFormat,
            bufferFrameSize: bufferDuration.computeFrames(decoder.outputFormat),
            deviceId: initialDeviceId,
          ),
        ) {
    // Build processing graph with a pre-decode ring buffer source in place of the decoder.
    // Decoder is now pulled by a background pump and feeds the ring; playback path reads from the ring.
    _ringBuffer = FrameRingBuffer(
      capacity: _ringCapacityFrames(decoder.outputFormat),
      format: decoder.outputFormat,
    );
    _ringSourceNode =
        _RingBufferSourceNode(ring: _ringBuffer, format: decoder.outputFormat);

    _ringSourceNode.outputBus.connect(_volumeNode.inputBus);
    _volumeNode.outputBus.connect(_peakingEQNode.inputBus);
    _peakingEQNode.outputBus.connect(_playbackNode.inputBus);
    _peakingEQNode.bypass = true;
    // Underrun/xrun logging
    _playbackNode.device.notification.listen((notification) {
      debugPrint(
          '[AudioPlayer#${_playbackNode.device.resourceId}] Notification(type: ${notification.type.name}, state: ${notification.state.name})');
      final t = notification.type.name.toLowerCase();
      if (t.contains('xrun') || t.contains('underrun')) {
        _underrunCount++;
        debugPrint('[AudioPlayer] XRUN/Underrun count: $_underrunCount');
      }
    });
  }

  factory AudioPlayer.findDecoder({
    required AudioDeviceBackend backend,
    required AudioInputDataSource dataSource,
    AudioDeviceId? deviceId,
  }) {
    // Find the decoder by trying to decode the audio data with different decoders
    AudioDecoder decoder;
    try {
      decoder = WavAudioDecoder(dataSource: dataSource);
    } on Exception catch (_) {
      try {
        decoder = MaAudioDecoder(dataSource: dataSource);
      } on Exception catch (e) {
        throw Exception('Could not find the decoder.\nInner exception: $e');
      }
    }

    return AudioPlayer(
      context: AudioDeviceContext(backends: [backend]),
      decoder: decoder,
      initialDeviceId: deviceId,
    );
  }

  // The AudioDeviceContext is used to create the playback device on the specified backend(platform)
  final AudioDeviceContext context;

  final AudioTime bufferDuration;

  // Adaptive feeding chunk size (frames)
  final int chunkFrames;

  final DecoderNode _decoderNode;

  final VolumeNode _volumeNode;

  final PeakingEQNode _peakingEQNode;

  final PlaybackNode _playbackNode;

  // Cached chunk buffer to minimize reallocation
  AllocatedAudioFrames? _chunkBuffer;

  // Separate decode chunk buffer for background decoding
  AllocatedAudioFrames? _decodeChunkBuffer;

  // Pre-decode ring buffer and source node
  late final FrameRingBuffer _ringBuffer;
  late final _RingBufferSourceNode _ringSourceNode;

  // Cached total device buffer capacity in frames
  int? _deviceBufferCapacityFrames;

  // Simple underrun counter
  int _underrunCount = 0;

  bool get isPlaying => _playbackNode.device.isStarted;

  double get volume => _playbackNode.device.volume;

  set volume(double value) {
    _playbackNode.device.volume = value;
  }

  /// Get the current playback time
  AudioTime get position {
    // Estimate played frames = decoded so far - (ring buffered + device queued)
    final decoded = _decoderNode.decoder.cursorInFrames;
    final ringBuffered = _ringBuffer.length;
    final deviceQueued = _playbackNode.device.availableReadFrames;
    final played = decoded - ringBuffered - deviceQueued;
    final frames = played.clamp(0, decoded);
    return AudioTime.fromFrames(
      frames,
      format: _decoderNode.decoder.outputFormat,
    );
  }

  /// Set the current playback time
  set position(AudioTime value) {
    // Set the cursor in the decoder to the specified position
    _decoderNode.decoder.cursorInFrames =
        value.computeFrames(_decoderNode.decoder.outputFormat);

    // Clear the playback device's buffer to prevent old audio data from being played
    _playbackNode.device.clearBuffer();
    // Also clear pre-decoded ring buffer and reset EOF state so new data is decoded
    _ringBuffer.clear();
    _ringSourceNode.decodeFinished = false;
  }

  AudioTime get duration {
    return AudioTime.fromFrames(_decoderNode.decoder.lengthInFrames!,
        format: _decoderNode.decoder.outputFormat);
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
      duration: AudioTime.fromFrames(_decoderNode.decoder.lengthInFrames!,
          format: _decoderNode.decoder.outputFormat),
    );
  }

  void play() {
    if (isPlaying) {
      return;
    }

    try {
      _playbackNode.device.start();
    } catch (e) {
      debugPrint("Error while starting device : $e");
      throw Exception('DeviceInitException : $e');
    }

    // Calculate device buffer capacity in frames using the current decoder output format
    final int capacityFrames =
        bufferDuration.computeFrames(_decoderNode.decoder.outputFormat);
    _deviceBufferCapacityFrames = capacityFrames;

    // Prepare or resize chunk buffer for adaptive feeding
    final int framesPerChunk = chunkFrames;
    if (_chunkBuffer == null ||
        _chunkBuffer!.sizeInFrames != framesPerChunk ||
        _chunkBuffer!.format != _decoderNode.decoder.outputFormat) {
      _chunkBuffer = AllocatedAudioFrames(
          length: framesPerChunk, format: _decoderNode.decoder.outputFormat);
    }

    // Prepare or resize decode chunk buffer
    if (_decodeChunkBuffer == null ||
        _decodeChunkBuffer!.sizeInFrames != framesPerChunk ||
        _decodeChunkBuffer!.format != _decoderNode.decoder.outputFormat) {
      _decodeChunkBuffer = AllocatedAudioFrames(
          length: framesPerChunk, format: _decoderNode.decoder.outputFormat);
    }

    // Reset ring EOF state
    _ringSourceNode.decodeFinished = false;

    // Quick prefill: decode ahead into ring up to ~80% capacity (non-blocking-ish loop)
    final int prefillTarget = (_ringBuffer.capacity * 0.8).floor();
    int safety = 0;
    while (_ringBuffer.length < prefillTarget && safety < 64) {
      final frames = _decodeChunkBuffer!;
      final buffer = frames.lock();
      final res = _decoderNode.outputBus.read(buffer);
      if (res.frameCount > 0) {
        final wrote = _ringBuffer.write(buffer.limit(res.frameCount));
        if (wrote <= 0) {
          frames.unlock();
          break; // ring full or cannot write
        }
      }
      frames.unlock();
      if (res.isEnd) {
        _ringSourceNode.decodeFinished = true;
        break;
      }
      safety++;
    }

    // Short tick (10ms) and adaptive while-fill based on available write frames
    AudioIntervalClock(const AudioTime(0.01)).runWithBuffer(
      frames: _chunkBuffer!,
      onTick: (_, buffer) {
        if (!_playbackNode.device.isStarted) {
          return false; // stop clock when paused/stopped
        }

        // Compute available space in device buffer (capacity - currently queued frames)
        final availableRead = _playbackNode.device.availableReadFrames;
        final capacity = _deviceBufferCapacityFrames ?? capacityFrames;
        var availableWrite = capacity - availableRead;

        // Keep the device buffer around ~90% full; leave small headroom
        final targetFill = (capacity * 0.9).floor();
        availableWrite = (targetFill - availableRead).clamp(0, capacity);

        while (availableWrite >= buffer.sizeInFrames) {
          final result = _playbackNode.outputBus.read(buffer);
          if (result.isEnd) {
            return false; // end of stream
          }
          availableWrite -= buffer.sizeInFrames;
        }

        // If nothing to write this tick, just continue
        return true;
      },
    );

    // Background decode pump: keep ring buffer filled ahead while device is running
    AudioIntervalClock(const AudioTime(0.01)).runWithBuffer(
      frames: _decodeChunkBuffer!,
      onTick: (_, buffer) {
        if (!_playbackNode.device.isStarted) {
          return false; // stop when paused/stopped
        }

        // Fill up to ~90% of ring capacity each tick to avoid long bursts
        final highWater = (_ringBuffer.capacity * 0.9).floor();
        while (_ringBuffer.length + buffer.sizeInFrames <= highWater) {
          final res = _decoderNode.outputBus.read(buffer);
          if (res.frameCount > 0) {
            final wrote = _ringBuffer.write(buffer.limit(res.frameCount));
            if (wrote <= 0) {
              break;
            }
          }
          if (res.isEnd) {
            _ringSourceNode.decodeFinished = true;
            break;
          }
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
    if (value < 0) {
      _volumeNode.volume = pow(10, (value - 2) / 20.0).toDouble();
    } else {
      _volumeNode.volume = pow(10, (0 - value - 2) / 20.0).toDouble();
    }
    _peakingEQNode.filter.update(gainDb: value);
  }

  void setEQFreq(double value) {
    _peakingEQNode.filter.update(frequency: value);
  }

  bool getEqState() {
    return !_peakingEQNode.bypass;
  }
}

// Compute the ring buffer capacity (in frames) for pre-decoding.
// Default to ~1.5 seconds of audio to absorb decode spikes.
int _ringCapacityFrames(AudioFormat format) {
  return (format.sampleRate * 3) ~/ 2; // 1.5s
}

/// A simple data source node that reads PCM frames from a FrameRingBuffer.
class _RingBufferSourceNode extends DataSourceNode {
  _RingBufferSourceNode({
    required this.ring,
    required AudioFormat format,
  }) : outputFormat = format;

  final FrameRingBuffer ring;

  @override
  final AudioFormat outputFormat;

  // Set to true when decoding reaches EOF. Combined with ring being empty it signals stream end.
  bool decodeFinished = false;

  @override
  AudioReadResult read(AudioOutputBus outputBus, AudioBuffer buffer) {
    final frames = ring.read(buffer, advance: true);
    final isEnd = decodeFinished && frames == 0 && ring.length == 0;
    return AudioReadResult(frameCount: frames, isEnd: isEnd);
  }
}
