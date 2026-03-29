import 'package:eq_trainer/features/settings/audio_settings_page.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';
import 'package:eq_trainer/features/settings/widget/freq_tooltip_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      children: [
        // Language Drop Down Menu
        SettingsCard(
          icon: Icons.language,
          title: "SETTING_CARD_LANG_TITLE".tr(),
          trailing: DropdownButton(
            alignment: Alignment.centerRight,
            isDense: true,
            value: context.locale.toStringWithSeparator(),
            menuMaxHeight: 400,
            items: <String>['en', 'ko'].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                  value: value,
                  child: (value == 'en') ? const Text("English")
                      : (value == 'ko') ? const Text("한국어")
                      : const Text('')
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                context.setLocale(value!.toLocale());
              });
            },
          ),
        ),
        // Dark Mode Button
        SettingsCard(
            icon: Icons.dark_mode,
            title: "SETTING_CARD_THEME_TITLE".tr(),
            trailing: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                  (themeProvider.themeMode == ThemeMode.system)
                      ? Icons.brightness_auto
                      : (themeProvider.themeMode == ThemeMode.light)
                      ? Icons.brightness_high
                      : Icons.brightness_4
              ),
              onPressed: () {
                themeProvider.toggleTheme();
              },
            )
        ),
        // Misc Settings
        const FrequencyTooltipCard(),
        const Divider(
          indent: 8,
          endIndent: 8,
        ),
        // Audio Settings
        GestureDetector(
          child: SettingsCard(
            icon: Icons.build,
            title: "SETTING_CARD_AUDIO_SETTING_TITLE".tr(),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AudioSettingsPage())
            );
          },
        ),
        const Divider(
          indent: 8,
          endIndent: 8,
        ),
        // Github Project Button
        SettingsCard(
          icon: FontAwesomeIcons.github,
          title: "SETTING_CARD_GITHUB_TITLE".tr(),
          trailing: IconButton(
            icon: const Icon(Icons.launch),
            onPressed: () {
              launchURL(URLList.github);
            },
          ),
        ),
        // Contact Dev
        SettingsCard(
          icon: Icons.person,
          title: "SETTING_CARD_CONTACT_TITLE".tr(),
          trailing: Wrap(
            children: [
              IconButton(
                icon: const Icon(Icons.mail),
                onPressed: () {
                  launchURL(URLList.mail);
                },
              ),
            ],
          ),
        ),
        // Open Source License Card
        SettingsCard(
          icon: Icons.code,
          title: "SETTING_CARD_LICENSE_TITLE".tr(),
          trailing: IconButton(
            icon: const Icon(Icons.launch),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LicensePage()));
            },
          ),
        ),
        // Version Info
        const Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project eqTrainer',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15
                ),
              ),
              SizedBox(height: 3,),
              Text(
                'Powered by Flutter & Open-source Community',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 13
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

enum URLList {
  github(url: "https://github.com/potatosalad775/eq_trainer"),
  mail(url: "mailto:transaction@kakao.com"),
  release(url: "https://github.com/potatosalad775/eq_trainer/releases/latest")
  ;

  final String url;

  const URLList({
    required this.url,
  });
}

void launchURL(URLList urlList) {
  try {
    launchUrl(Uri.parse(urlList.url), mode: LaunchMode.externalApplication);
  } catch (e) {
    throw Exception('could not launch url: $e');
  }
}