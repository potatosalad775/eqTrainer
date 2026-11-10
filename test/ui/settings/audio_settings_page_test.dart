import 'package:eq_trainer/data/clips/clip_recompress_service.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/settings/audio_settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRecompress extends Mock implements ClipRecompressService {}

void main() {
  late MiscSettingsProvider settings;
  late _MockRecompress recompress;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await MiscSettingsProvider.load();
    recompress = _MockRecompress();
    when(() => recompress.estimate()).thenAnswer(
      (_) async => const RecompressEstimate(clipCount: 0, totalBytes: 0),
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider<ClipRecompressService>.value(value: recompress),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: AudioSettingsPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // The backend card is scrolled out of the ListView's cache on a short test
  // surface, so make the surface tall.
  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the backend card is shown on Android', (tester) async {
    await tall(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pumpPage(tester);
    expect(find.text(l10n.audioSettingCardBackendTitle), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the backend card is absent elsewhere', (tester) async {
    await tall(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await pumpPage(tester);
    expect(find.text(l10n.audioSettingCardBackendTitle), findsNothing);
    expect(find.text(l10n.audioSettingCardVolumeCompDesc), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
