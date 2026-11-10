import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/output_selection.dart';

import '../helpers/fake_output_devices.dart';

/// eqTrainer has always pinned Android to OpenSL ES because several Digital
/// Audio Players accept an AAudio stream and then glitch on it, while SoLoud's
/// own default prefers AAudio on API >= 30. Reading the setting wrong therefore
/// does not fail loudly — it just puts those devices back on the backend they
/// misbehave on.
void main() {
  group('androidBackendFromName', () {
    test('a fresh install (nothing saved) gets OpenSL ES, not SoLoud\'s AAudio default', () {
      expect(androidBackendFromName(null), equals(AndroidAudioBackend.openSles));
    });

    test('an unrecognized value falls back to OpenSL ES', () {
      expect(androidBackendFromName('wasapi'), equals(AndroidAudioBackend.openSles));
    });
  });

  test('every backend round-trips through the saved value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    for (final backend in AndroidAudioBackend.values) {
      await saveAndroidBackend(prefs, backend);
      await prefs.reload();
      expect(
        androidBackendFromName(prefs.getString('androidBackend')),
        equals(backend),
        reason: '$backend did not survive a write/read cycle',
      );
    }
  });

  group('OutputSelection', () {
    PlaybackDevice dev(int id, String name, {bool isDefault = false}) =>
        playbackDevice(id, name, isDefault: isDefault);

    final speakers = dev(1, 'Speakers', isDefault: true);
    final dac = dev(2, 'DAC');
    final usb = dev(3, 'USB Headset');

    late SharedPreferences prefs;
    late FakeOutputDevices fake;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fake = FakeOutputDevices([speakers, dac]);
    });

    OutputSelection make({bool isAndroid = false, bool watches = false}) =>
        OutputSelection(
          prefs: prefs,
          devices: fake,
          isAndroid: isAndroid,
          watchesDevices: watches,
        );

    test('starts on the OS default device, not as a user choice', () {
      final s = make();
      expect(s.device, speakers);
      expect(s.userSelectedDevice, isFalse);
    });

    test('starts with no device when enumeration fails', () {
      fake.error = StateError('no context');
      expect(make().device, isNull);
    });

    test('starts with no device when nothing is the default', () {
      fake.devices = [dac];
      expect(make().device, isNull);
    });

    test('reads the saved backend on Android, and is auto elsewhere', () async {
      await saveAndroidBackend(prefs, AndroidAudioBackend.aaudio);
      expect(make(isAndroid: true).androidBackend, AndroidAudioBackend.aaudio);
      expect(make(isAndroid: false).androidBackend, AndroidAudioBackend.auto);
    });

    test('a fresh Android install gets OpenSL ES', () {
      expect(make(isAndroid: true).androidBackend, AndroidAudioBackend.openSles);
    });

    test('availableDevices lists through the seam', () {
      expect(make().availableDevices(), [speakers, dac]);
    });

    test('availableDevices returns the last list when enumeration fails', () {
      final s = make();
      fake.error = StateError('transient');
      expect(s.availableDevices(), [speakers, dac]);
    });

    test('selectDevice makes the choice explicit and notifies', () {
      final s = make();
      var notified = 0;
      s.addListener(() => notified++);
      s.selectDevice(dac);
      expect(s.device, dac);
      expect(s.userSelectedDevice, isTrue);
      expect(notified, 1);
    });

    test('setAndroidBackend saves, notifies, and keeps the device choice',
        () async {
      final s = make(isAndroid: true)..selectDevice(dac);
      var notified = 0;
      s.addListener(() => notified++);

      await s.setAndroidBackend(AndroidAudioBackend.aaudio);

      expect(s.androidBackend, AndroidAudioBackend.aaudio);
      expect(s.device, dac);
      expect(s.userSelectedDevice, isTrue);
      expect(notified, 1);
      expect(prefs.getString('androidBackend'), 'aaudio');
    });

    group('refresh', () {
      test('keeps a chosen device that is still there', () {
        final s = make()..selectDevice(dac);
        fake.devices = [speakers, dac, usb];
        s.refresh();
        expect(s.device, dac);
        expect(s.userSelectedDevice, isTrue);
      });

      test('a chosen device that went away falls back to the default', () {
        final s = make()..selectDevice(dac);
        var notified = 0;
        s.addListener(() => notified++);
        fake.devices = [speakers, usb];
        s.refresh();
        expect(s.device, speakers);
        expect(s.userSelectedDevice, isFalse);
        expect(notified, 1);
      });

      test('a chosen device that went away with no default leaves none', () {
        final s = make()..selectDevice(dac);
        fake.devices = [usb];
        s.refresh();
        expect(s.device, isNull);
        expect(s.userSelectedDevice, isFalse);
      });

      test('without a choice, follows a new OS default', () {
        final s = make();
        var notified = 0;
        s.addListener(() => notified++);
        fake.devices = [dev(1, 'Speakers'), dev(3, 'USB Headset', isDefault: true)];
        s.refresh();
        expect(s.device?.name, 'USB Headset');
        expect(s.userSelectedDevice, isFalse);
        expect(notified, 1);
      });

      test('an unchanged default does not notify', () {
        final s = make();
        var notified = 0;
        s.addListener(() => notified++);
        s.refresh();
        expect(notified, 0);
      });

      test('a failed enumeration changes nothing', () {
        final s = make()..selectDevice(dac);
        var notified = 0;
        s.addListener(() => notified++);
        fake.error = StateError('transient');
        s.refresh();
        expect(s.device, dac);
        expect(s.userSelectedDevice, isTrue);
        expect(notified, 0);
      });
    });

    // testWidgets for its fake clock; no widget is pumped. A timer left
    // running would fail the test as pending.
    group('watching', () {
      testWidgets('polls on the interval when it watches devices', (tester) async {
        final s = make(watches: true)
          ..startWatching(interval: const Duration(seconds: 5));
        fake.devices = [dev(3, 'USB Headset', isDefault: true)];
        await tester.pump(const Duration(seconds: 4));
        expect(s.device, speakers);
        await tester.pump(const Duration(seconds: 2));
        expect(s.device?.name, 'USB Headset');
        s.stopWatching();
      });

      testWidgets('stopWatching stops the polling', (tester) async {
        final s = make(watches: true)..startWatching();
        s.stopWatching();
        fake.devices = [dev(3, 'USB Headset', isDefault: true)];
        await tester.pump(const Duration(seconds: 30));
        expect(s.device, speakers);
      });

      testWidgets('startWatching does nothing when it does not watch devices',
          (tester) async {
        final s = make(watches: false)..startWatching();
        fake.devices = [dev(3, 'USB Headset', isDefault: true)];
        await tester.pump(const Duration(seconds: 30));
        expect(s.device, speakers);
      });
    });
  });
}
