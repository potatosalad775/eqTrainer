import 'package:eq_trainer/model/session/session_parameter.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/widget/config_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionParameter = SessionParameter();
    final cardTypeList = [
      ConfigCardType.startingBand,
      ConfigCardType.gain,
      ConfigCardType.qFactor,
      ConfigCardType.filterType,
      ConfigCardType.threshold,
    ];

    return ChangeNotifierProvider<SessionParameter>.value(
      value: sessionParameter,
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(5),
        itemCount: cardTypeList.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if(index != cardTypeList.length) {
            return ConfigCard(cardType: cardTypeList[index]);
          } else {
            return Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      try {
                        launchUrl(
                            Uri.parse("https://github.com/potatosalad775/eqTrainer/wiki/Tutorial"),
                            mode: LaunchMode.externalApplication
                        );
                      } catch (e) {
                        throw Exception('could not launch url: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        fixedSize: const Size(75, 75),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        )
                    ),
                    icon: Icon(
                      Icons.help_outline,
                      size: 30,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ChangeNotifierProvider<SessionParameter>.value(
                              value: sessionParameter,
                              builder: (context, child) => const SessionPage(),
                            )
                        ));
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
                            fontWeight: FontWeight.bold
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        fixedSize: const Size(double.infinity, 75),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}