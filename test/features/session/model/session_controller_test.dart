import 'package:flutter_soloud/flutter_soloud.dart' show AndroidAudioBackend;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/session_state.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';

import '../../../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AndroidAudioBackend.openSles);
  });

  group('SessionController', () {
    late MockPlayerService mockPlayer;
    late SessionStore sessionStore;
    late SessionParameter sessionParameter;
    late SessionController controller;

    setUp(() async {
      mockPlayer = MockPlayerService();
      sessionStore = SessionStore();
      sessionParameter = SessionParameter();
      controller = SessionController();

      // Stub all player calls used by initSession() and submitAnswer().
      // setEQParams is the only one that awaits — the rest are plain FFI
      // writes and return void, so they stub with thenReturn.
      when(() => mockPlayer.setEQParams(
            enableEQ: any(named: 'enableEQ'),
            frequency: any(named: 'frequency'),
            gainDb: any(named: 'gainDb'),
          )).thenAnswer((_) async {});
      when(() => mockPlayer.setEQ(any())).thenReturn(null);
      when(() => mockPlayer.setEQFreq(any())).thenReturn(null);
      when(() => mockPlayer.setEQGain(any())).thenReturn(null);
      when(() => mockPlayer.setEQQ(any())).thenReturn(null);

      // Populate frequency/graph data so initSession() has a valid list to pick from
      await sessionStore.initFrequency(sessionParameter: sessionParameter);

      // Run one initSession() so _answerGraphIndex is seeded
      await controller.initSession(
        mockPlayer,
        sessionStore: sessionStore,
        sessionParameter: sessionParameter,
      );

      // submitAnswer only proceeds from a ready session (re-entrancy guard),
      // which launchSession sets in production. Establish that precondition.
      sessionStore.setSessionState(SessionState.ready);
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

        expect(result!.isCorrect, isTrue);
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

        expect(result!.isCorrect, isFalse);
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

    // -------------------------------------------------------------------------
    // launchSession — the one path that touches every collaborator
    // -------------------------------------------------------------------------
    group('launchSession', () {
      late MockPlaylistService playlist;
      late AudioState audioState;

      // A fresh store: the outer setUp has already run one round on the
      // shared one, and launch has to be shown resetting that.
      late SessionStore store;

      setUp(() {
        playlist = MockPlaylistService();
        audioState = AudioState(
          androidBackend: AndroidAudioBackend.openSles,
          outputDevice: null,
        );
        store = SessionStore();
        when(() => mockPlayer.launch(
              androidBackend: any(named: 'androidBackend'),
              outputDevice: null,
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            )).thenAnswer((_) async {});
      });

      tearDown(() {
        store.dispose();
        audioState.dispose();
      });

      Future<void> launch({bool Function()? shouldContinue}) =>
          controller.launchSession(
            mockPlayer,
            audioState: audioState,
            sessionStore: store,
            sessionParameter: sessionParameter,
            playlistService: playlist,
            volumeCompensation: true,
            shouldContinue: shouldContinue,
          );

      test('opens the first enabled clip and reports ready', () async {
        when(playlist.listEnabledClipPaths)
            .thenAnswer((_) async => ['/a.flac', '/b.flac']);

        await launch();

        expect(store.sessionState, equals(SessionState.ready));
        expect(store.playlistPaths, equals(['/a.flac', '/b.flac']));
        expect(store.currentClipPath, equals('/a.flac'));
        verify(() => mockPlayer.launch(
              androidBackend: AndroidAudioBackend.openSles,
              outputDevice: null,
              path: '/a.flac',
              volumeCompensation: true,
            )).called(1);
        // The graph is populated and a first answer picked.
        expect(store.graphBarDataList, isNotEmpty);
        expect(controller.answerGraphIndex,
            inInclusiveRange(0, store.graphBarDataList.length - 1));
      });

      test('applies the session Q to the fresh player once', () async {
        when(playlist.listEnabledClipPaths).thenAnswer((_) async => ['/a.flac']);
        sessionParameter.qFactor = 2.5;

        await launch();

        verify(() => mockPlayer.setEQQ(2.5)).called(1);
      });

      test('reports playlistEmpty and never touches the player when nothing '
          'is enabled', () async {
        when(playlist.listEnabledClipPaths).thenAnswer((_) async => []);

        await launch();

        expect(store.sessionState, equals(SessionState.playlistEmpty));
        verifyNever(() => mockPlayer.launch(
              androidBackend: any(named: 'androidBackend'),
              outputDevice: any(named: 'outputDevice'),
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            ));
      });

      test('resets the previous session\'s score and picker', () async {
        when(playlist.listEnabledClipPaths).thenAnswer((_) async => ['/a.flac']);
        // Leave a finished session behind in the store.
        await store.initFrequency(sessionParameter: sessionParameter);
        store.applySubmission(centerFreq: 440, isCorrect: true);
        store.applySubmission(centerFreq: 440, isCorrect: false);
        store.setPickerValue(3);

        await launch();

        expect(store.elapsedSession, isZero);
        expect(store.resultCorrect, isZero);
        expect(store.resultIncorrect, isZero);
        expect(store.currentPickerValue, equals(1));
      });

      test('goes to init synchronously, before the first await', () {
        when(playlist.listEnabledClipPaths).thenAnswer((_) async => ['/a.flac']);
        store.setSessionState(SessionState.ready);

        // Not awaited on purpose: the state must already have moved so a
        // relaunch never renders the previous session's ready UI.
        final pending = launch();
        expect(store.sessionState, equals(SessionState.init));
        return pending;
      });

      test('stops writing to the store once shouldContinue turns false',
          () async {
        var stillOnPage = true;
        when(playlist.listEnabledClipPaths).thenAnswer((_) async {
          // The user leaves the page while the playlist is being read.
          stillOnPage = false;
          return ['/a.flac'];
        });

        await launch(shouldContinue: () => stillOnPage);

        // Nothing after the abandoned await may land in the app-scoped store.
        expect(store.sessionState, equals(SessionState.init));
        expect(store.playlistPaths, isEmpty);
        verifyNever(() => mockPlayer.launch(
              androidBackend: any(named: 'androidBackend'),
              outputDevice: any(named: 'outputDevice'),
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            ));
      });

      test('a player that fails to open reports error and rethrows', () async {
        when(playlist.listEnabledClipPaths).thenAnswer((_) async => ['/a.flac']);
        when(() => mockPlayer.launch(
              androidBackend: any(named: 'androidBackend'),
              outputDevice: null,
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            )).thenThrow(StateError('no device'));

        await expectLater(launch(), throwsException);
        expect(store.sessionState, equals(SessionState.error));
      });

      test('a failure after leaving the page does not write error either',
          () async {
        var stillOnPage = true;
        when(playlist.listEnabledClipPaths).thenAnswer((_) async {
          stillOnPage = false;
          throw StateError('box closed');
        });

        await expectLater(
          launch(shouldContinue: () => stillOnPage),
          throwsException,
        );
        expect(store.sessionState, equals(SessionState.init));
      });
    });
  });
}
