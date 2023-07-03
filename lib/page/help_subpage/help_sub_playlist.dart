import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HelpSubPagePlaylist extends StatelessWidget {
  const HelpSubPagePlaylist({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HELP_SUB_PLAYLIST_TITLE").tr(),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text("HELP_SUB_PLAYLIST_P1_PARAGRAPH_1").tr(),
            const SizedBox(height: 16),
            const Image(image: AssetImage('assets/image/editor_capture.png')),
            const SizedBox(height: 16),
            const Text("HELP_SUB_PLAYLIST_P1_PARAGRAPH_2").tr(),
          ],
        ),
      ),
    );
  }
}
