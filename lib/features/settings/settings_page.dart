import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:eq_trainer/features/settings/widget/settings_card.dart';
import 'package:eq_trainer/features/settings/widget/freq_tooltip_card.dart';
import 'package:eq_trainer/features/settings/widget/dev_backend_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    var themeMode = EasyDynamicTheme.of(context).themeMode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
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
                  (themeMode == ThemeMode.system)
                      ? Icons.brightness_auto
                      : (themeMode == ThemeMode.light)
                      ? Icons.brightness_high
                      : Icons.brightness_4
              ),
              onPressed: () {
                EasyDynamicTheme.of(context).changeTheme();
              },
            )
        ),
        const Divider(
          indent: 8,
          endIndent: 8,
        ),
        // Misc Settings
        const FrequencyTooltipCard(),
        // Developer Settings
        GestureDetector(
          child: SettingsCard(
            icon: Icons.build,
            title: "DEV_SETTING_CARD_BACKEND_TITLE".tr(),
            trailing: const Icon(Icons.keyboard_arrow_right),
          ),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevBackendPage()));
          },
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Center(child: const Text("DEV_SETTING_CARD_BACKEND_DESC").tr()),
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
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project eqTrainer',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 3,),
              Text(
                'Powered by Flutter & Open-source Community',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        // Added another '40' bottom padding since main navigation bar is floating
        SizedBox(height: 40),
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