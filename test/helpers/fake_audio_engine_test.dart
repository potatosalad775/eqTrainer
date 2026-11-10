import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_audio_engine.dart';

void main() {
  late FakeAudioEngine engine;
  late FakeVoice voice;

  setUp(() async {
    engine = FakeAudioEngine();
    await engine.open(device: null, androidBackend: AndroidAudioBackend.auto);
    final clip = await engine.load('a.wav', streamed: true);
    voice = engine.startPaused(clip, volume: 0.5) as FakeVoice;
  });

  test('time and fades stand still while nothing renders', () {
    engine.fadeEqWet(0, const Duration(milliseconds: 20));
    engine.advance(const Duration(seconds: 1));
    expect(engine.eqWet, 1);
    expect(voice.position, Duration.zero);
  });

  test('a fade lands only after enough rendering time', () {
    voice.paused = false;
    engine.fadeEqWet(0, const Duration(milliseconds: 20));
    engine.advance(const Duration(milliseconds: 10));
    expect(engine.eqWet, closeTo(0.5, 1e-9));
    engine.advance(const Duration(milliseconds: 10));
    expect(engine.eqWet, 0);
  });

  test('a step cancels a pending fade', () {
    voice.paused = false;
    engine.fadeEqWet(0, const Duration(milliseconds: 20));
    engine.stepEqWet(1);
    engine.advance(const Duration(milliseconds: 20));
    expect(engine.eqWet, 1);
  });

  test('a voice ends at the clip length, and unload ends the rest', () async {
    voice.paused = false;
    engine.advance(const Duration(seconds: 9));
    expect(engine.isValid(voice), isTrue);
    engine.advance(const Duration(seconds: 1));
    expect(engine.isValid(voice), isFalse);

    final clip = await engine.load('b.wav', streamed: true);
    final other = engine.startPaused(clip, volume: 1);
    await engine.unload(clip);
    expect(engine.isValid(other), isFalse);
  });

  test('a failing load throws', () {
    engine.failingPaths.add('bad.wav');
    expect(engine.load('bad.wav', streamed: true), throwsStateError);
  });

  test('calls snapshot the wet and rendering state at the call', () {
    voice.paused = false;
    engine.stepEqWet(0);
    voice.paused = true;
    engine.stepEqWet(1);
    final steps = engine.callsOf('stepEqWet');
    expect(steps.map((c) => c.rendering), [true, false]);
    expect(steps.map((c) => c.eqWet), [1, 0]);
  });
}
