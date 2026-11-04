import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/player/player_service.dart';
import 'package:eq_trainer/shared/service/clip_encoder.dart';

/// Gate 5 of `PLAN_drop_audio_decoder.md`: does decoding during playback cause
/// audible problems? Delete it with the spike once that is decided.
///
/// A person has to listen, on the slowest device available. A quiet steady chord
/// plays through the real [PlayerService], so that any click or dropout stands
/// out, while each kind of work runs in turn. The screen names the current phase,
/// so a problem can be tied to it.
///
///   fvm flutter test integration_test/gate5_listening_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const longMinutes = 10;

  testWidgets('listen for problems during each phase', (tester) async {
    // Pumped once and then driven by the notifier, because a pump waits for a
    // frame, and the audio must carry on whether or not one comes.
    IntegrationTestWidgetsFlutterBinding.instance.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    final screen = ValueNotifier('');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder(
                valueListenable: screen,
                builder: (context, text, child) => Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    void show(String title, String detail) {
      // ignore: avoid_print
      print('GATE5|$title');
      screen.value = '$title\n\n$detail';
    }

    show('PREPARING', 'Nothing to listen for yet.');

    final dir = await Directory.systemTemp.createTemp('eqt_gate5_');
    final soloud = SoLoud.instance;
    final encoder = ClipEncoder();

    final flac = p.join(dir.path, 'long.flac');
    final opus = p.join(dir.path, 'long.opus');
    final long = _chord(longMinutes * 60, 0.2);
    await soloud.encodePcmToFile(
      long,
      flac,
      sampleRate: _rate,
      channels: 2,
      format: MixerOutputFormat.flac,
    );
    await soloud.encodePcmToFile(
      long,
      opus,
      sampleRate: _rate,
      channels: 2,
      format: MixerOutputFormat.opus,
      bitrate: 192000,
    );

    final played = p.join(dir.path, 'played.flac');
    await soloud.encodePcmToFile(
      _chord(6 * 60, 0.1),
      played,
      sampleRate: _rate,
      channels: 2,
      format: MixerOutputFormat.flac,
    );

    final player = PlayerService();
    await player.launch(
      androidBackend: defaultAndroidBackend,
      outputDevice: null,
      path: played,
    );
    player.play();

    const start = Duration(minutes: longMinutes - 1);
    const end = Duration(minutes: longMinutes - 1, seconds: 10);

    Future<void> phase(
      String title,
      String detail,
      Duration length,
      Future<void> Function()? work,
    ) async {
      show(title, detail);
      final until = DateTime.now().add(length);
      var rounds = 0;
      while (DateTime.now().isBefore(until)) {
        if (work == null) {
          await Future<void>.delayed(const Duration(seconds: 1));
        } else {
          await work();
          rounds++;
        }
      }
      // ignore: avoid_print
      print('GATE5|$title done, $rounds rounds');
    }

    await phase(
      '1 of 6: BASELINE',
      'Nothing is decoding. Learn what clean sounds like.',
      const Duration(seconds: 20),
      null,
    );
    await phase(
      '2 of 6: TRIM FLAC',
      'New trim: a 10 s range of a 10 minute FLAC, encoded to Opus.',
      const Duration(seconds: 35),
      () => encoder.trimFile(
        sourcePath: flac,
        destPath: p.join(dir.path, 'trim_flac.opus'),
        start: start,
        end: end,
      ),
    );
    await phase(
      '3 of 6: TRIM OPUS',
      'New trim: a 10 s range of a 10 minute Opus file, encoded to Opus.',
      const Duration(seconds: 40),
      () => encoder.trimFile(
        sourcePath: opus,
        destPath: p.join(dir.path, 'trim_opus.opus'),
        start: start,
        end: end,
      ),
    );
    await phase(
      '4 of 6: WHOLE FILE',
      'Whole 10 minute Opus decode, what a conversion would do in Stage 3.',
      const Duration(seconds: 40),
      () => soloud.decodeFileToPcm(opus),
    );
    await phase(
      '5 of 6: OLD TRIM',
      'audio_decoder trim, for comparison with today.',
      const Duration(seconds: 30),
      () => AudioDecoder.trimAudio(
        flac,
        p.join(dir.path, 'old_trim.wav'),
        start,
        end,
      ),
    );
    await phase(
      '6 of 6: BASELINE',
      'Nothing is decoding again.',
      const Duration(seconds: 15),
      null,
    );

    show('DONE', 'Finished.');
    await player.shutdown();
    player.dispose();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

const _rate = 44100;

/// A soft, steady chord: nothing in it moves, so anything that does was added.
Float32List _chord(int seconds, double level) {
  final frames = seconds * _rate;
  final out = Float32List(frames * 2);
  final a = 2 * pi * 220 / _rate;
  final b = 2 * pi * 330 / _rate;
  final c = 2 * pi * 440 / _rate;
  for (var i = 0; i < frames; i++) {
    final s = level * (sin(a * i) + sin(b * i) + 0.5 * sin(c * i)) / 2.5;
    out[i * 2] = s;
    out[i * 2 + 1] = s;
  }
  return out;
}
