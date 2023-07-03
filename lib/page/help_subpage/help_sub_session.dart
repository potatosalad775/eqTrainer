import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HelpSubPageSession extends StatelessWidget {
  const HelpSubPageSession({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HELP_SUB_SESSION_TITLE").tr(),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Image(image: AssetImage('assets/image/session_selector_capture.png')),
            const SizedBox(height: 16),
            const Text("HELP_SUB_SESSION_P1_PARAGRAPH_1").tr(),
            const SizedBox(height: 16),
            const Image(image: AssetImage('assets/image/session_picker_capture.png')),
            const SizedBox(height: 16),
            const Text("HELP_SUB_SESSION_P1_PARAGRAPH_2").tr(),
            const SizedBox(height: 16),
            const Image(image: AssetImage('assets/image/session_appbar_capture.png')),
            const SizedBox(height: 16),
            const Text("HELP_SUB_SESSION_P1_PARAGRAPH_3").tr(),
          ],
        ),
      ),
    );
  }
}
