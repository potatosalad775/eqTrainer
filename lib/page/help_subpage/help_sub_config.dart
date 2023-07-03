import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HelpSubPageConfig extends StatelessWidget {
  const HelpSubPageConfig({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HELP_SUB_CONFIG_TITLE").tr(),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Image(image: AssetImage('assets/image/graph_capture.png')),
            const SizedBox(height: 16),
            const Text("HELP_SUB_CONFIG_P1_PARAGRAPH").tr(),
            const SizedBox(height: 16),
            const Text("HELP_SUB_CONFIG_P1_SB", style: TextStyle(fontWeight: FontWeight.bold),).tr(),
            const Text("HELP_SUB_CONFIG_P1_SB_DESC").tr(),
            const SizedBox(height: 16),
            const Text("HELP_SUB_CONFIG_P1_G", style: TextStyle(fontWeight: FontWeight.bold),).tr(),
            const Text("HELP_SUB_CONFIG_P1_G_DESC").tr(),
            const SizedBox(height: 16),
            const Text("HELP_SUB_CONFIG_P1_Q", style: TextStyle(fontWeight: FontWeight.bold),).tr(),
            const Text("HELP_SUB_CONFIG_P1_Q_DESC").tr(),
            const SizedBox(height: 16),
            const Text("HELP_SUB_CONFIG_P1_TYPE", style: TextStyle(fontWeight: FontWeight.bold),).tr(),
            const Text("HELP_SUB_CONFIG_P1_TYPE_DESC").tr(),
            const SizedBox(height: 16),
            const Text("HELP_SUB_CONFIG_P1_THR", style: TextStyle(fontWeight: FontWeight.bold),).tr(),
            const Text("HELP_SUB_CONFIG_P1_THR_DESC").tr(),
          ],
        ),
      ),
    );
  }
}
