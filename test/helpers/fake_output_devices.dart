import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:eq_trainer/data/output_selection.dart';

/// A `PlaybackDevice` without an engine. Its constructor is internal to
/// flutter_soloud, which only the plugin itself is meant to call.
PlaybackDevice playbackDevice(int id, String name, {bool isDefault = false}) =>
    // ignore: invalid_use_of_internal_member
    PlaybackDevice(id, isDefault, name);

/// The device list an `OutputSelection` reads, set by the test. Set [error] to
/// make enumeration fail.
class FakeOutputDevices implements OutputDevices {
  FakeOutputDevices([this.devices = const []]);

  List<PlaybackDevice> devices;
  Object? error;

  @override
  List<PlaybackDevice> list() {
    if (error != null) throw error!;
    return devices;
  }
}
