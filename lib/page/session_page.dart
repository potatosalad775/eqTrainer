import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/page/result_page.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';
import 'package:eq_trainer/widget/device_dropdown.dart';
import 'package:eq_trainer/widget/session/session_position_slider.dart';
import 'package:eq_trainer/widget/session/session_selector_landscape.dart';
import 'package:eq_trainer/widget/session/session_graph.dart';
import 'package:eq_trainer/widget/session/session_picker_portrait.dart';
import 'package:eq_trainer/widget/session/session_picker_landscape.dart';
import 'package:eq_trainer/widget/session/session_control.dart';
import 'package:eq_trainer/widget/session/session_selector_portrait.dart';
import 'package:eq_trainer/model/session_data.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {


  @override
  void initState() {
    super.initState();

    // Initializing Session
    Future.delayed(Duration.zero, () async {
      final player = Provider.of<IsolatedMusicPlayer>(context, listen: false);
      final sessionStateData = Provider.of<SessionStateData>(context, listen: false);
      final sessionAudioData = Provider.of<SessionAudioData>(context, listen: false);
      final sessionFreqData = Provider.of<SessionFrequencyData>(context, listen: false);
      final sessionResultData = Provider.of<SessionResultData>(context, listen: false);
      // Notify Session is Loading
      sessionStateData.sessionState = SessionState.loading;
      // Reset Session Result
      sessionResultData.resetResult();
      // Update Audio Clip Path list for Session
      sessionAudioData.updateAudioClipPathList();
      // Calculate Frequencies required for Session and Graph UI
      await sessionFreqData.initSessionFreqData();
      // Choose Random Index for Session
      if(context.mounted) await sessionFreqData.initSession(context);
      // If List of Audio clips for Session is Not Empty
      if(sessionAudioData.audioClipPathList.isNotEmpty) {
        // Open First AudioClip
        player.open(sessionAudioData.audioClipPathList[0]);
        // Notify the Session is Ready
        sessionStateData.sessionState = SessionState.ready;
      } else {
        // ... else notify the playlist is empty.
        sessionStateData.sessionState = SessionState.playlistEmpty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = context.select<SessionStateData, SessionState>((s) => s.sessionState);
    final sessionAnswerCorrect = context.select<SessionResultData, int>((d) => d.resultCorrect);
    final sessionAnswerIncorrect = context.select<SessionResultData, int>((d) => d.resultIncorrect);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "SESSION_APPBAR_TITLE".tr()
          ),
          actions: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.check),
                Text(
                  sessionAnswerCorrect.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.clear),
                Text(
                  sessionAnswerIncorrect.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ],
          // ADD PLAYER STOP BUTTON
        ),
        body: (sessionState == SessionState.loading)
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : (sessionState == SessionState.playlistEmpty)
            ? AlertDialog(
                title: Text("SESSION_ALERT_EMPTY_TITLE".tr()),
                content: Text("SESSION_ALERT_EMPTY_CONTENT".tr()),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("SESSION_ALERT_EMPTY_BUTTON".tr()),
                  )
                ],
              )
            : SafeArea(
                child: (MediaQuery.of(context).size.shortestSide > 550 && MediaQuery.of(context).size.longestSide > 800
                        && MediaQuery.of(context).orientation == Orientation.landscape)
                // 'Landscape View' if device has large display
                ? sessionViewLandscape()
                // ...else use 'Portrait View'
                : sessionViewPortrait(),
            ),
      ),
    );
  }

  Widget sessionViewLandscape() {
    return const Row(
      children: [
        Flexible(child: SessionGraph()),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SessionPickerLandscape(),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      DeviceDropdown(),
                      Spacer(),
                      SessionPositionSlider(),
                      SessionControl(),
                      SizedBox(height: 32),
                      SessionSelectorLandscape(),
                    ],
                  ),
                )
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget sessionViewPortrait() {
    return const Column(
      children: [
        Expanded(child: SessionGraph()),
        SessionPickerPortrait(),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.fromLTRB(30, 10, 30, 0),
          child: SessionPositionSlider(),
        ),
        SessionControl(),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.all(15),
          child: SessionSelectorPortrait(),
        ),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    final player = Provider.of<IsolatedMusicPlayer>(context, listen: false);

    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text("SESSION_ALERT_EXIT_CONTENT".tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text("SESSION_ALERT_EXIT_BUTTON_NO".tr()),
          ),
          TextButton(
            onPressed: () {
              player.stop();
              Navigator.of(context).pop(true);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ResultPage()));
            },
            child: Text("SESSION_ALERT_EXIT_BUTTON_YES".tr()),
          ),
        ],
      )
    ) ?? false;
  }
}