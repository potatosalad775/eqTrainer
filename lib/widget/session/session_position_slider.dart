import 'package:flutter/material.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class SessionPositionSlider extends StatelessWidget {
  const SessionPositionSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<IsolatedMusicPlayer>();
    final position = context.select<IsolatedMusicPlayer, AudioTime>((p) => p.position);
    final duration = context.select<IsolatedMusicPlayer, AudioTime?>((p) => p.duration) ?? position;

    return ProgressBar(
      barHeight: 12,
      timeLabelPadding: 8,
      progress: Duration(microseconds: (position.seconds * 1000 * 1000).toInt()),
      total: Duration(microseconds: (duration.seconds * 1000 * 1000).toInt()),
      onSeek: (player.state != MabAudioPlayerState.stopped)
          ? (position) {
        player.position = AudioTime(position.inMicroseconds / (1000 * 1000));
      } : null,
    );
  }
}