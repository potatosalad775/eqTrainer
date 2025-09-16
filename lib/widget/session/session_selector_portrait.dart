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

class SessionSelectorPortrait extends StatelessWidget {
  const SessionSelectorPortrait({
    super.key,
    required this.player,
    required this.audioState,
    required this.sessionModel,
    required this.freqData,
    required this.stateData,
    required this.resultData,
    required this.sessionPlaylist,
  });
  final SessionPlayer player;
  final AudioState audioState;
  final SessionModel sessionModel;
  final SessionFrequencyData freqData;
  final SessionStateData stateData;
  final SessionResultData resultData;
  final SessionPlaylist sessionPlaylist;

  @override
  Widget build(BuildContext context) {
    final pEQState = context.select<SessionPlayer, bool>((p) => p.fetchEQState);
    final sessionParameter = context.read<SessionParameter>();

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: (pEQState == true)
                ? () { player.setEQ(false); }
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
                ? () { player.setEQ(true); }
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
            // Notify 'the Session is Loading'
            stateData.sessionState = SessionState.loading;
            // Increase or Decrease 'sessionPoint' depends on whether user selected correct answer or not
            if (sessionModel.answerGraphIndex + 1 == freqData.currentPickerValue) {
              // Notify user chose correct answer
              Flushbar(
                icon: Icon(Icons.check, color: Theme.of(context).colorScheme.onTertiary),
                flushbarPosition: FlushbarPosition.TOP,
                duration: const Duration(seconds: 3),
                flushbarStyle: FlushbarStyle.GROUNDED,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                messageColor: Theme.of(context).colorScheme.onTertiary,
                message: "SESSION_SNACKBAR_CORRECT".tr(namedArgs: {'_INDEX': (sessionModel.answerGraphIndex + 1).toString()}),
              ).show(context);
              // Increase 'sessionPoint' and update result data
              stateData.currentSessionPoint++;
              resultData.updateResultFromFreq(sessionModel.answerCenterFreq, true);
            } else {
              // Notify user chose incorrect answer
              Flushbar(
                icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onTertiary),
                flushbarPosition: FlushbarPosition.TOP,
                duration: const Duration(seconds: 3),
                flushbarStyle: FlushbarStyle.GROUNDED,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                messageColor: Theme.of(context).colorScheme.onTertiary,
                message: "SESSION_SNACKBAR_INCORRECT".tr(namedArgs: {'_INDEX': (sessionModel.answerGraphIndex + 1).toString()}),
              ).show(context);
              // Decrease 'sessionPoint' and update result data
              stateData.currentSessionPoint--;
              resultData.updateResultFromFreq(sessionModel.answerCenterFreq, false);
            }
            // Increase or Decrease the number of 'bands'
            // ... if 'sessionPoint' hits the threshold
            // ... when the num of band is changed, recalculate the graph frequency data.
            if (stateData.currentSessionPoint == sessionParameter.threshold && sessionParameter.startingBand < 25) {
              stateData.currentSessionPoint = 0;
              stateData.selectedPickerNum = 1;
              sessionParameter.startingBand++;
              await freqData.initSessionFreqData(sessionParameter: sessionParameter);
            }
            else if (stateData.currentSessionPoint == (0 - sessionParameter.threshold) && sessionParameter.startingBand > 2) {
              stateData.currentSessionPoint = 0;
              stateData.selectedPickerNum = 1;
              sessionParameter.startingBand--;
              await freqData.initSessionFreqData(sessionParameter: sessionParameter);
            }
            // Initialize Session by selecting random index and more.
            await sessionModel.initSession(
              player,
              audioState: audioState,
              sessionState: stateData,
              sessionPlaylist: sessionPlaylist,
              sessionParameter: sessionParameter,
              sessionResult: resultData,
              sessionFreqData: freqData,
            );
            // Notify 'the Session is Ready'
            stateData.sessionState = SessionState.ready;
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
