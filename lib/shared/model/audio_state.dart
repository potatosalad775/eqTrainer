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

  AudioState copyWith({
    AudioDeviceBackend? backend,
    AudioDeviceInfo? outputDevice,
  }) {
    return AudioState(
      backend: backend ?? this.backend,
      outputDevice: outputDevice ?? this.outputDevice,
    );
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
          AudioDeviceBackend.aaudio => Platform.isAndroid,
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
      throw Exception([e.toString()]);
    }

    return AudioState(
      backend: deviceContext.activeBackend,
      outputDevice: deviceContext.getDevices(AudioDeviceType.playback).where((d) => d.isDefault).firstOrNull,
    );
  }
}