import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/core/widget/device_dropdown.dart';

import '../../../helpers/fake_output_devices.dart';

void main() {
  late FakeOutputDevices fake;
  late OutputSelection output;
  final speakers = playbackDevice(1, 'Speakers', isDefault: true);
  final dac = playbackDevice(2, 'DAC');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fake = FakeOutputDevices([speakers, dac]);
    output = OutputSelection(
      prefs: await SharedPreferences.getInstance(),
      devices: fake,
      watchesDevices: false,
    );
  });

  Future<void> pumpDropdown(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: output,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: DeviceDropdown()),
      ),
    ));
  }

  int? shownValue(WidgetTester tester) =>
      tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value;

  testWidgets('lists the devices from the selection and shows the current one',
      (tester) async {
    await pumpDropdown(tester);

    expect(shownValue(tester), speakers.id);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('Speakers'), findsWidgets);
    expect(find.text('DAC'), findsOneWidget);
  });

  // The dropdown used to swap in a new audio state that the running session
  // never saw. Picking now writes to the one selection every launch reads.
  testWidgets('picking a device selects it on the shared selection',
      (tester) async {
    await pumpDropdown(tester);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAC').last);
    await tester.pumpAndSettle();

    expect(output.device, dac);
    expect(output.userSelectedDevice, isTrue);
    expect(shownValue(tester), dac.id);
  });

  testWidgets('a selected device that is no longer listed shows no value',
      (tester) async {
    output.selectDevice(dac);
    fake.devices = [speakers];
    await pumpDropdown(tester);

    expect(tester.takeException(), isNull);
    expect(shownValue(tester), isNull);
  });

  testWidgets('keeps the last list when enumeration fails', (tester) async {
    await pumpDropdown(tester);
    fake.error = StateError('transient');

    output.selectDevice(dac);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(shownValue(tester), dac.id);
  });
}
