import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/import/import_audio_data.dart';
import 'package:eq_trainer/data/import_player.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Replaces `AudioTime.formatMMSS()`, which left with coast_audio. Only the
/// clip markers below use it, so it stays here rather than becoming a shared
/// helper with one caller.
extension _MmSs on Duration {
  String get mmss {
    final minutes = inMinutes;
    final seconds = inSeconds - minutes * 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class EditorPositionSlider extends StatelessWidget {
  const EditorPositionSlider({super.key});

  @override
  Widget build(BuildContext context) {
    // Providers
    final player = context.read<ImportPlayer>();
    final playerPosition = context.select<ImportPlayer, Duration>((p) => p.fetchPosition);
    final playerDuration = context.select<ImportPlayer, Duration>((p) => p.fetchDuration);
    final clipTimeData = context.watch<ImportAudioData>();

    // Marker positions are a fraction of the clip's length, so an unknown
    // duration has to pin them to the ends rather than divide by zero.
    double markerAlignment(Duration at) {
      if (playerDuration == Duration.zero) return -1;
      return ((2 * at.inMicroseconds / playerDuration.inMicroseconds) - 1).clamp(-1, 1);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clip Time Info
        Text(context.l10n.importEditorTimestampStart(time: clipTimeData.clipStartTime.mmss)),
        Text(context.l10n.importEditorTimestampEnd(time: clipTimeData.clipEndTime.mmss)),
        // Clip Indicator
        Stack(
          children: [
            Align(
              alignment: Alignment(markerAlignment(clipTimeData.clipStartTime), 1),
              child: const Icon(Icons.arrow_downward),
            ),
            Align(
              alignment: Alignment(
                playerDuration == Duration.zero ? 1 : markerAlignment(clipTimeData.clipEndTime),
                1,
              ),
              child: const Icon(Icons.arrow_downward),
            )
          ],
        ),
        // Slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ProgressBar(
            barHeight: 12,
            timeLabelPadding: 8,
            progress: playerPosition,
            total: playerDuration,
            onSeek: (position) {
              player.seek(position);
            }
          )
        ),
      ]
    );
  }
}
