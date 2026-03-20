import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/index.dart';

class SessionSelector extends StatelessWidget {
  const SessionSelector({super.key, required this.player, required this.isPortrait});
  final PlayerIsolate player;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final pEQState = context.select<PlayerIsolate, bool>((p) => p.fetchEQState);
    final audioState = context.read<AudioState>();
    final sessionStore = context.read<SessionStore>();
    final sessionController = context.read<SessionController>();
    final gap = isPortrait ? 16.0 : 20.0;

    final originalButton = Expanded(
      child: ElevatedButton(
        onPressed: (pEQState == true)
            ? () { sessionController.setEqEnabled(player, false); }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          minimumSize: isPortrait ? null : const Size(100, 50),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text("SESSION_BUTTON_ORIGINAL".tr(), style: filterButtonStyle),
        ),
      ),
    );

    final eqButton = Expanded(
      child: ElevatedButton(
        onPressed: (pEQState == false)
            ? () { sessionController.setEqEnabled(player, true); }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          minimumSize: isPortrait ? null : const Size(100, 50),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text("SESSION_BUTTON_EQ_FILTERED".tr(), style: filterButtonStyle),
        ),
      ),
    );

    void onSubmit() => sessionController.submitAnswer(
      player: player,
      audioState: audioState,
      sessionStore: sessionStore,
      sessionParameter: context.read<SessionParameter>(),
    );

    if (isPortrait) {
      return Row(
        children: [
          originalButton,
          SizedBox(width: gap),
          eqButton,
          SizedBox(width: gap),
          ElevatedButton(
            onPressed: onSubmit,
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
    } else {
      return Column(
        children: [
          Row(
            children: [
              originalButton,
              SizedBox(width: gap),
              eqButton,
            ],
          ),
          SizedBox(height: gap),
          ElevatedButton.icon(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
              minimumSize: const Size.fromHeight(60),
            ),
            icon: Icon(
              Icons.next_plan_outlined,
              color: Theme.of(context).colorScheme.onTertiary,
            ),
            label: Text("SESSION_BUTTON_SUBMIT".tr(), style: filterButtonStyle),
          ),
        ],
      );
    }
  }
}
