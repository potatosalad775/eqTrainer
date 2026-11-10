import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/data/player_service.dart';

import '../helpers/fake_audio_engine.dart';
import '../helpers/fake_encoder.dart';
import '../helpers/fake_output_devices.dart';
import '../helpers/mocks.dart';
import '../helpers/recording_hold.dart';

void main() {
  late OutputSelection output;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    output = OutputSelection(
      prefs: await SharedPreferences.getInstance(),
      devices: FakeOutputDevices([]),
      watchesDevices: false,
    );
  });

  test('constructing a player pauses the hold', () {
    final hold = RecordingHold();
    final player = PlayerService(output, hold: hold);
    expect(hold.pauses, 1);
    expect(hold.resumes, 0);
    player.dispose();
  });

  test('dispose resumes the hold once', () {
    final hold = RecordingHold();
    PlayerService(output, hold: hold).dispose();
    expect(hold.resumes, 1);
  });

  test('shutdown leaves the hold paused', () async {
    final hold = RecordingHold();
    final player = PlayerService(output, hold: hold);
    await player.shutdown();
    expect(hold.resumes, 0);
    player.dispose();
    expect(hold.resumes, 1);
  });

  testWidgets(
      'two players keep a real migration paused until both are disposed',
      (tester) async {
    final migration = ClipFormatMigration(
      MockClipLibrary(),
      importFormat: 0,
      encoder: FakeClipEncoder(),
    );
    final a = PlayerService(output, hold: migration);
    final b = PlayerService(output, hold: migration);
    expect(migration.isPaused, isTrue);

    a.dispose();
    expect(migration.isPaused, isTrue);
    b.dispose();
    expect(migration.isPaused, isFalse);
  });

  group('against the in-memory engine', () {
    late FakeAudioEngine engine;

    final players = <PlayerService>[];

    setUp(() {
      engine = FakeAudioEngine();
      players.clear();
    });

    /// A [testWidgets] that disposes every player before the test ends. The
    /// binding checks for pending timers before tearDowns run, so the poll
    /// timer has to be cancelled in the body.
    void playerTest(String name, Future<void> Function(WidgetTester) body) {
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          for (final p in players) {
            p.dispose();
          }
        }
      });
    }

    PlayerService newPlayer(WidgetTester tester, [OutputSelection? out]) {
      final player = PlayerService(
        out ?? output,
        hold: RecordingHold(),
        engine: engine,
      );
      players.add(player);
      return player;
    }

    Future<PlayerService> launched(
      WidgetTester tester, {
      String path = 'a.wav',
      bool volumeCompensation = true,
    }) async {
      final player = newPlayer(tester);
      await player.launch(path: path, volumeCompensation: volumeCompensation);
      return player;
    }

    /// Moves stream time and the test clock together, in 4 ms steps (the
    /// fade-wait poll interval).
    Future<void> elapse(WidgetTester tester, Duration d) async {
      const step = Duration(milliseconds: 4);
      for (var left = d; left > Duration.zero; left -= step) {
        final s = left < step ? left : step;
        engine.advance(s);
        await tester.pump(s);
      }
    }

    /// Ops of [calls], with the args of the wet moves for readable asserts.
    List<String> ops(Iterable<EngineCall> calls) =>
        calls.map((c) => c.op).toList();

    playerTest('wet moves as a fade while rendering, as a step while not',
        (tester) async {
      final player = await launched(tester);

      var from = engine.calls.length;
      player.setEQ(true); // paused
      var made = engine.calls.skip(from).toList();
      expect(ops(made), ['stepEqWet']);
      expect(made.single.args, [1.0]);

      player.play();
      from = engine.calls.length;
      player.setEQ(false);
      made = engine.calls.skip(from).toList();
      expect(ops(made), ['fadeEqWet']);
      expect(made.single.args, [0.0, const Duration(milliseconds: 20)]);

      // The clip ends under the player: the voice is invalid, so a step.
      await elapse(tester, const Duration(milliseconds: 50));
      engine.advance(const Duration(seconds: 20));
      from = engine.calls.length;
      player.setEQ(true);
      made = engine.calls.skip(from).toList();
      expect(ops(made), ['stepEqWet']);
    });

    playerTest('a toggle is dropped while a round transition is in flight',
        (tester) async {
      final player = await launched(tester);
      player.setEQ(true);
      player.play();

      var done = false;
      unawaited(player
          .setEQParams(enableEQ: false, frequency: 1000, gainDb: 6)
          .then((_) => done = true));
      final before = engine.calls.length;
      expect(ops(engine.calls.skip(before - 1)), ['fadeEqWet']);

      player.setEQ(true);
      expect(engine.calls.length, before);
      expect(player.fetchEQState, isFalse);
      expect(done, isFalse);

      await elapse(tester, const Duration(milliseconds: 40));
      expect(done, isTrue);
      expect(player.fetchEQState, isFalse);
      expect(engine.callsOf('fadeEqWet'), hasLength(1));
    });

    playerTest('a round transition waits for the fade to land before retuning',
        (tester) async {
      final player = await launched(tester);
      player.setEQ(true);
      player.play();

      var from = engine.calls.length;
      var done = false;
      unawaited(player
          .setEQParams(enableEQ: true, frequency: 1000, gainDb: 6)
          .then((_) => done = true));
      expect(ops(engine.calls.skip(from)), ['fadeEqWet']);
      await tester.pump();
      expect(done, isFalse);

      await elapse(tester, const Duration(milliseconds: 60));
      expect(done, isTrue);
      final made = engine.calls.skip(from).toList();
      expect(ops(made), [
        'fadeEqWet',
        'setEqFrequency',
        'setEqGain',
        'setVolume',
        'fadeEqWet',
      ]);
      expect(made[0].args.first, 0.0);
      expect(made[1].eqWet, closeTo(0, 1e-9));
      expect(made[2].eqWet, closeTo(0, 1e-9));
      expect(made[4].args.first, 1.0);

      // With the band already out there is nothing to wait for.
      player.setEQ(false);
      await elapse(tester, const Duration(milliseconds: 40));
      from = engine.calls.length;
      unawaited(player.setEQParams(enableEQ: true, frequency: 2000, gainDb: 3));
      expect(ops(engine.calls.skip(from)), [
        'setEqFrequency',
        'setEqGain',
        'setVolume',
        'fadeEqWet',
      ]);
    });

    playerTest('end of clip: rewind and stop', (tester) async {
      engine.lengths['short.wav'] = const Duration(milliseconds: 500);
      final player = await launched(tester, path: 'short.wav');
      player.play();
      await elapse(tester, const Duration(milliseconds: 100));
      expect(player.fetchPlayerState.isPlaying, isTrue);

      await elapse(tester, const Duration(milliseconds: 500));
      expect(player.fetchPlayerState.isPlaying, isFalse);
      expect(player.fetchPosition, Duration.zero);
      expect(engine.voices, hasLength(2));
      expect(engine.voices.last.paused, isTrue);
      expect(engine.voices.last.valid, isTrue);

      player.play();
      await elapse(tester, const Duration(milliseconds: 100));
      expect(engine.voices.last.position, const Duration(milliseconds: 100));
      expect(player.fetchPlayerState.isPlaying, isTrue);
    });

    playerTest('compensation volume reaches every new voice', (tester) async {
      engine.lengths['short.wav'] = const Duration(milliseconds: 500);
      final player = await launched(tester, path: 'short.wav');
      final gain = pow(10, -6 / 20).toDouble();

      player.setEQGain(6);
      expect(engine.voices.first.volume, closeTo(gain, 1e-12));

      player.play();
      await elapse(tester, const Duration(milliseconds: 600));
      expect(engine.voices, hasLength(2));
      expect(engine.voices.last.startVolume, closeTo(gain, 1e-12));

      await player.launch(path: 'short.wav');
      final starts = engine.callsOf('startPaused');
      expect(starts, hasLength(3));
      expect(starts.last.args[1], closeTo(gain, 1e-12));
    });

    playerTest('compensation volume is 1.0 with compensation off',
        (tester) async {
      engine.lengths['short.wav'] = const Duration(milliseconds: 500);
      final player = await launched(
        tester,
        path: 'short.wav',
        volumeCompensation: false,
      );
      player.setEQGain(6);
      expect(engine.voices.first.volume, 1.0);

      player.play();
      await elapse(tester, const Duration(milliseconds: 600));
      expect(engine.voices.last.startVolume, 1.0);
    });

    playerTest('launch takes the band out every time', (tester) async {
      final player = await launched(tester);
      var order = ops(engine.calls);
      expect(order.indexOf('stepEqWet'), greaterThan(order.indexOf('open')));
      expect(order.indexOf('stepEqWet'), lessThan(order.indexOf('load')));
      expect(engine.callsOf('stepEqWet').first.args, [0.0]);

      player.setEQ(true);
      expect(engine.eqWet, 1);
      var from = engine.calls.length;
      await player.launch(path: 'a.wav');
      order = ops(engine.calls.skip(from));
      expect(order.indexOf('stepEqWet'), greaterThan(order.indexOf('open')));
      expect(order.indexOf('stepEqWet'), lessThan(order.indexOf('load')));
      expect(engine.eqWet, 0);
      expect(player.fetchEQState, isFalse);

      // A second player over the same engine, which still holds wet = 1.
      player.setEQ(true);
      expect(engine.eqWet, 1);
      final other = newPlayer(tester);
      from = engine.calls.length;
      await other.launch(path: 'a.wav');
      order = ops(engine.calls.skip(from));
      expect(order.indexOf('stepEqWet'), greaterThan(order.indexOf('open')));
      expect(order.indexOf('stepEqWet'), lessThan(order.indexOf('load')));
      expect(engine.eqWet, 0);
      expect(other.fetchEQState, isFalse);
    });

    playerTest('a device picked mid-session reaches the next launch',
        (tester) async {
      final first = playbackDevice(1, 'first', isDefault: true);
      final second = playbackDevice(2, 'second');
      final out = OutputSelection(
        prefs: await SharedPreferences.getInstance(),
        devices: FakeOutputDevices([first, second]),
        watchesDevices: false,
      );
      final player = newPlayer(tester, out);

      await player.launch(path: 'a.wav');
      expect(engine.opens.last.device, first);

      out.selectDevice(second);
      await player.launch(path: 'a.wav');
      expect(engine.opens, hasLength(2));
      expect(engine.opens.last.device, second);
    });

    playerTest('a load that fails propagates and leaves nothing launched',
        (tester) async {
      final player = await launched(tester);
      expect(player.isLaunched, isTrue);

      engine.failingPaths.add('bad.wav');
      await expectLater(
        player.launch(path: 'bad.wav'),
        throwsA(isA<StateError>()),
      );
      expect(player.isLaunched, isFalse);

      await player.launch(path: 'a.wav');
      expect(player.isLaunched, isTrue);
    });

    playerTest('the fade wait gives up and steps when the fade never lands',
        (tester) async {
      final player = await launched(tester);
      player.setEQ(true);
      player.play();

      final from = engine.calls.length;
      var done = false;
      unawaited(player
          .setEQParams(enableEQ: true, frequency: 1000, gainDb: 6)
          .then((_) => done = true));
      // Stream time stops, so the fade can never land.
      player.pause();

      await elapse(tester, const Duration(milliseconds: 280));
      expect(ops(engine.calls.skip(from).where((c) => c.op == 'stepEqWet')),
          isEmpty);
      expect(done, isFalse);

      await elapse(tester, const Duration(milliseconds: 40));
      final made = engine.calls.skip(from).toList();
      final stepAt = made.indexWhere((c) => c.op == 'stepEqWet');
      expect(stepAt, isNonNegative);
      expect(made[stepAt].args, [0.0]);
      expect(made.indexWhere((c) => c.op == 'setEqFrequency'),
          greaterThan(stepAt));
      expect(done, isTrue);
    });
  });
}
