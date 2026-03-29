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

class PlayerHostRequestGetAllState extends PlayerHostRequest {
  const PlayerHostRequestGetAllState();
}

class PlayerHostRequestSetEQParams extends PlayerHostRequest {
  const PlayerHostRequestSetEQParams({
    required this.enableEQ,
    required this.frequency,
    required this.gainDb,
  });
  final bool enableEQ;
  final double frequency;
  final double gainDb;
}

class PlayerAllStateResponse {
  const PlayerAllStateResponse({
    required this.playerState,
    required this.position,
    required this.duration,
    required this.eqEnabled,
  });
  final PlayerStateResponse playerState;
  final AudioTime position;
  final AudioTime duration;
  final bool eqEnabled;
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
    this.volumeCompensation = false,
  });
  final AudioDeviceBackend backend;
  final AudioDeviceId? outputDeviceId;
  final String? path;
  final bool volumeCompensation;
}

/// A player isolate that plays audio from a file or buffer.
class PlayerIsolate extends ChangeNotifier {
  static const int _stateUpdateIntervalMs = 50;

  PlayerIsolate();
  final _isolate = AudioIsolate<_PlayerMessage>(_worker);

  bool get isLaunched => _isolate.isLaunched;
  Timer? _playerStateUpdateTimer;
  bool _isUpdating = false;
  bool _eqToggleInFlight = false;
  bool? _pendingEQValue;
  DateTime _eqToggleLastEnd = DateTime(0);

  bool _seekInFlight = false;
  AudioTime? _pendingSeekPosition;
  DateTime _seekLastEnd = DateTime(0);

  Future<void> launch({
    required AudioDeviceBackend backend,
    required AudioDeviceId? outputDeviceId,
    required String? path,
    bool volumeCompensation = false,
  }) async {
    await _isolate.launch(
      initialMessage: _PlayerMessage(
        backend: backend,
        outputDeviceId: outputDeviceId,
        path: path,
        volumeCompensation: volumeCompensation,
      ),
    );
    // Fetch initial state immediately so widgets don't wait for the first tick.
    _playerStateUpdate();
    _startPlayerStateUpdateTimer(milliseconds: _stateUpdateIntervalMs);
  }

  Future<void> attach() {
    return _isolate.attach();
  }

  Future<void> shutdown() async {
    _playerStateUpdateTimer?.cancel();
    if (!_isolate.isLaunched) return;
    await _isolate.shutdown();
  }

