import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/setting_data.dart';

class DevBackendPage extends StatefulWidget {
  const DevBackendPage({super.key});

  @override
  State<DevBackendPage> createState() => _DevBackendPageState();
}

class _DevBackendPageState extends State<DevBackendPage> {
  final backends = <AudioDeviceBackend, bool>{};

  @override
  void initState() {
    super.initState();
    if(backendList.isEmpty) {
      for (final backend in AudioDeviceBackend.values) {
        backends[backend] = switch (backend) {
          AudioDeviceBackend.coreAudio => Platform.isMacOS || Platform.isIOS,
          AudioDeviceBackend.aaudio => Platform.isAndroid,
          AudioDeviceBackend.openSLES => Platform.isAndroid,
          AudioDeviceBackend.wasapi => Platform.isWindows,
          AudioDeviceBackend.alsa => Platform.isLinux,
          AudioDeviceBackend.pulseAudio => Platform.isLinux,
          AudioDeviceBackend.jack => Platform.isLinux,
          AudioDeviceBackend.dummy => true,
        };
      }
    } else {
      for (final backend in AudioDeviceBackend.values) {
        backends[backend] = switch (backend) {
          AudioDeviceBackend.coreAudio => backendList.contains(AudioDeviceBackend.coreAudio),
          AudioDeviceBackend.aaudio => backendList.contains(AudioDeviceBackend.aaudio),
          AudioDeviceBackend.openSLES => backendList.contains(AudioDeviceBackend.openSLES),
          AudioDeviceBackend.wasapi => backendList.contains(AudioDeviceBackend.wasapi),
          AudioDeviceBackend.alsa => backendList.contains(AudioDeviceBackend.alsa),
          AudioDeviceBackend.pulseAudio => backendList.contains(AudioDeviceBackend.pulseAudio),
          AudioDeviceBackend.jack => backendList.contains(AudioDeviceBackend.jack),
          AudioDeviceBackend.dummy => true,
        };
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DEV_SETTING_BACKEND_APPBAR").tr(),
      ),
      body: ListView.builder(
        shrinkWrap: true,
        itemCount: AudioDeviceBackend.values.length + 1,
        itemBuilder: (context, index) {
          if(index != AudioDeviceBackend.values.length) {
            final backend = AudioDeviceBackend.values[index];
            return CheckboxListTile.adaptive(
              value: backends[backend],
              title: Text(
                switch (backend) {
                  AudioDeviceBackend.coreAudio => 'Core Audio',
                  AudioDeviceBackend.aaudio => 'AAudio',
                  AudioDeviceBackend.openSLES => 'OpenSL ES',
                  AudioDeviceBackend.wasapi => 'WASAPI',
                  AudioDeviceBackend.alsa => 'ALSA',
                  AudioDeviceBackend.pulseAudio => 'PulseAudio',
                  AudioDeviceBackend.jack => 'JACK',
                  AudioDeviceBackend.dummy => 'Dummy',
                },
              ),
              subtitle: Text(
                switch (backend) {
                  AudioDeviceBackend.coreAudio => 'macOS, iOS',
                  AudioDeviceBackend.aaudio => 'Android 8+',
                  AudioDeviceBackend.openSLES => 'Android 4.1+',
                  AudioDeviceBackend.wasapi => 'Windows Vista+',
                  AudioDeviceBackend.alsa => 'Linux',
                  AudioDeviceBackend.pulseAudio => 'Linux',
                  AudioDeviceBackend.jack => 'Linux',
                  AudioDeviceBackend.dummy => 'All platforms',
                },
              ),
              onChanged: (isChecked) {
                setState(() {
                  backends[backend] = isChecked!;
                });
              },
            );
          } else {
            return Container(height: 80);
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: backends.values.any((v) => v)
          ? () {
            // Apply Audio Backend API
            final AudioDeviceContext deviceContext;
            try {
              deviceContext = AudioDeviceContext(
                backends: backends.entries.where((e) => e.value).map((e) => e.key).toList(),
              );
            } on MaException catch (e) {
              switch (e.result) {
                case MaResult.noBackend:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("DEV_SETTING_BACKEND_SNACKBAR_ERROR").tr(),
                    ),
                  );
                default:
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
              return;
            }
            // Save Backend List
            backendList = backends.entries.where((e) => e.value).map((e) => e.key).toList();
            Hive.openBox<BackendData>(backendBoxName).then((backendBox) => {
              backendBox.put(backendKey, BackendData(backendList))
            });
            // Notify
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("DEV_SETTING_BACKEND_SNACKBAR_NOTIFY").tr(
                  namedArgs: {
                    "_BACKEND":
                    '\'${switch (deviceContext.activeBackend) {
                      AudioDeviceBackend.coreAudio => 'Core Audio',
                      AudioDeviceBackend.aaudio => 'AAudio',
                      AudioDeviceBackend.openSLES => 'OpenSL ES',
                      AudioDeviceBackend.wasapi => 'WASAPI',
                      AudioDeviceBackend.alsa => 'ALSA',
                      AudioDeviceBackend.pulseAudio => 'PulseAudio',
                      AudioDeviceBackend.jack => 'JACK',
                      AudioDeviceBackend.dummy => 'Dummy',
                    }}\''
                  }
                ),
              ),
            );
            App.of(context).applyAudioState(
              AudioState(
                backend: deviceContext.activeBackend,
                outputDevice: deviceContext.getDevices(AudioDeviceType.playback).where((d) => d.isDefault).firstOrNull,
              ),
            );
          }
          : null,
            child: const Icon(Icons.check),
      ),
    );
  }
}