import 'package:flutter_soloud/flutter_soloud.dart';

/// A clip the engine has loaded. Opaque: only the engine that made it reads it.
abstract interface class LoadedClip {}

/// One playing or paused instance of a loaded clip. Opaque, like [LoadedClip].
abstract interface class Voice {}

/// The operations [PlayerService] needs from the audio engine, and no more.
///
/// A seam so the player's rules can be tested without a device. Everything
/// except [open], [load] and [unload] is a synchronous call that returns at
/// once. The EQ is one peaking filter shared by every voice, so its settings
/// belong to the engine, not to a clip or a voice.
abstract interface class AudioEngine {
  /// Makes sure the engine is running on [device] (null = OS default) with the
  /// peaking EQ filter in place.
  ///
  /// Starts the engine on first use. Afterwards it only changes device when a
  /// different one is asked for. [androidBackend] is read only when the engine
  /// starts.
  Future<void> open({
    required PlaybackDevice? device,
    required AndroidAudioBackend androidBackend,
  });

  /// Loads the file at [path]. [streamed] true decodes from disk on the audio
  /// thread; false holds the whole file in memory. Throws if the engine cannot
  /// read the file.
  Future<LoadedClip> load(String path, {required bool streamed});

  /// The length of [clip].
  Duration lengthOf(LoadedClip clip);

  /// Releases [clip]. Its voices stop being valid.
  Future<void> unload(LoadedClip clip);

  /// A new voice for [clip], paused at 0, at [volume].
  Voice startPaused(LoadedClip clip, {required double volume});

  /// False once [voice] has reached the end of its clip. Check this before
  /// using a voice that may have finished.
  bool isValid(Voice voice);

  bool isPaused(Voice voice);

  void setPaused(Voice voice, {required bool paused});

  void seek(Voice voice, Duration position);

  Duration positionOf(Voice voice);

  /// The volume the engine has applied to [voice].
  double volumeOf(Voice voice);

  void setVolume(Voice voice, double volume);

  void setEqFrequency(double hz);

  void setEqGain(double db);

  void setEqQ(double q);

  /// The dry/wet mix the engine has actually applied, 0..1. A fade moves this
  /// only as the engine renders.
  double get eqWet;

  /// Sets the mix at once. Only safe while nothing is rendering: against live
  /// audio it is a click.
  void stepEqWet(double target);

  /// Fades the mix to [target] over [time] of stream time. Does not advance
  /// while nothing is rendering.
  void fadeEqWet(double target, Duration time);
}

final class _SoLoudClip implements LoadedClip {
  const _SoLoudClip(this.source);

  final AudioSource source;
}

final class _SoLoudVoice implements Voice {
  const _SoLoudVoice(this.handle);

  final SoundHandle handle;
}

/// The real engine, over the SoLoud singleton. Every call is passed straight
/// through, except [open], which also decides which device is open.
final class SoLoudAudioEngine implements AudioEngine {
  const SoLoudAudioEngine();

  SoLoud get _soloud => SoLoud.instance;

  /// Id of the device the (singleton) engine currently has open.
  ///
  /// Static because the engine is: the session page, the playlist preview and
  /// the import editor each build their own player over one shared SoLoud
  /// instance. Per-instance, a second player would always see `null` here and
  /// re-run `changeDevice` on a device that was already open, needlessly
  /// restarting the output.
  static int? _activeDeviceId;

  @override
  Future<void> open({
    required PlaybackDevice? device,
    required AndroidAudioBackend androidBackend,
  }) async {
    if (_soloud.isInitialized) {
      // The device can change while the engine is up (user picks another
      // output). changeDevice reuses the context, so the Android backend
      // choice made at init survives.
      if (device != null && device.id != _activeDeviceId) {
        await _soloud.changeDevice(newDevice: device);
        _activeDeviceId = device.id;
      }
      return;
    }

    await _soloud.init(device: device, androidBackend: androidBackend);
    _activeDeviceId = device?.id;

    // The peaking EQ is a *global* filter, applied to the mixed output. That
    // ordering matters: SoLoud mixes each voice at its handle volume, then
    // runs global filters, then clips — volume -> EQ -> clamp, matching the
    // chain the coast_audio graph had. A per-voice filter would run *before*
    // the voice's volume and invert it. Being global also means it survives
    // track switches without re-attaching.
    // `wet` defaults to 1 (soloud_filter.cpp:96), i.e. the band fully
    // audible; PlayerService.launch() takes it back out once the filter exists.
    final eq = _soloud.filters.peakingEqFilter;
    if (!eq.isActive) {
      eq.activate();
    }
  }

  @override
  Future<LoadedClip> load(String path, {required bool streamed}) async {
    final source = await _soloud.loadFile(
      path,
      mode: streamed ? LoadMode.disk : LoadMode.memory,
    );
    return _SoLoudClip(source);
  }

  @override
  Duration lengthOf(LoadedClip clip) =>
      _soloud.getLength((clip as _SoLoudClip).source);

  @override
  Future<void> unload(LoadedClip clip) =>
      _soloud.disposeSource((clip as _SoLoudClip).source);

  @override
  Voice startPaused(LoadedClip clip, {required double volume}) {
    final handle = _soloud.play(
      (clip as _SoLoudClip).source,
      paused: true,
      volume: volume,
    );
    return _SoLoudVoice(handle);
  }

  @override
  bool isValid(Voice voice) =>
      _soloud.getIsValidVoiceHandle((voice as _SoLoudVoice).handle);

  @override
  bool isPaused(Voice voice) =>
      _soloud.getPause((voice as _SoLoudVoice).handle);

  @override
  void setPaused(Voice voice, {required bool paused}) =>
      _soloud.setPause((voice as _SoLoudVoice).handle, paused);

  @override
  void seek(Voice voice, Duration position) =>
      _soloud.seek((voice as _SoLoudVoice).handle, position);

  @override
  Duration positionOf(Voice voice) =>
      _soloud.getPosition((voice as _SoLoudVoice).handle);

  @override
  double volumeOf(Voice voice) =>
      _soloud.getVolume((voice as _SoLoudVoice).handle);

  @override
  void setVolume(Voice voice, double volume) =>
      _soloud.setVolume((voice as _SoLoudVoice).handle, volume);

  @override
  void setEqFrequency(double hz) =>
      _soloud.filters.peakingEqFilter.frequency.value = hz;

  @override
  void setEqGain(double db) => _soloud.filters.peakingEqFilter.gain.value = db;

  @override
  void setEqQ(double q) => _soloud.filters.peakingEqFilter.q.value = q;

  @override
  double get eqWet => _soloud.filters.peakingEqFilter.wet.value;

  @override
  void stepEqWet(double target) =>
      _soloud.filters.peakingEqFilter.wet.value = target;

  @override
  void fadeEqWet(double target, Duration time) =>
      _soloud.filters.peakingEqFilter.wet
          .fadeFilterParameter(to: target, time: time);
}
