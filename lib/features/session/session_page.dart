import 'package:eq_trainer/shared/widget/interaction_lock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/result/result_page.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/shared/widget/device_dropdown.dart';
import 'package:eq_trainer/shared/widget/max_width_center_box.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/service/playlist_service.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';
import 'package:eq_trainer/features/session/data/session_state.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/features/session/widgets/index.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final player = PlayerIsolate();

  @override
  void initState() {
    super.initState();
    // Initializing Session
    _init();
  }

  Future<void> _init() async {
    final audioState = Provider.of<AudioState>(context, listen: false);
    final sessionParameter = Provider.of<SessionParameter>(context, listen: false);
    final sessionStore = Provider.of<SessionStore>(context, listen: false);
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final sessionController = Provider.of<SessionController>(context, listen: false);

    await sessionController.launchSession(
      player,
      audioState: audioState,
      sessionStore: sessionStore,
      sessionParameter: sessionParameter,
      playlistService: playlistService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerIsolate>.value(value: player),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if(!didPop) _onPop();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              "SESSION_APPBAR_TITLE".tr()
            ),
            actions: [
              Consumer<SessionStore>(
                builder: (_, store, __) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.check),
                      Text(
                        store.resultCorrect.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.clear),
                      Text(
                        store.resultIncorrect.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  );
                }
              ),
            ],
            elevation: 10,
            // ADD PLAYER STOP BUTTON
          ),
          body: Selector<SessionStore, SessionState>(
            selector: (_, store) => store.sessionState,
            builder: (_, sessionState, __) {
              if (sessionState == SessionState.init) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else if (sessionState == SessionState.playlistEmpty) {
                return AlertDialog(
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
                );
              } else if (sessionState == SessionState.error) {
                return AlertDialog(
                  title: Text("SESSION_ALERT_ERROR_TITLE".tr()),
                  content: Text("SESSION_ALERT_ERROR_CONTENT".tr()),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text("SESSION_ALERT_ERROR_BUTTON".tr()),
                    )
                  ],
                );
              } else { // sessionState == SessionState.loading || SessionState.ready
                return InteractionLock(
                  locked: sessionState == SessionState.loading,
                  useOverlay: true,
                  child: SafeArea(
                    child: (MediaQuery.of(context).size.width < MediaQuery.of(context).size.height
                        && MediaQuery.of(context).orientation == Orientation.portrait)
                    // 'Portrait View'
                        ? sessionViewPortrait()
                    // 'Landscape View'
                        : sessionViewLandscape(),
                  ),
                );
              }
            }
          )
        ),
      ),
    );
  }

  Widget sessionViewLandscape() {
    return MaxWidthCenterBox(
      ratio: 3,
      child: Row(
        children: [
          const Flexible(
              child: SessionGraph()
          ),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SessionPickerLandscape(),
                Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const DeviceDropdown(),
                          const Spacer(),
                          const SessionPositionSlider(),
                          SessionControl(player: player),
                          const SizedBox(height: 32),
                          SessionSelectorLandscape(player: player),
                        ],
                      ),
                    )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sessionViewPortrait() {
    return Column(
      children: [
        const Expanded(
            child: SessionGraph()
        ),
        const SessionPickerPortrait(),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.fromLTRB(30, 10, 30, 0),
          child: SessionPositionSlider(),
        ),
        SessionControl(player: player),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.all(15),
          child: SessionSelectorPortrait(player: player),
        ),
      ],
    );
  }

  void _onPop() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("SESSION_ALERT_EXIT_TITLE".tr()),
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
              player.shutdown();
              Navigator.of(context).pop(true);
              Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => ResultPage())
              );
            },
            child: Text("SESSION_ALERT_EXIT_BUTTON_YES".tr()),
          ),
        ],
      )
    );

    return;
  }
}