import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';

/// The saved-setting migration off coast_audio's backend list.
///
/// eqTrainer has always pinned Android to OpenSL ES because several Digital
/// Audio Players accept an AAudio stream and then glitch on it, while SoLoud's
/// own default prefers AAudio on API >= 30. Reading an existing user's setting
/// wrong therefore does not fail loudly — it just puts those devices back on
/// the backend they misbehave on.
void main() {
  group('androidBackendFromSavedListOnAndroid', () {
    test('a fresh install (empty list) gets OpenSL ES, not SoLoud\'s AAudio default', () {
      expect(androidBackendFromSavedListOnAndroid([]),
          equals(AndroidAudioBackend.openSles));
    });

    test('the shipped Android default list gets OpenSL ES', () {
      expect(androidBackendFromSavedListOnAndroid(['openSLES']),
          equals(AndroidAudioBackend.openSles));
    });

    test('a deliberate AAudio-only opt-in is preserved', () {
      expect(androidBackendFromSavedListOnAndroid(['aaudio']),
          equals(AndroidAudioBackend.aaudio));
    });

    test('AAudio merely enabled alongside OpenSL ES is not an opt-in', () {
      // coast_audio took the first backend that initialized, so this user was
      // on whichever won — not necessarily AAudio. OpenSL ES is the safe read.
      expect(androidBackendFromSavedListOnAndroid(['aaudio', 'openSLES']),
          equals(AndroidAudioBackend.openSles));
    });

    test('an unrelated legacy list (desktop backends) falls back to OpenSL ES', () {
      expect(androidBackendFromSavedListOnAndroid(['wasapi', 'dummy']),
          equals(AndroidAudioBackend.openSles));
    });

    test('every backend round-trips through the saved list', () {
      for (final backend in AndroidAudioBackend.values) {
        expect(
          androidBackendFromSavedListOnAndroid(savedListForAndroidBackend(backend)),
          equals(backend),
          reason: '$backend did not survive a write/read cycle',
        );
      }
    });
  });
}
