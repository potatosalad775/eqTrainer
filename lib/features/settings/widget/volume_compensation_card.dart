import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';

class VolumeCompensationCard extends StatelessWidget {
  const VolumeCompensationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final volumeCompensation = context.watch<MiscSettingsProvider>().volumeCompensation;
    return SettingsCard(
      icon: Icons.volume_up,
      title: "AUDIO_SETTING_CARD_VOLUME_COMP_TITLE".tr(),
      trailing: Switch(
        value: volumeCompensation,
        onChanged: (bool value) {
          context.read<MiscSettingsProvider>().setVolumeCompensation(value);
        },
      ),
    );
  }
}
