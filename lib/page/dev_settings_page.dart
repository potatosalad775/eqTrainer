import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/setting_data.dart';
import 'package:eq_trainer/widget/settings_card.dart';
import 'package:hive/hive.dart';

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
              SettingsCard(
                cardInfo: SettingsCardType.androidBackend,
                trailing: DropdownButton(
                  alignment: Alignment.centerRight,
                  isDense: true,
                  value: androidAudioBackend ?? AndroidAudioBackend.opensl,
                  menuMaxHeight: 400,
                  items: <AndroidAudioBackend>[AndroidAudioBackend.opensl, AndroidAudioBackend.aaudio].map<DropdownMenuItem<AndroidAudioBackend>>((AndroidAudioBackend value) {
                    return DropdownMenuItem<AndroidAudioBackend>(
                        value: value,
                        child: (value == AndroidAudioBackend.opensl) ? const Text("OpenSL")
                            : (value == AndroidAudioBackend.aaudio) ? const Text("AAudio")
                            : const Text('')
                    );
                  }).toList(),
                  onChanged: (value) {
                    androidAudioBackend = value;
                    var settingBox = Hive.box<SettingData>(settingBoxName);
                    settingBox.put(audioBackendKey, SettingData(value!));
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("DEV_SETTING_CARD_BACKEND_ALERT_TITLE").tr(),
                        content: const Text("DEV_SETTING_CARD_BACKEND_ALERT_CONTENT").tr(),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text("DEV_SETTING_CARD_BACKEND_ALERT_BUTTON").tr(),
                          )
                        ],
                      )
                    );
                  },
                ),
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
