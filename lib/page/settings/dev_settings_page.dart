import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/widget/settings_card.dart';
import 'package:eq_trainer/page/settings/dev_backend_page.dart';

class DevSettingsPage extends StatelessWidget {
  const DevSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DEV_SETTING_APPBAR_TITLE").tr(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(5),
        children: [
          Column(
            children: [
              GestureDetector(
                child: SettingsCard(
                  icon: Icons.build,
                  title: "DEV_SETTING_CARD_BACKEND_TITLE".tr(),
                  trailing: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_right),
                    onPressed: () {},
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevBackendPage()));
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: const Text("DEV_SETTING_CARD_BACKEND_DESC").tr(),
              )
            ],
          )
        ],
      ),
    );
  }
}