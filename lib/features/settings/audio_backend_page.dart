import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:eq_trainer/l10n/l10n.dart';
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

String _backendName(AppLocalizations l10n, AndroidAudioBackend backend) => switch (backend) {
  AndroidAudioBackend.auto     => l10n.audioSettingBackendAuto,
  AndroidAudioBackend.aaudio   => 'AAudio',
  AndroidAudioBackend.openSles => 'OpenSL ES',
};

String _backendDescription(AppLocalizations l10n, AndroidAudioBackend backend) => switch (backend) {
  AndroidAudioBackend.auto     => l10n.audioSettingBackendAutoDesc,
  AndroidAudioBackend.aaudio   => l10n.audioSettingBackendAaudioDesc,
  AndroidAudioBackend.openSles => l10n.audioSettingBackendOpenslesDesc,
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
        content: Text(context.l10n.audioSettingBackendSnackbarNotify(
          backend: _backendName(context.l10n, _selected),
        )),
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
        title: Text(context.l10n.audioSettingBackendAppbar),
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
                        title: Text(_backendName(context.l10n, backend)),
                        subtitle: Text(_backendDescription(context.l10n, backend)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.padding),
                child: Text(context.l10n.audioSettingBackendRestartNote),
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
