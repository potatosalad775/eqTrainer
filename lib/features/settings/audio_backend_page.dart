import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';

/// Picks the native backend the engine opens the Android output device with.
///
/// Android-only, and reached only from a card that is itself hidden elsewhere
/// (see `audio_settings_page.dart`). Under coast_audio this page offered every
/// platform's backends as a checklist because coast_audio required an explicit
/// list; SoLoud chooses on its own everywhere except Android, where the choice
/// genuinely matters — see [AndroidAudioBackend].
class AudioBackendPage extends StatefulWidget {
  const AudioBackendPage({super.key});

  @override
  State<AudioBackendPage> createState() => _AudioBackendPageState();
}

String _backendName(AndroidAudioBackend backend) => switch (backend) {
  AndroidAudioBackend.auto     => 'AUDIO_SETTING_BACKEND_AUTO'.tr(),
  AndroidAudioBackend.aaudio   => 'AAudio',
  AndroidAudioBackend.openSles => 'OpenSL ES',
};

String _backendDescription(AndroidAudioBackend backend) => switch (backend) {
  AndroidAudioBackend.auto     => 'AUDIO_SETTING_BACKEND_AUTO_DESC'.tr(),
  AndroidAudioBackend.aaudio   => 'AUDIO_SETTING_BACKEND_AAUDIO_DESC'.tr(),
  AndroidAudioBackend.openSles => 'AUDIO_SETTING_BACKEND_OPENSLES_DESC'.tr(),
};

class _AudioBackendPageState extends State<AudioBackendPage> {
  late AndroidAudioBackend _selected;

  @override
  void initState() {
    super.initState();
    _selected = androidBackendFromSavedList(backendList);
  }

  Future<void> _apply() async {
    // Keep whatever output device is in effect: this page only changes which
    // API opens it, and dropping the selection here would silently undo the
    // user's choice in the device dropdown.
    final outputDevice = context.read<AudioState>().outputDevice;
    final saved = savedListForAndroidBackend(_selected);
    final backendBox = await Hive.openBox<BackendData>(backendBoxName);
    await backendBox.put(backendKey, BackendData(saved));

    if (!mounted) return;
    // The engine reads the backend at init only, so a change taken now would
    // not reach an already-running engine. Say so rather than implying the
    // switch happened.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("AUDIO_SETTING_BACKEND_SNACKBAR_NOTIFY").tr(
          namedArgs: {"_BACKEND": _backendName(_selected)},
        ),
      ),
    );
    App.of(context).applyAudioState(
      AudioState(
        androidBackend: _selected,
        outputDevice: outputDevice,
      ),
      savedBackendList: saved,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AUDIO_SETTING_BACKEND_APPBAR").tr(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.maxWidgetWidth),
          child: ListView(
            children: [
              RadioGroup<AndroidAudioBackend>(
                groupValue: _selected,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selected = value);
                },
                child: Column(
                  children: [
                    for (final backend in AndroidAudioBackend.values)
                      RadioListTile<AndroidAudioBackend>.adaptive(
                        value: backend,
                        title: Text(_backendName(backend)),
                        subtitle: Text(_backendDescription(backend)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.padding),
                child: const Text("AUDIO_SETTING_BACKEND_RESTART_NOTE").tr(),
              ),
              Container(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _apply,
        child: const Icon(Icons.check),
      ),
    );
  }
}
