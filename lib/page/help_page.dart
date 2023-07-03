import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/page/help_subpage/help_sub_freq.dart';
import 'package:eq_trainer/page/help_subpage/help_sub_goal.dart';
import 'package:eq_trainer/page/help_subpage/help_sub_playlist.dart';
import 'package:eq_trainer/page/help_subpage/help_sub_config.dart';
import 'package:eq_trainer/page/help_subpage/help_sub_session.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // List of SubPages
    final List<Widget> pages = [
      const HelpSubPageFreq(),
      const HelpSubPageGoal(),
      const HelpSubPagePlaylist(),
      const HelpSubPageConfig(),
      const HelpSubPageSession(),
    ];

    // List of SubPage Title
    final List<String> pageTitle = [
      "HELP_SUB_FREQ_TITLE".tr(),
      "HELP_SUB_GOAL_TITLE".tr(),
      "HELP_SUB_PLAYLIST_TITLE".tr(),
      "HELP_SUB_CONFIG_TITLE".tr(),
      "HELP_SUB_SESSION_TITLE".tr(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("HELP_APPBAR_TITLE").tr(),
      ),
      body: SafeArea(
        child: ListView.builder(
          itemCount: pages.length,
          padding: const EdgeInsets.all(5),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.all(3),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: ListTile(
                  title: Text(pageTitle[index]),
                  trailing: const Icon(Icons.keyboard_arrow_right),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => pages[index]));
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
