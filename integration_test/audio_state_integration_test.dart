import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';

/// Device enumeration without a running engine.
///
/// The settings page and [AudioState.initialize] both list devices at startup,
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
      expect(devices.where((d) => d.isDefault), isNotEmpty,
          reason: 'no device reported itself as the OS default');
    });

    test('AudioState.initialize picks up the default device', () {
      final state = AudioState.initialize(backendList: []);
      expect(state.outputDevice, isNotNull);
      expect(state.outputDevice!.isDefault, isTrue);
      state.dispose();
    });

    test('refreshDevices holds a still-present user selection', () {
      final state = AudioState.initialize(backendList: [])
        ..userSelectedDevice = true;
      final chosen = state.outputDevice;
      state.refreshDevices();
      expect(state.outputDevice?.name, equals(chosen?.name));
      expect(state.userSelectedDevice, isTrue);
      state.dispose();
    });
  });
}
