import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsCard extends StatelessWidget {
  final SettingsCardType cardInfo;
  final Widget trailing;
  const SettingsCard({super.key, required this.cardInfo, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          horizontalTitleGap: 0,
          leading: FaIcon(
            getIcon(cardInfo),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            getTitle(cardInfo),
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: trailing,
        ),
      ),
    );
  }

  IconData getIcon(SettingsCardType cardInfo) {
    if (cardInfo == SettingsCardType.darkmode) { return Icons.dark_mode; }
    else if (cardInfo == SettingsCardType.language) { return Icons.language; }
    else if (cardInfo == SettingsCardType.github) { return FontAwesomeIcons.github; }
    else if (cardInfo == SettingsCardType.contact) { return Icons.person; }
    else if (cardInfo == SettingsCardType.devSetting) { return Icons.developer_mode; }
    else if (cardInfo == SettingsCardType.license) { return Icons.code; }
    else if (cardInfo == SettingsCardType.androidBackend) { return Icons.android; }
    else { return Icons.question_mark; }
  }

  String getTitle(SettingsCardType cardInfo) {
    if (cardInfo == SettingsCardType.darkmode) { return "SETTING_CARD_THEME_TITLE".tr(); }
    else if (cardInfo == SettingsCardType.language) { return "SETTING_CARD_LANG_TITLE".tr(); }
    else if (cardInfo == SettingsCardType.github) { return "SETTING_CARD_GITHUB_TITLE".tr(); }
    else if (cardInfo == SettingsCardType.contact) { return "SETTING_CARD_CONTACT_TITLE".tr(); }
    else if (cardInfo == SettingsCardType.devSetting) { return "SETTING_CARD_DEV_SETTING_TITLE".tr(); }
    else if (cardInfo == SettingsCardType.license) { return "SETTING_CARD_LICENSE_TITLE".tr(); }
    else if (cardInfo == SettingsCardType.androidBackend) { return "DEV_SETTING_CARD_BACKEND_TITLE".tr(); }
    else { return "?"; }
  }
}

enum SettingsCardType { darkmode, language, github, contact, devSetting, license, androidBackend }