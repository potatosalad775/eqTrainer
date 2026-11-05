import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_soloud/flutter_soloud.dart' show AndroidAudioBackend;

import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:eq_trainer/shared/service/import_workflow_service.dart';

import '../../helpers/fake_encoder.dart';

class _MockImportPlayer extends Mock implements ImportPlayer {}

/// The import page's two service calls, headless.
///
/// `convertTo` is the seam where a foreign file becomes an app-format clip
/// before `AudioClipService` ever sees it. The behaviour worth pinning is the
/// failure path: a half-written file left in the temp directory would be
/// picked up by the importer as if it were a finished conversion.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpRoot;
  late Directory srcDir;
  late FakeClipEncoder encoder;
  late ImportWorkflowService service;

  setUpAll(() => registerFallbackValue(AndroidAudioBackend.openSles));

  setUp(() async {
    tmpRoot = await Directory.systemTemp.createTemp('eqt_import_tmp_');
    srcDir = await Directory.systemTemp.createTemp('eqt_import_src_');
    encoder = FakeClipEncoder();
    service = ImportWorkflowService(encoder: encoder);

    // path_provider's platform implementations register through the plugin
    // registrant, which a unit test never runs, so the default method-channel
    // implementation is in play and can be answered here.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async =>
          call.method == 'getTemporaryDirectory' ? tmpRoot.path : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await tmpRoot.delete(recursive: true);
    await srcDir.delete(recursive: true);
  });

  Future<String> source(String name) async {
    final f = File(p.join(srcDir.path, name));
    await f.writeAsBytes([9, 9, 9]);
    return f.path;
  }

  group('convertTo', () {
    test('writes into a temp/ folder under the app temp directory', () async {
      final out = await service.convertTo(
        fileNameWithoutExt: '1000',
        sourcePath: await source('song.m4a'),
        targetExt: '.opus',
      );

      expect(out, equals(p.join(tmpRoot.path, 'temp', '1000.opus')));
      expect(File(out).existsSync(), isTrue);
    });

    for (final targetExt in const ['.flac', '.opus', '.wav']) {
      test('a $targetExt target goes through the encoder', () async {
        final out = await service.convertTo(
          fileNameWithoutExt: '1000',
          sourcePath: await source('song.m4a'),
          targetExt: targetExt,
        );

        expect(encoder.encoded, equals([out]));
        expect(File(out).existsSync(), isTrue);
      });
    }

    test('a failed encode removes the partial file and rethrows', () async {
      service = ImportWorkflowService(
        encoder: FakeClipEncoder(throwOnEncode: true),
      );
      // What an encoder that died mid-write would leave behind.
      final partial = File(p.join(tmpRoot.path, 'temp', '1000.opus'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);

      await expectLater(
        service.convertTo(
          fileNameWithoutExt: '1000',
          sourcePath: await source('song.m4a'),
          targetExt: '.opus',
        ),
        throwsException,
      );
      expect(partial.existsSync(), isFalse);
    });

  });

  group('loadAudioFile', () {
    late _MockImportPlayer player;
    late AudioState audioState;

    setUp(() {
      player = _MockImportPlayer();
      audioState = AudioState(
        androidBackend: AndroidAudioBackend.openSles,
        outputDevice: null,
      );
      when(() => player.launch(
            androidBackend: any(named: 'androidBackend'),
            outputDevice: null,
            path: any(named: 'path'),
            volumeCompensation: any(named: 'volumeCompensation'),
          )).thenAnswer((_) async {});
    });

    tearDown(() => audioState.dispose());

    test('returns the duration the player reports once loaded', () async {
      when(() => player.fetchDuration)
          .thenReturn(const Duration(seconds: 42));

      final duration = await service.loadAudioFile(
        audioState: audioState,
        importPlayer: player,
        filePath: '/x.flac',
      );

      expect(duration, equals(const Duration(seconds: 42)));
      verify(() => player.launch(
            androidBackend: AndroidAudioBackend.openSles,
            outputDevice: null,
            path: '/x.flac',
            volumeCompensation: any(named: 'volumeCompensation'),
          )).called(1);
    });

    test('a file that decodes to nothing is an error, not a wait', () async {
      when(() => player.fetchDuration).thenReturn(Duration.zero);

      await expectLater(
        service.loadAudioFile(
          audioState: audioState,
          importPlayer: player,
          filePath: '/empty.flac',
        ),
        throwsException,
      );
    });
  });
}
