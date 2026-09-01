import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';

class AudioImportFormatCard extends StatelessWidget {
  const AudioImportFormatCard({super.key});

  @override
  Widget build(BuildContext context) {
    final importFormat = context.watch<MiscSettingsProvider>().importFormat;
    // AAC and Keep-Original are retired (see ImportFormat); both now behave as
    // Smart. Show them as Smart rather than leaving the dropdown with a value
    // no item matches, which trips its "exactly one matching item" assertion.
    final selected = importFormat == ImportFormat.allWav
        ? ImportFormat.allWav
        : ImportFormat.smart;
    return SettingsCard(
      icon: Icons.audio_file,
      title: "AUDIO_SETTING_CARD_IMPORT_FORMAT_TITLE".tr(),
      trailing: DropdownButton<int>(
        alignment: Alignment.centerRight,
        isDense: true,
        value: selected,
        items: [
          DropdownMenuItem(
            value: ImportFormat.smart,
            child: Text("AUDIO_SETTING_IMPORT_FORMAT_SMART".tr()),
          ),
          DropdownMenuItem(
            value: ImportFormat.allWav,
            child: Text("AUDIO_SETTING_IMPORT_FORMAT_WAV".tr()),
          ),
        ],
        onChanged: (int? value) {
          if (value == null) return;
          context.read<MiscSettingsProvider>().setImportFormat(value);
        },
      ),
    );
  }
}
