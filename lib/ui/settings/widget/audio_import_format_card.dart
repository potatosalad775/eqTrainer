import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/domain/audio_format_helper.dart';
import 'package:eq_trainer/ui/settings/widget/settings_card.dart';

class AudioImportFormatCard extends StatelessWidget {
  const AudioImportFormatCard({super.key});

  /// Label for each offered format. Kept beside [ImportFormat.selectable]
  /// so a value can never be offered without a string to show for it.
  static final _labels = <int, String Function(AppLocalizations)>{
    ImportFormat.smart: (l10n) => l10n.audioSettingImportFormatSmart,
    ImportFormat.allFlac: (l10n) => l10n.audioSettingImportFormatFlac,
    ImportFormat.allOpus: (l10n) => l10n.audioSettingImportFormatOpus,
    ImportFormat.allWav: (l10n) => l10n.audioSettingImportFormatWav,
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
      title: context.l10n.audioSettingCardImportFormatTitle,
      trailing: DropdownButton<int>(
        alignment: Alignment.centerRight,
        isDense: true,
        value: selected,
        items: [
          for (final format in ImportFormat.selectable)
            DropdownMenuItem(
              value: format,
              child: Text(_labels[format]!(context.l10n)),
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
