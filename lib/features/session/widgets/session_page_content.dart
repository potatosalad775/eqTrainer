import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/session/data/session_state.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/widgets/session_page_content_landscape.dart';
import 'package:eq_trainer/features/session/widgets/session_page_content_portrait.dart';
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
                Text("SESSION_ALERT_EMPTY_TITLE".tr(), style: context.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text("SESSION_ALERT_EMPTY_CONTENT".tr()),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("SESSION_ALERT_EMPTY_BUTTON".tr()),
                ),
              ],
            ),
          );
        } else if (sessionState == SessionState.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("SESSION_ALERT_ERROR_TITLE".tr(), style: context.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text("SESSION_ALERT_ERROR_CONTENT".tr()),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("SESSION_ALERT_ERROR_BUTTON".tr()),
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