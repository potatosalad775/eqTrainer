import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
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
  List<PlaybackDevice> _devices = [];

  // No cached device context to own any more: SoLoud enumerates devices
  // without creating one, so the coast_audio dance of holding a context alive
  // (and disposing it so it couldn't collide with the playback context) is
  // gone along with it.
  void _refreshDeviceList() {
    try {
      _devices = SoLoud.instance.listPlaybackDevices();
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

    // Ensure device list includes the current output device. Match by id,
    // not name: two DACs can share a display name, and matching by name
    // could pick the wrong one or leave the dropdown's value unmatched.
    if (audioState.outputDevice != null &&
        !_devices.any((d) => d.id == audioState.outputDevice!.id)) {
      _refreshDeviceList();
    }

    // Only pass a value the dropdown actually has a matching item for.
    // Otherwise a stale/disconnected selection trips DropdownButton's
    // "exactly one matching item" assertion and crashes the page.
    final currentId = audioState.outputDevice?.id;
    final selectedValue =
        (currentId != null && _devices.any((d) => d.id == currentId)) ? currentId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            const Icon(Icons.headphones),
            const SizedBox(width: 16),
            Expanded(
              child: RepaintBoundary(
                child: DropdownButton<int>(
                  items: _devices.map((e) =>
                    DropdownMenuItem<int>(
                      value: e.id,
                      child: Text(
                        e.name,
                        maxLines: 1,
                      ),
                    )).toList(),
                  isExpanded: true,
                  value: selectedValue,
                  onChanged: (deviceId) {
                    final device = _devices
                        .where((d) => d.id == deviceId)
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
