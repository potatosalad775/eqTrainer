import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/features/session/data/session_state.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/widgets/session_page_content_landscape.dart';
import 'package:eq_trainer/features/session/widgets/session_page_content_portrait.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:eq_trainer/shared/widget/interaction_lock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionPageContent extends StatelessWidget {
  const SessionPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<SessionStore, SessionState>(
      selector: (_, store) => store.sessionState,
      builder: (_, sessionState, __) {
        if (sessionState == SessionState.init) {
          return const Center(child: CircularProgressIndicator());
        } else if (sessionState == SessionState.playlistEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.sessionAlertEmptyTitle, style: context.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(context.l10n.sessionAlertEmptyContent),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.sessionAlertEmptyButton),
                ),
              ],
            ),
          );
        } else if (sessionState == SessionState.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.sessionAlertErrorTitle, style: context.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(context.l10n.sessionAlertErrorContent),
                if (context.read<SessionStore>().playlistPaths.any(mayNeedFfmpeg)) ...[
                  const SizedBox(height: 12),
                  Text(context.l10n.importAlertUnsupportedContentLinux),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.sessionAlertErrorButton),
                ),
              ],
            ),
          );
        } else {
          // sessionState == SessionState.loading || SessionState.ready
          return InteractionLock(
            locked: sessionState == SessionState.loading,
            useOverlay: true,
            child: SafeArea(
              child: (MediaQuery.of(context).size.width < MediaQuery.of(context).size.height
                      && MediaQuery.of(context).orientation == Orientation.portrait)
                  ? const SessionPageContentPortrait()
                  : const SessionPageContentLandscape(),
            ),
          );
        }
      },
    );
  }
}