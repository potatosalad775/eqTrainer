import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/index.dart';

class SessionSelectorPortrait extends StatelessWidget {
  const SessionSelectorPortrait({
    super.key,
    required this.player,
    required this.audioState,
    required this.sessionStore,
    required this.sessionController,
  });
  final PlayerIsolate player;
  final AudioState audioState;
  final SessionStore sessionStore;
  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final pEQState = context.select<PlayerIsolate, bool>((p) => p.fetchEQState);

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: (pEQState == true)
                ? () { sessionController.setEqEnabled(player, false); }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                "SESSION_BUTTON_ORIGINAL".tr(),
                style: filterButtonStyle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: (pEQState == false)
                ? () { sessionController.setEqEnabled(player, true); }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                "SESSION_BUTTON_EQ_FILTERED".tr(),
                style: filterButtonStyle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () => sessionController.submitAnswer(
            player: player,
            audioState: audioState,
            sessionStore: sessionStore,
            sessionParameter: context.read<SessionParameter>(),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            foregroundColor: Theme.of(context).colorScheme.onTertiary,
            minimumSize: const Size(50, 50),
            shape: const CircleBorder(),
          ),
          child: Icon(
            Icons.next_plan_outlined,
            color: Theme.of(context).colorScheme.onTertiary,
          ),
        ),
      ],
    );
  }
}
