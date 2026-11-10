import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/ui/session/widgets/session_graph.dart';

void main() {
  late SessionStore store;
  late MiscSettingsProvider settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      MiscSettingsProvider.frequencyToolTipKey: true,
    });
    settings = await MiscSettingsProvider.load();
    store = SessionStore();
  });

  tearDown(() => store.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MaterialApp(home: Scaffold(body: SessionGraph())),
      ));

  String labelOf(BandLayout layout, int graphIndex) =>
      '${layout.frequencyOf(graphIndex).toInt()}Hz';

  testWidgets('the tooltip names the picked graph\'s frequency', (tester) async {
    store.applyLayout(BandLayout(3, FilterType.peak));
    await pump(tester);
    expect(find.text('63Hz'), findsOneWidget);

    store.setPickerValue(2);
    await tester.pump();
    expect(find.text('630Hz'), findsOneWidget);
  });

  // A band count change puts the picker back on the first graph, which is
  // where it may already be, so the pick alone does not say the label is old.
  testWidgets('the tooltip follows a new layout with the picker unmoved',
      (tester) async {
    final before = BandLayout(3, FilterType.peak);
    final after = BandLayout(4, FilterType.peak);
    store.applyLayout(before);
    await pump(tester);
    expect(find.text(labelOf(before, 0)), findsOneWidget);

    store.applyLayout(after);
    await tester.pump();

    expect(labelOf(after, 0), isNot(labelOf(before, 0)));
    expect(find.text(labelOf(after, 0)), findsOneWidget);
    expect(find.text(labelOf(before, 0)), findsNothing);
  });
}
