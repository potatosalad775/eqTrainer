import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:coast_audio/coast_audio.dart';

final class AudioState extends ChangeNotifier {
  AudioState({
    required this.backend,
    required this.outputDevice,
  });

  late AudioDeviceBackend backend;
  late AudioDeviceInfo? outputDevice;

  /// True when the user has explicitly chosen a device from the dropdown.
  bool userSelectedDevice = false;

  Timer? _pollTimer;

  /// Cached context for device enumeration — reused across polls to avoid
  /// creating multiple miniaudio contexts on the same backend, which can
  /// interfere with an active playback device (especially on AAudio/Android).
  AudioDeviceContext? _pollContext;

  AudioState copyWith({
    AudioDeviceBackend? backend,
    AudioDeviceInfo? outputDevice,
    bool? userSelectedDevice,
  }) {
    return AudioState(
      backend: backend ?? this.backend,
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
      _pollContext ??= AudioDeviceContext(backends: [backend]);
      final devices = _pollContext!.getDevices(AudioDeviceType.playback);

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
    _pollContext = null;
  }

  @override
  void dispose() {
    stopDevicePolling();
    super.dispose();
  }

  factory AudioState.initialize({ required List<String> backendList }) {
    final AudioDeviceContext deviceContext;
    final backends = <AudioDeviceBackend, bool>{};

    if(backendList.isNotEmpty) {
      for (final backend in AudioDeviceBackend.values) {
        backends[backend] = switch (backend) {
          AudioDeviceBackend.coreAudio => backendList.contains("coreAudio"),
          AudioDeviceBackend.aaudio => backendList.contains("aaudio"),
          AudioDeviceBackend.openSLES => backendList.contains("openSLES"),
          AudioDeviceBackend.wasapi => backendList.contains("wasapi"),
          AudioDeviceBackend.alsa => backendList.contains("alsa"),
          AudioDeviceBackend.pulseAudio => backendList.contains("pulseAudio"),
          AudioDeviceBackend.jack => backendList.contains("jack"),
          AudioDeviceBackend.dummy => true,
        };
      }
    } else {
      // Initialize Default Backend
      for (final backend in AudioDeviceBackend.values) {
        backends[backend] = switch (backend) {
          AudioDeviceBackend.coreAudio => Platform.isIOS || Platform.isMacOS,
          AudioDeviceBackend.aaudio => false,
          AudioDeviceBackend.openSLES => Platform.isAndroid,
          AudioDeviceBackend.wasapi => Platform.isWindows,
          AudioDeviceBackend.alsa => Platform.isLinux,
          AudioDeviceBackend.pulseAudio => Platform.isLinux,
          AudioDeviceBackend.jack => Platform.isLinux,
          AudioDeviceBackend.dummy => true,
        };
      }
    }

    try {
      deviceContext = AudioDeviceContext(
          backends: backends.entries.where((e) => e.value).map((e) => e.key).toList()
      );
    } on MaException catch (e) {
      throw Exception(e.toString());
    }

    final activeBackend = deviceContext.activeBackend;
    final defaultDevice = deviceContext.getDevices(AudioDeviceType.playback).where((d) => d.isDefault).firstOrNull;

    // Dispose the probe context immediately — keeping it alive can interfere
    // with the playback AudioDeviceContext created later in the audio isolate,
    // especially on AAudio/Android where multiple ma_contexts on the same
    // backend cause start-up failures.
    AudioResourceManager.dispose(deviceContext.resourceId);

    return AudioState(
      backend: activeBackend,
      outputDevice: defaultDevice,
    );
  }
}
