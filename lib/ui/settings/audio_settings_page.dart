import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/settings/widget/audio_import_format_card.dart';
import 'package:eq_trainer/ui/settings/widget/clip_recompress_card.dart';
import 'package:eq_trainer/ui/settings/audio_backend_page.dart';
import 'package:eq_trainer/ui/settings/widget/settings_card.dart';
import 'package:eq_trainer/ui/settings/widget/volume_compensation_card.dart';
import 'package:eq_trainer/ui/core/app_dimens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AudioSettingsPage extends StatelessWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.audioSettingAppbarTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.maxWidgetWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              const AudioImportFormatCard(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text(context.l10n.audioSettingImportFormatDesc1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text(context.l10n.audioSettingImportFormatDesc2),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text(context.l10n.audioSettingImportFormatDesc3),
              ),
              // Renders nothing, description and spacing included, when the
              // library holds no WAV clips.
              const ClipRecompressCard(),
              const SizedBox(height: 12),
              const VolumeCompensationCard(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text(context.l10n.audioSettingCardVolumeCompDesc),
              ),
              // Android only: SoLoud picks the backend itself on every other
              // platform and gives Dart no way to override it (Windows and
              // Linux never create an explicit miniaudio context at all), so
              // there would be nothing behind this card to choose.
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                const Divider(indent: 6, endIndent: 6, height: 32),
                GestureDetector(
                  child: SettingsCard(
                    icon: Icons.build,
                    title: context.l10n.audioSettingCardBackendTitle,
                    trailing: const Icon(Icons.keyboard_arrow_right),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AudioBackendPage())
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Text(context.l10n.audioSettingCardBackendDesc),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}