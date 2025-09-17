import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coast_audio/coast_audio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/shared/model/error.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
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
    final playerPosition = context.select<ImportPlayer, AudioTime>((p) => p.fetchPosition);
    final playerDuration = context.select<ImportPlayer, AudioTime>((p) => p.fetchDuration);
    final playerState = context.select<ImportPlayer, PlayerStateResponse>((p) => p.fetchPlayerState);
    final clipTimeData = context.watch<ImportAudioData>();

    if(clipTimeData.clipEndTime == AudioTime.zero) {
      clipTimeData.initEndTime(playerDuration);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        // Audio Control Button Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Skip Previous
            IconButton(
              onPressed: () {
                player.seek(clipTimeData.clipStartTime);
              },
              iconSize: 56,
              icon: const Icon(Icons.skip_previous),
              enableFeedback: false,
            ),
            SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
            // Play Pause
            IconButton(
              onPressed: () {
                if (playerState.isPlaying) {
                  player.pause();
                } else {
                  player.play().onError((e, _) {
                    if(context.mounted) {
                      showPlayerErrorDialog(context,
                        action: () {
                          player.shutdown();
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        error: e
                      );
                    }
                  });
                }
              },
              iconSize: 64,
              icon: Icon(playerState.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
              enableFeedback: false,
            ),
            SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
            // Skip Next
            IconButton(
              onPressed: () {
                player.seek(clipTimeData.clipEndTime);
              },
              iconSize: 56,
              icon: const Icon(Icons.skip_next),
              enableFeedback: false,
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Set Start / End Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if(playerPosition < clipTimeData.clipEndTime) {
                    clipTimeData.clipStartTime = playerPosition;
                  } else {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        content: const Text("IMPORT_EDITOR_ALERT_START_CONTENT").tr(),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'OK'),
                            child: const Text("IMPORT_EDITOR_ALERT_BUTTON").tr(),
                          )
                        ],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Text("IMPORT_EDITOR_BUTTON_SET_START").tr(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if(clipTimeData.clipStartTime < playerPosition) {
                    clipTimeData.clipEndTime = playerPosition;
                  } else {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        content: const Text("IMPORT_EDITOR_ALERT_END_CONTENT").tr(),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'OK'),
                            child: const Text("IMPORT_EDITOR_ALERT_BUTTON").tr(),
                          )
                        ],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Text("IMPORT_EDITOR_BUTTON_SET_END").tr(),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
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
                    isEdit: playerDuration != clipTimeData.clipEndTime,
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