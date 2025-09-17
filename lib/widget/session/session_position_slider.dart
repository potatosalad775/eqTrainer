import 'package:flutter/material.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/player/player_isolate.dart';

class SessionPositionSlider extends StatelessWidget {
  const SessionPositionSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerIsolate>();
    final playerPosition = context.select<PlayerIsolate, AudioTime>((p) => p.fetchPosition);
    final playerDuration = context.select<PlayerIsolate, AudioTime>((p) => p.fetchDuration);

    return ProgressBar(
      barHeight: 12,
      timeLabelPadding: 8,
      progress: Duration(microseconds: (playerPosition.seconds * 1000 * 1000).toInt()),
      total: Duration(microseconds: (playerDuration.seconds * 1000 * 1000).toInt()),
      onSeek: (position) {
        player.seek(AudioTime(position.inMicroseconds / (1000 * 1000)));
      },
    );
  }
}