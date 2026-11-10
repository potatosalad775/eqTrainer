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
    /// round, then one per submit.
    SessionController controllerFor(List<int> script) =>
        SessionController(random: ScriptedRandom(script));

    Future<void> launch(
      SessionController controller, {
      bool Function()? shouldContinue,
      ClipLibrary? clipLibrary,
    }) =>
        controller.launchSession(
          player,
          audioState: audioState,
          sessionStore: store,
          sessionParameter: parameter,
          clipLibrary: clipLibrary ?? library,
          volumeCompensation: true,
          shouldContinue: shouldContinue,
        );

    /// Picks [graphIndex] and submits it.
    Future<RoundOutcome?> submit(
      SessionController controller,
      int graphIndex, {
      void Function(bool isCorrect, int correctGraphIndex)? onResult,
    }) {
      store.setPickerValue(SessionStore.pickerValueOf(graphIndex));
      return controller.submitAnswer(
        player: player,
        sessionStore: store,
        onResult: onResult,
      );
    }

    // -------------------------------------------------------------------------
    // submitAnswer
    // -------------------------------------------------------------------------
    group('submitAnswer', () {
      test('sends the next round to the player with the band taken out',
          () async {
        final controller = controllerFor([0, 2]);
        await launch(controller);

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
        await launch(controller);

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
        await launch(controller);

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
        await launch(controller);

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
        await launch(controller);
        expect(store.graphBarDataList.length, 3);

        await submit(controller, 2);

        expect(store.graphBarDataList.length, 4);
        expect(store.layout, equals(BandLayout(4, FilterType.peak)));
        expect(store.currentPickerValue, 1);
      });

      test('leaves the picker where it is when the band count stays', () async {
        final controller = controllerFor([1, 2]);
        await launch(controller);

        await submit(controller, 1);

        expect(store.graphBarDataList.length, 3);
        expect(store.currentPickerValue, 2);
      });

      test('goes loading, then ready', () async {
        final controller = controllerFor([0, 1]);
        await launch(controller);

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
        await launch(controller);
        store.setPickerValue(1);

        final first = controller.submitAnswer(player: player, sessionStore: store);
        final second = controller.submitAnswer(player: player, sessionStore: store);

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

        final outcome = await controller.submitAnswer(
          player: player,
          sessionStore: store,
        );

        expect(outcome, isNull);
        verifyNever(() => player.setEQParams(
              enableEQ: any(named: 'enableEQ'),
              frequency: any(named: 'frequency'),
              gainDb: any(named: 'gainDb'),
            ));
      });

      test('a throw ends in the error state and returns null', () async {
        final controller = controllerFor([0, 1]);
        await launch(controller);
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
    // The app keeps one store, one controller and one SessionParameter across
    // sessions, so whatever a session leaves behind in them is what the next
    // one starts from.
    // -------------------------------------------------------------------------
    group('one session after another', () {
      test('a new session starts at zero points', () async {
        // The rounds are drawn 0, 1, 2 in the first session and 0, 1 in the
        // second. Two points are left behind; one more would reach the
        // threshold of 3 if they carried over, and add a band.
        final controller = controllerFor([0, 1, 2, 0, 1]);
        await launch(controller);
        await submit(controller, 0);
        await submit(controller, 1);
        expect(store.graphBarDataList.length, 3);

        await launch(controller);
        await submit(controller, 0);

        expect(store.graphBarDataList.length, 3,
            reason: 'the second session began with points left over from the '
                'first');
      });

      test('a session whose band count went up leaves the settings alone',
          () async {
        final controller = controllerFor([0, 1, 2, 0, 0]);
        await launch(controller);
        await submit(controller, 0);
        await submit(controller, 1);
        await submit(controller, 2);
        expect(store.graphBarDataList.length, 4, reason: 'the ladder moved');

        expect(parameter.startingBand, 3);

        await launch(controller);
        expect(store.graphBarDataList.length, 3,
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
        await launch(controller);
        clearInteractions(player);

        controller.updatePlayerState(player, eqEnabled: true);

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

        await launch(controllerFor([1]));

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

        await launch(controllerFor([0]));

        expect(store.layout, equals(BandLayout(7, FilterType.peak)));
      });

      test('applies the session Q to the fresh player once', () async {
        parameter.qFactor = 2.0;

        await launch(controllerFor([0]));

        verify(() => player.setEQQ(2.0)).called(1);
      });

      test('reports playlistEmpty and never touches the player when nothing '
          'is enabled', () async {
        when(library.enabledClipPaths).thenAnswer((_) async => []);

        await launch(controllerFor([]));

        expect(store.sessionState, equals(SessionState.playlistEmpty));
        verifyNever(() => player.launch(
              androidBackend: any(named: 'androidBackend'),
              outputDevice: any(named: 'outputDevice'),
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            ));
      });

      test('resets the previous session\'s results and picker', () async {
        // Leave a finished session behind in the store.
        final controller = controllerFor([0, 1, 2, 0]);
        await launch(controller);
        await submit(controller, 0);
        await submit(controller, 1);
        store.setPickerValue(2);

        await launch(controller);

        expect(store.results.rounds, isZero);
        expect(controller.results.rounds, isZero);
        expect(store.currentPickerValue, equals(1));
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

        await launch(controllerFor([]), clipLibrary: ClipLibrary(repo, dirs));

        expect(store.sessionState, equals(SessionState.playlistEmpty));
        expect(repo.getAllClips(), [clip]);
      });

      test('goes to init synchronously, before the first await', () {
        store.setSessionState(SessionState.ready);

        // Not awaited on purpose: the state must already have moved so a
        // relaunch never renders the previous session's ready UI.
        final pending = launch(controllerFor([0]));
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

        await launch(controllerFor([]), shouldContinue: () => stillOnPage);

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

        await expectLater(launch(controllerFor([])), throwsException);
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
          launch(controllerFor([]), shouldContinue: () => stillOnPage),
          throwsException,
        );
        expect(store.sessionState, equals(SessionState.init));
      });
    });
  });
}
