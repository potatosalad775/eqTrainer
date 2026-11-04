import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/player/player_service.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/audio_clip_service.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/service/clip_encoder.dart';
import 'package:eq_trainer/shared/service/wav_pcm.dart';

import 'helpers/fixture_formats.dart';

/// SPIKE. Answers whether `audio_decoder` can go, for `PLAN_drop_audio_decoder.md`.
/// Delete it once that is decided.
///
/// Nothing plays, so this is silent, and SoLoud is only brought up for the one
/// test that needs an engine. Run it on each platform and keep the `SPIKE|`
/// lines:
///
///   fvm flutter test integration_test/drop_audio_decoder_spike_test.dart -d macos
///
/// Only what the switch cannot do without fails: the formats SoLoud has to read
/// everywhere, and the trim. The rest is reported, because what a platform loses
/// is a decision and not a bug.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const mustDecode = {
    'wav16',
    'wav24',
    'mp3',
    'flac',
    'ogg_vorbis',
    'ogg_opus',
  };

  late Directory dir;

  void report(String line) {
    // ignore: avoid_print
    print('SPIKE|$line');
  }

  String fixturePath(FormatFixture f) => p.join(dir.path, f.fileName);

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('eqt_spike_');
    for (final f in formatFixtures) {
      await File(fixturePath(f)).writeAsBytes(base64Decode(f.base64Data));
    }
    report('platform ${Platform.operatingSystemVersion}');
  });

  tearDownAll(() => dir.delete(recursive: true));

  testWidgets('format matrix: SoLoud against audio_decoder', (_) async {
    report('format | SoLoud | audio_decoder');
    final failures = <String>[];
    for (final f in formatFixtures) {
      final viaSoLoud = await _describe(
        () async => _Pcm.fromSoLoud(
          await SoLoud.instance.decodeFileToPcm(fixturePath(f)),
        ),
      );
      final viaPlugin = await _describe(() async {
        final wav = await AudioDecoder.convertToWavBytes(
          await File(fixturePath(f)).readAsBytes(),
          formatHint: p.extension(f.fileName).replaceFirst('.', ''),
        );
        final pcm = parseWav(wav);
        return _Pcm(pcm.samples, pcm.sampleRate, pcm.channels);
      });
      report('${f.name} | ${viaSoLoud.text} | ${viaPlugin.text}');
      if (mustDecode.contains(f.name) && !viaSoLoud.correct) {
        failures.add('${f.name}: ${viaSoLoud.text}');
      }
    }
    expect(failures, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('trim: decode, slice, encode, and read it back', (_) async {
    final source = p.join(dir.path, 'a.flac');
    final pcm = await SoLoud.instance.decodeFileToPcm(source);

    const startSec = 0.1;
    const endSec = 0.2;
    final slice = _slice(pcm, startSec, endSec);
    final expectedFrames = slice.length ~/ pcm.channels;

    final flac = p.join(dir.path, 'trim_out.flac');
    await SoLoud.instance.encodePcmToFile(
      slice,
      flac,
      sampleRate: pcm.sampleRate,
      channels: pcm.channels,
    );
    final back = await SoLoud.instance.decodeFileToPcm(flac);
    expect(back.sampleRate, pcm.sampleRate);
    expect(back.channels, pcm.channels);
    expect(back.samples.length, slice.length);
    // A 16-bit round trip, so within one quantisation step.
    var worst = 0.0;
    for (var i = 0; i < slice.length; i++) {
      worst = max(worst, (slice[i] - back.samples[i]).abs());
    }
    expect(worst, lessThan(2 / 32768));

    final opus = p.join(dir.path, 'trim_out.opus');
    await SoLoud.instance.encodePcmToFile(
      slice,
      opus,
      sampleRate: pcm.sampleRate,
      channels: pcm.channels,
      format: MixerOutputFormat.opus,
      bitrate: 192000,
    );
    final opusBack = await SoLoud.instance.decodeFileToPcm(opus);
    final opusSec =
        opusBack.samples.length / opusBack.channels / opusBack.sampleRate;

    // What the code does today, for comparison.
    final viaPlugin = p.join(dir.path, 'trim_plugin.wav');
    await AudioDecoder.trimAudio(
      source,
      viaPlugin,
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 200),
    );
    final pluginPcm = parseWav(await File(viaPlugin).readAsBytes());
    final pluginFrames = pluginPcm.samples.length ~/ pluginPcm.channels;

    report('trim SoLoud: $expectedFrames frames, FLAC round-trip error '
        '${_db(worst)}, Opus ${opusSec.toStringAsFixed(3)} s');
    report('trim audio_decoder: $pluginFrames frames, '
        '${pluginPcm.channels} ch, ${pluginPcm.sampleRate} Hz');

    // The suspected Apple failure: audio_decoder trimming an Ogg source.
    final oggTrim = p.join(dir.path, 'trim_ogg.wav');
    try {
      await AudioDecoder.trimAudio(
        p.join(dir.path, 'a.opus'),
        oggTrim,
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 200),
      );
      report('trim audio_decoder on .opus: ok');
    } catch (e) {
      report('trim audio_decoder on .opus: FAILED ${_short(e)}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  // Every format SoLoud reads here: a range must be exactly those frames of the
  // whole decode, or a trim would not line up with what the editor showed.
  testWidgets('ranges match the whole decode', (_) async {
    const start = Duration(milliseconds: 100);
    const end = Duration(milliseconds: 200);
    for (final f in formatFixtures) {
      final DecodedPcm whole;
      try {
        whole = await SoLoud.instance.decodeFileToPcm(fixturePath(f));
      } on SoLoudOfflineDecodeCppException {
        continue;
      }
      final part = await SoLoud.instance.decodeFileToPcm(
        fixturePath(f),
        start: start,
        end: end,
      );
      final expected = _slice(whole, 0.1, 0.2);
      var same = part.samples.length == expected.length;
      for (var i = 0; same && i < expected.length; i++) {
        same = part.samples[i] == expected[i];
      }
      report('range ${f.name}: ${part.samples.length ~/ part.channels} frames, '
          '${same ? 'exact' : 'DIFFERS'}');
      expect(same, isTrue, reason: f.name);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  // Stage 3: the crash this replaced came on round 2 of the same loop.
  testWidgets('convertFile on ALAC, repeatedly', (_) async {
    final source = fixturePath(
      formatFixtures.firstWhere((f) => f.name == 'm4a_alac'),
    );
    final encoder = ClipEncoder();
    var converted = 0;
    var refused = 0;
    for (var i = 0; i < 60; i++) {
      try {
        await encoder.convertFile(
          sourcePath: source,
          destPath: p.join(dir.path, 'alac_out.flac'),
        );
        converted++;
      } on SoLoudOfflineDecodeCppException {
        refused++;
      }
    }
    report('convertFile ALAC x60: $converted converted, $refused refused');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('non-ASCII paths', (_) async {
    for (final name in ['a.opus', 'a.flac', 'a.mp3', 'a.m4a']) {
      final ext = p.extension(name);
      final path = p.join(dir.path, '한글 파일 é$ext');
      await File(p.join(dir.path, name)).copy(path);
      final decoded = await _describe(
        () async =>
            _Pcm.fromSoLoud(await SoLoud.instance.decodeFileToPcm(path)),
      );
      report('non-ASCII decode $ext: ${decoded.text}');
    }
  });

  testWidgets('non-ASCII paths through the engine loader', (_) async {
    await SoLoud.instance.init(androidBackend: defaultAndroidBackend);
    try {
      for (final ext in ['.opus', '.flac', '.mp3', '.m4a']) {
        final path = p.join(dir.path, '한글 파일 é$ext');
        try {
          final source =
              await SoLoud.instance.loadFile(path, mode: LoadMode.disk);
          report('non-ASCII loadFile $ext: ok');
          await SoLoud.instance.disposeSource(source);
        } catch (e) {
          report('non-ASCII loadFile $ext: FAILED ${_short(e)}');
        }
      }
    } finally {
      SoLoud.instance.deinit();
    }
  });

  // Whole-file decoding is the cost of the switch, since a trim has to decode up
  // to its end point. Shorten [_longMinutes] if a slow device takes too long.
  testWidgets('a long file: time and memory', (_) async {
    final frames = _longMinutes * 60 * 44100;
    final samples = Float32List(frames * 2);
    for (var i = 0; i < frames; i++) {
      final t = i / 44100;
      samples[i * 2] = 0.2 * sin(2 * pi * 440 * t);
      samples[i * 2 + 1] = 0.2 * sin(2 * pi * 880 * t);
    }

    for (final (ext, format) in [
      ('.flac', MixerOutputFormat.flac),
      ('.opus', MixerOutputFormat.opus),
    ]) {
      final path = p.join(dir.path, 'long$ext');
      await SoLoud.instance.encodePcmToFile(
        samples,
        path,
        sampleRate: 44100,
        channels: 2,
        format: format,
        bitrate: 192000,
      );
      final size = await File(path).length();

      final measured = await _measure(
        () => SoLoud.instance.decodeFileToPcm(path),
      );
      final decodedMb = measured.result.samples.lengthInBytes ~/ (1024 * 1024);
      report('long $_longMinutes min $ext (${size ~/ (1024 * 1024)} MB file): '
          'decoded in ${measured.seconds} s, $decodedMb MB of PCM, '
          'RSS rose by up to ${measured.rssRiseMb} MB');

      final trim = await _measure(
        () => SoLoud.instance.decodeFileToPcm(
          path,
          start: const Duration(minutes: _longMinutes - 1),
          end: const Duration(minutes: _longMinutes - 1, seconds: 10),
        ),
      );
      final trimMb = trim.result.samples.lengthInBytes ~/ (1024 * 1024);
      report('long $_longMinutes min $ext, 10 s range near the end: '
          '${trim.seconds} s, $trimMb MB of PCM, '
          'RSS rose by up to ${trim.rssRiseMb} MB');
    }

    final flac = p.join(dir.path, 'long.flac');

    // An import of a long M4A, the worst case: only platform codecs read it, so
    // the whole file is in memory, and the new path holds it twice while
    // interleaving.
    final m4a = p.join(dir.path, 'long.m4a');
    await AudioDecoder.convertToM4a(flac, m4a);
    final encoder = ClipEncoder();
    final viaSoLoud = await _measure(
      () => encoder.convertFile(
        sourcePath: m4a,
        destPath: p.join(dir.path, 'long_import_new.opus'),
      ),
    );
    report('long $_longMinutes min .m4a import, SoLoud: '
        '${viaSoLoud.seconds} s, RSS rose by up to ${viaSoLoud.rssRiseMb} MB');
    // On Android the old path cannot be measured: on a JM21 it ends the process
    // with an OutOfMemoryError, returning 105 MB over the method channel.
    if (!Platform.isAndroid) {
      final viaPlugin = await _measure(() async {
        await encoder.encodeWavBytes(
          wavBytes: await AudioDecoder.convertToWavBytes(
            await File(m4a).readAsBytes(),
            formatHint: 'm4a',
          ),
          destPath: p.join(dir.path, 'long_import_old.opus'),
        );
      });
      report('long $_longMinutes min .m4a import, audio_decoder: '
          '${viaPlugin.seconds} s, RSS rose by up to ${viaPlugin.rssRiseMb} MB');
    }

    final out = p.join(dir.path, 'long_trim.wav');
    final measured = await _measure(
      () => AudioDecoder.trimAudio(
        flac,
        out,
        const Duration(minutes: _longMinutes - 1),
        const Duration(minutes: _longMinutes - 1, seconds: 10),
      ),
    );
    report('long .flac, audio_decoder trim of 10 s near the end: '
        '${measured.seconds} s, RSS rose by up to ${measured.rssRiseMb} MB');
  }, timeout: const Timeout(Duration(minutes: 20)));

  // The app's own trim path, on what it would really be handed: an Ogg file, or
  // the Opus temp file a converted import leaves behind.
  testWidgets('today: createClip trimming each kept format', (_) async {
    final clips = await Directory(p.join(dir.path, 'clips')).create();
    final service = AudioClipService(_NoRepository(), _Dirs(clips.path));
    for (final name in ['a.opus', 'a.ogg', 'a.flac', 'a.mp3', 'a.wav']) {
      try {
        await service.createClip(
          sourcePath: p.join(dir.path, name),
          startSec: 0.1,
          endSec: 0.2,
          isTrimmed: true,
          importFormat: ImportFormat.smart,
        );
        report('createClip trim $name: ok');
      } catch (e) {
        report('createClip trim $name: FAILED ${_short(e)}');
      }
    }
  });
}

class _NoRepository extends Fake implements IAudioClipRepository {
  @override
  Future<void> addClip(AudioClip clip) async {}
}

class _Dirs extends Fake implements AppDirectories {
  _Dirs(this.clipsPath);

  final String clipsPath;

  @override
  Future<String> getClipsPath() async => clipsPath;
}

/// Runs [work], sampling RSS meanwhile. `ProcessInfo.maxRss` would not do: it
/// never falls, so it would only report the buffer this test synthesised.
Future<({T result, String seconds, int rssRiseMb})> _measure<T>(
  Future<T> Function() work,
) async {
  final before = ProcessInfo.currentRss;
  var peak = before;
  final sampler = Timer.periodic(const Duration(milliseconds: 20), (_) {
    peak = max(peak, ProcessInfo.currentRss);
  });
  final watch = Stopwatch()..start();
  final result = await work();
  final seconds = (watch.elapsedMilliseconds / 1000).toStringAsFixed(1);
  peak = max(peak, ProcessInfo.currentRss);
  sampler.cancel();
  return (
    result: result,
    seconds: seconds,
    rssRiseMb: (peak - before) ~/ (1024 * 1024),
  );
}

const _longMinutes = 10;

Float32List _slice(DecodedPcm pcm, double startSec, double endSec) {
  final start = (startSec * pcm.sampleRate).round() * pcm.channels;
  final end = (endSec * pcm.sampleRate).round() * pcm.channels;
  return Float32List.sublistView(
    pcm.samples,
    start,
    min(end, pcm.samples.length),
  );
}

String _db(double linear) => linear <= 0
    ? '-inf dB'
    : '${(20 * log(linear) / ln10).toStringAsFixed(1)} dB';

String _short(Object e) {
  final text = e.toString().replaceAll('\n', ' ');
  return text.length > 90 ? '${text.substring(0, 90)}...' : text;
}

class _Pcm {
  _Pcm(this.samples, this.sampleRate, this.channels);

  factory _Pcm.fromSoLoud(DecodedPcm pcm) =>
      _Pcm(pcm.samples, pcm.sampleRate, pcm.channels);

  final Float32List samples;
  final int sampleRate;
  final int channels;

  /// Level of [frequency] in [channel], by a Goertzel filter.
  double level(int channel, double frequency) {
    final frames = samples.length ~/ channels;
    final w = 2 * pi * frequency / sampleRate;
    var a = 0.0;
    var b = 0.0;
    for (var i = 0; i < frames; i++) {
      final s = samples[i * channels + channel];
      a += s * cos(w * i);
      b += s * sin(w * i);
    }
    return 2 * sqrt(a * a + b * b) / frames;
  }
}

/// One cell of the matrix.
Future<({String text, bool correct})> _describe(
  Future<_Pcm> Function() decode,
) async {
  final _Pcm pcm;
  try {
    pcm = await decode().timeout(const Duration(seconds: 30));
  } catch (e) {
    return (text: 'FAILED ${_short(e)}', correct: false);
  }

  final seconds = pcm.samples.length / pcm.channels / pcm.sampleRate;
  // 0.3 s, give or take a lossy codec's priming and padding.
  final lengthOk = (seconds - 0.3).abs() < 0.08;

  var channelsOk = true;
  if (pcm.channels == 2) {
    // The left is 440 Hz and the right 880 Hz, except for the mono fixtures,
    // which only come back as two channels if something upmixed them.
    final left440 = pcm.level(0, 440);
    final right440 = pcm.level(1, 440);
    final left880 = pcm.level(0, 880);
    final right880 = pcm.level(1, 880);
    channelsOk = left440 > 4 * right440 && right880 > 4 * left880;
  }

  final desc = '${pcm.channels} ch ${pcm.sampleRate} Hz '
      '${seconds.toStringAsFixed(3)} s';
  final notes = [
    if (!lengthOk) 'BAD LENGTH',
    if (!channelsOk) 'BAD CHANNELS',
  ];
  return (
    text: notes.isEmpty ? desc : '$desc ${notes.join(' ')}',
    correct: lengthOk && channelsOk,
  );
}
