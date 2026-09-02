import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // easy_localization persists the chosen locale through shared_preferences.
    // Stub the channel rather than depending on the package, as elsewhere in
    // this suite (see import_workflow_service_test.dart).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : null,
    );
    await EasyLocalization.ensureInitialized();
  });

  for (final (locale, key, expected) in [
    (const Locale('en'), 'MAIN_NAVBAR_PLAYLIST', 'Playlist'),
    (const Locale('ko'), 'MAIN_NAVBAR_PLAYLIST', '플레이리스트'),
  ]) {
    testWidgets('${locale.languageCode}.json loads through the default loader',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ko')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          useOnlyLangCode: true,
          startLocale: locale,
          child: Builder(builder: (c) {
            ctx = c;
            return MaterialApp(
              localizationsDelegates: c.localizationDelegates,
              supportedLocales: c.supportedLocales,
              locale: c.locale,
              home: const SizedBox(),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(ctx.locale, locale);
      expect(key.tr(), expected, reason: 'key did not resolve — asset missing?');
    });
  }
}
