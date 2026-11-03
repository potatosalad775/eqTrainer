import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/features/settings/settings_page.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/shared/model/locale_provider.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';

void main() {
  late Directory dir;
  late LocaleProvider localeProvider;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('eqt_settings_');
    Hive.init(dir.path);
    Hive.registerAdapter(MiscSettingsAdapter());
    await Hive.openBox<MiscSettings>(miscSettingsBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localeProvider = await LocaleProvider.load();
  });

  Future<void> pumpSettings(WidgetTester tester, {required Locale device}) async {
    tester.platformDispatcher.localesTestValue = [device];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider(create: (_) => MiscSettingsProvider()),
      ],
      builder: (context, _) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: context.watch<LocaleProvider>().locale,
        home: const Scaffold(body: SettingsPage()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  String langTitle(String code) =>
      lookupAppLocalizations(Locale(code)).settingCardLangTitle;

  // A dropdown asserts when its value is not among its items, which is what a
  // hand-kept language list did the moment a translation was added without it.
  testWidgets('a device in a translated language gets that language',
      (tester) async {
    await pumpSettings(tester, device: const Locale('ru', 'RU'));
    expect(tester.takeException(), isNull);
    expect(find.text(langTitle('ru')), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
  });

  testWidgets('a device in an untranslated language falls back to English',
      (tester) async {
    await pumpSettings(tester, device: const Locale('fr', 'FR'));
    expect(tester.takeException(), isNull);
    expect(find.text(langTitle('en')), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('every language can be picked, and picking one applies it',
      (tester) async {
    await pumpSettings(tester, device: const Locale('en'));

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    for (final name in ['한국어', 'Русский', 'Українська']) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.tap(find.text('Українська'));
    await tester.pumpAndSettle();

    expect(localeProvider.locale, const Locale('uk'));
    expect(find.text(langTitle('uk')), findsOneWidget);
  });
}
