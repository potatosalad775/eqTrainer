import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:eq_trainer/widget/settings_card.dart';
import 'package:eq_trainer/page/dev_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    var themeMode = EasyDynamicTheme.of(context).themeMode;
    return ListView(
      padding: const EdgeInsets.all(5),
      children: [
        //
        // Language Drop Down Menu
        //
        SettingsCard(
          cardInfo: SettingsCardType.language,
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
        //
        // Dark Mode Button
        //
        SettingsCard(
            cardInfo: SettingsCardType.darkmode,
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
        //
        // Github Project Button
        //
        SettingsCard(
          cardInfo: SettingsCardType.github,
          trailing: IconButton(
            icon: const Icon(Icons.launch),
            onPressed: () {
              launchURL(URLList.github);
            },
          ),
        ),
        //
        // Contact Dev
        //
        SettingsCard(
          cardInfo: SettingsCardType.contact,
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
        //
        // Developer Settings
        //
        SettingsCard(
          cardInfo: SettingsCardType.devSetting,
          trailing: IconButton(
            icon: const Icon(Icons.keyboard_arrow_right),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevSettingsPage()));
            },
          ),
        ),
        //
        // Open Source License Card
        //
        SettingsCard(
          cardInfo: SettingsCardType.license,
          trailing: IconButton(
            icon: const Icon(Icons.launch),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LicensePage()));
            },
          ),
        ),
        //
        // Version Info
        //
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
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 3,),
              Text(
                'Powered by Flutter & Open-source Community',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum URLList {
  github(url: "https://github.com/potatosalad775"),
  mail(url: "mailto:transaction@kakao.com"),
  release(url: "https://github.com/potatosalad775/eq_trainer/release/latest")
  ;

  final String url;

  const URLList({
    required this.url,
  });
}

Future<void> launchURL(URLList urlList) async {
  if(!await launchUrl(Uri.parse(urlList.url), mode: LaunchMode.externalApplication)) {
    throw Exception('could not launch url');
  }
}