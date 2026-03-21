import 'package:flutter/material.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/features/config/widget/config_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eq_trainer/features/session/session_page.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  static const _cardTypeList = <ConfigCardType>[
    ConfigCardType.startingBand,
    ConfigCardType.gain,
    ConfigCardType.qFactor,
    ConfigCardType.filterType,
    ConfigCardType.threshold,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: ListView.builder(
        itemCount: _cardTypeList.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index < _cardTypeList.length) {
            return ConfigCard(cardType: _cardTypeList[index]);
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(13, 3, 13, 13),
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
                    backgroundColor: context.colors.secondary,
                    fixedSize: const Size(70, 70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    Icons.help_outline,
                    size: 30,
                    color: context.colors.onSecondary,
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
                      color: context.colors.onPrimary,
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
                      backgroundColor: context.colors.primary,
                      foregroundColor: context.colors.onPrimary,
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