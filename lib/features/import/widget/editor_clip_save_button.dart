import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:eq_trainer/shared/service/audio_clip_service.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorClipSaveButton extends StatelessWidget {
  const EditorClipSaveButton({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<ImportPlayer>();
    final clipTimeData = context.read<ImportAudioData>();

    return ElevatedButton(
      onPressed: () async {
        await player.pause();
        if (!context.mounted) return;
        final clipService = context.read<AudioClipService>();
        await clipService.createClip(
          sourcePath: player.filePath,
          startSec: clipTimeData.clipStartTime.seconds,
          endSec: clipTimeData.clipEndTime.seconds,
          isTrimmed: player.fetchDuration != clipTimeData.clipEndTime,
        );
        if (!context.mounted) return;
        Navigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: const Text(
          "IMPORT_EDITOR_BUTTON_DONE",
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
      ),
    );
  }
}