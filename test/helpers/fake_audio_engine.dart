import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:eq_trainer/data/audio_engine.dart';

/// One engine call, as it stood when it was made.
///
/// [eqWet] and [rendering] are snapshots taken at the call, so a test about
/// order asserts on what the engine looked like then, not on what it looks
/// like by the time the test reads it.
class EngineCall {
  const EngineCall(this.op, this.args,
      {required this.eqWet, required this.rendering});

  final String op;
  final List<Object?> args;
  final double eqWet;
  final bool rendering;

  @override
  String toString() => '$op($args) wet=$eqWet rendering=$rendering';
}

/// A small deterministic model of the parts of SoLoud that `PlayerService`'s
/// rules depend on:
///
/// - Stream time moves only while a voice is rendering (valid and not paused).
///   Tests move it with [advance].
/// - `eqWet` starts at 1 and moves only in [advance] (a fade) or at once
///   ([stepEqWet]).
/// - A voice that reaches the end of its clip becomes invalid.
///
/// Whether this matches SoLoud is checked by nothing here: the integration
/// suites are the only test that the model is right.
///
/// [calls] logs every mutating call (not the plain reads: `isValid`,
/// `isPaused`, `positionOf`, `volumeOf`, `lengthOf`, `eqWet`).
class FakeAudioEngine implements AudioEngine {
  /// Length of any clip whose path is not in [lengths].
  static const defaultLength = Duration(seconds: 10);

  final calls = <EngineCall>[];

  /// Each `open` call's device and backend.
  final opens = <({PlaybackDevice? device, AndroidAudioBackend backend})>[];

  /// Paths whose `load` throws.
  final failingPaths = <String>{};

  /// Clip length per path.
  final lengths = <String, Duration>{};

  final voices = <FakeVoice>[];

  double _wet = 1;
  ({double from, double to, Duration total, Duration elapsed})? _fade;

  bool get isRendering => voices.any((v) => v.isRendering);

  List<EngineCall> callsOf(String op) =>
      calls.where((c) => c.op == op).toList();

  void _log(String op, [List<Object?> args = const []]) =>
      calls.add(EngineCall(op, args, eqWet: _wet, rendering: isRendering));

  /// Moves stream time by [d]. Does nothing at all unless a voice is rendering.
  void advance(Duration d) {
    if (!isRendering) return;
    for (final v in voices.where((v) => v.isRendering).toList()) {
      v.position += d;
      if (v.position >= v.clip.length) v.valid = false;
    }
    final fade = _fade;
    if (fade != null) {
      final elapsed = fade.elapsed + d;
      if (elapsed >= fade.total) {
        _wet = fade.to;
        _fade = null;
      } else {
        final t = elapsed.inMicroseconds / fade.total.inMicroseconds;
        _wet = fade.from + (fade.to - fade.from) * t;
        _fade =
            (from: fade.from, to: fade.to, total: fade.total, elapsed: elapsed);
      }
    }
  }

  @override
  Future<void> open({
    required PlaybackDevice? device,
    required AndroidAudioBackend androidBackend,
  }) async {
    opens.add((device: device, backend: androidBackend));
    _log('open', [device, androidBackend]);
  }

  @override
  Future<LoadedClip> load(String path, {required bool streamed}) async {
    _log('load', [path, streamed]);
    if (failingPaths.contains(path)) {
      throw StateError('cannot read $path');
    }
    return FakeClip(path, lengths[path] ?? defaultLength);
  }

  @override
  Duration lengthOf(LoadedClip clip) => (clip as FakeClip).length;

  @override
  Future<void> unload(LoadedClip clip) async {
    final c = clip as FakeClip;
    _log('unload', [c.path]);
    for (final v in voices.where((v) => v.clip == c)) {
      v.valid = false;
    }
  }

  @override
  Voice startPaused(LoadedClip clip, {required double volume}) {
    _log('startPaused', [(clip as FakeClip).path, volume]);
    final v = FakeVoice(clip, volume);
    voices.add(v);
    return v;
  }

  @override
  bool isValid(Voice voice) => (voice as FakeVoice).valid;

  @override
  bool isPaused(Voice voice) => (voice as FakeVoice).paused;

  @override
  void setPaused(Voice voice, {required bool paused}) {
    _log('setPaused', [paused]);
    (voice as FakeVoice).paused = paused;
  }

  @override
  void seek(Voice voice, Duration position) {
    _log('seek', [position]);
    (voice as FakeVoice).position = position;
  }

  @override
  Duration positionOf(Voice voice) => (voice as FakeVoice).position;

  @override
  double volumeOf(Voice voice) => (voice as FakeVoice).volume;

  @override
  void setVolume(Voice voice, double volume) {
    _log('setVolume', [volume]);
    (voice as FakeVoice).volume = volume;
  }

  @override
  void setEqFrequency(double hz) => _log('setEqFrequency', [hz]);

  @override
  void setEqGain(double db) => _log('setEqGain', [db]);

  @override
  void setEqQ(double q) => _log('setEqQ', [q]);

  @override
  double get eqWet => _wet;

  @override
  void stepEqWet(double target) {
    _log('stepEqWet', [target]);
    _wet = target;
    _fade = null;
  }

  @override
  void fadeEqWet(double target, Duration time) {
    _log('fadeEqWet', [target, time]);
    _fade = (from: _wet, to: target, total: time, elapsed: Duration.zero);
  }
}

final class FakeClip implements LoadedClip {
  FakeClip(this.path, this.length);

  final String path;
  final Duration length;
}

final class FakeVoice implements Voice {
  FakeVoice(this.clip, double volume)
      : startVolume = volume,
        volume = volume;

  final FakeClip clip;

  /// The volume it was started with.
  final double startVolume;

  double volume;
  bool paused = true;
  bool valid = true;
  Duration position = Duration.zero;

  bool get isRendering => valid && !paused;
}
