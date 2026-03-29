import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/settings/widget/audio_import_format_card.dart';
import 'package:eq_trainer/features/settings/audio_backend_page.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';
import 'package:eq_trainer/features/settings/widget/volume_compensation_card.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';

class AudioSettingsPage extends StatefulWidget {
  const AudioSettingsPage({super.key});

  @override
  State<AudioSettingsPage> createState() => _AudioSettingsPageState();
}

class _AudioSettingsPageState extends State<AudioSettingsPage> {
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
              AudioImportFormatCard(onChanged: () => setState(() {})),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text("AUDIO_SETTING_IMPORT_FORMAT_DESC".tr()),
              ),
              if (savedMiscSettingsValue.importFormat == ImportFormat.keepOriginal)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Text("AUDIO_SETTING_IMPORT_FORMAT_ORIGINAL_WARN".tr(), style: TextStyle(color: context.colors.error)),
                ),
              const SizedBox(height: 12),
              const VolumeCompensationCard(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text("AUDIO_SETTING_CARD_VOLUME_COMP_DESC".tr()),
              ),
              const Divider(indent: 6, endIndent: 6, height: 32),
              // Developer Settings
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
          ),
        ),
      ),
    );
  }
}