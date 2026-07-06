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
    return SettingsCard(
      icon: Icons.audio_file,
      title: "AUDIO_SETTING_CARD_IMPORT_FORMAT_TITLE".tr(),
      trailing: DropdownButton<int>(
        alignment: Alignment.centerRight,
        isDense: true,
        value: importFormat,
        items: [
          DropdownMenuItem(
            value: ImportFormat.smart,
            child: Text("AUDIO_SETTING_IMPORT_FORMAT_SMART".tr()),
          ),
          DropdownMenuItem(
            value: ImportFormat.allM4a,
            child: Text("AUDIO_SETTING_IMPORT_FORMAT_M4A".tr()),
          ),
          DropdownMenuItem(
            value: ImportFormat.allWav,
            child: Text("AUDIO_SETTING_IMPORT_FORMAT_WAV".tr()),
          ),
          DropdownMenuItem(
            value: ImportFormat.keepOriginal,
            child: Text("AUDIO_SETTING_IMPORT_FORMAT_ORIGINAL".tr()),
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
