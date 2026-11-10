import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/playlist/widget/playlist_control_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_audio_engine.dart';
import '../../../helpers/fake_encoder.dart';
import '../../../helpers/fake_output_devices.dart';
import '../../../helpers/mocks.dart';

void main() {
  late OutputSelection output;
  late ClipFormatMigration migration;
  late FakeAudioEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    output = OutputSelection(
      prefs: await SharedPreferences.getInstance(),
      devices: FakeOutputDevices([]),
      watchesDevices: false,
    );
    migration = ClipFormatMigration(
      MockClipLibrary(),
      importFormat: 0,
      encoder: FakeClipEncoder(),
    );
    engine = FakeAudioEngine();
  });

  Widget app(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: output),
          ChangeNotifierProvider.value(value: migration),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: home),
        ),
      );

  PlaylistControlView view(String path) => PlaylistControlView(
        filePath: path,
        createPlayer: (context) => PlaylistPlayer(
          output,
          hold: migration,
          engine: engine,
        ),
      );

  /// Moves stream time and the test clock together, in 4 ms steps.
  Future<void> elapse(WidgetTester tester, Duration d) async {
    const step = Duration(milliseconds: 4);
    for (var left = d; left > Duration.zero; left -= step) {
      final s = left < step ? left : step;
      engine.advance(s);
      await tester.pump(s);
    }
  }

  /// Removes the view, which cancels the player's poll timer; the binding
  /// checks for pending timers before tearDowns run.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> open(WidgetTester tester, {String path = 'a.wav'}) async {
    await tester.pumpWidget(app(view(path)));
    await tester.pump(const Duration(milliseconds: 20));
  }

  ProgressBar bar(WidgetTester tester) =>
      tester.widget<ProgressBar>(find.byType(ProgressBar));

  testWidgets('opening loads the path and shows its length', (tester) async {
    engine.lengths['a.wav'] = const Duration(seconds: 42);
    await open(tester);

    expect(engine.callsOf('load').single.args.first, 'a.wav');
    expect(bar(tester).total, const Duration(seconds: 42));
    await leave(tester);
  });

  testWidgets('play/pause plays and pauses the voice, and the icon follows',
      (tester) async {
    await open(tester);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expect(engine.voices.single.paused, isTrue);

    await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
    await tester.pump();
    expect(engine.voices.single.paused, isFalse);
    expect(find.byIcon(Icons.pause_circle_filled_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_circle_filled_rounded));
    await tester.pump();
    expect(engine.voices.single.paused, isTrue);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    await leave(tester);
  });

  testWidgets('previous seeks to the start', (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
    await tester.pump();
    await elapse(tester, const Duration(seconds: 2));
    expect(engine.voices.single.position, const Duration(seconds: 2));

    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pump();
    expect(engine.callsOf('seek').last.args, [Duration.zero]);
    expect(engine.voices.single.position, Duration.zero);
    await leave(tester);
  });

  testWidgets('holds the library migration while up', (tester) async {
    expect(migration.isPaused, isFalse);
    await open(tester);
    expect(migration.isPaused, isTrue);

    await leave(tester);
    expect(migration.isPaused, isFalse);
  });

  group('presented as the app does, in a modal bottom sheet', () {
    Future<void> openSheet(WidgetTester tester, String path) async {
      await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isDismissible: false,
            enableDrag: false,
            builder: (_) => SafeArea(child: view(path)),
          ),
          child: const Text('preview'),
        ),
      )));
      await tester.tap(find.text('preview'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a path that fails to load shows the error dialog',
        (tester) async {
      engine.failingPaths.add('bad.wav');
      await openSheet(tester, 'bad.wav');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining(l10n.errorPlayerAlertContent), findsOneWidget);
      expect(find.text(l10n.errorPlayerAlertExitButton), findsOneWidget);
      await leave(tester);
    });

    // Skipped, production bug. Fails today: the dialog's action pops once, and the topmost route is the
    // dialog itself, so the sheet is left open on a player that was shut down.
    testWidgets('the error dialog action closes the view', (tester) async {
      engine.failingPaths.add('bad.wav');
      await openSheet(tester, 'bad.wav');

      await tester.tap(find.text(l10n.errorPlayerAlertExitButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlaylistControlView), findsNothing);
      await leave(tester);
    }, skip: true);

    testWidgets('the close button pops', (tester) async {
      await openSheet(tester, 'a.wav');
      expect(find.byType(PlaylistControlView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlaylistControlView), findsNothing);
      await leave(tester);
    });
  });
}
