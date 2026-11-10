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
import 'package:eq_trainer/data/clips/import_workflow_service.dart';

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

class _FakeWorkflow implements ImportWorkflowService {
  _FakeWorkflow({this.convert, this.loadError});

  final Future<String> Function()? convert;
  final Object? loadError;

  @override
  Future<String> convertTo({
    required String fileNameWithoutExt,
    required String sourcePath,
    required String targetExt,
  }) =>
      convert!();

  @override
  Future<Duration> loadAudioFile({
    required ImportPlayer importPlayer,
    required String filePath,
    String? originalPath,
  }) async {
    throw loadError ?? StateError('not expected to load');
  }
}

/// The page against a fake picker and workflow, so no engine is involved.
void main() {
  late ClipFormatMigration migration;
  late MiscSettingsProvider settings;
  late OutputSelection output;
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
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required String pick,
    required ImportWorkflowService workflow,
  }) async {
    FilePickerPlatform.instance = _FakePicker(pick);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: migration),
        ChangeNotifierProvider.value(value: output),
        Provider<ImportWorkflowService>.value(value: workflow),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: ImportPage(),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  String unsupportedText() => Platform.isLinux
      ? l10n.importAlertUnsupportedContentLinux
      : l10n.importAlertUnsupportedContent;

  testWidgets('holds the library migration while open', (tester) async {
    await pumpPage(
      tester,
      pick: 'a.ogg',
      workflow: _FakeWorkflow(),
    );
    expect(migration.isPaused, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(migration.isPaused, isFalse);
  });

  testWidgets('a file that skips conversion and cannot load gets its own dialog',
      (tester) async {
    await pumpPage(
      tester,
      pick: 'corrupt.ogg',
      workflow: _FakeWorkflow(loadError: const SoLoudFileLoadFailedException()),
    );
    expect(find.text(unsupportedText()), findsOneWidget);
  });

  testWidgets('a load failure unrelated to the file stays a generic error',
      (tester) async {
    await pumpPage(
      tester,
      pick: 'a.ogg',
      workflow: _FakeWorkflow(loadError: const SoLoudFileNotFoundException()),
    );
    expect(find.text(l10n.importAlertErrorContent), findsOneWidget);
  });

  testWidgets('too many channels says so', (tester) async {
    await pumpPage(
      tester,
      pick: 'surround.m4a',
      workflow: _FakeWorkflow(
        convert: () async => throw const UnsupportedChannelCountException(6),
      ),
    );
    expect(find.text(l10n.importAlertTooManyChannelsContent), findsOneWidget);
  });

  testWidgets('leaving during a conversion deletes the file it finishes with',
      (tester) async {
    final conversion = Completer<String>();
    await pumpPage(
      tester,
      pick: 'long.m4a',
      workflow: _FakeWorkflow(convert: () => conversion.future),
    );
    expect(find.text(l10n.importConverting1), findsOneWidget);

    await tester.pumpWidget(const SizedBox());

    final dir = Directory.systemTemp.createTempSync('import_page_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final converted = File(p.join(dir.path, 'long.opus'))
      ..writeAsBytesSync([1, 2, 3]);

    conversion.complete(converted.path);
    await tester.pump();

    await tester.runAsync(() async {
      for (var i = 0; i < 100 && converted.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(converted.existsSync(), isFalse);
    });
  });
}
