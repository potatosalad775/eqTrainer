import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HelpSubPageGoal extends StatelessWidget {
  const HelpSubPageGoal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HELP_SUB_GOAL_TITLE").tr(),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Image(image: AssetImage('assets/image/howtolisten_capture.png')),
            const SizedBox(height: 16),
            const Text("HELP_SUB_GOAL_P1_PARAGRAPH_1").tr(),
            const SizedBox(height: 16),
            const Text("HELP_SUB_GOAL_P1_PARAGRAPH_2").tr(),
          ],
        ),
      ),
    );
  }
}
