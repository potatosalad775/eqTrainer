import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/page/import_page.dart';

class EditorControlView extends StatefulWidget {
  const EditorControlView({Key? key}) : super(key: key);

  @override
  State<EditorControlView> createState() => _EditorControlViewState();
}

class _EditorControlViewState extends State<EditorControlView> {
  @override
  Widget build(BuildContext context) {
    // Providers
    final player = context.read<ImportPlayer>();
    final playerState = context.select<ImportPlayer, MabAudioPlayerState>((p) => p.state);
    final playerPosition = context.select<ImportPlayer, AudioTime>((p) => p.position);
    final playerDuration = context.select<ImportPlayer, AudioTime?>((p) => p.duration) ?? playerPosition;
    final clipDivProvider = context.watch<ImportAudioData>();

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
              const Text("IMPORT_EDITOR_TIMESTAMP_START").tr(namedArgs: {'_TIME': clipDivProvider.clipStartTime.formatMMSS()}),
              const Text("IMPORT_EDITOR_TIMESTAMP_END").tr(namedArgs: {'_TIME': clipDivProvider.clipEndTime.formatMMSS()}),
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
                  : ((2 * clipDivProvider.clipStartTime.seconds / playerDuration.seconds) - 1).clamp(-1, 1), 1
                ),
                child: const Icon(Icons.arrow_downward),
              ),
              Align(
                alignment: Alignment(
                  (playerDuration == AudioTime.zero) ? 1
                  : ((2 * clipDivProvider.clipEndTime.seconds / playerDuration.seconds) - 1).clamp(-1, 1), 1
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
            onSeek: (player.state != MabAudioPlayerState.stopped)
                ? (position) {
              player.position = AudioTime(position.inMicroseconds / (1000 * 1000));
            } : null,
          )
        ),
        // Audio Control Button Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Skip Previous
            IconButton(
              onPressed: () {
                player.position = clipDivProvider.clipStartTime;
              },
              iconSize: 56,
              icon: const Icon(Icons.skip_previous),
              enableFeedback: false,
            ),
            SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
            // Play Pause
            IconButton(
              onPressed: playerState != MabAudioPlayerState.stopped
                  ? () {
                      if (playerState == MabAudioPlayerState.playing) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    }
                  : null,
              iconSize: 64,
              icon: Icon(playerState == MabAudioPlayerState.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
              enableFeedback: false,
            ),
            SizedBox(width: MediaQuery.of(context).size.width * reactiveElementData.controlSpacer),
            // Skip Next
            IconButton(
              onPressed: () {
                player.position = clipDivProvider.clipEndTime;
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
                  if(playerPosition < clipDivProvider.clipEndTime) {
                    clipDivProvider.clipStartTime = player.position;
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
                  if(clipDivProvider.clipStartTime < playerPosition) {
                    clipDivProvider.clipEndTime = player.position;
                    debugPrint(player.position.seconds.toString());
                    debugPrint(clipDivProvider.clipEndTime.seconds.toString());
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
                  player.stop();
                  await makeAudioClip(player.filePath!, clipDivProvider.clipStartTime.seconds, clipDivProvider.clipEndTime.seconds);
                  if(context.mounted) Navigator.pop(context);
                },
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

Future<void> makeAudioClip(String targetFilePath, double clipStartSec, double clipEndSec) async {
  DateTime dt = DateTime.now();
  String audioClipFileName = "${dt.year}${dt.month}${dt.day}${dt.hour}${dt.minute}${dt.second}";
  String audioClipExtension = p.extension(targetFilePath);
  String audioClipDirString = "${audioClipDir.path}/$audioClipFileName$audioClipExtension";

  int clipStartMilliSec = (clipStartSec * 1000).toInt();
  int clipDurationMilliSec = (clipEndSec * 1000).toInt() - clipStartMilliSec;
  // separated arguments for splitting original audio file into audio clip
  // -y : force overwrite temp files
  // -vn : Remove Video
  // -ss clipStartSec ~ -to clipDurationSec : cutting audio into clip, starting from clipStartSec with duration of clipDurationSec
  List<String> ffmpegArg = ["-y", "-vn", "-ss", "${clipStartMilliSec}ms", "-i", targetFilePath, "-to", "${clipDurationMilliSec}ms", audioClipDirString];
  FFmpegKit.executeWithArguments(ffmpegArg);

  Box<AudioClip> audioClipBox = Hive.box<AudioClip>(audioClipBoxName);
  audioClipBox.add(AudioClip("$audioClipFileName$audioClipExtension", targetFilePath.split('/').last.split('.').first, clipEndSec - clipStartSec, true));
}

class ImportAudioData extends ChangeNotifier {
  AudioTime _clipStartTime = AudioTime.zero;
  AudioTime _clipEndTime = const AudioTime(double.maxFinite);

  AudioTime get clipStartTime => _clipStartTime;
  AudioTime get clipEndTime => _clipEndTime;

  set clipStartTime(value) {
    _clipStartTime = value;
    notifyListeners();
  }
  set clipEndTime(value) {
    _clipEndTime = value;
    notifyListeners();
  }

  void initEndTime(AudioTime value) {
    _clipEndTime = value;
    return;
  }
}