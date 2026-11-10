import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
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
    registerFallbackValue(Duration.zero);
  });

  group('SessionController', () {
    late MockPlayerService player;
    late MockClipLibrary library;
    late SessionStore store;
    late SessionParameter parameter;

    // Peak mode with the default 3 bands keeps the picker easy to read: graph
    // i is picker value i + 1, and every graph has its own frequency.
    final peak3 = BandLayout(3, FilterType.peak);

    setUp(() {
      player = MockPlayerService();
      library = MockClipLibrary();
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
            path: any(named: 'path'),
            volumeCompensation: any(named: 'volumeCompensation'),
          )).thenAnswer((_) async {});
      when(library.enabledClipPaths).thenAnswer((_) async => ['/a.flac']);
      // A clip is where the queue says it is unless a test says otherwise.
      when(() => library.resolvePath(any()))
          .thenAnswer((i) async => i.positionalArguments.first as String);
      when(() => player.pause()).thenReturn(null);
      when(() => player.play()).thenReturn(null);
      when(() => player.seek(any())).thenAnswer((_) async => null);
      when(() => player.fetchEQState).thenReturn(false);
      when(() => player.fetchPosition).thenReturn(Duration.zero);
    });

    tearDown(() {
      store.dispose();
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
    // Track switching
    // -------------------------------------------------------------------------
    group('track switching', () {
      Future<SessionController> launched(
        List<String> paths, {
        List<int> script = const [1],
      }) async {
        when(library.enabledClipPaths).thenAnswer((_) async => paths);
        final controller = controllerFor(script);
        await controller.launch();
        clearInteractions(player);
        clearInteractions(library);
        return controller;
      }

      /// The paths the player was asked to load, in order.
      List<String> loaded() => verify(() => player.launch(
            path: captureAny(named: 'path'),
            volumeCompensation: any(named: 'volumeCompensation'),
          )).captured.cast<String>();

      void launchThrowsFor(String path, [Object error = 'cannot decode']) {
        when(() => player.launch(
              path: path,
              volumeCompensation: any(named: 'volumeCompensation'),
            )).thenThrow(error);
      }

      group('nextTrack', () {
        test('pauses, loads the next clip, re-applies the round and plays, in '
            'that order', () async {
          parameter.qFactor = 2.0;
          parameter.gain = 8;
          final controller = await launched(['/a', '/b'], script: [1]);

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.switched);
          verifyInOrder([
            () => player.fetchEQState,
            () => player.pause(),
            () => player.launch(
                  path: '/b',
                  volumeCompensation: true,
                ),
            () => player.setEQQ(2.0),
            () => player.setEQFreq(peak3.frequencyOf(1)),
            () => player.setEQGain(8.0),
            () => player.setEQ(false),
            () => player.play(),
          ]);
        });

        test('does not shut the player down first', () async {
          final controller = await launched(['/a', '/b']);

          await controller.nextTrack();

          verifyNever(() => player.shutdown());
        });

        test('puts the Original or Filtered view back after the new clip loads',
            () async {
          final controller = await launched(['/a', '/b']);
          when(() => player.fetchEQState).thenReturn(true);
          // launch() takes the band out, so the player reports it off by the
          // time the round is re-applied. What counts is what it said before.
          when(() => player.launch(
                path: any(named: 'path'),
                volumeCompensation: any(named: 'volumeCompensation'),
              )).thenAnswer((_) async {
            when(() => player.fetchEQState).thenReturn(false);
          });

          await controller.nextTrack();

          verify(() => player.setEQ(true)).called(1);
          verifyNever(() => player.setEQ(false));
        });

        test('wraps from the last clip to the first', () async {
          final controller = await launched(['/a', '/b', '/c']);

          await controller.nextTrack();
          await controller.nextTrack();
          await controller.nextTrack();

          expect(loaded(), ['/b', '/c', '/a']);
        });
      });

      group('previousTrack', () {
        test('wraps from the first clip to the last', () async {
          final controller = await launched(['/a', '/b', '/c']);

          final result = await controller.previousTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(loaded(), ['/c']);
        });

        test('steps back one clip at a time', () async {
          final controller = await launched(['/a', '/b', '/c']);

          await controller.previousTrack();
          await controller.previousTrack();

          expect(loaded(), ['/c', '/b']);
        });

        test('past three seconds restarts the clip instead of switching',
            () async {
          when(() => player.fetchPosition)
              .thenReturn(const Duration(seconds: 3, milliseconds: 1));
          final controller = await launched(['/a', '/b']);

          final result = await controller.previousTrack();

          expect(result.status, TrackSwitchStatus.restarted);
          verify(() => player.seek(Duration.zero)).called(1);
          verifyNever(() => player.launch(
                path: any(named: 'path'),
                volumeCompensation: any(named: 'volumeCompensation'),
              ));
        });

        test('at exactly three seconds switches', () async {
          when(() => player.fetchPosition).thenReturn(const Duration(seconds: 3));
          final controller = await launched(['/a', '/b']);

          final result = await controller.previousTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(loaded(), ['/b']);
          verifyNever(() => player.seek(any()));
        });

        test('inside three seconds switches', () async {
          when(() => player.fetchPosition).thenReturn(const Duration(seconds: 1));
          final controller = await launched(['/a', '/b']);

          final result = await controller.previousTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(loaded(), ['/b']);
        });

        test('a restart does not move the queue', () async {
          final controller = await launched(['/a', '/b', '/c']);
          when(() => player.fetchPosition).thenReturn(const Duration(seconds: 9));
          await controller.previousTrack();
          when(() => player.fetchPosition).thenReturn(Duration.zero);

          await controller.previousTrack();

          // Still on /a, so back from it is /c.
          expect(loaded(), ['/c']);
        });
      });

      group('a stale path', () {
        test('is resolved before loading and written back', () async {
          when(() => library.resolvePath('/b.m4a'))
              .thenAnswer((_) async => '/b.opus');
          final controller = await launched(['/a.flac', '/b.m4a', '/c.flac']);

          await controller.nextTrack();

          expect(loaded(), ['/b.opus']);
        });

        test('is looked up once, not on every visit', () async {
          when(() => library.resolvePath('/b.m4a'))
              .thenAnswer((_) async => '/b.opus');
          final controller = await launched(['/a.flac', '/b.m4a']);

          await controller.nextTrack(); // /b.m4a, resolved
          await controller.nextTrack(); // /a.flac
          await controller.nextTrack(); // /b.opus, already current

          verify(() => library.resolvePath('/b.m4a')).called(1);
          verify(() => library.resolvePath('/b.opus')).called(1);
        });
      });

      group('a missing clip', () {
        test('is skipped without a word and stays in the queue', () async {
          when(() => library.resolvePath('/b')).thenAnswer((_) async => null);
          final controller = await launched(['/a', '/b', '/c']);

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(result.skipped, 0);
          expect(loaded(), ['/c']);

          // The file comes back, and the clip was still there to play.
          when(() => library.resolvePath('/b'))
              .thenAnswer((_) async => '/b');
          await controller.nextTrack(); // /a
          await controller.nextTrack(); // /b
          expect(loaded(), ['/a', '/b']);
        });

        test('is skipped going back too', () async {
          when(() => library.resolvePath('/c')).thenAnswer((_) async => null);
          final controller = await launched(['/a', '/b', '/c']);

          final result = await controller.previousTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(loaded(), ['/b']);
        });

        test('with every clip missing, nothing is playable and nothing loads',
            () async {
          when(() => library.resolvePath(any())).thenAnswer((_) async => null);
          final controller = await launched(['/a', '/b', '/c']);

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.nothingPlayable);
          // One look at each clip, then it stops rather than looping.
          verify(() => library.resolvePath(any())).called(3);
          verifyNever(() => player.pause());
          verifyNever(() => player.launch(
                path: any(named: 'path'),
                volumeCompensation: any(named: 'volumeCompensation'),
              ));
        });
      });

      test('an empty queue has nothing playable', () async {
        final controller = await launched([]);

        expect((await controller.nextTrack()).status,
            TrackSwitchStatus.nothingPlayable);
        expect((await controller.previousTrack()).status,
            TrackSwitchStatus.nothingPlayable);
        verifyNever(() => player.pause());
      });

      test('a second call while one is in flight is busy and loads nothing',
          () async {
        final controller = await launched(['/a', '/b', '/c']);
        final loading = Completer<void>();
        when(() => player.launch(
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            )).thenAnswer((_) => loading.future);

        final first = controller.nextTrack();
        final second = await controller.nextTrack();
        final third = await controller.previousTrack();

        expect(second.status, TrackSwitchStatus.busy);
        expect(third.status, TrackSwitchStatus.busy);
        loading.complete();
        expect((await first).status, TrackSwitchStatus.switched);
        expect(loaded(), ['/b']);
        // And once it has finished the next one is accepted.
        expect((await controller.nextTrack()).status,
            TrackSwitchStatus.switched);
      });

      test('a load that finishes after the page is gone leaves the player alone',
          () async {
        // The player goes with the page, and touching it afterwards asserts.
        final pageStore = SessionStore();
        when(library.enabledClipPaths).thenAnswer((_) async => ['/a', '/b']);
        final controller = controllerFor([1], sessionStore: pageStore);
        await controller.launch();
        clearInteractions(player);
        final loading = Completer<void>();
        when(() => player.launch(
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            )).thenAnswer((_) => loading.future);

        final pending = controller.nextTrack();
        pageStore.dispose();
        loading.complete();
        await pending;

        verifyNever(() => player.setEQ(any()));
        verifyNever(() => player.play());
      });

      group('a clip that fails to load', () {
        test('is dropped, counted, and the next one is tried', () async {
          final controller = await launched(['/a', '/b', '/c']);
          launchThrowsFor('/b');

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(result.skipped, 1);
          expect(loaded(), ['/b', '/c']);
          verify(() => player.play()).called(1);
        });

        test('several in a row are all dropped', () async {
          final controller = await launched(['/a', '/b', '/c', '/d']);
          launchThrowsFor('/b');
          launchThrowsFor('/c');

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(result.skipped, 2);
          expect(loaded(), ['/b', '/c', '/d']);
        });

        test('can come all the way round to the clip that was playing',
            () async {
          final controller = await launched(['/a', '/b', '/c', '/d']);
          launchThrowsFor('/b');
          launchThrowsFor('/c');
          launchThrowsFor('/d');

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(result.skipped, 3);
          expect(loaded(), ['/b', '/c', '/d', '/a']);
        });

        test('is not tried again later in the session', () async {
          final controller = await launched(['/a', '/b', '/c']);
          launchThrowsFor('/b');

          await controller.nextTrack(); // /b fails, lands on /c
          await controller.nextTrack(); // /a
          await controller.nextTrack(); // /c, not /b

          expect(loaded(), ['/b', '/c', '/a', '/c']);
        });

        test('is dropped going back too', () async {
          final controller = await launched(['/a', '/b', '/c', '/d']);
          launchThrowsFor('/d');
          launchThrowsFor('/c');

          final result = await controller.previousTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(result.skipped, 2);
          expect(loaded(), ['/d', '/c', '/b']);
        });

        test('going back, the dropped clip is not tried again', () async {
          final controller = await launched(['/a', '/b', '/c']);
          launchThrowsFor('/c');

          await controller.previousTrack(); // /c fails, lands on /b
          await controller.previousTrack(); // /a
          await controller.previousTrack(); // /b, not /c

          expect(loaded(), ['/c', '/b', '/a', '/b']);
        });

        test('is counted apart from a missing clip, which stays', () async {
          when(() => library.resolvePath('/b')).thenAnswer((_) async => null);
          final controller = await launched(['/a', '/b', '/c', '/d']);
          launchThrowsFor('/c');

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.switched);
          expect(result.skipped, 1);
          expect(loaded(), ['/c', '/d']);
        });

        test('does not cost the Original or Filtered view', () async {
          // launch() takes the band out before it tries to load, so by the
          // second attempt the player already says it is off.
          final controller = await launched(['/a', '/b', '/c']);
          when(() => player.fetchEQState).thenReturn(true);
          when(() => player.launch(
                path: '/b',
                volumeCompensation: any(named: 'volumeCompensation'),
              )).thenAnswer((_) async {
            when(() => player.fetchEQState).thenReturn(false);
            throw StateError('cannot decode');
          });

          await controller.nextTrack();

          verify(() => player.setEQ(true)).called(1);
          verifyNever(() => player.setEQ(false));
        });

        test('with every clip failing, the switch fails with the last error '
            'and path', () async {
          final controller = await launched(['/a', '/b']);
          launchThrowsFor('/b', StateError('b is broken'));
          launchThrowsFor('/a', StateError('a is broken'));

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.failed);
          expect(result.skipped, 2);
          expect(result.error, isA<StateError>());
          expect((result.error as StateError).message, 'a is broken');
          expect(result.path, '/a');
          verifyNever(() => player.play());
        });

        test('a single clip that fails to reload fails the switch', () async {
          final controller = await launched(['/a']);
          launchThrowsFor('/a');

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.failed);
          expect(result.path, '/a');
        });

        test('leaves nothing playable once every clip is gone', () async {
          final controller = await launched(['/a', '/b']);
          launchThrowsFor('/a');
          launchThrowsFor('/b');
          await controller.nextTrack();

          final result = await controller.nextTrack();

          expect(result.status, TrackSwitchStatus.nothingPlayable);
        });

        test('lets the next switch through after a failed one', () async {
          final controller = await launched(['/a', '/b']);
          launchThrowsFor('/a');
          launchThrowsFor('/b');
          await controller.nextTrack();

          final result = await controller.previousTrack();

          expect(result.status, isNot(TrackSwitchStatus.busy));
        });
      });
    });

    // -------------------------------------------------------------------------
    // launch: the one path that touches every collaborator
    // -------------------------------------------------------------------------
    group('launch', () {
      test('opens the first enabled clip and reports ready', () async {
        when(library.enabledClipPaths)
            .thenAnswer((_) async => ['/a.flac', '/b.flac']);

        final controller = controllerFor([1]);
        final skipped = await controller.launch();

        expect(skipped, 0);
        expect(store.sessionState, equals(SessionState.ready));
        expect(controller.clipPaths, equals(['/a.flac', '/b.flac']));
        verify(() => player.launch(
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

      group('a clip that fails to load at the start', () {
        void launchThrowsFor(String path, [Object error = 'cannot decode']) {
          when(() => player.launch(
                path: path,
                volumeCompensation: any(named: 'volumeCompensation'),
              )).thenThrow(error);
        }

        List<String> loaded() => verify(() => player.launch(
              path: captureAny(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            )).captured.cast<String>();

        test('is skipped, and the session starts on the next one', () async {
          when(library.enabledClipPaths)
              .thenAnswer((_) async => ['/a', '/b', '/c']);
          launchThrowsFor('/a');

          final skipped = await controllerFor([1]).launch();

          expect(skipped, 1);
          expect(store.sessionState, SessionState.ready);
          expect(loaded(), ['/a', '/b']);
          // The session carries on exactly as if /b had been first.
          verify(() => player.setEQQ(any())).called(1);
          verify(() => player.setEQParams(
                enableEQ: false,
                frequency: peak3.frequencyOf(1),
                gainDb: 6.0,
              )).called(1);
        });

        test('several in a row are all skipped', () async {
          when(library.enabledClipPaths)
              .thenAnswer((_) async => ['/a', '/b', '/c', '/d']);
          launchThrowsFor('/a');
          launchThrowsFor('/b');
          launchThrowsFor('/c');

          final skipped = await controllerFor([0]).launch();

          expect(skipped, 3);
          expect(store.sessionState, SessionState.ready);
          expect(loaded(), ['/a', '/b', '/c', '/d']);
        });

        test('with every clip failing, ends in error and throws the last '
            'error', () async {
          when(library.enabledClipPaths)
              .thenAnswer((_) async => ['/a', '/b']);
          launchThrowsFor('/a', StateError('a is broken'));
          launchThrowsFor('/b', StateError('b is broken'));

          await expectLater(
            controllerFor([]).launch(),
            throwsA(isA<Exception>().having(
                (e) => e.toString(), 'message', contains('b is broken'))),
          );

          expect(store.sessionState, SessionState.error);
          expect(loaded(), ['/a', '/b']);
          verifyNever(() => player.setEQQ(any()));
        });

        test('still lists every path for the error view after all of them '
            'failed', () async {
          when(library.enabledClipPaths)
              .thenAnswer((_) async => ['/a.m4a', '/b.flac']);
          launchThrowsFor('/a.m4a');
          launchThrowsFor('/b.flac');
          final controller = controllerFor([]);

          await expectLater(controller.launch(), throwsException);

          expect(controller.clipPaths, ['/a.m4a', '/b.flac']);
        });

        test('is not visited by a later switch', () async {
          when(library.enabledClipPaths)
              .thenAnswer((_) async => ['/a', '/b', '/c']);
          launchThrowsFor('/a');
          final controller = controllerFor([1]);
          await controller.launch();
          clearInteractions(player);

          await controller.nextTrack(); // /c
          await controller.nextTrack(); // /b, not /a
          await controller.nextTrack(); // /c

          expect(loaded(), ['/c', '/b', '/c']);
        });

        test('does not count a clip that loads', () async {
          when(library.enabledClipPaths)
              .thenAnswer((_) async => ['/a', '/b']);

          expect(await controllerFor([0]).launch(), 0);
        });

        test('leaves the loop and the store alone once the page is gone',
            () async {
          var stillOnPage = true;
          when(library.enabledClipPaths)
              .thenAnswer((_) async => ['/a', '/b', '/c']);
          when(() => player.launch(
                path: '/a',
                volumeCompensation: any(named: 'volumeCompensation'),
              )).thenAnswer((_) async {
            // The user leaves while the first clip is failing to load.
            stillOnPage = false;
            throw StateError('cannot decode');
          });

          await controllerFor([])
              .launch(shouldContinue: () => stillOnPage);

          expect(loaded(), ['/a']);
          expect(store.sessionState, SessionState.init);
          verifyNever(() => player.setEQQ(any()));
          verifyNever(() => player.setEQParams(
                enableEQ: any(named: 'enableEQ'),
                frequency: any(named: 'frequency'),
                gainDb: any(named: 'gainDb'),
              ));
        });
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

        final controller = controllerFor([]);
        await controller.launch(shouldContinue: () => stillOnPage);

        // Nothing after the abandoned await may land in the store.
        expect(store.sessionState, equals(SessionState.init));
        expect(controller.clipPaths, isEmpty);
        verifyNever(() => player.launch(
              path: any(named: 'path'),
              volumeCompensation: any(named: 'volumeCompensation'),
            ));
      });

      test('a player that fails to open reports error and rethrows', () async {
        when(() => player.launch(
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
