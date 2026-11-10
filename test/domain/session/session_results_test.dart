import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/session_results.dart';

void main() {
  group('ResultBand', () {
    test('has the seven bands, lowest first, covering 20 Hz to 20 kHz', () {
      expect(ResultBand.values, [
        ResultBand.subBass,
        ResultBand.midBass,
        ResultBand.lowerMidrange,
        ResultBand.centreMidrange,
        ResultBand.upperMidrange,
        ResultBand.treble,
        ResultBand.upperTreble,
      ]);
      expect([for (final b in ResultBand.values) b.lowerHz],
          [20, 80, 200, 800, 1500, 5000, 10000]);
      expect([for (final b in ResultBand.values) b.upperHz],
          [80, 200, 800, 1500, 5000, 10000, 20000]);
    });

    test('each band starts where the one below ends', () {
      for (var i = 1; i < ResultBand.values.length; i++) {
        expect(ResultBand.values[i].lowerHz, ResultBand.values[i - 1].upperHz);
      }
    });

    group('of', () {
      for (final band in ResultBand.values) {
        test('${band.name} includes its lower bound and excludes its upper', () {
          expect(ResultBand.of(band.lowerHz.toDouble()), band);
          expect(ResultBand.of(band.lowerHz + 0.5), band);
          expect(ResultBand.of(band.upperHz - 0.5), band);
        });
      }

      test('the upper bound belongs to the band above', () {
        expect(ResultBand.of(80), ResultBand.midBass);
        expect(ResultBand.of(1500), ResultBand.upperMidrange);
        expect(ResultBand.of(10000), ResultBand.upperTreble);
      });

      test('anything outside every range falls in the top band', () {
        expect(ResultBand.of(19.9), ResultBand.upperTreble);
        expect(ResultBand.of(0), ResultBand.upperTreble);
        expect(ResultBand.of(20000), ResultBand.upperTreble);
        expect(ResultBand.of(48000), ResultBand.upperTreble);
      });
    });
  });

  group('SessionResults', () {
    test('a session with no rounds has zero counts and no percentages', () {
      final results = SessionResults.empty();
      expect(results.rounds, 0);
      expect(results.correct, 0);
      expect(results.incorrect, 0);
      expect(results.percentage, isNull);
      for (final band in ResultBand.values) {
        expect(results.roundsIn(band), 0);
        expect(results.correctIn(band), 0);
        expect(results.percentageIn(band), isNull);
      }
    });

    test('files a round under the band it was asked in', () {
      final results = SessionResults.empty()
          .withRound(ResultBand.lowerMidrange, isCorrect: true)
          .withRound(ResultBand.lowerMidrange, isCorrect: false)
          .withRound(ResultBand.treble, isCorrect: true);

      expect(results.roundsIn(ResultBand.lowerMidrange), 2);
      expect(results.correctIn(ResultBand.lowerMidrange), 1);
      expect(results.roundsIn(ResultBand.treble), 1);
      expect(results.correctIn(ResultBand.treble), 1);
      expect(results.roundsIn(ResultBand.subBass), 0);
    });

    test('adds up rounds, correct and incorrect across bands', () {
      final results = SessionResults.empty()
          .withRound(ResultBand.subBass, isCorrect: true)
          .withRound(ResultBand.treble, isCorrect: false)
          .withRound(ResultBand.treble, isCorrect: false);

      expect(results.rounds, 3);
      expect(results.correct, 1);
      expect(results.incorrect, 2);
    });

    test('percentages are exact for all, half and none correct', () {
      var results = SessionResults.empty();
      results = results.withRound(ResultBand.midBass, isCorrect: true);
      expect(results.percentage, 100.0);
      results = results.withRound(ResultBand.midBass, isCorrect: false);
      expect(results.percentage, 50.0);
      expect(results.percentageIn(ResultBand.midBass), 50.0);

      final none = SessionResults.empty()
          .withRound(ResultBand.midBass, isCorrect: false);
      expect(none.percentage, 0.0);
      expect(none.percentageIn(ResultBand.midBass), 0.0);
    });

    test('a band with no rounds has no percentage even when others do', () {
      final results =
          SessionResults.empty().withRound(ResultBand.midBass, isCorrect: true);
      expect(results.percentageIn(ResultBand.treble), isNull);
    });

    test('withRound leaves the results it was called on unchanged', () {
      final before = SessionResults.empty();
      before.withRound(ResultBand.subBass, isCorrect: true);
      expect(before.rounds, 0);
      expect(before, equals(SessionResults.empty()));
    });

    test('results with the same counts are equal', () {
      SessionResults make() =>
          SessionResults.empty().withRound(ResultBand.subBass, isCorrect: true);
      expect(make(), equals(make()));
      expect(make(), isNot(equals(SessionResults.empty())));
    });
  });
}
