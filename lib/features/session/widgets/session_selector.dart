import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';
import 'package:toastification/toastification.dart';

class SessionSelector extends StatelessWidget {
  const SessionSelector({
    super.key, 
    required this.isPortrait
  });
  final bool isPortrait;

  Widget _buildOriginalButton(
    BuildContext context, {
    required bool pEQState,
    required SessionController sessionController,
  }) {
    final player = context.read<PlayerIsolate>();
    return Expanded(
      child: ElevatedButton(
        onPressed: pEQState ? () { sessionController.setEqEnabled(player, false); } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.primary,
          foregroundColor: context.colors.onPrimary,
          minimumSize: const Size(100, 64),
        ),
        child: Text("SESSION_BUTTON_ORIGINAL".tr()),
      ),
    );
  }

  Widget _buildEqButton(
    BuildContext context, {
    required bool pEQState,
    required SessionController sessionController,
  }) {
    final player = context.read<PlayerIsolate>();
    return Expanded(
      child: ElevatedButton(
        onPressed: !pEQState ? () { sessionController.setEqEnabled(player, true); } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.primary,
          foregroundColor: context.colors.onPrimary,
          minimumSize: const Size(100, 64),
        ),
        child: Text("SESSION_BUTTON_EQ_FILTERED".tr()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerIsolate>();
    final pEQState = context.select<PlayerIsolate, bool>((p) => p.fetchEQState);
    final sessionStore = context.read<SessionStore>();
    final sessionController = context.read<SessionController>();
    final gap = isPortrait ? 16.0 : 20.0;

    void onSubmit() => sessionController.submitAnswer(
      player: player,
      sessionStore: sessionStore,
      sessionParameter: context.read<SessionParameter>(),
      onResult: (isCorrect, correctIndex) {
        toastification.show(
          type: isCorrect ? ToastificationType.success : ToastificationType.error,
          style: ToastificationStyle.flatColored,
          description: Text(isCorrect
              ? "SESSION_SNACKBAR_CORRECT".tr(namedArgs: {'_INDEX': correctIndex.toString()})
              : "SESSION_SNACKBAR_INCORRECT".tr(namedArgs: {'_INDEX': correctIndex.toString()})),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 3),
          animationDuration: const Duration(milliseconds: 300),
          dragToClose: true,
          closeOnClick: true,
        );
      },
    );

    if (isPortrait) {
      return Row(
        spacing: 12,
        children: [
          _buildOriginalButton(context, pEQState: pEQState, sessionController: sessionController),
          _buildEqButton(context, pEQState: pEQState, sessionController: sessionController),
          ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.tertiary,
              foregroundColor: context.colors.onTertiary,
              fixedSize: const Size(56, 56),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Icon(Icons.next_plan_outlined, color: context.colors.onTertiary),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            spacing: 12,
            children: [
              _buildOriginalButton(context, pEQState: pEQState, sessionController: sessionController),
              _buildEqButton(context, pEQState: pEQState, sessionController: sessionController),
            ],
          ),
          SizedBox(height: gap),
          ElevatedButton.icon(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.tertiary,
              foregroundColor: context.colors.onTertiary,
              minimumSize: const Size.fromHeight(64),
            ),
            icon: Icon(Icons.next_plan_outlined, color: context.colors.onTertiary),
            label: Text("SESSION_BUTTON_SUBMIT".tr()),
          ),
        ],
      );
    }
  }
}
