import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/session/state/session_controller.dart';
import 'package:eq_trainer/ui/session/widgets/session_control.dart';

import '../../../helpers/mocks.dart';

class _MockSessionController extends Mock implements SessionController {}

// The switch itself is the controller's, and tested there. These are about what
// the buttons make of the outcome.
void main() {
  late MockPlayerService player;
  late _MockSessionController controller;
  final en = lookupAppLocalizations(const Locale('en'));

  setUp(() {
    player = MockPlayerService();
    controller = _MockSessionController();
    when(() => player.fetchPlayerState)
        .thenReturn(const PlayerStateResponse(isPlaying: false));
  });

  Future<void> pumpControl(WidgetTester tester) async {
    await tester.pumpWidget(ToastificationWrapper(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerService>.value(value: player),
          Provider<SessionController>.value(value: controller),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SessionControl()),
        ),
      ),
    ));
  }

  testWidgets('a switch that skipped a clip says so', (tester) async {
    when(() => controller.nextTrack()).thenAnswer(
        (_) async => const TrackSwitch(TrackSwitchStatus.switched, skipped: 1));
    await pumpControl(tester);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(en.sessionSnackbarClipSkipped), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    // Let the toast run its course so no timer outlives the test.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a switch that skipped nothing says nothing', (tester) async {
    when(() => controller.nextTrack())
        .thenAnswer((_) async => const TrackSwitch(TrackSwitchStatus.switched));
    await pumpControl(tester);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(en.sessionSnackbarClipSkipped), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a switch that failed shows the error dialog with the cause',
      (tester) async {
    when(() => controller.previousTrack()).thenAnswer((_) async =>
        const TrackSwitch(TrackSwitchStatus.failed,
            skipped: 2, error: 'cannot decode', path: '/a.flac'));
    await pumpControl(tester);

    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('cannot decode'), findsOneWidget);
    expect(find.text(en.sessionSnackbarClipSkipped), findsNothing);
  });

  testWidgets('the buttons are off while a switch is running', (tester) async {
    final pending = Future<TrackSwitch>.delayed(
        const Duration(seconds: 1),
        () => const TrackSwitch(TrackSwitchStatus.switched));
    when(() => controller.nextTrack()).thenAnswer((_) => pending);
    await pumpControl(tester);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons.map((b) => b.onPressed), everyElement(isNull));

    await tester.pump(const Duration(seconds: 2));
  });
}
