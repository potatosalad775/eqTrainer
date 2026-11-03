import 'package:eq_trainer/features/settings/audio_settings_page.dart';
import 'package:eq_trainer/shared/model/locale_provider.dart';
import 'package:eq_trainer/shared/model/misc_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
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
    final themeProvider = Provider.of<MiscSettingsProvider>(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      children: [
        // Language Drop Down Menu
        SettingsCard(
          icon: Icons.language,
          title: context.l10n.settingCardLangTitle,
          trailing: DropdownButton<Locale>(
            alignment: Alignment.centerRight,
            isDense: true,
            // The resolved locale, not the saved one: it is always one of the
            // items, even on a device language the app has no translation for.
            value: Localizations.localeOf(context),
            menuMaxHeight: 400,
            items: [
              for (final locale in AppLocalizations.supportedLocales)
                DropdownMenuItem(
                  value: locale,
                  child: Text(lookupAppLocalizations(locale).languageName),
                ),
            ],
            onChanged: (Locale? value) {
              context.read<LocaleProvider>().setLocale(value!);
            },
          ),
        ),
        // Dark Mode Button
        SettingsCard(
            icon: Icons.dark_mode,
            title: context.l10n.settingCardThemeTitle,
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
            title: context.l10n.settingCardAudioSettingTitle,
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
          title: context.l10n.settingCardGithubTitle,
          trailing: IconButton(
            icon: const Icon(Icons.launch),
            onPressed: () async {
              await launchURL(URLList.github);
            },
          ),
        ),
        // Contact Dev
        SettingsCard(
          icon: Icons.person,
          title: context.l10n.settingCardContactTitle,
          trailing: Wrap(
            children: [
              IconButton(
                icon: const Icon(Icons.mail),
                onPressed: () async {
                  await launchURL(URLList.mail);
                },
              ),
            ],
          ),
        ),
        // Open Source License Card
        SettingsCard(
          icon: Icons.code,
          title: context.l10n.settingCardLicenseTitle,
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

Future<void> launchURL(URLList urlList) async {
  final launched = await launchUrl(Uri.parse(urlList.url), mode: LaunchMode.externalApplication);
  if (!launched) {
    throw Exception('could not launch url: ${urlList.url}');
  }
}