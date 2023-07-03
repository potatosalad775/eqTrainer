import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/model/session_data.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';

class SessionSelectorLandscape extends StatelessWidget {
  const SessionSelectorLandscape({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<IsolatedMusicPlayer>();
    final freqData = context.read<SessionFrequencyData>();
    final stateData = context.read<SessionStateData>();
    final resultData = context.read<SessionResultData>();
    final sessionData = context.read<SessionData>();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (player.pEQState == true)
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
                onPressed: (player.pEQState == false)
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
            // Notify 'the Session is Loading'
            stateData.sessionState = SessionState.loading;
            // Increase or Decrease 'sessionPoint' depends on whether user selected correct answer or not
            if (freqData.sessionResultGraphIndex + 1 == stateData.selectedGraphValue) {
              // Notify user chose correct answer
              Flushbar(
                icon: Icon(Icons.check, color: Theme.of(context).colorScheme.onTertiary),
                flushbarPosition: FlushbarPosition.TOP,
                duration: const Duration(seconds: 3),
                flushbarStyle: FlushbarStyle.GROUNDED,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                messageColor: Theme.of(context).colorScheme.onTertiary,
                message: "SESSION_SNACKBAR_CORRECT".tr(namedArgs: {'_INDEX': (freqData.sessionResultGraphIndex + 1).toString()}),
              ).show(context);
              // Increase 'sessionPoint' and update result data
              stateData.currentSessionPoint++;
              resultData.updateResultFromFreq(freqData.sessionResultCenterFreq, true);
            } else {
              // Notify user chose incorrect answer
              Flushbar(
                icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onTertiary),
                flushbarPosition: FlushbarPosition.TOP,
                duration: const Duration(seconds: 3),
                flushbarStyle: FlushbarStyle.GROUNDED,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                messageColor: Theme.of(context).colorScheme.onTertiary,
                message: "SESSION_SNACKBAR_INCORRECT".tr(namedArgs: {'_INDEX': (freqData.sessionResultGraphIndex + 1).toString()}),
              ).show(context);
              // Decrease 'sessionPoint' and update result data
              stateData.currentSessionPoint--;
              resultData.updateResultFromFreq(freqData.sessionResultCenterFreq, false);
            }
            // Increase or Decrease the number of 'bands'
            // ... if 'sessionPoint' hits the threshold
            // ... when the num of band is changed, recalculate the graph frequency data.
            if (stateData.currentSessionPoint == sessionData.threshold) {
              stateData.currentSessionPoint = 0;
              sessionData.startingBand++;
              await freqData.initSessionFreqData();
            }
            else if (stateData.currentSessionPoint == (0 - sessionData.threshold)) {
              stateData.currentSessionPoint = 0;
              if(sessionData.startingBand > 2) sessionData.startingBand--;
              await freqData.initSessionFreqData();
            }
            // Initialize Session by selecting random index and more.
            if(context.mounted) await freqData.initSession(context);
            // Notify 'the Session is Ready'
            stateData.sessionState = SessionState.ready;
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            foregroundColor: Theme.of(context).colorScheme.onTertiary,
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.next_plan_outlined),
          label: Text(
            "SESSION_BUTTON_SUBMIT".tr(),
            style: filterButtonStyle,
          ),
        ),
      ],
    );
  }
}
