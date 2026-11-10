import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/audio_state.dart';

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
}
