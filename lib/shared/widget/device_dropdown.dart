import 'package:flutter/material.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:easy_localization/easy_localization.dart';

class DeviceDropdown extends StatefulWidget {
  const DeviceDropdown({super.key});

  @override
  State<DeviceDropdown> createState() => _DeviceDropdownState();
}

class _DeviceDropdownState extends State<DeviceDropdown> {
  List<AudioDeviceInfo> _devices = [];

  void _refreshDeviceList() {
    final audioState = Provider.of<AudioState>(context, listen: false);
    try {
      final deviceContext = AudioDeviceContext(backends: [audioState.backend]);
      _devices = deviceContext.getDevices(AudioDeviceType.playback);
    } catch (_) {
      // Keep existing list if enumeration fails.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshDeviceList();
  }

  @override
  Widget build(BuildContext context) {
    final audioState = context.watch<AudioState>();

    // Ensure device list includes the current output device.
    if (audioState.outputDevice != null &&
        !_devices.any((d) => d.name == audioState.outputDevice!.name)) {
      _refreshDeviceList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            const Icon(Icons.headphones),
            const SizedBox(width: 16),
            Expanded(
              child: RepaintBoundary(
                child: DropdownButton<String>(
                  items: _devices.map((e) => e.name).map((e) =>
                    DropdownMenuItem<String>(
                      value: e,
                      child: Text(
                        e,
                        maxLines: 1,
                      ),
                    )).toList(),
                  isExpanded: true,
                  value: audioState.outputDevice?.name,
                  onChanged: (deviceName) {
                    final device = _devices
                        .where((d) => d.name == deviceName)
                        .firstOrNull;
                    if (device == null) return;
                    audioState.userSelectedDevice = true;
                    App.of(context).applyAudioState(
                      audioState.copyWith(
                        outputDevice: device,
                        userSelectedDevice: true,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const Text("SESSION_DDBUTTON_DEVICE_DISCLAIMER").tr()
      ],
    );
  }
}
