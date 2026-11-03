import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/shared/model/locale_provider.dart';

void main() {
  test('follows the device until the user picks a language', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await LocaleProvider.load();
    expect(provider.locale, isNull);
  });

  test("restores the choice easy_localization saved", () async {
    SharedPreferences.setMockInitialValues({'locale': 'ko'});
    final provider = await LocaleProvider.load();
    expect(provider.locale, const Locale('ko'));
  });

  test('drops the region from an older saved locale', () async {
    SharedPreferences.setMockInitialValues({'locale': 'ko_KR'});
    final provider = await LocaleProvider.load();
    expect(provider.locale, const Locale('ko'));
  });

  test('a new choice notifies and survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await LocaleProvider.load();
    var notified = 0;
    provider.addListener(() => notified++);

    provider.setLocale(const Locale('uk'));

    expect(provider.locale, const Locale('uk'));
    expect(notified, 1);
    expect((await LocaleProvider.load()).locale, const Locale('uk'));
  });
}
