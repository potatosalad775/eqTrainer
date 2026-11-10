import 'package:eq_trainer/data/output_selection.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An [OutputDevices] that lists nothing, so [OutputSelection.device] is null
/// and the engine opens the OS default, as the suites did before the selection
/// existed. The backend is whatever the platform's default is.
class _NoDevices implements OutputDevices {
  const _NoDevices();

  @override
  List<PlaybackDevice> list() => const [];
}

/// The output selection the player suites hand to `PlayerService`.
Future<OutputSelection> testOutputSelection() async {
  SharedPreferences.setMockInitialValues({});
  return OutputSelection(
    prefs: await SharedPreferences.getInstance(),
    devices: const _NoDevices(),
  );
}
