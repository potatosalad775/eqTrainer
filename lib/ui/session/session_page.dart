import 'package:eq_trainer/ui/session/widgets/session_page_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/result/result_page.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/domain/session/session_parameter.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/ui/session/state/session_controller.dart';
import 'package:eq_trainer/ui/session/widgets/clip_skipped_toast.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  // A session's state lives exactly as long as this page: made here when the
  // session starts and dropped in dispose(), so nothing carries over to the
  // next one.
  late final PlayerService player;
  final _store = SessionStore();
  late final SessionController _controller;

  /// Captured in initState rather than read in dispose, where the element is
  /// already detached from the tree.
  late final ClipFormatMigration _clipFormatMigration;

  @override
  void initState() {
    super.initState();
    // A decode-and-encode pass competing with playback is audible on a phone
    // or a DAP, and the session is the one screen where that matters. The
    // migration holds at its next clip boundary until this page is gone.
    _clipFormatMigration = context.read<ClipFormatMigration>()..pause();
    player = PlayerService(context.read<OutputSelection>());
    _controller = SessionController(
      player: player,
      sessionStore: _store,
      clipLibrary: context.read<ClipLibrary>(),
      // Frozen now: what the user does on the config page later cannot reach
      // this session.
      settings: context.read<SessionParameter>().snapshot(),
      volumeCompensation: context.read<MiscSettingsProvider>().volumeCompensation,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _clipFormatMigration.resume();
    player.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
    // Captured up front: the launch finishes after an await, by which time the
    // page may be gone.
    final l10n = context.l10n;
    try {
      final skipped = await _controller.launch(shouldContinue: () => mounted);
      if (mounted && skipped > 0) showClipSkippedToast(l10n);
    } catch (_) {
      // The store's sessionState already reflects the failure (set inside
      // launch); nothing else to surface here, and rethrowing would
      // otherwise escape as an uncaught async exception since this runs from
      // a post-frame callback with no caller awaiting it.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerService>.value(value: player),
        ChangeNotifierProvider<SessionStore>.value(value: _store),
        Provider<SessionController>.value(value: _controller),
      ],
      builder: (context, child) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if(!didPop) _onPop();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              context.l10n.sessionAppbarTitle
            ),
            actions: [
              Selector<SessionStore, (int, int)>(
                selector: (_, store) => (store.results.correct, store.results.incorrect),
                builder: (_, counts, __) {
                  final (correct, incorrect) = counts;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.check),
                      Text(
                        correct.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.clear),
                      Text(
                        incorrect.toString(),
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
    final results = _controller.results;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sessionAlertExitTitle),
        content: Text(context.l10n.sessionAlertExitContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(context.l10n.sessionAlertExitButtonNo),
          ),
          TextButton(
            onPressed: () {
              // dispose() handles player.shutdown(); just navigate.
              Navigator.of(context).pop(true);
              Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => ResultPage(results: results))
              );
            },
            child: Text(context.l10n.sessionAlertExitButtonYes),
          ),
        ],
      )
    );
    return;
  }
}