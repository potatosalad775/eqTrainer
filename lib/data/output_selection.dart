import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the list of playback devices comes from. A seam so the rules in
/// [OutputSelection] are tested without an engine.
abstract interface class OutputDevices {
  /// The devices SoLoud sees now. May throw: enumeration can fail transiently.
  List<PlaybackDevice> list();
}

/// The real list, from SoLoud.
final class SoLoudOutputDevices implements OutputDevices {
  const SoLoudOutputDevices();

  @override
  List<PlaybackDevice> list() =>
      // Safe with or without an initialized engine. Before init it uses a
      // temporary context, never alongside the engine's.
      SoLoud.instance.listPlaybackDevices();
}

/// The output the engine opens: the Android backend and the playback device.
///
/// One instance lives for the whole app, so a choice made while a session runs
/// is the one its next launch reads. SoLoud picks the desktop backend itself,
/// and Linux's override is left at its default, so the only backend choice left
/// is Android's — which eqTrainer does need, see [androidBackend].
class OutputSelection extends ChangeNotifier {
  /// [devices], [isAndroid] and [watchesDevices] are for tests; each defaults
  /// to the real platform.
  ///
  /// Device enumeration is best-effort: it runs before the engine is up, and a
  /// null [device] simply means "let SoLoud open the OS default".
  OutputSelection({
    required SharedPreferences prefs,
    OutputDevices? devices,
    bool? isAndroid,
    bool? watchesDevices,
  })  : _prefs = prefs,
        _devices = devices ?? const SoLoudOutputDevices(),
        watchesDevices = watchesDevices ??
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
        androidBackend = readAndroidBackend(prefs, isAndroid: isAndroid) {
    _device = _defaultOf(_enumerate());
  }

  final SharedPreferences _prefs;
  final OutputDevices _devices;

  /// Whether the device list is polled. Desktop only: creating a parallel
  /// device context can interfere with an active AAudio playback device on
  /// Android, so [startWatching] and a resume-triggered [refresh] are gated on
  /// this.
  final bool watchesDevices;

  /// Which native backend the engine opens the Android output device with.
  ///
  /// Read at [SoLoud.init] only, so a change reaches the engine on the next
  /// launch of the app. Ignored on every other platform.
  AndroidAudioBackend androidBackend;

  PlaybackDevice? _device;

  /// The device to open, or null to let SoLoud open the OS default.
  PlaybackDevice? get device => _device;

  bool _userSelectedDevice = false;

  /// True when the user has explicitly chosen a device from the dropdown.
  bool get userSelectedDevice => _userSelectedDevice;

  /// What the last successful enumeration returned.
  List<PlaybackDevice> _lastList = const [];

  Timer? _timer;

  /// The devices to offer. If enumeration fails, the last list it returned.
  List<PlaybackDevice> availableDevices() => _enumerate() ?? _lastList;

  /// The user's explicit choice of [device].
  void selectDevice(PlaybackDevice device) {
    _device = device;
    _userSelectedDevice = true;
    notifyListeners();
  }

  /// Saves [backend] and uses it from the next engine start. Keeps the device
  /// choice: this only changes which API opens it.
  Future<void> setAndroidBackend(AndroidAudioBackend backend) async {
    await saveAndroidBackend(_prefs, backend);
    androidBackend = backend;
    notifyListeners();
  }

  /// Re-enumerates playback devices and updates [device] if needed.
  ///
  /// - If the user explicitly selected a device and it still exists, keep it.
  /// - If the user's selected device disappeared, fall back to the OS default.
  /// - If no explicit selection was made, follow the OS default device.
  void refresh() {
    // Enumeration can fail transiently; skip this poll.
    final devices = _enumerate();
    if (devices == null) return;

    if (_userSelectedDevice && _device != null) {
      final stillExists = devices.any((d) => d.name == _device!.name);
      if (!stillExists) {
        _device = _defaultOf(devices);
        _userSelectedDevice = false;
        notifyListeners();
      }
    } else {
      final newDefault = _defaultOf(devices);
      if (newDefault != null && newDefault.name != _device?.name) {
        _device = newDefault;
        notifyListeners();
      }
    }
  }

  /// Starts periodic [refresh] calls. Does nothing unless [watchesDevices].
  void startWatching({Duration interval = const Duration(seconds: 5)}) {
    if (!watchesDevices) return;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  void stopWatching() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }

  /// The list, or null if enumeration failed.
  List<PlaybackDevice>? _enumerate() {
    try {
      return _lastList = _devices.list();
    } catch (_) {
      return null;
    }
  }

  static PlaybackDevice? _defaultOf(List<PlaybackDevice>? devices) =>
      devices?.where((d) => d.isDefault).firstOrNull;
}

const String _androidBackendKey = 'androidBackend';

/// The saved Android backend choice. Always [AndroidAudioBackend.auto] on other
/// platforms, where nothing reads it. [isAndroid] is for tests.
AndroidAudioBackend readAndroidBackend(SharedPreferences prefs, {bool? isAndroid}) =>
    (isAndroid ?? Platform.isAndroid)
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
