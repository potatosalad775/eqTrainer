import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/domain/session/session_parameter.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/session/session_page.dart';

import '../../helpers/fake_encoder.dart';
import '../../helpers/fake_output_devices.dart';
import '../../helpers/mocks.dart';

void main() {
  // A device picked while a session runs has to reach the clip after it. The
  // engine cannot run here, so this pins the wiring that makes it so: the
  // session's player reads the app's one OutputSelection, not a copy taken
  // when the session started.
  testWidgets('the session holds the migration while it is up', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final library = MockClipLibrary();
    when(library.enabledClipPaths).thenAnswer((_) async => []);
    final migration = ClipFormatMigration(
      MockClipLibrary(),
      importFormat: 0,
      encoder: FakeClipEncoder(),
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: OutputSelection(
            prefs: await SharedPreferences.getInstance(),
            devices: FakeOutputDevices([]),
            watchesDevices: false,
          ),
        ),
        ChangeNotifierProvider.value(value: await MiscSettingsProvider.load()),
        ChangeNotifierProvider.value(value: migration),
        ChangeNotifierProvider(create: (_) => SessionParameter()),
        Provider<ClipLibrary>.value(value: library),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SessionPage(),
      ),
    ));
    await tester.pump();
    expect(migration.isPaused, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(migration.isPaused, isFalse);
  });

  testWidgets("the session's player reads the app's output selection",
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dac = playbackDevice(2, 'DAC');
    final output = OutputSelection(
      prefs: await SharedPreferences.getInstance(),
      devices: FakeOutputDevices([playbackDevice(1, 'Speakers', isDefault: true), dac]),
      watchesDevices: false,
    );
    final library = MockClipLibrary();
    when(library.enabledClipPaths).thenAnswer((_) async => []);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: output),
        ChangeNotifierProvider.value(value: await MiscSettingsProvider.load()),
        ChangeNotifierProvider.value(
          value: ClipFormatMigration(
            MockClipLibrary(),
            importFormat: 0,
            encoder: FakeClipEncoder(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => SessionParameter()),
        Provider<ClipLibrary>.value(value: library),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SessionPage(),
      ),
    ));
    await tester.pump();

    final player = Provider.of<PlayerService>(
      tester.element(find.byType(Scaffold).first),
      listen: false,
    );
    expect(identical(player.output, output), isTrue);

    output.selectDevice(dac);
    expect(player.output.device, dac);

    await tester.pumpWidget(const SizedBox());
  });
}
