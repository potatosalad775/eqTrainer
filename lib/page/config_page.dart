import 'package:flutter/material.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/widget/config_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cardTypeList = <ConfigCardType>[
      ConfigCardType.startingBand,
      ConfigCardType.gain,
      ConfigCardType.qFactor,
      ConfigCardType.filterType,
      ConfigCardType.threshold,
    ];

    return Container(
      constraints: const BoxConstraints.expand(),
      child: ListView.builder(
        itemCount: cardTypeList.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index < cardTypeList.length) {
            return ConfigCard(cardType: cardTypeList[index]);
          }
          return Padding(
            // Added another '40' bottom padding since main navigation bar is floating
            padding: const EdgeInsets.fromLTRB(13, 3, 13, 13 + 40),
            child: Row(
              spacing: 12,
              children: [
                IconButton(
                  onPressed: () {
                    try {
                      launchUrl(
                        Uri.parse("https://github.com/potatosalad775/eqTrainer/wiki/Tutorial"),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      throw Exception('could not launch url: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    fixedSize: const Size(70, 70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    Icons.help_outline,
                    size: 30,
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SessionPage(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.play_arrow,
                      size: 35,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    label: Text(
                      "CONFIG_BUTTON_START".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      fixedSize: const Size(double.infinity, 70),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}