  Future<void> play() async {
    await _isolate.request(const PlayerHostRequestStart());
    if (_lastState != null) {
      _lastState = PlayerStateResponse(
          isPlaying: true, outputFormat: _lastState!.outputFormat);
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _isolate.request(const PlayerHostRequestPause());
    if (_lastState != null) {
      _lastState = PlayerStateResponse(
          isPlaying: false, outputFormat: _lastState!.outputFormat);
      notifyListeners();
    }
  }

  Future<PlayerPositionResponse?> seek(AudioTime position) async {
    _lastPosition = position;
    notifyListeners();

    if (_seekInFlight) {
      _pendingSeekPosition = position;
      return null;
    }

    _seekInFlight = true;
    try {
      var result =
          await _isolate.request(PlayerHostRequestSeek(position: position));
      while (_pendingSeekPosition != null) {
        final next = _pendingSeekPosition!;
        _pendingSeekPosition = null;
        result =
            await _isolate.request(PlayerHostRequestSeek(position: next));
      }
      return result;
    } finally {
      _seekInFlight = false;
      _seekLastEnd = DateTime.now();
    }
  }

  Future<void> setVolume(double volume) {
    return _isolate.request(PlayerHostRequestSetVolume(volume: volume));
  }

  Future<void> setEQ(bool enableEQ) async {
    if (_lastEQState == enableEQ) return; // Skip redundant

    _lastEQState = enableEQ;
    notifyListeners(); // Optimistic: UI disables button immediately

    if (_eqToggleInFlight) {
      _pendingEQValue = enableEQ; // Coalesce: remember latest
      return;
    }

    _eqToggleInFlight = true;
    try {
      await _isolate.request(PlayerHostRequestSetEQ(enableEQ: enableEQ));
      // Drain pending (only the last value matters)
      while (_pendingEQValue != null) {
        final next = _pendingEQValue!;
        _pendingEQValue = null;
        if (next != enableEQ) {
          enableEQ = next;
          await _isolate.request(PlayerHostRequestSetEQ(enableEQ: next));
        }
      }
    } finally {
      _eqToggleInFlight = false;
      _eqToggleLastEnd = DateTime.now();
    }
  }

  Future<void> setEQGain(double gainDb) {
    return _isolate.request(PlayerHostRequestSetEQGain(gainDb: gainDb));
  }

  Future<void> setEQFreq(double frequency) {
    return _isolate.request(PlayerHostRequestSetEQFreq(frequency: frequency));
  }

  Future<void> setEQParams({
    required bool enableEQ,
    required double frequency,
    required double gainDb,
  }) async {
    await _isolate.request(PlayerHostRequestSetEQParams(
      enableEQ: enableEQ,
      frequency: frequency,
      gainDb: gainDb,
    ));
    _lastEQState = enableEQ;
    notifyListeners();
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

  Future<PlayerAllStateResponse?> getAllState() {
    return _isolate.request(const PlayerHostRequestGetAllState());
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
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
    if (!isLaunched || _isUpdating || _eqToggleInFlight || _seekInFlight) return;
    // After an EQ toggle, give the audio isolate breathing room for MP3 decoding
    // before resuming polling traffic.
    if (DateTime.now().difference(_eqToggleLastEnd).inMilliseconds < 200) return;
    if (DateTime.now().difference(_seekLastEnd).inMilliseconds < 100) return;
    _isUpdating = true;
    try {
      final all = await getAllState();
      if (all == null) return;

      bool shouldNotify = false;

      if (all.playerState != _lastState) {
        _lastState = all.playerState;
        shouldNotify = true;
      }
      if (all.position != _lastPosition) {
        _lastPosition = all.position;
        shouldNotify = true;
      }
      if (all.duration != _lastDuration) {
        _lastDuration = all.duration;
        shouldNotify = true;
      }
      if (all.eqEnabled != _lastEQState && !_eqToggleInFlight) {
        _lastEQState = all.eqEnabled;
        shouldNotify = true;
      }

      if (shouldNotify) {
        notifyListeners();
      }
    } finally {
      _isUpdating = false;
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
    if (message.path == null) return;
    final AudioInputDataSource dataSource;
    dataSource =
        AudioFileDataSource(file: File(message.path!), mode: FileMode.read);

    final player = AudioPlayer.findDecoder(
      backend: message.backend,
      dataSource: dataSource,
      deviceId: message.outputDeviceId,
      volumeCompensation: message.volumeCompensation,
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
          case PlayerHostRequestGetAllState():
            return PlayerAllStateResponse(
              playerState: player.getState(),
              position: player.position,
              duration: player.duration,
              eqEnabled: player.getEqState(),
            );
          case PlayerHostRequestSetEQParams():
            player.setEQFreq(request.frequency);
            player.setEQGain(request.gainDb);
            player.setEQ(request.enableEQ);
            break;
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
    bool volumeCompensation = false,
  })  : _volumeCompensation = volumeCompensation,
        _decoderNode = DecoderNode(decoder: decoder),
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

    _ringSourceNode.outputBus.connect(_peakingEQNode.inputBus);
    _peakingEQNode.outputBus.connect(_playbackNode.inputBus);
    // EQ filter stays in the chain at all times (no bypass toggle).
    // Gain is set to 0 dB (transparent) until a session round begins.
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
    bool volumeCompensation = false,
  }) {
    // Find the decoder by trying to decode the audio data with different decoders.
    // Order: WAV (pure Dart) → AAC/M4A (FDK-AAC) → miniaudio fallback (MP3, FLAC, etc.)
    AudioDecoder decoder;
    final errors = <String, String>{};
    try {
      decoder = WavAudioDecoder(dataSource: dataSource);
    } on Exception catch (e) {
      errors['WAV'] = e.toString();
      if (dataSource.canSeek) dataSource.position = 0;
      try {
        decoder = AacAudioDecoder(dataSource: dataSource);
      } on Exception catch (e) {
        errors['AAC'] = e.toString();
        if (dataSource.canSeek) dataSource.position = 0;
        try {
          decoder = MaAudioDecoder(dataSource: dataSource);
        } on Exception catch (e) {
          errors['miniaudio'] = e.toString();
          throw Exception(
            'Could not find a suitable decoder.\n'
            'Tried decoders:\n'
            '${errors.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}',
          );
        }
      }
    }

    debugPrint('[AudioPlayer.findDecoder] Selected ${decoder.runtimeType} '
        '(format: ${decoder.outputFormat})');

    final isMobile = Platform.isAndroid || Platform.isIOS;
    return AudioPlayer(
      context: AudioDeviceContext(backends: [backend]),
      decoder: decoder,
      bufferDuration: AudioTime(isMobile ? 0.4 : 0.25),
      chunkFrames: isMobile ? 2048 : 4096,
      initialDeviceId: deviceId,
      volumeCompensation: volumeCompensation,
    );
  }

  // The AudioDeviceContext is used to create the playback device on the specified backend(platform)
  final AudioDeviceContext context;

  final AudioTime bufferDuration;

  // Adaptive feeding chunk size (frames)
  final int chunkFrames;

  final bool _volumeCompensation;

  final DecoderNode _decoderNode;

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

    // ca_device_start handles the AAudio async-start race condition internally
    // (force-stop + retry).  If it still throws here, the device truly failed.
    try {
      _playbackNode.device.start();
    } catch (e) {
      debugPrint("Error while starting device: $e");
      return;
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
        final writeBuf = res.frameCount == buffer.sizeInFrames
            ? buffer
            : buffer.limit(res.frameCount);
        final wrote = _ringBuffer.write(writeBuf);
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

    // Pre-compute constants used every tick.
    final deviceCapacity = _deviceBufferCapacityFrames ?? capacityFrames;
    final deviceTargetFill = (deviceCapacity * 0.9).floor();
    final ringHighWater = (_ringBuffer.capacity * 0.9).floor();

    // Short tick (10ms) and adaptive while-fill based on available write frames
    AudioIntervalClock(const AudioTime(0.01)).runWithBuffer(
      frames: _chunkBuffer!,
      onTick: (_, buffer) {
        if (!_playbackNode.device.isStarted) {
          return false; // stop clock when paused/stopped
        }

        // Compute available space in device buffer (capacity - currently queued frames)
        final availableRead = _playbackNode.device.availableReadFrames;
        var availableWrite =
            (deviceTargetFill - availableRead).clamp(0, deviceCapacity);

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

        while (_ringBuffer.length + buffer.sizeInFrames <= ringHighWater) {
          final res = _decoderNode.outputBus.read(buffer);
          if (res.frameCount > 0) {
            // Skip limit() allocation when decoder returned a full chunk.
            final writeBuf = res.frameCount == buffer.sizeInFrames
                ? buffer
                : buffer.limit(res.frameCount);
            final wrote = _ringBuffer.write(writeBuf);
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

  // Track EQ enabled state for the current round.
  bool _eqEnabled = false;

  void setEQ(bool value) {
    _eqEnabled = value;
    // Toggle the node bypass instead of recalculating filter coefficients via
    // ma_peak2_reinit (FFI). This makes the toggle a simple boolean flip with
    // zero native overhead, keeping the audio isolate's event loop free for
    // MP3 decoding and device feeding.
    _peakingEQNode.bypassed = !value;
  }

  void setEQGain(double value) {
    if (_volumeCompensation) {
      // Compensate volume so a boost and a cut of equal magnitude sound equally loud.
      // Attenuate by the absolute gain: volume = 10^(-|gainDb| / 20).
      // Applied at the device level so VolumeNode stays at 1.0 (fast-path skip).
      _playbackNode.device.volume = pow(10, -value.abs() / 20.0).toDouble();
    } else {
      _playbackNode.device.volume = 0.9;
    }
    // Always keep the filter configured with the active gain so it is ready
    // when the user toggles EQ on (bypass off).
    _peakingEQNode.filter.update(gainDb: value);
  }

  void setEQFreq(double value) {
    _peakingEQNode.filter.update(frequency: value);
  }

  bool getEqState() {
    return _eqEnabled;
  }
}

// Compute the ring buffer capacity (in frames) for pre-decoding.
// Mobile gets 2.0s to absorb decode spikes under CPU throttling; desktop uses 1.5s.
int _ringCapacityFrames(AudioFormat format) {
  final multiplier = (Platform.isAndroid || Platform.isIOS) ? 2.0 : 1.5;
  return (format.sampleRate * multiplier).floor();
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
