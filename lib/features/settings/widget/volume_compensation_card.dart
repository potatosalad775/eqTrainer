import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';
import 'package:hive_ce/hive.dart';

class VolumeCompensationCard extends StatefulWidget {
  const VolumeCompensationCard({super.key});

  @override
  State<VolumeCompensationCard> createState() => _VolumeCompensationCardState();
}

class _VolumeCompensationCardState extends State<VolumeCompensationCard> {
  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Icons.volume_up,
      title: "AUDIO_SETTING_CARD_VOLUME_COMP_TITLE".tr(),
      trailing: Switch(
        value: savedMiscSettingsValue.volumeCompensation,
        onChanged: (bool value) {
          setState(() {
            savedMiscSettingsValue.volumeCompensation = value;
            Hive.box<MiscSettings>(miscSettingsBoxName).put(
              miscSettingsKey,
              savedMiscSettingsValue.copyWith(inputVolumeCompensation: value),
            );
          });
        },
      ),
    );
  }
}
