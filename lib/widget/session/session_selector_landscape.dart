import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/model/session/session_frequency.dart';
import 'package:eq_trainer/model/session/session_parameter.dart';
import 'package:eq_trainer/model/session/session_result.dart';
import 'package:eq_trainer/model/session/session_model.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/session/session_playlist.dart';
import 'package:eq_trainer/model/state/session_state_data.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/controller/session_controller.dart';

class SessionSelectorLandscape extends StatelessWidget {
  const SessionSelectorLandscape({
    super.key,
    required this.player,
    required this.audioState,
    required this.sessionModel,
    required this.freqData,
    required this.stateData,
    required this.resultData,
    required this.sessionPlaylist,
    required this.sessionController,
  });
  final SessionPlayer player;
  final AudioState audioState;
  final SessionModel sessionModel;
  final SessionFrequencyData freqData;
  final SessionStateData stateData;
  final SessionResultData resultData;
  final SessionPlaylist sessionPlaylist;
  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final pEQState = context.select<SessionPlayer, bool>((p) => p.fetchEQState);
    final sessionParameter = context.read<SessionParameter>();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (pEQState == true)
                    ? () { player.setEQ(false); }
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
                    ? () { player.setEQ(true); }
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
          onPressed: () async {
            final result = await sessionController.submitAnswer(
              player: player,
              audioState: audioState,
              sessionModel: sessionModel,
              freqData: freqData,
              stateData: stateData,
              resultData: resultData,
              sessionPlaylist: sessionPlaylist,
              sessionParameter: sessionParameter,
            );

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
