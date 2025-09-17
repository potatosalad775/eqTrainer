import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/index.dart';

class SessionSelectorLandscape extends StatelessWidget {
  const SessionSelectorLandscape({ super.key, required this.player });
  final PlayerIsolate player;

  @override
  Widget build(BuildContext context) {
    final pEQState = context.select<PlayerIsolate, bool>((p) => p.fetchEQState);
    final audioState = context.read<AudioState>();
    final sessionStore = context.read<SessionStore>();
    final sessionController = context.read<SessionController>();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (pEQState == true)
                    ? () { sessionController.setEqEnabled(player, false); }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(100, 50),
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
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                onPressed: (pEQState == false)
                    ? () { sessionController.setEqEnabled(player, true); }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(100, 50),
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
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => sessionController.submitAnswer(
            player: player,
            audioState: audioState,
            sessionStore: sessionStore,
            sessionParameter: context.read<SessionParameter>(),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            foregroundColor: Theme.of(context).colorScheme.onTertiary,
            minimumSize: const Size.fromHeight(60),
          ),
          icon: Icon(
            Icons.next_plan_outlined,
            color: Theme.of(context).colorScheme.onTertiary,
          ),
          label: Text(
            "SESSION_BUTTON_SUBMIT".tr(),
            style: filterButtonStyle,
          ),
        ),
      ],
    );
  }
}
