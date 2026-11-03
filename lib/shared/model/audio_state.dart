import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Output device selection, plus the Android backend the engine opens it with.
///
/// Under coast_audio this also owned a set of enabled *backends* per platform,
/// because every platform's backend had to be picked explicitly. SoLoud picks
/// the desktop backend itself and exposes no hook to override it (Windows and
/// Linux never create an explicit `ma_context`), so the only choice left is
/// Android's — which eqTrainer does need, see [androidBackend].
final class AudioState extends ChangeNotifier {
  AudioState({
    required this.androidBackend,
    required this.outputDevice,
  });

  /// Which native backend the engine opens the Android output device with.
  ///
  /// Read at [SoLoud.init] only. Ignored on every other platform, where SoLoud
  /// chooses the backend and offers nothing to override it with.
  AndroidAudioBackend androidBackend;

  PlaybackDevice? outputDevice;

  /// True when the user has explicitly chosen a device from the dropdown.
  bool userSelectedDevice = false;

  Timer? _pollTimer;

  AudioState copyWith({
    AndroidAudioBackend? androidBackend,
    PlaybackDevice? outputDevice,
    bool? userSelectedDevice,
  }) {
    return AudioState(
      androidBackend: androidBackend ?? this.androidBackend,
      outputDevice: outputDevice ?? this.outputDevice,
    )..userSelectedDevice = userSelectedDevice ?? this.userSelectedDevice;
  }

  /// Re-enumerates playback devices and updates [outputDevice] if needed.
  ///
  /// - If the user explicitly selected a device and it still exists, keep it.
  /// - If the user's selected device disappeared, fall back to the OS default.
  /// - If no explicit selection was made, follow the OS default device.
  void refreshDevices() {
    try {
      // Safe with or without an initialized engine, and it does not create a
      // second context — the coast_audio version had to cache an
      // AudioDeviceContext here precisely to avoid that.
      final devices = SoLoud.instance.listPlaybackDevices();

      if (userSelectedDevice && outputDevice != null) {
        final stillExists = devices.any((d) => d.name == outputDevice!.name);
        if (!stillExists) {
          outputDevice = devices.where((d) => d.isDefault).firstOrNull;
          userSelectedDevice = false;
          notifyListeners();
        }
      } else {
        final newDefault = devices.where((d) => d.isDefault).firstOrNull;
        if (newDefault != null && newDefault.name != outputDevice?.name) {
          outputDevice = newDefault;
          notifyListeners();
        }
      }
    } catch (_) {
      // Device enumeration can fail transiently; silently skip this poll.
    }
  }

  /// Starts periodic device polling (desktop only).
  void startDevicePolling({Duration interval = const Duration(seconds: 5)}) {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => refreshDevices());
  }

  /// Stops periodic device polling.
  void stopDevicePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    stopDevicePolling();
    super.dispose();
  }

  /// Builds the initial state from the saved backend setting.
  ///
  /// Device enumeration is best-effort: it runs before the engine is up, and a
  /// null [outputDevice] simply means "let SoLoud open the OS default".
  factory AudioState.initialize({required AndroidAudioBackend androidBackend}) {
    PlaybackDevice? defaultDevice;
    try {
      defaultDevice = SoLoud.instance
          .listPlaybackDevices()
          .where((d) => d.isDefault)
          .firstOrNull;
    } catch (_) {
      defaultDevice = null;
    }

    return AudioState(
      androidBackend: androidBackend,
      outputDevice: defaultDevice,
    );
  }
}

const String _androidBackendKey = 'androidBackend';

/// The saved Android backend choice. Always [AndroidAudioBackend.auto] on other
/// platforms, where nothing reads it.
AndroidAudioBackend readAndroidBackend(SharedPreferences prefs) =>
    Platform.isAndroid
        ? androidBackendFromName(prefs.getString(_androidBackendKey))
        : AndroidAudioBackend.auto;

/// The Android half of [readAndroidBackend], split out so it can be tested
/// off-device.
///
/// Nothing saved, or nothing recognizable, gets OpenSL ES, which is what
/// eqTrainer has always shipped on Android. Several Digital Audio Players
/// accept an AAudio stream and then glitch on it, and automatic fallback cannot
/// help — miniaudio only skips a backend that fails to *initialize*.
@visibleForTesting
AndroidAudioBackend androidBackendFromName(String? name) =>
    AndroidAudioBackend.values.asNameMap()[name] ?? AndroidAudioBackend.openSles;

Future<bool> saveAndroidBackend(
  SharedPreferences prefs,
  AndroidAudioBackend backend,
) =>
    prefs.setString(_androidBackendKey, backend.name);
