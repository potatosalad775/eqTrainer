import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/player/player_service.dart';

/// Exercises [PlayerService] against a real SoLoud engine and a real output
/// device. The native filter's own correctness (response vs RBJ, fade
/// artifact levels) is covered by `run_peaking_eq_test.sh` in the
/// flutter_soloud fork; what's verified here is the Dart-side contract the
/// session depends on — transport, the round-transition sequencing, and the
/// per-handle volume compensation that has to be re-applied on track switch.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory fixturesDir;
  late PlayerService player;

  String fixture(String name) => p.join(fixturesDir.path, name);

  /// The compensation volume the player should be holding for [gainDb].
  double expectedCompensation(double gainDb) =>
      pow(10, -gainDb.abs() / 20.0).toDouble();

  setUpAll(() async {
    fixturesDir = await Directory.systemTemp.createTemp('eqt_player_');
    for (final name in ['sine_440hz_3s.mp3', 'silence_2s.wav']) {
      final data = await rootBundle.load('test/fixtures/audio/$name');
      await File(p.join(fixturesDir.path, name))
          .writeAsBytes(data.buffer.asUint8List());
    }
  });

  setUp(() {
    player = PlayerService();
  });

  tearDown(() async {
    await player.shutdown();
    player.dispose();
  });

  Future<void> launch(String name, {bool volumeCompensation = true}) async {
    await player.launch(
      androidBackend: defaultAndroidBackend,
      outputDevice: null,
      path: fixture(name),
      volumeCompensation: volumeCompensation,
    );
  }

  group('PlayerService — lifecycle', () {
    testWidgets('launch loads a clip and reports its duration', (_) async {
      await launch('silence_2s.wav');

      expect(player.isLaunched, isTrue);
      // Duration is available immediately once the sound is loaded. The old
      // import flow polled for up to 5 s waiting for this.
      expect(player.fetchDuration.inMilliseconds, closeTo(2000, 50));
      expect(player.filePath, endsWith('silence_2s.wav'));
    });

    testWidgets('starts paused at position zero', (_) async {
      await launch('sine_440hz_3s.mp3');

      expect(player.fetchPlayerState.isPlaying, isFalse);
      expect(player.fetchPosition, Duration.zero);
    });

    testWidgets('shutdown releases the clip but leaves the engine up',
        (_) async {
      await launch('silence_2s.wav');
      await player.shutdown();

      expect(player.isLaunched, isFalse);
      // The engine stays initialized so a track switch doesn't re-open the
      // output device.
      expect(SoLoud.instance.isInitialized, isTrue);
    });

    testWidgets('relaunching switches tracks without tearing down the engine',
        (_) async {
      await launch('silence_2s.wav');
      await launch('sine_440hz_3s.mp3');

      expect(player.filePath, endsWith('sine_440hz_3s.mp3'));
      expect(player.fetchDuration.inMilliseconds, closeTo(3000, 100));
      expect(SoLoud.instance.isInitialized, isTrue);
    });
  });

  group('PlayerService — transport', () {
    testWidgets('play then pause reports the transport state', (_) async {
      await launch('sine_440hz_3s.mp3');

      await player.play();
      expect(player.fetchPlayerState.isPlaying, isTrue);

      await player.pause();
      expect(player.fetchPlayerState.isPlaying, isFalse);
    });

    testWidgets('playback advances the position', (_) async {
      await launch('sine_440hz_3s.mp3');
      await player.play();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await player.pause();

      expect(player.fetchPosition, greaterThan(Duration.zero));
    });

    testWidgets('seek moves the position', (_) async {
      await launch('sine_440hz_3s.mp3');

      final result = await player.seek(const Duration(milliseconds: 1500));

      expect(result, isNotNull);
      expect(result!.position, const Duration(milliseconds: 1500));
      expect(player.fetchPosition.inMilliseconds, closeTo(1500, 50));
    });
  });

  group('PlayerService — EQ', () {
    testWidgets('starts with the band inaudible', (_) async {
      await launch('sine_440hz_3s.mp3');

      expect(player.fetchEQState, isFalse);
      // `wet` defaults to 1 on a freshly activated filter; the service must
      // snap it to 0 so the first round starts on "Original".
      expect(SoLoud.instance.filters.peakingEqFilter.wet.value, 0);
    });

    testWidgets('setEQ steps the band while paused', (_) async {
      await launch('sine_440hz_3s.mp3');
      final eq = SoLoud.instance.filters.peakingEqFilter;

      // Nothing is rendering, so the toggle applies immediately: there is no
      // signal to click on, and a fade would never advance.
      await player.setEQ(true);
      expect(player.fetchEQState, isTrue);
      expect(eq.wet.value, closeTo(1, 0.001));

      await player.setEQ(false);
      expect(player.fetchEQState, isFalse);
      expect(eq.wet.value, closeTo(0, 0.001));
    });

    testWidgets('setEQParams applies the new band and leaves it disabled',
        (_) async {
      await launch('sine_440hz_3s.mp3');
      final eq = SoLoud.instance.filters.peakingEqFilter;

      await player.setEQParams(
        enableEQ: false,
        frequency: 2500,
        gainDb: 12,
      );

      expect(eq.frequency.value, closeTo(2500, 0.01));
      expect(eq.gain.value, closeTo(12, 0.01));
      expect(player.fetchEQState, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(eq.wet.value, closeTo(0, 0.001));
    });

    testWidgets(
        'setEQParams from the Filtered view retunes only once the band is out '
        '(while playing)', (_) async {
      await launch('sine_440hz_3s.mp3');
      final eq = SoLoud.instance.filters.peakingEqFilter;
      await player.play();

      await player.setEQParams(enableEQ: true, frequency: 200, gainDb: 15);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(eq.wet.value, closeTo(1, 0.001));

      // The user submits an answer while sitting in the Filtered view. The
      // band must be faded out and the fade *actually applied* before the
      // coefficients are snapped, otherwise the retune is audible. A fade
      // lands on a mix-block boundary, not after its nominal duration, so
      // this is the case a fixed 20 ms delay in Dart would get wrong.
      await player.setEQParams(enableEQ: false, frequency: 5000, gainDb: 12);

      expect(eq.wet.value, closeTo(0, 0.001));
      expect(eq.frequency.value, closeTo(5000, 0.01));
      expect(eq.gain.value, closeTo(12, 0.01));
    });

    testWidgets(
        'setEQParams from the Filtered view retunes with the band out '
        '(while paused)', (_) async {
      await launch('sine_440hz_3s.mp3');
      final eq = SoLoud.instance.filters.peakingEqFilter;

      await player.setEQParams(enableEQ: true, frequency: 200, gainDb: 15);
      expect(eq.wet.value, closeTo(1, 0.001));

      // Paused, the engine's fader does not advance at all — the output
      // device idle-pauses and stream time stops. The band still has to be
      // out of the signal before the retune, so the service must step `wet`
      // here rather than wait on a fade that will never land.
      await player.setEQParams(enableEQ: false, frequency: 5000, gainDb: 12);

      expect(eq.wet.value, closeTo(0, 0.001));
      expect(eq.frequency.value, closeTo(5000, 0.01));
      expect(eq.gain.value, closeTo(12, 0.01));
    });

    testWidgets('setEQ toggles reach their target while playing', (_) async {
      await launch('sine_440hz_3s.mp3');
      final eq = SoLoud.instance.filters.peakingEqFilter;
      await player.play();

      await player.setEQ(true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(eq.wet.value, closeTo(1, 0.001));

      await player.setEQ(false);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(eq.wet.value, closeTo(0, 0.001));
    });

    testWidgets('rapid toggling settles on the last requested state',
        (_) async {
      await launch('sine_440hz_3s.mp3');
      final eq = SoLoud.instance.filters.peakingEqFilter;
      await player.play();

      // Hammer the Original/Filtered button. Each fade restarts from the
      // currently applied value (soloud_filter.cpp:141), so the parameter
      // stays piecewise-linear throughout and no toggle can step it.
      for (var i = 0; i < 12; i++) {
        await player.setEQ(i.isEven);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await player.setEQ(true);

      expect(player.fetchEQState, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(eq.wet.value, closeTo(1, 0.001));
    });

    testWidgets('a toggle during a round transition does not desync the band',
        (_) async {
      await launch('sine_440hz_3s.mp3');
      final eq = SoLoud.instance.filters.peakingEqFilter;
      await player.play();

      await player.setEQParams(enableEQ: true, frequency: 200, gainDb: 15);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(eq.wet.value, closeTo(1, 0.001));

      // Submit an answer and tap Filtered in the same frame, before the
      // transition's fade-out has been applied. The round transition owns the
      // EQ state and must win; the stale tap must not leave the reported
      // state and the actual band disagreeing.
      final transition =
          player.setEQParams(enableEQ: false, frequency: 5000, gainDb: 12);
      await player.setEQ(true);
      await transition;

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(player.fetchEQState, isFalse);
      expect(eq.wet.value, closeTo(0, 0.001));
      expect(eq.frequency.value, closeTo(5000, 0.01));
    });

    testWidgets('setEQQ applies the session bandwidth', (_) async {
      await launch('sine_440hz_3s.mp3');

      await player.setEQQ(4.5);

      expect(SoLoud.instance.filters.peakingEqFilter.q.value, closeTo(4.5, 0.01));
    });
  });

  group('PlayerService — volume compensation', () {
    testWidgets('pre-attenuates by the absolute gain', (_) async {
      await launch('sine_440hz_3s.mp3');

      await player.setEQGain(15);

      expect(player.outputVolume,
          closeTo(expectedCompensation(15), 0.0001));
    });

    testWidgets('compensates a cut by the same amount as a boost', (_) async {
      await launch('sine_440hz_3s.mp3');

      await player.setEQGain(-15);

      expect(player.outputVolume,
          closeTo(expectedCompensation(15), 0.0001));
    });

    testWidgets('is held while the band is inaudible', (_) async {
      await launch('sine_440hz_3s.mp3');

      // EQ disabled — the attenuation must still be applied, otherwise the
      // user could pick the boosted round out by loudness alone.
      await player.setEQParams(enableEQ: false, frequency: 1000, gainDb: 12);

      expect(player.fetchEQState, isFalse);
      expect(player.outputVolume,
          closeTo(expectedCompensation(12), 0.0001));
    });

    testWidgets('is re-applied to the new handle after a track switch',
        (_) async {
      await launch('sine_440hz_3s.mp3');
      await player.setEQParams(enableEQ: false, frequency: 1000, gainDb: 12);

      // A fresh voice starts at volume 1.0, so the switch must re-apply the
      // compensation — this is the landmine the migration notes call out.
      await launch('silence_2s.wav');

      expect(player.outputVolume,
          closeTo(expectedCompensation(12), 0.0001));
    });

    testWidgets('stays at unity when compensation is disabled', (_) async {
      await launch('sine_440hz_3s.mp3', volumeCompensation: false);

      await player.setEQGain(15);

      expect(player.outputVolume, closeTo(1.0, 0.0001));
    });
  });
}
