import 'package:flutter/material.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:easy_localization/easy_localization.dart';

class DeviceDropdown extends StatelessWidget {
  const DeviceDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final audioState = Provider.of<AudioState>(context, listen: false);
    late final deviceContext = AudioDeviceContext(backends: [audioState.backend]);
    late final devices = deviceContext.getDevices(AudioDeviceType.playback);

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
                  items: devices.map((e) => e.name).map((e) =>
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
                    final audioState = Provider.of<AudioState>(context, listen: false);
                    App.of(context).applyAudioState(
                      audioState.copyWith(outputDevice: devices.firstWhere((device) => device.name == deviceName))
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
