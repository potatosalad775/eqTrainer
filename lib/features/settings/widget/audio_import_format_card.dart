import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';

class AudioImportFormatCard extends StatelessWidget {
  const AudioImportFormatCard({super.key});

  /// Label key for each offered format. Kept beside [ImportFormat.selectable]
  /// so a value can never be offered without a string to show for it.
  static const _labelKeys = {
    ImportFormat.smart: "AUDIO_SETTING_IMPORT_FORMAT_SMART",
    ImportFormat.allFlac: "AUDIO_SETTING_IMPORT_FORMAT_FLAC",
    ImportFormat.allOpus: "AUDIO_SETTING_IMPORT_FORMAT_OPUS",
    ImportFormat.allWav: "AUDIO_SETTING_IMPORT_FORMAT_WAV",
  };

  @override
  Widget build(BuildContext context) {
    final importFormat = context.watch<MiscSettingsProvider>().importFormat;
    // AAC and Keep-Original are retired (see ImportFormat) and both behave as
    // Smart. Normalizing here keeps the dropdown from being handed a value no
    // item matches, which trips its "exactly one matching item" assertion.
    final selected = ImportFormat.normalize(importFormat);

    return SettingsCard(
      icon: Icons.audio_file,
      title: "AUDIO_SETTING_CARD_IMPORT_FORMAT_TITLE".tr(),
      trailing: DropdownButton<int>(
        alignment: Alignment.centerRight,
        isDense: true,
        value: selected,
        items: [
          for (final format in ImportFormat.selectable)
            DropdownMenuItem(
              value: format,
              child: Text(_labelKeys[format]!.tr()),
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
