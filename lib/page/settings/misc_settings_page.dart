import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/setting_data.dart';
import 'package:eq_trainer/widget/settings_card.dart';
import 'package:eq_trainer/widget/common/MaxWidthCenterBox.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive/hive.dart';

class MiscSettingsPage extends StatefulWidget {
  const MiscSettingsPage({super.key});

  @override
  State<MiscSettingsPage> createState() => _MiscSettingsPageState();
}

class _MiscSettingsPageState extends State<MiscSettingsPage> {
  late final Box<MiscSettings> miscSettingsBox;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load Miscellaneous Settings
    miscSettingsBox = await Hive.openBox<MiscSettings>(miscSettingsBoxName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MISC_SETTING_APPBAR_TITLE").tr(),
      ),
      body: MaxWidthCenterBox(
        child: ListView(
          padding: const EdgeInsets.all(5),
          children: [
            Column(
              children: [
                SettingsCard(
                  icon: FontAwesomeIcons.message,
                  title: "MISC_SETTING_CARD_TOOLTIP_TITLE".tr(),
                  trailing: Switch(
                    value: savedMiscSettingsValue.frequencyToolTip,
                    onChanged: (bool value) {
                      setState(() {
                        savedMiscSettingsValue.frequencyToolTip = value;
                        miscSettingsBox.put(
                          miscSettingsKey,
                          savedMiscSettingsValue.copyWith(
                            inputFrequencyToolTip: value,
                          )
                        );
                      });
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    miscSettingsBox.close();
  }
}