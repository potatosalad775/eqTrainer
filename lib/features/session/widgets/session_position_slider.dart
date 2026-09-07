import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/shared/player/player_service.dart';

class SessionPositionSlider extends StatelessWidget {
  const SessionPositionSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final playerPosition = context.select<PlayerService, Duration>((p) => p.fetchPosition);
    final playerDuration = context.select<PlayerService, Duration>((p) => p.fetchDuration);

    return ProgressBar(
      barHeight: 12,
      timeLabelPadding: 8,
      progress: playerPosition,
      total: playerDuration,
      onSeek: (position) {
        player.seek(position);
      },
    );
  }
}
