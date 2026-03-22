import 'package:eq_trainer/features/session/widgets/session_page_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/result/result_page.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/service/playlist_service.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
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
    return ChangeNotifierProvider<PlayerIsolate>.value(
      value: player,
      builder: (context, child) => PopScope(
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
          ),
          body: const SessionPageContent(),
        ),
      ),
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
              // dispose() handles player.shutdown(); just navigate.
              Navigator.of(context).pop(true);
              Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const ResultPage())
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