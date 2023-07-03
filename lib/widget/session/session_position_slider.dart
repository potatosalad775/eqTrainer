import 'package:flutter/material.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';

class SessionPositionSlider extends StatelessWidget {
  const SessionPositionSlider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player = context.read<IsolatedMusicPlayer>();
    final position = context.select<IsolatedMusicPlayer, AudioTime>((p) => p.position);

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 10,
            trackShape: CustomTrackShape(),
          ),
          child: Slider(
            value: player.position.seconds,
            min: 0,
            max: player.duration.seconds,
            onChanged: (player.state != MabAudioPlayerState.stopped)
                ? (position) {
              player.position = AudioTime(position);
            } : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                position.formatMMSS(),
                style: const TextStyle(
                  height: 1,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                (player.duration - position).formatMMSS(),
                style: const TextStyle(
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
