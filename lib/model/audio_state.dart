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

  factory AudioState.initialize({ required List<AudioDeviceBackend> backendList }) {
    final AudioDeviceContext deviceContext;

    if(backendList.isNotEmpty) {
      try {
        deviceContext = AudioDeviceContext(
          backends: backendList,
        );
      } on MaException catch (e) {
        throw Exception([e.toString()]);
      }
    } else {
      // Initialize Default Backend
      final backends = <AudioDeviceBackend, bool>{};
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

      try {
        deviceContext = AudioDeviceContext(
          backends: backends.entries.where((e) => e.value).map((e) => e.key).toList()
        );
      } on MaException catch (e) {
        throw Exception([e.toString()]);
      }
    }

    return AudioState(
      backend: deviceContext.activeBackend,
      outputDevice: deviceContext.getDevices(AudioDeviceType.playback).where((d) => d.isDefault).firstOrNull,
    );
  }
}