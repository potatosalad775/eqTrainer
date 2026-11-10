import 'dart:io';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/output_selection.dart';

/// miniaudio's Android enumeration reports one device and never sets its
/// default flag, so [OutputSelection.device] stays null there. That is the
/// documented "let SoLoud open the OS default".
const _noDefaultFlag = 'Android devices do not report isDefault';

/// Device enumeration without a running engine.
///
/// The settings page and [OutputSelection]'s constructor both list devices at startup,
/// long before anything plays — under coast_audio that meant standing up a
/// probe `AudioDeviceContext` and disposing it before it could collide with
/// the playback one. SoLoud claims `listPlaybackDevices` is safe uninitialized;
/// this is the check that it is actually true on a real device, since every
/// other suite here brings the engine up first.
///
/// Needs an output device. Not run in CI — see AGENTS.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('device enumeration before init', () {
    test('the engine really is down at this point', () {
      expect(SoLoud.instance.isInitialized, isFalse);
    });

    test('listPlaybackDevices returns the machine\'s devices', () {
      final devices = SoLoud.instance.listPlaybackDevices();
      expect(devices, isNotEmpty);
      if (Platform.isAndroid) return; // See [_noDefaultFlag].
      expect(devices.where((d) => d.isDefault), isNotEmpty,
          reason: 'no device reported itself as the OS default');
    });

    test('OutputSelection picks up the default device', () async {
      SharedPreferences.setMockInitialValues({});
      final state = OutputSelection(prefs: await SharedPreferences.getInstance());
      expect(state.device, isNotNull);
      expect(state.device!.isDefault, isTrue);
      state.dispose();
    }, skip: Platform.isAndroid ? _noDefaultFlag : false);

    test('refresh holds a still-present user selection', () async {
      // Prefer a non-default device: refresh would land on the default
      // anyway, so only this one can tell a held selection from a followed one.
      final devices = SoLoud.instance.listPlaybackDevices();
      expect(devices, isNotEmpty);
      final chosen = devices.firstWhere(
        (d) => !d.isDefault,
        orElse: () => devices.first,
      );
      SharedPreferences.setMockInitialValues({});
      final state = OutputSelection(prefs: await SharedPreferences.getInstance())
        ..selectDevice(chosen);
      state.refresh();
      expect(state.device?.name, equals(chosen.name));
      expect(state.userSelectedDevice, isTrue);
      state.dispose();
    });
  });
}
