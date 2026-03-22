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
  late AudioDeviceContext _deviceContext;
  late List<AudioDeviceInfo> _devices;

  @override
  void initState() {
    super.initState();
    final audioState = Provider.of<AudioState>(context, listen: false);
    _deviceContext = AudioDeviceContext(backends: [audioState.backend]);
    _devices = _deviceContext.getDevices(AudioDeviceType.playback);
  }

  @override
  Widget build(BuildContext context) {
    final audioState = Provider.of<AudioState>(context, listen: false);

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
                    App.of(context).applyAudioState(
                      audioState.copyWith(outputDevice: device),
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
