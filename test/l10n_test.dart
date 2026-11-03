import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/l10n/l10n.dart';

void main() {
  final arbFiles = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList();
  Map<String, dynamic> read(File f) => jsonDecode(f.readAsStringSync());
  final template = read(File('lib/l10n/app_en.arb'));

  // gen-l10n quietly fills a missing message in from the template, so a
  // half-translated file would still build.
  final messages = template.keys.where((k) => !k.startsWith('@')).toSet();

  for (final file in arbFiles) {
    final arb = read(file);
    final name = file.uri.pathSegments.last;

    test('$name translates every message', () {
      expect(arb.keys.where((k) => !k.startsWith('@')).toSet(), messages);
    });

    test('$name keeps every placeholder', () {
      for (final key in messages) {
        final meta = template['@$key'] as Map<String, dynamic>?;
        final placeholders = meta?['placeholders'] as Map<String, dynamic>?;
        for (final placeholder in placeholders?.keys ?? const <String>[]) {
          expect(
            RegExp('\\{$placeholder[,}]').hasMatch(arb[key] as String),
            isTrue,
            reason: '$key lost {$placeholder}',
          );
        }
      }
    });
  }

  test('iOS declares every supported locale', () {
    // Nothing generates this list, and a language missing from it is not
    // offered on iOS at all.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final declared = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist)!.group(1)!;
    expect(
      RegExp(r'<string>(\w+)</string>')
          .allMatches(declared)
          .map((m) => m.group(1))
          .toSet(),
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
    );
  });

  test('English is the fallback for an untranslated device language', () {
    expect(AppLocalizations.supportedLocales.first, const Locale('en'));
  });

  test('each language picker entry is named in its own language', () {
    final names = {
      for (final locale in AppLocalizations.supportedLocales)
        locale.languageCode: lookupAppLocalizations(locale).languageName,
    };
    expect(names, {
      'en': 'English',
      'ko': '한국어',
      'ru': 'Русский',
      'uk': 'Українська',
    });
  });

  group('plurals', () {
    String done(String lang, int count) =>
        lookupAppLocalizations(Locale(lang))
            .audioSettingRecompressDone(count: count, saved: '1 MB');

    test('English', () {
      expect(done('en', 1), 'Recompressed 1 clip, freeing 1 MB');
      expect(done('en', 2), 'Recompressed 2 clips, freeing 1 MB');
      expect(done('en', 21), 'Recompressed 21 clips, freeing 1 MB');
    });

    // The cases that separate the East Slavic rules from English: 21 is "one",
    // 22 is "few", and the teens are all "many" despite ending in 1 to 4.
    test('Russian', () {
      expect(done('ru', 1), 'Пересжат 1 клип, освобождено 1 MB');
      expect(done('ru', 3), 'Пересжато 3 клипа, освобождено 1 MB');
      expect(done('ru', 5), 'Пересжато 5 клипов, освобождено 1 MB');
      expect(done('ru', 11), 'Пересжато 11 клипов, освобождено 1 MB');
      expect(done('ru', 21), 'Пересжат 21 клип, освобождено 1 MB');
      expect(done('ru', 22), 'Пересжато 22 клипа, освобождено 1 MB');
    });

    test('Ukrainian', () {
      expect(done('uk', 1), 'Перестиснуто 1 кліп, звільнено 1 MB');
      expect(done('uk', 3), 'Перестиснуто 3 кліпи, звільнено 1 MB');
      expect(done('uk', 5), 'Перестиснуто 5 кліпів, звільнено 1 MB');
      expect(done('uk', 12), 'Перестиснуто 12 кліпів, звільнено 1 MB');
      expect(done('uk', 21), 'Перестиснуто 21 кліп, звільнено 1 MB');
    });

    test('Korean has no plural forms and takes the count as is', () {
      expect(done('ko', 1), contains('1개'));
      expect(done('ko', 21), contains('21개'));
    });

    test('the converted and failed counts agree independently', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        en.audioSettingRecompressDoneWithErrors(count: 3, saved: '1 MB', failed: 1),
        'Recompressed 3 clips, freeing 1 MB. '
        '1 clip could not be converted and was left as it is.',
      );
      final ru = lookupAppLocalizations(const Locale('ru'));
      expect(
        ru.audioSettingRecompressDoneWithErrors(count: 1, saved: '1 MB', failed: 5),
        'Пересжат 1 клип, освобождено 1 MB. '
        '5 клипов не удалось конвертировать, они оставлены как есть.',
      );
    });

    test('the confirmation keeps its size placeholders apart', () {
      final message = lookupAppLocalizations(const Locale('en'))
          .audioSettingRecompressConfirm(count: 1, size: '2 MB', after: '1 MB');
      expect(message, startsWith('Recompress 1 WAV clip to FLAC?'));
      expect(message, contains('uses 2 MB and should end up near 1 MB'));
    });
  });
}
