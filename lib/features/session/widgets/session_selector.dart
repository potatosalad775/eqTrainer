import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';

class SessionSelector extends StatelessWidget {
  const SessionSelector({super.key, required this.player, required this.isPortrait});
  final PlayerIsolate player;
  final bool isPortrait;

  Widget _buildOriginalButton(
    BuildContext context, {
    required bool pEQState,
    required SessionController sessionController,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: ElevatedButton(
        onPressed: pEQState ? () { sessionController.setEqEnabled(player, false); } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: isPortrait ? null : const Size(100, 50),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text("SESSION_BUTTON_ORIGINAL".tr(), style: filterButtonStyle),
        ),
      ),
    );
  }

  Widget _buildEqButton(
    BuildContext context, {
    required bool pEQState,
    required SessionController sessionController,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: ElevatedButton(
        onPressed: !pEQState ? () { sessionController.setEqEnabled(player, true); } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: isPortrait ? null : const Size(100, 50),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text("SESSION_BUTTON_EQ_FILTERED".tr(), style: filterButtonStyle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pEQState = context.select<PlayerIsolate, bool>((p) => p.fetchEQState);
    final audioState = context.read<AudioState>();
    final sessionStore = context.read<SessionStore>();
    final sessionController = context.read<SessionController>();
    final colors = Theme.of(context).colorScheme;
    final gap = isPortrait ? 16.0 : 20.0;

    void onSubmit() => sessionController.submitAnswer(
      player: player,
      audioState: audioState,
      sessionStore: sessionStore,
      sessionParameter: context.read<SessionParameter>(),
    );

    if (isPortrait) {
      return Row(
        children: [
          _buildOriginalButton(context, pEQState: pEQState, sessionController: sessionController),
          SizedBox(width: gap),
          _buildEqButton(context, pEQState: pEQState, sessionController: sessionController),
          SizedBox(width: gap),
          ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.tertiary,
              foregroundColor: colors.onTertiary,
              minimumSize: const Size(50, 50),
              shape: const CircleBorder(),
            ),
            child: Icon(Icons.next_plan_outlined, color: colors.onTertiary),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              _buildOriginalButton(context, pEQState: pEQState, sessionController: sessionController),
              SizedBox(width: gap),
              _buildEqButton(context, pEQState: pEQState, sessionController: sessionController),
            ],
          ),
          SizedBox(height: gap),
          ElevatedButton.icon(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.tertiary,
              foregroundColor: colors.onTertiary,
              minimumSize: const Size.fromHeight(60),
            ),
            icon: Icon(Icons.next_plan_outlined, color: colors.onTertiary),
            label: Text("SESSION_BUTTON_SUBMIT".tr(), style: filterButtonStyle),
          ),
        ],
      );
    }
  }
}
