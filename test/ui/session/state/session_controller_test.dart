import 'dart:async';
import 'dart:io';

import 'package:flutter_soloud/flutter_soloud.dart' show AndroidAudioBackend;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/data/audio_state.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:eq_trainer/domain/session/session_parameter.dart';
import 'package:eq_trainer/domain/session/session_rounds.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';
import 'package:eq_trainer/ui/session/state/session_controller.dart';
import 'package:eq_trainer/ui/session/state/session_state.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/scripted_random.dart';

// The rules of a session (which graph is the answer, the score, the band
// ladder) are tested against SessionRounds without a player. These tests are
// about what the controller does with them: what reaches the player, what
// reaches the store, and in what order.
void main() {
  setUpAll(() {
    registerFallbackValue(AndroidAudioBackend.openSles);
  });

  group('SessionController', () {
    late MockPlayerService player;
    late MockClipLibrary library;
    late AudioState audioState;
    late SessionStore store;
    late SessionParameter parameter;

    // Peak mode with the default 3 bands keeps the picker easy to read: graph
    // i is picker value i + 1, and every graph has its own frequency.
    final peak3 = BandLayout(3, FilterType.peak);

    setUp(() {
      player = MockPlayerService();
      library = MockClipLibrary();
      audioState = AudioState(
        androidBackend: AndroidAudioBackend.openSles,
        outputDevice: null,
      );
      store = SessionStore();
      parameter = SessionParameter()..filterType = FilterType.peak;

      // setEQParams is the only call that awaits; the rest are plain FFI
      // writes and return void.
      when(() => player.setEQParams(
            enableEQ: any(named: 'enableEQ'),
            frequency: any(named: 'frequency'),
            gainDb: any(named: 'gainDb'),
          )).thenAnswer((_) async {});
      when(() => player.setEQ(any())).thenReturn(null);
      when(() => player.setEQFreq(any())).thenReturn(null);
      when(() => player.setEQGain(any())).thenReturn(null);
      when(() => player.setEQQ(any())).thenReturn(null);
      when(() => player.launch(
            androidBackend: any(named: 'androidBackend'),
            outputDevice: null,
            path: any(named: 'path'),
            volumeCompensation: any(named: 'volumeCompensation'),
          )).thenAnswer((_) async {});
      when(library.enabledClipPaths).thenAnswer((_) async => ['/a.flac']);
    });

    tearDown(() {
      store.dispose();
      audioState.dispose();
    });

    /// A controller whose rounds come up in [script]: first the launch's
    /// round, then one per submit. It is made from [parameter] as it is now,
    /// the way the session page snapshots it when a session starts.
    SessionController controllerFor(
      List<int> script, {
      SessionStore? sessionStore,
      ClipLibrary? clipLibrary,
    }) =>
        SessionController(
          player: player,
          sessionStore: sessionStore ?? store,
          clipLibrary: clipLibrary ?? library,
          audioState: audioState,
          settings: parameter.snapshot(),
          volumeCompensation: true,
          random: ScriptedRandom(script),
        );

    /// Picks [graphIndex] in [on] (the test's store unless given) and submits.
    Future<RoundOutcome?> submit(
      SessionController controller,
      int graphIndex, {
      SessionStore? on,
      void Function(bool isCorrect, int correctGraphIndex)? onResult,
    }) {
      (on ?? store).setPickerValue(SessionStore.pickerValueOf(graphIndex));
      return controller.submitAnswer(onResult: onResult);
    }

    // -------------------------------------------------------------------------
    // submitAnswer
    // -------------------------------------------------------------------------
    group('submitAnswer', () {
      test('sends the next round to the player with the band taken out',
          () async {
        final controller = controllerFor([0, 2]);
        await controller.launch();

        await submit(controller, 0);

        // Once at launch for graph 0, once now for graph 2.
        verify(() => player.setEQParams(
              enableEQ: false,
              frequency: peak3.frequencyOf(2),
              gainDb: 6.0,
            )).called(1);
      });

      test('sends a dip as a negative gain', () async {
        parameter.filterType = FilterType.peakDip;
        final peakDip3 = BandLayout(3, FilterType.peakDip);
        final controller = controllerFor([0, 3]);
        await controller.launch();

        await submit(controller, 0);

        verify(() => player.setEQParams(
              enableEQ: false,
              frequency: peakDip3.frequencyOf(3),
              gainDb: -6.0,
            )).called(1);
      });

      test('tells onResult whether the pick was right and which graph was',
          () async {
        final controller = controllerFor([2, 0]);
        await controller.launch();

        bool? isCorrect;
        int? correctGraphIndex;
        await submit(controller, 1, onResult: (right, graph) {
          isCorrect = right;
          correctGraphIndex = graph;
        });

        expect(isCorrect, isFalse);
        expect(correctGraphIndex, 2);
      });

      test('puts the results in the store', () async {
        final controller = controllerFor([0, 1, 2]);
        await controller.launch();

        await submit(controller, 0);
        await submit(controller, 0);

        expect(store.results.rounds, 2);
        expect(store.results.correct, 1);
        expect(store.results.incorrect, 1);
        expect(controller.results, equals(store.results));
      });

      test('shows the new layout and puts the picker back when the band count '
          'changes', () async {
        parameter.threshold = 1;
        final controller = controllerFor([2, 0]);
        await controller.launch();
        expect(store.graphBarDataList.length, 3);

        await submit(controller, 2);

        expect(store.graphBarDataList.length, 4);
        expect(store.layout, equals(BandLayout(4, FilterType.peak)));
        expect(store.currentPickerValue, 1);
      });

      test('leaves the picker where it is when the band count stays', () async {
        final controller = controllerFor([1, 2]);
        await controller.launch();

        await submit(controller, 1);

        expect(store.graphBarDataList.length, 3);
        expect(store.currentPickerValue, 2);
      });

      test('goes loading, then ready', () async {
        final controller = controllerFor([0, 1]);
        await controller.launch();

        final states = <SessionState>[];
        store.addListener(() {
          if (states.isEmpty || states.last != store.sessionState) {
            states.add(store.sessionState);
          }
        });

        await submit(controller, 0);

        expect(states, [SessionState.loading, SessionState.ready]);
      });

      test('a second submit while the first is running is ignored', () async {
        final controller = controllerFor([0, 1, 2]);
        await controller.launch();
        store.setPickerValue(1);

        final first = controller.submitAnswer();
        final second = controller.submitAnswer();

        expect(await second, isNull);
        expect(await first, isNotNull);
        expect(store.results.rounds, 1);
        // The launch's round and the one next round, not a third.
        verify(() => player.setEQParams(
              enableEQ: any(named: 'enableEQ'),
              frequency: any(named: 'frequency'),
              gainDb: any(named: 'gainDb'),
            )).called(2);
      });

      test('is ignored before the session is ready', () async {
        final controller = controllerFor([0]);

        final outcome = await controller.submitAnswer();

        expect(outcome, isNull);
        verifyNever(() => player.setEQParams(
              enableEQ: any(named: 'enableEQ'),
              frequency: any(named: 'frequency'),
              gainDb: any(named: 'gainDb'),
            ));
      });

      test('a submit that finishes after the page is gone writes nothing',
          () async {
        // The store is dropped with the page, and writing to a disposed
        // notifier asserts.
        final pageStore = SessionStore();
        final controller = controllerFor([0, 1], sessionStore: pageStore);
        await controller.launch();
        final retuned = Completer<void>();
        when(() => player.setEQParams(
              enableEQ: any(named: 'enableEQ'),
              frequency: any(named: 'frequency'),
              gainDb: any(named: 'gainDb'),
            )).thenAnswer((_) => retuned.future);

        final pending = submit(controller, 0, on: pageStore);
        pageStore.dispose();
        retuned.complete();

        expect(await pending, isNull);
      });

      test('a throw ends in the error state and returns null', () async {
        final controller = controllerFor([0, 1]);
        await controller.launch();
        when(() => player.setEQParams(
              enableEQ: any(named: 'enableEQ'),
              frequency: any(named: 'frequency'),
              gainDb: any(named: 'gainDb'),
            )).thenThrow(StateError('engine gone'));

        final outcome = await submit(controller, 0);

        expect(outcome, isNull);
        expect(store.sessionState, SessionState.error);
      });
    });

    // -------------------------------------------------------------------------
    // One session after another
    //
    // The session page makes a store and a controller when a session starts
    // and drops them when it ends. Only the SessionParameter outlives them.
    // -------------------------------------------------------------------------
    group('one session after another', () {
      test('a new session starts at zero points', () async {
        // Two points are left behind by the first session. One more would
        // reach the threshold of 3 if they carried over, and add a band.
        final first = controllerFor([0, 1, 2]);
        await first.launch();
        await submit(first, 0);
        await submit(first, 1);
        expect(store.graphBarDataList.length, 3);

        final nextStore = SessionStore();
        addTearDown(nextStore.dispose);
        final second = controllerFor([0, 1], sessionStore: nextStore);
        await second.launch();
        await submit(second, 0, on: nextStore);

        expect(nextStore.graphBarDataList.length, 3,
            reason: 'the second session began with points left over from the '
                'first');
      });

      test('a new session starts with no results and the picker on the first '
          'graph', () async {
        final first = controllerFor([0, 1, 2]);
        await first.launch();
        await submit(first, 0);
        await submit(first, 1);
        store.setPickerValue(3);

        final nextStore = SessionStore();
        addTearDown(nextStore.dispose);
        final second = controllerFor([0], sessionStore: nextStore);
        await second.launch();

        expect(nextStore.results.rounds, isZero);
        expect(second.results.rounds, isZero);
        expect(nextStore.currentPickerValue, 1);
        // And the first session's are still its own.
        expect(first.results.rounds, 2);
        expect(store.results.rounds, 2);
      });

      test('a session whose band count went up leaves the settings alone',
          () async {
        final first = controllerFor([0, 1, 2, 0]);
        await first.launch();
        await submit(first, 0);
        await submit(first, 1);
        await submit(first, 2);
        expect(store.graphBarDataList.length, 4, reason: 'the ladder moved');

        expect(parameter.startingBand, 3);

        final nextStore = SessionStore();
        addTearDown(nextStore.dispose);
        final second = controllerFor([0], sessionStore: nextStore);
        await second.launch();
        expect(nextStore.graphBarDataList.length, 3,
            reason: 'the next session starts at the configured band count');
      });
    });

    // -------------------------------------------------------------------------
    // updatePlayerState
    // -------------------------------------------------------------------------
    group('updatePlayerState', () {
      test('re-sends Q, the answer and the toggle to a fresh player', () async {
        parameter.qFactor = 2.0;
        parameter.gain = 8;
        final controller = controllerFor([1]);
        await controller.launch();
        clearInteractions(player);

        controller.updatePlayerState(eqEnabled: true);

        verify(() => player.setEQQ(2.0)).called(1);
        verify(() => player.setEQFreq(peak3.frequencyOf(1))).called(1);
        verify(() => player.setEQGain(8.0)).called(1);
        verify(() => player.setEQ(true)).called(1);
      });
    });

    // -------------------------------------------------------------------------
    // launchSession — the one path that touches every collaborator
    // -------------------------------------------------------------------------
    group('launchSession', () {
      test('opens the first enabled clip and reports ready', () async {
        when(library.enabledClipPaths)
            .thenAnswer((_) async => ['/a.flac', '/b.flac']);

        await controllerFor([1]).launch();

        expect(store.sessionState, equals(SessionState.ready));
        expect(store.playlistPaths, equals(['/a.flac', '/b.flac']));
        expect(store.currentClipPath, equals('/a.flac'));
        verify(() => player.launch(
              androidBackend: AndroidAudioBackend.openSles,
              outputDevice: null,
              path: '/a.flac',
              volumeCompensation: true,
            )).called(1);
        // The graphs are shown and the first round is on the player.
        expect(store.graphBarDataList.length, 3);
        verify(() => player.setEQParams(
              enableEQ: false,
              frequency: peak3.frequencyOf(1),
              gainDb: 6.0,
            )).called(1);
      });

      test('starts at the configured band count', () async {
        parameter.startingBand = 7;

        await controllerFor([0]).launch();

        expect(store.layout, equals(BandLayout(7, FilterType.peak)));
      });

      test('applies the session Q to the fresh player once', () async {
        parameter.qFactor = 2.0;

        await controllerFor([0]).launch();

        verify(() => player.setEQQ(2.0)).called(1);
      });

      test('reports playlistEmpty and never touches the player when nothing '
          'is enabled', () async {
        when(library.enabledClipPaths).thenAnswer((_) async => []);

        await controllerFor([]).launch();

        expect(store.sessionState, equals(SessionState.playlistEmpty));
        verifyNever(() => player.launch(
              androidBackend: any(named: 'androidBackend'),
              outputDevice: any(named: 'outputDevice'),
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            ));
      });

      test('has no results before it has launched', () {
        expect(controllerFor([]).results.rounds, isZero);
      });

      test('reports playlistEmpty when the only enabled clip has no file, and '
          'keeps its record', () async {
        // The real library: what matters is that a missing clip is skipped
        // rather than deleted (ADR 0003), so the mock cannot show it.
        final dir = Directory.systemTemp.createTempSync('eqt_session_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final repo = await AudioClipRepository.open(
          File(p.join(dir.path, 'audio_clips.json')),
        );
        final clip = AudioClip('gone.flac', 'gone', 1, true);
        await repo.addClip(clip);
        final dirs = MockAppDirectories();
        when(() => dirs.getClipsPath()).thenAnswer((_) async => dir.path);

        await controllerFor([], clipLibrary: ClipLibrary(repo, dirs)).launch();

        expect(store.sessionState, equals(SessionState.playlistEmpty));
        expect(repo.getAllClips(), [clip]);
      });

      test('goes to init synchronously, before the first await', () {
        store.setSessionState(SessionState.ready);

        // Not awaited on purpose: the state must already have moved so a
        // relaunch never renders the previous session's ready UI.
        final pending = controllerFor([0]).launch();
        expect(store.sessionState, equals(SessionState.init));
        return pending;
      });

      test('stops writing to the store once shouldContinue turns false',
          () async {
        var stillOnPage = true;
        when(library.enabledClipPaths).thenAnswer((_) async {
          // The user leaves the page while the playlist is being read.
          stillOnPage = false;
          return ['/a.flac'];
        });

        await controllerFor([]).launch(shouldContinue: () => stillOnPage);

        // Nothing after the abandoned await may land in the store.
        expect(store.sessionState, equals(SessionState.init));
        expect(store.playlistPaths, isEmpty);
        verifyNever(() => player.launch(
              androidBackend: any(named: 'androidBackend'),
              outputDevice: any(named: 'outputDevice'),
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            ));
      });

      test('a player that fails to open reports error and rethrows', () async {
        when(() => player.launch(
              androidBackend: any(named: 'androidBackend'),
              outputDevice: null,
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            )).thenThrow(StateError('no device'));

        await expectLater(controllerFor([]).launch(), throwsException);
        expect(store.sessionState, equals(SessionState.error));
      });

      test('a failure after leaving the page does not write error either',
          () async {
        var stillOnPage = true;
        when(library.enabledClipPaths).thenAnswer((_) async {
          stillOnPage = false;
          throw StateError('box closed');
        });

        await expectLater(
          controllerFor([]).launch(shouldContinue: () => stillOnPage),
          throwsException,
        );
        expect(store.sessionState, equals(SessionState.init));
      });
    });
  });
}
