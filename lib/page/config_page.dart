import 'package:flutter/material.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/widget/config_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(5),
      children: [
        const ConfigCard(cardType: ConfigCardType.startingBand),
        const ConfigCard(cardType: ConfigCardType.gain),
        const ConfigCard(cardType: ConfigCardType.qFactor),
        const ConfigCard(cardType: ConfigCardType.filterType),
        const ConfigCard(cardType: ConfigCardType.threshold),
        // Button Row
        Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  try {
                    launchUrl(Uri.parse("https://github.com/potatosalad775/eqTrainer/wiki/Tutorial"), mode: LaunchMode.externalApplication);
                  } catch (e) {
                    throw Exception('could not launch url: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  minimumSize: const Size(75, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  )
                ),
                child: Icon(
                  Icons.help_outline,
                  size: 30,
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SessionPage()));
                  },
                  icon: const Icon(
                    Icons.play_arrow,
                    size: 35,
                  ),
                  label: Text(
                    "CONFIG_BUTTON_START".tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(75, 75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              ),
            ],
          ),
        )
      ],
    );
  }
}