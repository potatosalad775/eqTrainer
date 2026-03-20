import 'package:eq_trainer/features/import/widget/editor_clip_button_group.dart';
import 'package:eq_trainer/features/import/widget/editor_control_button_group.dart';
import 'package:eq_trainer/features/import/widget/editor_position_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:eq_trainer/shared/service/audio_clip_service.dart';
import 'package:eq_trainer/features/import/data/import_audio_data.dart';

class EditorControlView extends StatefulWidget {
  const EditorControlView({super.key});

  @override
  State<EditorControlView> createState() => _EditorControlViewState();
}

class _EditorControlViewState extends State<EditorControlView> {
  @override
  Widget build(BuildContext context) {
    // Providers
    final player = context.read<ImportPlayer>();
    final clipTimeData = context.read<ImportAudioData>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Position Slider with Timestamp
        const EditorPositionSlider(),
        // Audio Control Button Row
        const EditorControlButtonGroup(),
        const SizedBox(height: 32),
        // Set Start / End Buttons
        const EditorClipButtonGroup(),
        const SizedBox(height: 16),
        // Done Button - add to Database
        Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  player.pause();
                  await context.read<AudioClipService>().createClip(
                    sourcePath: player.filePath,
                    startSec: clipTimeData.clipStartTime.seconds,
                    endSec: clipTimeData.clipEndTime.seconds,
                    isEdit: player.fetchDuration != clipTimeData.clipEndTime,
                  );
                  if(context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Text(
                    "IMPORT_EDITOR_BUTTON_DONE",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ).tr(),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ],
    );
  }
}