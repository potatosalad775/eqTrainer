import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/settings/audio_backend_page.dart';

import '../../helpers/fake_output_devices.dart';

void main() {
  late SharedPreferences prefs;
  late OutputSelection output;
  final speakers = playbackDevice(1, 'Speakers', isDefault: true);
  final dac = playbackDevice(2, 'DAC');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    output = OutputSelection(
      prefs: prefs,
      devices: FakeOutputDevices([speakers, dac]),
      isAndroid: true,
      watchesDevices: false,
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: output,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: AudioBackendPage(),
      ),
    ));
  }

  testWidgets('starts on the backend in effect', (tester) async {
    await pumpPage(tester);
    final group = tester.widget<RadioGroup<AndroidAudioBackend>>(
        find.byType(RadioGroup<AndroidAudioBackend>));
    expect(group.groupValue, AndroidAudioBackend.openSles);
  });

  // The page used to build a new audio state from the backend and the device,
  // and forgot that the user had chosen the device: the next poll then moved it
  // back to the OS default.
  testWidgets('applying a backend keeps a device the user chose',
      (tester) async {
    output.selectDevice(dac);
    await pumpPage(tester);

    await tester.tap(find.text('AAudio'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(output.androidBackend, AndroidAudioBackend.aaudio);
    expect(output.device, dac);
    expect(output.userSelectedDevice, isTrue);
    expect(prefs.getString('androidBackend'), 'aaudio');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('applying a backend leaves a followed default followed',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('AAudio'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(output.device, speakers);
    expect(output.userSelectedDevice, isFalse);
  });
}
