import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eq_trainer/ui/import/import_page.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/data/import_player.dart';
import 'package:eq_trainer/data/clips/clip_encoder.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/clips/audio_clip_service.dart';
import 'package:eq_trainer/data/clips/clip_import.dart';
import 'package:eq_trainer/ui/import/widget/editor_clip_save_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_encoder.dart';
import '../../helpers/fake_output_devices.dart';
import '../../helpers/mocks.dart';

class _FakePicker extends FilePickerPlatform {
  _FakePicker(this.fileName);

  final String fileName;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async =>
      [_FakeFile(fileName)];
}

final class _FakeFile extends PlatformFile {
  _FakeFile(this.name);

  @override
  final String name;

  @override
  String? get path => '/picked/$name';

  @override
  Uri get uri => throw UnimplementedError();
  @override
  get xFile => throw UnimplementedError();
  @override
  lengthSync() => throw UnimplementedError();
  @override
  length() => throw UnimplementedError();
  @override
  readAsBytes() => throw UnimplementedError();
  @override
  readAsByteStream() => throw UnimplementedError();
}

class _MockClipService extends Mock implements AudioClipService {}

/// A player whose load does what the test says, so no engine is involved.
class _ScriptedPlayer extends ImportPlayer {
  _ScriptedPlayer(super.output, {required super.hold, this.loadError});

  final Object? loadError;

  @override
  Future<void> launch({required String? path, bool volumeCompensation = true}) async {
    if (loadError != null) throw loadError!;
  }

  @override
  Duration get fetchDuration => const Duration(seconds: 5);
}

