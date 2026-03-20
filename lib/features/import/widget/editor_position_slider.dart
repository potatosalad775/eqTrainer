import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/import/data/import_audio_data.dart';
import 'package:eq_trainer/shared/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorPositionSlider extends StatelessWidget {
  const EditorPositionSlider({super.key});

  @override
  Widget build(BuildContext context) {
    // Providers
    final player = context.read<ImportPlayer>();
    final playerPosition = context.select<ImportPlayer, AudioTime>((p) => p.fetchPosition);
    final playerDuration = context.select<ImportPlayer, AudioTime>((p) => p.fetchDuration);
    final clipTimeData = context.watch<ImportAudioData>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clip Time Info
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //Text("File Path : ${player.filePath ?? "NOT AVAILABLE"}"),
              const Text("IMPORT_EDITOR_TIMESTAMP_START").tr(namedArgs: {'_TIME': clipTimeData.clipStartTime.formatMMSS()}),
              const Text("IMPORT_EDITOR_TIMESTAMP_END").tr(namedArgs: {'_TIME': clipTimeData.clipEndTime.formatMMSS()}),
            ],
          ),
        ),
        // Clip Indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(23, 0, 23, 0),
          child: Stack(
            children: [
              Align(
                alignment: Alignment(
                  (playerDuration == AudioTime.zero) ? -1
                  : ((2 * clipTimeData.clipStartTime.seconds / playerDuration.seconds) - 1).clamp(-1, 1), 1
                ),
                child: const Icon(Icons.arrow_downward),
              ),
              Align(
                alignment: Alignment(
                  (playerDuration == AudioTime.zero) ? 1
                  : ((2 * clipTimeData.clipEndTime.seconds / playerDuration.seconds) - 1).clamp(-1, 1), 1
                ),
                child: const Icon(Icons.arrow_downward),
              )
            ],
          ),
        ),
        // Slider
        Padding(
          padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
          child: ProgressBar(
            barHeight: 12,
            timeLabelPadding: 8,
            progress: Duration(microseconds: (playerPosition.seconds * 1000 * 1000).toInt()),
            total: Duration(microseconds: (playerDuration.seconds * 1000 * 1000).toInt()),
            onSeek: (position) {
              player.seek(AudioTime(position.inMicroseconds / (1000 * 1000)));
            }
          )
        ),
      ]
    );
  }
}