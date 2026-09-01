import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Snapshot of the player's transport state, polled for the UI.
///
/// Only [isPlaying] is rendered; the class exists so widgets can
/// `context.select` on transport changes without rebuilding on every
/// position tick.
class PlayerStateResponse extends Equatable {
  const PlayerStateResponse({required this.isPlaying});

  final bool isPlaying;

  @override
  List<Object?> get props => [isPlaying];
}

/// Position and duration of the loaded clip, as of the last poll.
class PlayerPositionResponse extends Equatable {
  const PlayerPositionResponse({
    required this.position,
    required this.duration,
  });

  final Duration position;
  final Duration duration;

  @override
  List<Object?> get props => [position, duration];
}

/// Audio playback with a single-band peaking EQ, backed by flutter_soloud.
///
/// Replaces the coast_audio `PlayerIsolate`. The whole audio path — decode,
/// mixing and the EQ — now runs on the native miniaudio callback thread, so
/// there is no Dart code in the audio path and none of the in-flight guards,
/// poll cooldowns or stale-clock races the isolate needed. Every control call
/// here is a synchronous FFI write; the only `await`s left are genuine waits
/// (file loading, and the deliberate fade delay in [setEQParams]).
///
/// The public surface deliberately mirrors the old `PlayerIsolate` so the
/// session UI and its tests carry over, except that `AudioTime` is now
/// [Duration].
class PlayerService extends ChangeNotifier {
  /// How often the transport state is polled for the UI. Unlike the old
  /// isolate poll this is a plain synchronous read, so it cannot back up.
  static const Duration _pollInterval = Duration(milliseconds: 50);

  /// Length of the dry/wet crossfade used to bring the band in and out.
  ///
  /// The filter is built so that fading `wet` moves no recursive coefficient
  /// (see the fork's `peaking_eq_filter.cpp`), which is what makes the
  /// transition click-free. 20 ms measures ~110-125 dB below the signal,
  /// against 52-67 dB for a hard bypass switch.
  static const Duration _fadeDuration = Duration(milliseconds: 20);

  /// How long [_awaitWet] will wait for a fade to be applied before giving up.
  ///
  /// A fade is driven by the engine's stream time, not by wall clock, so it
  /// lands on a mix-block boundary — ~46 ms at the default 2048-frame buffer,
  /// more if the device period is larger. This is a safety net, not the
  /// expected wait: the poll below normally returns well inside it.
  static const Duration _fadeWaitTimeout = Duration(milliseconds: 300);

  /// How often [_awaitWet] re-reads the applied value while waiting.
  static const Duration _fadeWaitPollInterval = Duration(milliseconds: 4);

  /// `wet` at or below this counts as fully out of the signal.
  static const double _wetEpsilon = 1e-4;

  SoLoud get _soloud => SoLoud.instance;

  AudioSource? _source;
  SoundHandle? _handle;
  String? _path;

  Timer? _pollTimer;

  bool _volumeCompensation = true;

  /// Playback volume that offsets the EQ's peak gain. Held for the whole
  /// round (not only while the band is audible) so the dry and wet signals
  /// match in loudness and the user cannot identify the boosted round by
  /// level alone. Re-applied to every new handle, because a fresh voice
  /// starts at 1.0.
  double _compensationVolume = 1.0;

  /// Mirror of the filter's `wet` parameter: 1 while the band is audible.
  /// Tracked in Dart because the round transition needs to know whether a
  /// fade-out is required before retuning.
  bool _eqEnabled = false;

  /// True while [setEQParams] is mid-transition, i.e. between taking the band
  /// out and finishing the retune. The transition owns the band for that
  /// window; see [setEQ].
  bool _roundTransitionActive = false;

  PlayerStateResponse? _lastState;
  Duration? _lastPosition;
  Duration? _lastDuration;

  bool get isLaunched => _source != null;

  /// Absolute path of the clip currently loaded, if any.
  String? get filePath => _path;

  Duration get fetchPosition => _lastPosition ?? Duration.zero;
  Duration get fetchDuration => _lastDuration ?? Duration.zero;
  bool get fetchEQState => _eqEnabled;
  PlayerStateResponse get fetchPlayerState =>
      _lastState ?? const PlayerStateResponse(isPlaying: false);

