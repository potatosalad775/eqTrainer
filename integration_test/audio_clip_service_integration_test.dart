import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/audio_clip_service.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory fixturesDir;
  late Directory hiveDir;
  late Directory clipsDir;
  late Box<AudioClip> box;
  late AudioClipRepository repo;
  late AudioClipService service;

  // Fixture files are bundled as Flutter assets and extracted to a temp
  // directory at test startup. This works on all platforms, including
  // sandboxed macOS where Directory.current.path is not the project root.
  String fixture(String name) => p.join(fixturesDir.path, name);

  setUpAll(() async {
    fixturesDir = await Directory.systemTemp.createTemp('eqt_fixtures_');
    for (final name in [
      'sine_440hz_1s.wav',
      'sine_440hz_3s.mp3',
      'sine_440hz_3s.flac',
      'silence_2s.wav',
    ]) {
      final data = await rootBundle.load('test/fixtures/audio/$name');
      await File(p.join(fixturesDir.path, name))
          .writeAsBytes(data.buffer.asUint8List());
    }
  });

  tearDownAll(() async {
    if (fixturesDir.existsSync()) fixturesDir.deleteSync(recursive: true);
  });

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('eqt_hive_');
    clipsDir = await Directory.systemTemp.createTemp('eqt_clips_');

    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AudioClipAdapter());
    }

    // Use a unique box name per test run to avoid state leakage
    box = await Hive.openBox<AudioClip>('test_audio_clips');

    // Wire up the real repository with the test box
    repo = AudioClipRepository(box: box);

    // Real AppDirectories subclass that points to our temp clips dir
    final dirs = _TestAppDirectories(clipsDir.path);

    service = AudioClipService(repo, dirs);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    await hiveDir.delete(recursive: true);
    await clipsDir.delete(recursive: true);
  });

  // ---------------------------------------------------------------------------
  // isTrimmed: false — convert to WAV path
  // ---------------------------------------------------------------------------
  group('createClip (isTrimmed: false)', () {
    testWidgets('converts WAV file and saves correct metadata to Hive', (tester) async {
      final sourcePath = fixture('sine_440hz_1s.wav');

      await service.createClip(
        sourcePath: sourcePath,
        startSec: 0.0,
        endSec: 1.0,
        isTrimmed: false,
      );

      final clips = repo.getAllClips();
      expect(clips.length, equals(1));

      final clip = clips.first;
      expect(clip.fileName, endsWith('.wav'));
      expect(clip.ogAudioName, equals('sine_440hz_1s.wav'));
      expect(clip.duration, equals(1.0));
      expect(clip.isEnabled, isTrue);

      // The physical file must exist in the clips directory
      final destFile = File(p.join(clipsDir.path, clip.fileName));
      expect(destFile.existsSync(), isTrue);
      expect(destFile.lengthSync(), greaterThan(0));
    });

    testWidgets('converts MP3 file to WAV', (tester) async {
      await service.createClip(
        sourcePath: fixture('sine_440hz_3s.mp3'),
        startSec: 0.0,
        endSec: 3.0,
        isTrimmed: false,
      );

      final clip = repo.getAllClips().first;
      // isTrimmed: false always converts to WAV
      expect(clip.fileName, endsWith('.wav'));
      expect(File(p.join(clipsDir.path, clip.fileName)).existsSync(), isTrue);
    });

    testWidgets('converts FLAC file to WAV', (tester) async {
      await service.createClip(
        sourcePath: fixture('sine_440hz_3s.flac'),
        startSec: 0.0,
        endSec: 3.0,
        isTrimmed: false,
      );

      final clip = repo.getAllClips().first;
      // isTrimmed: false always converts to WAV
      expect(clip.fileName, endsWith('.wav'));
    });

    testWidgets('multiple createClip calls store multiple clips', (tester) async {
      await service.createClip(
        sourcePath: fixture('sine_440hz_1s.wav'),
        startSec: 0.0,
        endSec: 1.0,
        isTrimmed: false,
      );
      await service.createClip(
        sourcePath: fixture('sine_440hz_3s.mp3'),
        startSec: 0.0,
        endSec: 3.0,
        isTrimmed: false,
      );

      expect(repo.getAllClips().length, equals(2));
    });
  });

  // ---------------------------------------------------------------------------
  // isTrimmed: true — trim path (AudioDecoder.trimAudio)
  // ---------------------------------------------------------------------------
  group('createClip (isTrimmed: true)', () {
    testWidgets('trims WAV and stores duration = endSec - startSec', (tester) async {
      await service.createClip(
        sourcePath: fixture('sine_440hz_1s.wav'),
        startSec: 0.0,
        endSec: 0.5,
        isTrimmed: true,
      );

      final clip = repo.getAllClips().first;
      expect(clip.duration, closeTo(0.5, 0.001));
      expect(clip.fileName, endsWith('.wav'));

      // The trimmed file must exist and be smaller than the original
      final destFile = File(p.join(clipsDir.path, clip.fileName));
      final sourceFile = File(fixture('sine_440hz_1s.wav'));
      expect(destFile.existsSync(), isTrue);
      expect(destFile.lengthSync(), lessThan(sourceFile.lengthSync()));
    });

    testWidgets('trims from the middle of a WAV file', (tester) async {
      await service.createClip(
        sourcePath: fixture('silence_2s.wav'),
        startSec: 0.5,
        endSec: 1.5,
        isTrimmed: true,
      );

      final clip = repo.getAllClips().first;
      expect(clip.duration, closeTo(1.0, 0.001));
      expect(File(p.join(clipsDir.path, clip.fileName)).existsSync(), isTrue);
    });
  });
}

// A minimal AppDirectories implementation that returns a fixed clips path.
class _TestAppDirectories implements AppDirectories {
  _TestAppDirectories(this._clipsPath);
  final String _clipsPath;

  @override
  Future<String> getClipsPath() async => _clipsPath;

  @override
  Future<Directory> getClipsDir() async => Directory(_clipsPath);

  @override
  Future<Directory> getAppSupportDir() async => Directory(_clipsPath);
}
