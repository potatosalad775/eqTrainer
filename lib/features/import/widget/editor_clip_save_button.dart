import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/player/import_player.dart';
import 'package:eq_trainer/shared/service/audio_clip_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/theme_data.dart';

class EditorClipSaveButton extends StatelessWidget {
  const EditorClipSaveButton({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<ImportPlayer>();
    final clipTimeData = context.read<ImportAudioData>();

    return ElevatedButton(
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