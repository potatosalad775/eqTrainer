import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';
import 'package:eq_trainer/model/session/session_result.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/state/session_state_data.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/controller/session_controller.dart';
import 'package:eq_trainer/model/state/session_store.dart';
import 'package:eq_trainer/player/player_isolate.dart';

class SessionSelectorPortrait extends StatelessWidget {
  const SessionSelectorPortrait({
    super.key,
    required this.player,
    required this.audioState,
    required this.stateData,
    required this.resultData,
    required this.sessionStore,
    required this.sessionController,
  });
  final PlayerIsolate player;
  final AudioState audioState;
  final SessionStateData stateData;
  final SessionResultData resultData;
  final SessionStore sessionStore;
  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final pEQState = context.select<PlayerIsolate, bool>((p) => p.fetchEQState);
    final sessionParameter = context.read<SessionParameter>();

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
          onPressed: () async {
            final result = await sessionController.submitAnswer(
              player: player,
              audioState: audioState,
              stateData: stateData,
              resultData: resultData,
              sessionStore: sessionStore,
              sessionParameter: sessionParameter,
            );

            if (!context.mounted) return;

            if (result.isCorrect) {
              Flushbar(
                icon: Icon(Icons.check, color: Theme.of(context).colorScheme.onTertiary),
                flushbarPosition: FlushbarPosition.TOP,
                duration: const Duration(seconds: 3),
                flushbarStyle: FlushbarStyle.GROUNDED,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                messageColor: Theme.of(context).colorScheme.onTertiary,
                message: "SESSION_SNACKBAR_CORRECT".tr(namedArgs: {'_INDEX': (result.correctIndex).toString()}),
              ).show(context);
            } else {
              Flushbar(
                icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onTertiary),
                flushbarPosition: FlushbarPosition.TOP,
                duration: const Duration(seconds: 3),
                flushbarStyle: FlushbarStyle.GROUNDED,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                messageColor: Theme.of(context).colorScheme.onTertiary,
                message: "SESSION_SNACKBAR_INCORRECT".tr(namedArgs: {'_INDEX': (result.correctIndex).toString()}),
              ).show(context);
            }
          },
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