/// The page against a fake picker, encoder and player, so no engine is involved.
void main() {
  late ClipFormatMigration migration;
  late MiscSettingsProvider settings;
  late OutputSelection output;
  late Directory tmp;
  late _MockClipService clips;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await MiscSettingsProvider.load();
    output = OutputSelection(
      prefs: await SharedPreferences.getInstance(),
      devices: FakeOutputDevices(),
    );
    migration = ClipFormatMigration(
      MockClipLibrary(),
      importFormat: 0,
      encoder: FakeClipEncoder(),
    );
    tmp = Directory.systemTemp.createTempSync('import_page_');
    clips = _MockClipService();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> pumpPage(
    WidgetTester tester, {
    required String pick,
    FakeClipEncoder? encoder,
    Object? loadError,
    bool Function()? settled,
  }) async {
    FilePickerPlatform.instance = _FakePicker(pick);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: migration),
        ChangeNotifierProvider.value(value: output),
        Provider<AudioClipService>.value(value: clips),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ImportPage(
          createImport: (context) => ClipImport(
            clips: clips,
            importFormat: settings.importFormat,
            encoder: encoder ?? FakeClipEncoder(),
            tempDirectory: () async => tmp,
          ),
          createPlayer: (context) => _ScriptedPlayer(
            output,
            hold: migration,
            loadError: loadError,
          ),
        ),
      ),
    ));
    await tester.pump();
    // The temp directory and the fake encoder do real file I/O, which a
    // fake-async test only sees complete if the real clock is let run, one
    // step at a time since each await resumes on a pump.
    //
    // Without [settled] that is a fixed 10 steps. With it, the wait ends as
    // soon as it holds, and is given up to 2 s of real time, for a slow disk.
    final steps = settled == null ? 10 : 100;
    for (var i = 0; i < steps; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (settled != null && settled()) break;
    }
  }

  /// True once a pick that converts has landed its file and shown the editor.
  bool Function() convertedAndShown(File converted) =>
      () =>
          converted.existsSync() &&
          find.byType(EditorClipSaveButton).evaluate().isNotEmpty;

  // Flutter tests run as Android whatever the host, so ask the same question
  // the message does.
  String unsupportedText() => ffmpegMayBeMissing()
      ? l10n.importAlertUnsupportedContentLinux
      : l10n.importAlertUnsupportedContent;

  testWidgets('holds the library migration while open', (tester) async {
    await pumpPage(tester, pick: 'a.ogg');
    expect(migration.isPaused, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(migration.isPaused, isFalse);
  });

  testWidgets('a file that loads shows the editor', (tester) async {
    await pumpPage(tester, pick: 'a.ogg');
    expect(find.byType(EditorClipSaveButton), findsOneWidget);
  });

  testWidgets('a file that skips conversion and cannot load gets its own dialog',
      (tester) async {
    await pumpPage(
      tester,
      pick: 'corrupt.ogg',
      loadError: const SoLoudFileLoadFailedException(),
    );
    expect(find.text(unsupportedText()), findsOneWidget);
  });

  testWidgets('a load failure unrelated to the file stays a generic error',
      (tester) async {
    await pumpPage(
      tester,
      pick: 'a.ogg',
      loadError: const SoLoudFileNotFoundException(),
    );
    expect(find.text(l10n.importAlertErrorContent), findsOneWidget);
  });

  testWidgets('too many channels says so', (tester) async {
    await pumpPage(
      tester,
      pick: 'surround.m4a',
      encoder: _FailingEncoder(const UnsupportedChannelCountException(6)),
    );
    expect(find.text(l10n.importAlertTooManyChannelsContent), findsOneWidget);
  });

  testWidgets('shows the converting state, and leaving mid-conversion cleans up',
      (tester) async {
    final landing = Completer<void>();
    await pumpPage(
      tester,
      pick: 'long.m4a',
      encoder: FakeClipEncoder(onWrite: () => landing.future),
    );
    expect(find.text(l10n.importConverting1), findsOneWidget);

    // Leaving while it runs: the output is deleted when it lands.
    await tester.pumpWidget(const SizedBox());
    landing.complete();
    final converted = File(p.join(tmp.path, 'temp', 'long.opus'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(converted.existsSync(), isFalse);
  });

  testWidgets('leaving deletes the converted file', (tester) async {
    final converted = File(p.join(tmp.path, 'temp', 'song.opus'));
    await pumpPage(tester,
        pick: 'song.m4a', settled: convertedAndShown(converted));
    expect(converted.existsSync(), isTrue);

    await tester.pumpWidget(const SizedBox());
    // Normally gone at once. A slow runner can still have the conversion in
    // flight, which finishes on the real clock, and on Windows the first
    // delete can find the file still open, which ClipImport retries on timers
    // that only a pump with a duration fires. So wait on both clocks.
    for (var i = 0; i < 100 && converted.existsSync(); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(converted.existsSync(), isFalse);
  });

  testWidgets('leaving mid-save keeps the converted file until it settles',
      (tester) async {
    final finish = Completer<void>();
    bool? existedWhenRead;
    when(() => clips.createClip(
          sourcePath: any(named: 'sourcePath'),
          originalPath: any(named: 'originalPath'),
          startSec: any(named: 'startSec'),
          endSec: any(named: 'endSec'),
          isTrimmed: any(named: 'isTrimmed'),
          importFormat: any(named: 'importFormat'),
        )).thenAnswer((invocation) async {
      await finish.future;
      existedWhenRead =
          File(invocation.namedArguments[#sourcePath] as String).existsSync();
    });
    final converted = File(p.join(tmp.path, 'temp', 'song.opus'));
    await pumpPage(tester,
        pick: 'song.m4a', settled: convertedAndShown(converted));

    await tester.tap(find.byType(EditorClipSaveButton));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(converted.existsSync(), isTrue);

    finish.complete();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();

    expect(existedWhenRead, isTrue);
    expect(converted.existsSync(), isFalse);
  });

  testWidgets('a save that fails says why in a snackbar', (tester) async {
    when(() => clips.createClip(
          sourcePath: any(named: 'sourcePath'),
          originalPath: any(named: 'originalPath'),
          startSec: any(named: 'startSec'),
          endSec: any(named: 'endSec'),
          isTrimmed: any(named: 'isTrimmed'),
          importFormat: any(named: 'importFormat'),
        )).thenAnswer(
        (_) async => throw const UnsupportedChannelCountException(6));
    await pumpPage(tester, pick: 'a.ogg');

    await tester.tap(find.byType(EditorClipSaveButton));
    await tester.pump();

    expect(find.text(l10n.importAlertTooManyChannelsContent), findsOneWidget);
  });

  testWidgets('a save that fails for no known reason says so', (tester) async {
    when(() => clips.createClip(
          sourcePath: any(named: 'sourcePath'),
          originalPath: any(named: 'originalPath'),
          startSec: any(named: 'startSec'),
          endSec: any(named: 'endSec'),
          isTrimmed: any(named: 'isTrimmed'),
          importFormat: any(named: 'importFormat'),
        )).thenAnswer((_) async => throw Exception('disk full'));
    await pumpPage(tester, pick: 'a.ogg');

    await tester.tap(find.byType(EditorClipSaveButton));
    await tester.pump();

    expect(find.text(l10n.importEditorSaveError), findsOneWidget);
  });
}

class _FailingEncoder extends FakeClipEncoder {
  _FailingEncoder(this.error);

  final Object error;

  @override
  Future<void> convertFile({
    required String sourcePath,
    required String destPath,
  }) async =>
      throw error;
}