  /// Volume actually applied to the playing voice, or 1.0 when nothing is
  /// loaded. This is the EQ's loudness compensation in effect (see
  /// [setEQGain]), read back from the engine rather than from Dart state.
  double get outputVolume {
    final handle = _handle;
    if (handle == null || !_soloud.getIsValidVoiceHandle(handle)) {
      return _compensationVolume;
    }
    return _soloud.getVolume(handle);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes the engine if needed, then loads [path] paused at 0.
  ///
  /// Safe to call repeatedly for track switches: the engine, the output device
  /// and the global EQ filter are all kept across calls, so a switch only
  /// disposes the old source and loads the new one. That is also why the
  /// compensation volume has to be re-applied here — the new voice is a fresh
  /// handle at volume 1.0.
  Future<void> launch({
    required AndroidAudioBackend androidBackend,
    required PlaybackDevice? outputDevice,
    required String? path,
    bool volumeCompensation = true,
  }) async {
    _volumeCompensation = volumeCompensation;

    // Clear the cached transport state so widgets don't briefly render the
    // previous clip's position/duration before the first poll lands.
    _lastState = null;
    _lastPosition = null;
    _lastDuration = null;
    notifyListeners();

    await _ensureEngine(
      androidBackend: androidBackend,
      outputDevice: outputDevice,
    );
    await _disposeSource();

    // Take the band out on every launch, not just the first.
    //
    // The peaking EQ is a *global* filter, so it belongs to the engine and
    // outlives any one PlayerService — but `_eqEnabled` is per-instance and
    // starts false. A new player over an engine still holding `wet = 1` would
    // disagree with what is audible, and [setEQParams] would then skip its
    // fade-out and snap coefficients into a fully-wet signal. In the app that
    // is a fresh session page (session_page.dart builds its own player):
    // leaving a session on "Filtered" would make round 1 of the next session
    // audibly filtered while the UI said "Original", giving the answer away.
    // A step is safe here — nothing is rendering yet, the source below is
    // loaded paused. This matches the old isolate, which started bypassed
    // because the isolate itself was new.
    _soloud.filters.peakingEqFilter.wet.value = 0;
    _eqEnabled = false;

    if (path == null) return;

    _source = await _soloud.loadFile(path, mode: LoadMode.disk);
    _path = path;

    // Duration is available as soon as the sound is loaded — no polling loop.
    _lastDuration = _soloud.getLength(_source!);

    _startHandle();
    _startPolling();
    _poll();
  }

  /// Brings up the SoLoud engine on first use and keeps it up afterwards.
  ///
  /// Re-initializing per track would be both slow and pointless: the engine
  /// stops the output device on its own once no voice is playing.
  Future<void> _ensureEngine({
    required AndroidAudioBackend androidBackend,
    required PlaybackDevice? outputDevice,
  }) async {
    if (_soloud.isInitialized) {
      // The device can change while the engine is up (user picks another
      // output). changeDevice reuses the context, so the Android backend
      // choice made at init survives.
      if (outputDevice != null && outputDevice.id != _activeDeviceId) {
        await _soloud.changeDevice(newDevice: outputDevice);
        _activeDeviceId = outputDevice.id;
      }
      return;
    }

    await _soloud.init(
      device: outputDevice,
      androidBackend: androidBackend,
    );
    _activeDeviceId = outputDevice?.id;

    // The peaking EQ is a *global* filter, applied to the mixed output. That
    // ordering matters: SoLoud mixes each voice at its handle volume, then
    // runs global filters, then clips — volume -> EQ -> clamp, matching the
    // chain the coast_audio graph had. A per-voice filter would run *before*
    // the voice's volume and invert it. Being global also means it survives
    // track switches without re-attaching.
    // `wet` defaults to 1 (soloud_filter.cpp:96), i.e. the band fully
    // audible; launch() takes it back out once the filter exists.
    final eq = _soloud.filters.peakingEqFilter;
    if (!eq.isActive) {
      eq.activate();
    }
  }

  int? _activeDeviceId;

  /// Creates a paused voice for the loaded source at position 0 and applies
  /// the compensation volume to it.
  void _startHandle() {
    final source = _source;
    if (source == null) return;
    _handle = _soloud.play(source, paused: true, volume: _compensationVolume);
  }

  Future<void> _disposeSource() async {
    final source = _source;
    _handle = null;
    _source = null;
    _path = null;
    if (source != null) {
      await _soloud.disposeSource(source);
    }
  }

  /// Releases the loaded clip but leaves the engine (and the global EQ filter)
  /// running, so a track switch doesn't pay a device re-open.
  Future<void> shutdown() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _disposeSource();
    _lastState = null;
    _lastPosition = null;
    _lastDuration = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    // Fire-and-forget: dispose() cannot await, and the engine outlives the
    // page anyway.
    unawaited(_disposeSource());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  Future<void> play() async {
    final handle = _handle;
    if (handle == null) return;
    // The voice is invalidated once it reaches the end of the clip; recreate
    // it so the play button replays from the start.
    if (!_soloud.getIsValidVoiceHandle(handle)) {
      _startHandle();
    }
    final live = _handle;
    if (live == null) return;
    _soloud.setPause(live, false);
    _lastState = const PlayerStateResponse(isPlaying: true);
    notifyListeners();
  }

  Future<void> pause() async {
    final handle = _handle;
    if (handle == null) return;
    if (_soloud.getIsValidVoiceHandle(handle)) {
      _soloud.setPause(handle, true);
    }
    _lastState = const PlayerStateResponse(isPlaying: false);
    notifyListeners();
  }

  /// Seeks to [position]. Returns the resulting transport snapshot, or null
  /// if nothing is loaded.
  ///
  /// No coalescing or in-flight guard: the seek is a synchronous FFI call, so
  /// a slider drag cannot queue requests behind each other the way it could
  /// when every seek was an isolate round-trip.
  Future<PlayerPositionResponse?> seek(Duration position) async {
    final handle = _handle;
    if (handle == null) return null;
    if (!_soloud.getIsValidVoiceHandle(handle)) {
      _startHandle();
    }
    final live = _handle;
    if (live == null) return null;
    _soloud.seek(live, position);
    _lastPosition = position;
    notifyListeners();
    return PlayerPositionResponse(
      position: position,
      duration: _lastDuration ?? Duration.zero,
    );
  }

  Future<void> setVolume(double volume) async {
    final handle = _handle;
    if (handle == null) return;
    _soloud.setVolume(handle, volume);
  }

  // ---------------------------------------------------------------------------
  // EQ
  // ---------------------------------------------------------------------------

  /// Brings the band in ([enableEQ] true) or out, as a fade.
  ///
  /// This is the Original/Filtered toggle. Never set `wet` in a step: the
  /// instantaneous dry/filtered swap is exactly the "noise burst out of
  /// nowhere" this migration exists to fix.
  Future<void> setEQ(bool enableEQ) async {
    if (!isLaunched) return;
    // A round transition owns the band while it runs, and its EQ state has to
    // win over a tap that raced it: the user can hit Filtered in the same
    // frame as they submit an answer. Letting the tap through would fade the
    // band back in underneath [setEQParams], which then waits out its full
    // timeout and force-steps `wet` into live audio — a click at exactly the
    // wrong moment — and leaves the reported state disagreeing with what is
    // audible. Dropping the tap matches what the old isolate did.
    if (_roundTransitionActive) return;
    if (_eqEnabled == enableEQ) return;
    _eqEnabled = enableEQ;
    _setWet(enableEQ ? 1 : 0);
    notifyListeners();
  }

  /// Sets the band's peak gain in dB, and the matching compensation volume.
  ///
  /// The attenuation is applied whether or not the band is currently audible,
  /// so switching between Original and Filtered doesn't change perceived
  /// loudness.
  Future<void> setEQGain(double gainDb) async {
    if (!isLaunched) return;
    _applyCompensation(gainDb);
    _soloud.filters.peakingEqFilter.gain.value = gainDb;
  }

  Future<void> setEQFreq(double frequency) async {
    if (!isLaunched) return;
    _soloud.filters.peakingEqFilter.frequency.value = frequency;
  }

  Future<void> setEQQ(double q) async {
    if (!isLaunched) return;
    _soloud.filters.peakingEqFilter.q.value = q;
  }

  /// Retunes the band for a new round, and leaves it enabled per [enableEQ].
  ///
  /// Coefficients may only be snapped while the band is inaudible, and the
  /// user can submit an answer while sitting in the Filtered view — so the
  /// order is: fade `wet` out, *wait for the fade to finish*, then retune.
  /// There is no completion callback for a parameter fade, hence the delay.
  /// Retuning first (what the old worker did) is part of today's click.
  Future<void> setEQParams({
    required bool enableEQ,
    required double frequency,
    required double gainDb,
  }) async {
    if (!isLaunched) return;
    final eq = _soloud.filters.peakingEqFilter;

    _roundTransitionActive = true;
    try {
      if (_eqEnabled) {
        _eqEnabled = false;
        notifyListeners();
        _setWet(0);
        await _awaitWet(0);
        // The clip can be torn down while we wait out the fade.
        if (!isLaunched) return;
      }

      // Inaudible now, so these are free to snap.
      eq.frequency.value = frequency;
      eq.gain.value = gainDb;
      _applyCompensation(gainDb);

      if (enableEQ) {
        _eqEnabled = true;
        _setWet(1);
      }
    } finally {
      _roundTransitionActive = false;
    }
    notifyListeners();
  }

  /// True while a voice is actually feeding the output.
  ///
  /// This gates [_setWet] because SoLoud's parameter fader advances on the
  /// engine's stream time: with no voice playing the output device idle-pauses
  /// and the fader stops dead, so a requested fade would simply never land.
  bool get _isRendering {
    final handle = _handle;
    return handle != null &&
        _soloud.getIsValidVoiceHandle(handle) &&
        !_soloud.getPause(handle);
  }

  /// Moves the band's dry/wet mix to [target].
  ///
  /// While audio is rendering this has to be a fade — a step between the dry
  /// and the fully-filtered signal is the click this migration exists to
  /// remove. While nothing is rendering it has to be a step: there is no
  /// signal for a step to click on, and a fade would not advance at all (see
  /// [_isRendering]), leaving `wet` stuck at its old value.
  void _setWet(double target) {
    final wet = _soloud.filters.peakingEqFilter.wet;
    if (_isRendering) {
      wet.fadeFilterParameter(to: target, time: _fadeDuration);
    } else {
      wet.value = target;
    }
  }

  /// Waits until the engine reports `wet` has reached [target].
  ///
  /// Polling the applied value is what makes the round transition correct on
  /// any buffer size: a fade completes on a mix-block boundary, so waiting a
  /// fixed [_fadeDuration] in Dart would return while the band was still
  /// audible and the retune below it would click.
  Future<void> _awaitWet(double target) async {
    final wet = _soloud.filters.peakingEqFilter.wet;
    final deadline = DateTime.now().add(_fadeWaitTimeout);
    while ((wet.value - target).abs() > _wetEpsilon) {
      if (DateTime.now().isAfter(deadline)) {
        // Fall through rather than hang the round. Snapping the coefficients
        // now may be audible, but a session that never advances is worse.
        wet.value = target;
        return;
      }
      await Future<void>.delayed(_fadeWaitPollInterval);
    }
  }

  /// Recomputes the pre-attenuation for [gainDb] and applies it to the
  /// current voice.
  void _applyCompensation(double gainDb) {
    _compensationVolume =
        _volumeCompensation ? pow(10, -gainDb.abs() / 20.0).toDouble() : 1.0;
    final handle = _handle;
    if (handle != null && _soloud.getIsValidVoiceHandle(handle)) {
      _soloud.setVolume(handle, _compensationVolume);
    }
  }

  // ---------------------------------------------------------------------------
  // Polling
  // ---------------------------------------------------------------------------

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Reads the transport state for the UI.
  ///
  /// Every call here is a synchronous native read, so unlike the old isolate
  /// poll there is nothing to guard against re-entering.
  void _poll() {
    final handle = _handle;
    if (handle == null) return;

    var changed = false;

    if (_soloud.getIsValidVoiceHandle(handle)) {
      final position = _soloud.getPosition(handle);
      if (position != _lastPosition) {
        _lastPosition = position;
        changed = true;
      }
      final playing = !_soloud.getPause(handle);
      if (_lastState?.isPlaying != playing) {
        _lastState = PlayerStateResponse(isPlaying: playing);
        changed = true;
      }
    } else if (_lastState?.isPlaying ?? false) {
      // End of clip. Mirror the old player: stop and rewind to 0 so the play
      // button replays from the start rather than leaving a
      // playing-but-silent transport.
      _startHandle();
      _lastPosition = Duration.zero;
      _lastState = const PlayerStateResponse(isPlaying: false);
      changed = true;
    }

    if (changed) notifyListeners();
  }
}

/// The Android backend eqTrainer opens the output device with.
///
/// SoLoud prefers AAudio on API >= 30, but several Digital Audio Player
/// devices accept an AAudio stream and then glitch on it, so eqTrainer has
/// always pinned OpenSL ES. Kept as a named default rather than inlined so
/// the settings page and the saved-setting migration share one source.
AndroidAudioBackend get defaultAndroidBackend =>
    Platform.isAndroid ? AndroidAudioBackend.openSles : AndroidAudioBackend.auto;
