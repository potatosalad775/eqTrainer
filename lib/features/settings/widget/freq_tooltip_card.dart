import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive_ce/hive.dart';

class FrequencyTooltipCard extends StatefulWidget {
  const FrequencyTooltipCard({super.key});

  @override
  State<FrequencyTooltipCard> createState() => _FrequencyTooltipCardState();
}

class _FrequencyTooltipCardState extends State<FrequencyTooltipCard> {
  late final Box<MiscSettings> miscSettingsBox;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load Miscellaneous Settings
    miscSettingsBox = await Hive.openBox<MiscSettings>(miscSettingsBoxName);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: FontAwesomeIcons.message,
      title: "MISC_SETTING_CARD_TOOLTIP_TITLE".tr(),
      trailing: Switch(
        value: savedMiscSettingsValue.frequencyToolTip,
        onChanged: (bool value) {
          setState(() {
            savedMiscSettingsValue.frequencyToolTip = value;
            miscSettingsBox.put(
              miscSettingsKey,
              savedMiscSettingsValue.copyWith(
                inputFrequencyToolTip: value,
              )
            );
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    miscSettingsBox.close();
  }
}