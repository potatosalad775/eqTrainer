import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FrequencyTooltipCard extends StatelessWidget {
  const FrequencyTooltipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final frequencyToolTip = context.watch<MiscSettingsProvider>().frequencyToolTip;
    return SettingsCard(
      icon: FontAwesomeIcons.message,
      title: "MISC_SETTING_CARD_TOOLTIP_TITLE".tr(),
      trailing: Switch(
        value: frequencyToolTip,
        onChanged: (bool value) {
          context.read<MiscSettingsProvider>().setFrequencyToolTip(value);
        },
      ),
    );
  }
}
