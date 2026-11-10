import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/ui/settings/widget/settings_card.dart';

class VolumeCompensationCard extends StatelessWidget {
  const VolumeCompensationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final volumeCompensation = context.watch<MiscSettingsProvider>().volumeCompensation;
    return SettingsCard(
      icon: Icons.volume_up,
      title: context.l10n.audioSettingCardVolumeCompTitle,
      trailing: Switch(
        value: volumeCompensation,
        onChanged: (bool value) {
          context.read<MiscSettingsProvider>().setVolumeCompensation(value);
        },
      ),
    );
  }
}
