import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/settings/widget/audio_import_format_card.dart';
import 'package:eq_trainer/features/settings/widget/clip_recompress_card.dart';
import 'package:eq_trainer/features/settings/audio_backend_page.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';
import 'package:eq_trainer/features/settings/widget/volume_compensation_card.dart';
import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:flutter/material.dart';

class AudioSettingsPage extends StatelessWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AUDIO_SETTING_APPBAR_TITLE".tr()),
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
                child: Text("AUDIO_SETTING_IMPORT_FORMAT_DESC_1".tr()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text("AUDIO_SETTING_IMPORT_FORMAT_DESC_2".tr()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text("AUDIO_SETTING_IMPORT_FORMAT_DESC_3".tr()),
              ),
              const SizedBox(height: 12),
              // Renders nothing when the library holds no WAV clips, so this
              // costs an empty box rather than a dead button.
              const ClipRecompressCard(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text("AUDIO_SETTING_RECOMPRESS_DESC".tr()),
              ),
              const SizedBox(height: 12),
              const VolumeCompensationCard(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text("AUDIO_SETTING_CARD_VOLUME_COMP_DESC".tr()),
              ),
              // Android only: SoLoud picks the backend itself on every other
              // platform and gives Dart no way to override it (Windows and
              // Linux never create an explicit miniaudio context at all), so
              // there would be nothing behind this card to choose.
              if (Platform.isAndroid) ...[
                const Divider(indent: 6, endIndent: 6, height: 32),
                GestureDetector(
                  child: SettingsCard(
                    icon: Icons.build,
                    title: "AUDIO_SETTING_CARD_BACKEND_TITLE".tr(),
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
                  child: Text("AUDIO_SETTING_CARD_BACKEND_DESC".tr()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}