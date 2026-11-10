import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/result/result_page.dart';
import 'package:eq_trainer/ui/result/widget/result_item_tile.dart';

void main() {
  group('resultBandRange', () {
    // The page has always shown these seven strings; they now come from the
    // bands' bounds, so they are pinned here character for character.
    test('writes all seven ranges as they have always been shown', () {
      expect([for (final band in ResultBand.values) resultBandRange(band)], [
        '20Hz ~ 80Hz',
        '80Hz ~ 200Hz',
        '200Hz ~ 800Hz',
        '800Hz ~ 1.5kHz',
        '1.5kHz ~ 5kHz',
        '5kHz ~ 10kHz',
        '10kHz ~ 20kHz',
      ]);
    });
  });

  group('ResultPage', () {
    Future<void> pump(WidgetTester tester, SessionResults results) {
      // Tall enough for all seven tiles, which the list builds lazily.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ResultPage(results: results),
      ));
    }

    testWidgets('shows a dash and N/A for a session with no rounds',
        (tester) async {
      await pump(tester, SessionResults.empty());

      expect(find.text('N/A'), findsOneWidget);
      // Every band is untouched, so every band shows a dash and 0 / 0.
      expect(find.text('-'), findsNWidgets(7));
      expect(find.text('0 / 0'), findsNWidgets(7));
    });

    testWidgets('shows each band\'s counts and both percentages to two places',
        (tester) async {
      final results = SessionResults.empty()
          .withRound(ResultBand.subBass, isCorrect: true)
          .withRound(ResultBand.subBass, isCorrect: true)
          .withRound(ResultBand.subBass, isCorrect: false)
          .withRound(ResultBand.midBass, isCorrect: false);
      await pump(tester, results);

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('66.67%'), findsOneWidget);
      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('0.00%'), findsOneWidget);
      expect(find.text('20Hz ~ 80Hz'), findsOneWidget);
      expect(find.text('-'), findsNWidgets(5));
      // 2 of 4 rounds overall.
      expect(find.text('50.00%'), findsOneWidget);
    });
  });
}
