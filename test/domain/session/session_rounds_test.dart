import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/domain/session/session_rounds.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';

import '../../helpers/scripted_random.dart';

SessionSettings settings({
  int startingBand = 3,
  int gain = 6,
  FilterType filterType = FilterType.peak,
  int threshold = 3,
}) =>
    SessionSettings(
      startingBand: startingBand,
      gain: gain,
      qFactor: 1.0,
      filterType: filterType,
      threshold: threshold,
    );

RoundOutcome answerRight(SessionRounds rounds) =>
    rounds.submit(rounds.current.answerGraphIndex);

RoundOutcome answerWrong(SessionRounds rounds) =>
    rounds.submit((rounds.current.answerGraphIndex + 1) % rounds.layout.graphCount);

void main() {
  group('the first round', () {
    test('is picked on construction, inside the layout', () {
      final rounds = SessionRounds(settings(), random: Random(1));
      expect(rounds.current.answerGraphIndex, inInclusiveRange(0, 2));
      expect(rounds.points, 0);
      expect(rounds.results.rounds, 0);
    });

    test('carries the answer band\'s frequency and the configured gain', () {
      final rounds = SessionRounds(
        settings(gain: 8),
        random: ScriptedRandom([1]),
      );
      expect(rounds.current.answerGraphIndex, 1);
      expect(rounds.current.frequency, rounds.layout.centerFrequencies[1]);
      expect(rounds.current.gainDb, 8.0);
    });

    test('has a negative gain when the answer is a dip', () {
      final dips = SessionRounds(
        settings(filterType: FilterType.dip),
        random: ScriptedRandom([0]),
      );
      expect(dips.current.gainDb, -6.0);

      final peakDip = SessionRounds(
        settings(filterType: FilterType.peakDip),
        random: ScriptedRandom([3]),
      );
      expect(peakDip.current.answerGraphIndex, 3);
      expect(peakDip.current.frequency, peakDip.layout.centerFrequencies[1]);
      expect(peakDip.current.gainDb, -6.0);
    });

    test('starts at the settings\' band count', () {
      final rounds = SessionRounds(settings(startingBand: 7), random: Random(1));
      expect(rounds.bandCount, 7);
      expect(rounds.layout.bandCount, 7);
    });
  });

  group('submit', () {
    test('reports whether the pick was right and what the answer was', () {
      final rounds = SessionRounds(settings(), random: ScriptedRandom([2, 0, 1]));

      final right = rounds.submit(2);
      expect(right.isCorrect, isTrue);
      expect(right.correctGraphIndex, 2);

      final wrong = rounds.submit(2);
      expect(wrong.isCorrect, isFalse);
      expect(wrong.correctGraphIndex, 0);
    });

    test('next is the round that is now current', () {
      final rounds = SessionRounds(settings(), random: ScriptedRandom([2, 0]));
      final outcome = rounds.submit(2);
      expect(outcome.next.answerGraphIndex, 0);
      expect(identical(outcome.next, rounds.current), isTrue);
    });

    test('a correct answer is one point, a wrong one is minus one', () {
      final rounds = SessionRounds(settings(threshold: 10), random: Random(2));
      answerRight(rounds);
      expect(rounds.points, 1);
      answerWrong(rounds);
      answerWrong(rounds);
      expect(rounds.points, -1);
    });

    test('files each round under the band of the frequency it asked about', () {
      // Three peak bands sit at about 63 Hz, 632 Hz and 6.3 kHz.
      final rounds = SessionRounds(
        settings(threshold: 10),
        random: ScriptedRandom([0, 1, 2, 1]),
      );
      rounds.submit(0); // sub-bass, right
      rounds.submit(0); // lower midrange, wrong
      rounds.submit(2); // treble, right
      final results = rounds.results;

      expect(results.rounds, 3);
      expect(results.correct, 2);
      expect(results.incorrect, 1);
      expect(results.roundsIn(ResultBand.subBass), 1);
      expect(results.correctIn(ResultBand.subBass), 1);
      expect(results.roundsIn(ResultBand.lowerMidrange), 1);
      expect(results.correctIn(ResultBand.lowerMidrange), 0);
      expect(results.roundsIn(ResultBand.treble), 1);
      expect(results.percentage, closeTo(200 / 3, 1e-9));
    });

    test('a peak and a dip of the same band are filed together', () {
      final rounds = SessionRounds(
        settings(filterType: FilterType.peakDip, threshold: 10),
        random: ScriptedRandom([2, 3, 0]),
      );
      rounds.submit(2);
      rounds.submit(3);
      expect(rounds.results.roundsIn(ResultBand.lowerMidrange), 2);
    });
  });

  group('the band ladder', () {
    test('goes up one band and resets the points at the threshold', () {
      final rounds = SessionRounds(settings(), random: Random(3));

      expect(answerRight(rounds).bandCountChanged, isFalse);
      expect(answerRight(rounds).bandCountChanged, isFalse);
      expect(rounds.bandCount, 3);
      expect(rounds.points, 2);

      final outcome = answerRight(rounds);
      expect(outcome.bandCountChanged, isTrue);
      expect(rounds.bandCount, 4);
      expect(rounds.points, 0);
      expect(rounds.layout.graphCount, 4);
    });

    test('goes down one band and resets the points at minus the threshold', () {
      final rounds = SessionRounds(settings(startingBand: 10), random: Random(3));

      answerWrong(rounds);
      answerWrong(rounds);
      expect(rounds.bandCount, 10);
      expect(rounds.points, -2);

      final outcome = answerWrong(rounds);
      expect(outcome.bandCountChanged, isTrue);
      expect(rounds.bandCount, 9);
      expect(rounds.points, 0);
    });

    test('a threshold of 1 moves on every answer', () {
      final rounds = SessionRounds(
        settings(startingBand: 5, threshold: 1),
        random: Random(3),
      );
      answerRight(rounds);
      expect(rounds.bandCount, 6);
      answerWrong(rounds);
      expect(rounds.bandCount, 5);
    });

    test('the next round belongs to the new layout', () {
      final rounds = SessionRounds(
        settings(startingBand: 2, threshold: 1, filterType: FilterType.peakDip),
        random: Random(4),
      );
      for (var i = 0; i < 20; i++) {
        final before = rounds.layout.graphCount;
        final outcome = answerRight(rounds);
        expect(outcome.bandCountChanged, isTrue);
        expect(rounds.layout.graphCount, before + 2);
        expect(outcome.next.answerGraphIndex, lessThan(rounds.layout.graphCount));
      }
    });

    test('stops at 25 bands and clamps the points to the threshold', () {
      final rounds = SessionRounds(settings(startingBand: 25), random: Random(5));

      for (var i = 0; i < 10; i++) {
        final outcome = answerRight(rounds);
        expect(outcome.bandCountChanged, isFalse);
        expect(rounds.bandCount, 25);
        expect(rounds.points, lessThanOrEqualTo(3));
      }
      expect(rounds.points, 3);
    });

    // Without the clamp, ten right answers would leave 10 points and it would
    // take thirteen wrong ones to get down to minus 3.
    test('after an overshoot at 25 a band is lost after threshold * 2 wrong', () {
      final rounds = SessionRounds(settings(startingBand: 25), random: Random(5));
      for (var i = 0; i < 10; i++) {
        answerRight(rounds);
      }

      for (var i = 0; i < 5; i++) {
        expect(answerWrong(rounds).bandCountChanged, isFalse);
      }
      expect(rounds.bandCount, 25);
      expect(answerWrong(rounds).bandCountChanged, isTrue);
      expect(rounds.bandCount, 24);
    });

    test('stops at 2 bands and clamps the points to minus the threshold', () {
      final rounds = SessionRounds(settings(startingBand: 2), random: Random(5));

      for (var i = 0; i < 10; i++) {
        final outcome = answerWrong(rounds);
        expect(outcome.bandCountChanged, isFalse);
        expect(rounds.bandCount, 2);
      }
      expect(rounds.points, -3);
    });

    test('after an overshoot at 2 a band is gained after threshold * 2 right', () {
      final rounds = SessionRounds(settings(startingBand: 2), random: Random(5));
      for (var i = 0; i < 10; i++) {
        answerWrong(rounds);
      }

      for (var i = 0; i < 5; i++) {
        expect(answerRight(rounds).bandCountChanged, isFalse);
      }
      expect(rounds.bandCount, 2);
      expect(answerRight(rounds).bandCountChanged, isTrue);
      expect(rounds.bandCount, 3);
    });

    test('never writes the band count back to the settings', () {
      final original = settings();
      final rounds = SessionRounds(original, random: Random(6));
      for (var i = 0; i < 9; i++) {
        answerRight(rounds);
      }

      expect(rounds.bandCount, 6);
      expect(rounds.settings, same(original));
      expect(original.startingBand, 3);
      expect(SessionRounds(original, random: Random(6)).bandCount, 3);
    });
  });

  group('picking', () {
    test('is never the same graph twice in a row with more than 2 graphs', () {
      for (final type in FilterType.values) {
        // Alternate right and wrong so the band count stays where it is.
        final rounds = SessionRounds(
          settings(startingBand: 3, threshold: 10, filterType: type),
          random: Random(7),
        );
        var previous = rounds.current.answerGraphIndex;
        for (var i = 0; i < 300; i++) {
          if (i.isEven) {
            answerRight(rounds);
          } else {
            answerWrong(rounds);
          }
          expect(rounds.current.answerGraphIndex, isNot(previous),
              reason: '$type repeated at round $i');
          previous = rounds.current.answerGraphIndex;
        }
      }
    });

    test('a repeated draw is thrown back while there is a real choice', () {
      final rounds = SessionRounds(
        settings(threshold: 10),
        random: ScriptedRandom([1, 1, 1, 2]),
      );
      expect(rounds.current.answerGraphIndex, 1);
      rounds.submit(1);
      expect(rounds.current.answerGraphIndex, 2);
    });

    test('with exactly 2 graphs the same graph may come up again', () {
      final rounds = SessionRounds(
        settings(startingBand: 2, threshold: 10),
        random: ScriptedRandom([1, 1, 0, 0]),
      );
      expect(rounds.current.answerGraphIndex, 1);
      rounds.submit(1);
      expect(rounds.current.answerGraphIndex, 1);
      rounds.submit(1);
      expect(rounds.current.answerGraphIndex, 0);
      rounds.submit(0);
      expect(rounds.current.answerGraphIndex, 0);
    });

    test('a band count change forgets the previous pick', () {
      // Graph 2 is drawn, answered, and the ladder moves to 4 bands. Drawing
      // 2 again is fine in the new layout; had the old pick been kept, it
      // would be thrown back and the script would run out.
      final rounds = SessionRounds(
        settings(threshold: 1),
        random: ScriptedRandom([2, 2]),
      );
      final outcome = rounds.submit(2);
      expect(outcome.bandCountChanged, isTrue);
      expect(outcome.next.answerGraphIndex, 2);
    });

    test('draws uniformly: every graph comes up', () {
      final rounds = SessionRounds(
        settings(startingBand: 4, threshold: 10, filterType: FilterType.peakDip),
        random: Random(8),
      );
      final seen = <int>{rounds.current.answerGraphIndex};
      for (var i = 0; i < 200; i++) {
        if (i.isEven) {
          answerRight(rounds);
        } else {
          answerWrong(rounds);
        }
        seen.add(rounds.current.answerGraphIndex);
      }
      expect(seen, {for (var i = 0; i < 8; i++) i});
    });
  });
}
