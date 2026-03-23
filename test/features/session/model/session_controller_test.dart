import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';

class MockPlayerIsolate extends Mock implements PlayerIsolate {}

void main() {
  group('SessionController', () {
    late MockPlayerIsolate mockPlayer;
    late SessionStore sessionStore;
    late SessionParameter sessionParameter;
    late SessionController controller;

    setUp(() async {
      mockPlayer = MockPlayerIsolate();
      sessionStore = SessionStore();
      sessionParameter = SessionParameter();
      controller = SessionController();

      // Stub all player calls used by initSession() and submitAnswer()
      when(() => mockPlayer.setEQParams(
            enableEQ: any(named: 'enableEQ'),
            frequency: any(named: 'frequency'),
            gainDb: any(named: 'gainDb'),
          )).thenAnswer((_) async {});
      when(() => mockPlayer.setEQ(any())).thenAnswer((_) async {});
      when(() => mockPlayer.setEQFreq(any())).thenAnswer((_) async {});
      when(() => mockPlayer.setEQGain(any())).thenAnswer((_) async {});

      // Populate frequency/graph data so initSession() has a valid list to pick from
      await sessionStore.initFrequency(sessionParameter: sessionParameter);

      // Run one initSession() so _answerGraphIndex is seeded
      await controller.initSession(
        mockPlayer,
        sessionStore: sessionStore,
        sessionParameter: sessionParameter,
      );
    });

    tearDown(() {
      sessionStore.dispose();
    });

    // -------------------------------------------------------------------------
    // submitAnswer — correctness detection
    // -------------------------------------------------------------------------
    group('submitAnswer — result detection', () {
      test('returns isCorrect=true when pickerValue matches answer', () async {
        // Capture before submitAnswer() — it calls initSession() internally which changes the index
        final expectedIndex = controller.answerGraphIndex + 1;
        sessionStore.setPickerValue(expectedIndex);

        final result = await controller.submitAnswer(
          player: mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );

        expect(result.isCorrect, isTrue);
        expect(result.correctIndex, equals(expectedIndex));
      });

      test('returns isCorrect=false when pickerValue does not match answer', () async {
        final answerIndex = controller.answerGraphIndex;
        final wrongValue = answerIndex == 0 ? 2 : 1;
        sessionStore.setPickerValue(wrongValue);

        final result = await controller.submitAnswer(
          player: mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );

        expect(result.isCorrect, isFalse);
        expect(result.correctIndex, equals(answerIndex + 1));
      });

      test('onResult callback receives correct values', () async {
        final expectedIndex = controller.answerGraphIndex + 1;
        sessionStore.setPickerValue(expectedIndex);

        bool? cbCorrect;
        int? cbIndex;

        await controller.submitAnswer(
          player: mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
          onResult: (isCorrect, correctIndex) {
            cbCorrect = isCorrect;
            cbIndex = correctIndex;
          },
        );

        expect(cbCorrect, isTrue);
        expect(cbIndex, equals(expectedIndex));
      });

      test('onResult is optional — submitAnswer succeeds without it', () async {
        await expectLater(
          controller.submitAnswer(
            player: mockPlayer,
            sessionStore: sessionStore,
            sessionParameter: sessionParameter,
          ),
          completes,
        );
      });
    });

    // -------------------------------------------------------------------------
    // submitAnswer — score tracking
    // -------------------------------------------------------------------------
    group('submitAnswer — score tracking', () {
      test('correct answer increments resultCorrect', () async {
        sessionStore.setPickerValue(controller.answerGraphIndex + 1);

        await controller.submitAnswer(
          player: mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );

        expect(sessionStore.resultCorrect, equals(1));
        expect(sessionStore.resultIncorrect, equals(0));
      });

      test('incorrect answer increments resultIncorrect', () async {
        final wrongValue = controller.answerGraphIndex == 0 ? 2 : 1;
        sessionStore.setPickerValue(wrongValue);

        await controller.submitAnswer(
          player: mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );

        expect(sessionStore.resultIncorrect, equals(1));
        expect(sessionStore.resultCorrect, equals(0));
      });
    });

    // -------------------------------------------------------------------------
    // submitAnswer — band threshold adjustments
    // -------------------------------------------------------------------------
    group('submitAnswer — threshold logic', () {
      test('startingBand increments when score reaches +threshold', () async {
        final threshold = sessionParameter.threshold;
        final initialBand = sessionParameter.startingBand;

        for (var i = 0; i < threshold; i++) {
          sessionStore.setPickerValue(controller.answerGraphIndex + 1);
          await controller.submitAnswer(
            player: mockPlayer,
            sessionStore: sessionStore,
            sessionParameter: sessionParameter,
          );
        }

        expect(sessionParameter.startingBand, equals(initialBand + 1));
      });

      test('startingBand decrements when score reaches -threshold', () async {
        final threshold = sessionParameter.threshold;
        sessionParameter.startingBand = 10;
        final initialBand = sessionParameter.startingBand;

        // Re-seed initSession after changing startingBand (graph count changes)
        await sessionStore.initFrequency(sessionParameter: sessionParameter);
        await controller.initSession(
          mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );

        for (var i = 0; i < threshold; i++) {
          final wrongValue = controller.answerGraphIndex == 0 ? 2 : 1;
          sessionStore.setPickerValue(wrongValue);
          await controller.submitAnswer(
            player: mockPlayer,
            sessionStore: sessionStore,
            sessionParameter: sessionParameter,
          );
        }

        expect(sessionParameter.startingBand, equals(initialBand - 1));
      });

      test('startingBand does not exceed 25', () async {
        sessionParameter.startingBand = 25;
        final threshold = sessionParameter.threshold;

        await sessionStore.initFrequency(sessionParameter: sessionParameter);
        await controller.initSession(
          mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );

        for (var i = 0; i < threshold; i++) {
          sessionStore.setPickerValue(controller.answerGraphIndex + 1);
          await controller.submitAnswer(
            player: mockPlayer,
            sessionStore: sessionStore,
            sessionParameter: sessionParameter,
          );
        }

        expect(sessionParameter.startingBand, equals(25));
      });

      test('startingBand does not go below 2', () async {
        sessionParameter.startingBand = 2;
        final threshold = sessionParameter.threshold;

        await sessionStore.initFrequency(sessionParameter: sessionParameter);
        await controller.initSession(
          mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );

        for (var i = 0; i < threshold; i++) {
          final wrongValue = controller.answerGraphIndex == 0 ? 2 : 1;
          sessionStore.setPickerValue(wrongValue);
          await controller.submitAnswer(
            player: mockPlayer,
            sessionStore: sessionStore,
            sessionParameter: sessionParameter,
          );
        }

        expect(sessionParameter.startingBand, equals(2));
      });
    });

    // -------------------------------------------------------------------------
    // initSession — randomness invariant
    // -------------------------------------------------------------------------
    group('initSession', () {
      test('never picks the same answerGraphIndex twice in a row', () async {
        for (var i = 0; i < 50; i++) {
          final before = controller.answerGraphIndex;
          await controller.initSession(
            mockPlayer,
            sessionStore: sessionStore,
            sessionParameter: sessionParameter,
          );
          expect(controller.answerGraphIndex, isNot(equals(before)),
              reason: 'Same index picked twice in a row at iteration $i');
        }
      });

      test('answerCenterFreq maps correctly for FilterType.peak', () async {
        sessionParameter.filterType = FilterType.peak;
        await sessionStore.initFrequency(sessionParameter: sessionParameter);
        await controller.initSession(
          mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );
        // For peak/dip: freqIndex == graphIndex
        final expectedFreq = sessionStore.centerFreqLogList[controller.answerGraphIndex];
        expect(controller.answerCenterFreq, equals(expectedFreq));
      });

      test('answerCenterFreq maps correctly for FilterType.peakDip', () async {
        sessionParameter.filterType = FilterType.peakDip;
        await sessionStore.initFrequency(sessionParameter: sessionParameter);
        await controller.initSession(
          mockPlayer,
          sessionStore: sessionStore,
          sessionParameter: sessionParameter,
        );
        // For peakDip: freqIndex = floor(graphIndex / 2)
        final expectedFreqIndex = (controller.answerGraphIndex / 2).floor();
        final expectedFreq = sessionStore.centerFreqLogList[expectedFreqIndex];
        expect(controller.answerCenterFreq, equals(expectedFreq));
      });
    });
  });
}
