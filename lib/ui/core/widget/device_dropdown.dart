import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart' show PlaybackDevice;
import 'package:provider/provider.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/l10n/l10n.dart';

class DeviceDropdown extends StatefulWidget {
  const DeviceDropdown({super.key});

  @override
  State<DeviceDropdown> createState() => _DeviceDropdownState();
}

class _DeviceDropdownState extends State<DeviceDropdown> {
  List<PlaybackDevice> _devices = [];

  // Keeps the existing list if enumeration fails: availableDevices() returns
  // the last one it got.
  void _refreshDeviceList(OutputSelection selection) {
    _devices = selection.availableDevices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshDeviceList(context.read<OutputSelection>());
  }

  @override
  Widget build(BuildContext context) {
    final selection = context.watch<OutputSelection>();

    // Ensure device list includes the current output device. Match by id,
    // not name: two DACs can share a display name, and matching by name
    // could pick the wrong one or leave the dropdown's value unmatched.
    if (selection.device != null &&
        !_devices.any((d) => d.id == selection.device!.id)) {
      _refreshDeviceList(selection);
    }

    // Only pass a value the dropdown actually has a matching item for.
    // Otherwise a stale/disconnected selection trips DropdownButton's
    // "exactly one matching item" assertion and crashes the page.
    final currentId = selection.device?.id;
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
                    selection.selectDevice(device);
                  },
                ),
              ),
            ),
          ],
        ),
        Text(context.l10n.sessionDdbuttonDeviceDisclaimer)
      ],
    );
  }
}
