import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/ui/settings/widget/settings_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FrequencyTooltipCard extends StatelessWidget {
  const FrequencyTooltipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final frequencyToolTip = context.watch<MiscSettingsProvider>().frequencyToolTip;
    return SettingsCard(
      icon: FontAwesomeIcons.message,
      title: context.l10n.miscSettingCardTooltipTitle,
      trailing: Switch(
        value: frequencyToolTip,
        onChanged: (bool value) {
          context.read<MiscSettingsProvider>().setFrequencyToolTip(value);
        },
      ),
    );
  }
}
