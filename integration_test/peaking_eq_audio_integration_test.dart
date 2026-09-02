import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:integration_test/integration_test.dart';

import 'package:eq_trainer/shared/player/player_service.dart';

import 'helpers/fixtures.dart';

/// End-to-end check that the peaking EQ actually shapes eqTrainer's audio.
///
/// `player_service_integration_test.dart` asserts that the filter parameters
/// are *driven* correctly. This file asserts on the audio that comes out:
/// SoLoud's mixer output is captured as float PCM and measured, so a filter
/// that was wired up but never applied — or applied as a broadband gain —
/// would fail here.
///
/// The fixture is a 440 Hz sine, so a band centred on 440 Hz should lift the
/// level by its gain, and a band placed well away from it should leave the
/// level alone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestFixtures fixtures;

  /// Root-mean-square of interleaved float32 PCM.
  double rms(Float32List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return sqrt(sum / samples.length);
  }

  double toDb(double ratio) => 20 * (log(ratio) / ln10);

  setUpAll(() async {
    fixtures = await TestFixtures.create();
  });

  tearDownAll(() => fixtures.dispose());

  /// Plays the sine with the band at [frequency]/[gainDb] and returns the RMS
  /// of the rendered output with the band out, then with the band in.
  ///
  /// Volume compensation is off so the numbers show the filter alone; the
  /// compensation is a constant scaling on both states and is covered
  /// separately.
  Future<({double dry, double wet})> measure({
    required double frequency,
    required double gainDb,
    double q = 1,
  }) async {
    final player = PlayerService();
    final chunks = <Uint8List>[];
    StreamSubscription<Uint8List>? sub;
    try {
      await player.launch(
        androidBackend: defaultAndroidBackend,
        outputDevice: null,
        path: fixtures.path(TestFixtures.sine440hz3sFlac),
        volumeCompensation: false,
      );
      player.setEQQ(q);
      await player.setEQParams(
        enableEQ: false,
        frequency: frequency,
        gainDb: gainDb,
      );

      final stream = SoLoud.instance.startMixerOutputStream();
      sub = stream.listen(chunks.add);
      player.play();

      // Let the dry signal render, then capture the boundary between the two
      // states so each half can be measured separately.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final dryBytes = chunks.fold<int>(0, (a, c) => a + c.length);

      player.setEQ(true);
      // Skip past the fade so only the settled wet signal is measured.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final wetStart = chunks.fold<int>(0, (a, c) => a + c.length);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      SoLoud.instance.stopMixerOutputStream();
      await sub.cancel();
      sub = null;

      final all = Uint8List.fromList(
        chunks.expand((c) => c).toList(growable: false),
      );

      Float32List slice(int startByte, int endByte) {
        // Align to 4-byte float boundaries.
        final s = (startByte ~/ 4) * 4;
        final e = (min(endByte, all.length) ~/ 4) * 4;
        if (e <= s) return Float32List(0);
        return all.buffer.asFloat32List(all.offsetInBytes + s, (e - s) ~/ 4);
      }

      // Drop the first 200 ms of the dry window: playback start and the
      // device ramp-up land there.
      final dry = slice(dryBytes ~/ 3, dryBytes);
      final wet = slice(wetStart, all.length);
      expect(dry.length, greaterThan(1000),
          reason: 'not enough dry audio captured');
      expect(wet.length, greaterThan(1000),
          reason: 'not enough wet audio captured');

      return (dry: rms(dry), wet: rms(wet));
    } finally {
      await sub?.cancel();
      if (SoLoud.instance.isMixerOutputStreamRunning) {
        SoLoud.instance.stopMixerOutputStream();
      }
      await player.shutdown();
      player.dispose();
    }
  }

  group('peaking EQ — rendered audio', () {
    testWidgets('renders audio at all', (_) async {
      final r = await measure(frequency: 440, gainDb: 0);
      expect(r.dry, greaterThan(0.001),
          reason: 'the engine rendered silence — nothing was captured');
    });

    testWidgets('a band on the tone lifts the level by its gain', (_) async {
      const gainDb = 15.0;
      final r = await measure(frequency: 440, gainDb: gainDb);

      final measured = toDb(r.wet / r.dry);
      // The tone sits at the centre of the bell, so it takes very nearly the
      // full peak gain. Tolerance covers the capture window boundaries and
      // the fixture's tuning, not filter error.
      expect(measured, closeTo(gainDb, 2.0),
          reason: 'expected ~$gainDb dB of boost, measured '
              '${measured.toStringAsFixed(2)} dB');
    });

    testWidgets('a band on the tone cuts the level by its gain', (_) async {
      const gainDb = -15.0;
      final r = await measure(frequency: 440, gainDb: gainDb);

      final measured = toDb(r.wet / r.dry);
      expect(measured, closeTo(gainDb, 2.0),
          reason: 'expected ~$gainDb dB of cut, measured '
              '${measured.toStringAsFixed(2)} dB');
    });

    testWidgets('a band away from the tone leaves the level alone', (_) async {
      // Same +15 dB, but four octaves up. If the filter were applying a
      // broadband gain rather than a bell, this would boost just as much.
      final r = await measure(frequency: 7000, gainDb: 15, q: 4);

      final measured = toDb(r.wet / r.dry);
      expect(measured.abs(), lessThan(1.0),
          reason: 'a band at 7 kHz should not move a 440 Hz tone, but the '
              'level changed by ${measured.toStringAsFixed(2)} dB');
    });
  });
}
