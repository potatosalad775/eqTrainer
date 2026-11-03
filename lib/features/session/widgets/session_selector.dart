import 'package:eq_trainer/features/session/widgets/session_eq_button_row.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/shared/player/player_service.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';
import 'package:toastification/toastification.dart';

class SessionSelector extends StatelessWidget {
  const SessionSelector({
    super.key,
    required this.isPortrait
  });
  final bool isPortrait;

  void onSubmit(BuildContext context) {
    final sessionController = context.read<SessionController>();

    // Captured up front: the result arrives after an await, by which time this
    // widget may be gone.
    final l10n = context.l10n;
    sessionController.submitAnswer(
      player: context.read<PlayerService>(),
      sessionStore: context.read<SessionStore>(),
      sessionParameter: context.read<SessionParameter>(),
      onResult: (isCorrect, correctIndex) {
        toastification.show(
          type: isCorrect ? ToastificationType.success : ToastificationType.error,
          style: ToastificationStyle.flatColored,
          description: Text(isCorrect
            ? l10n.sessionSnackbarCorrect
            : l10n.sessionSnackbarIncorrect(index: correctIndex.toString())),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 3),
          animationDuration: const Duration(milliseconds: 300),
          dragToClose: true,
          closeOnClick: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isPortrait) {
      return Row(
        spacing: 12,
        children: [
          const Expanded(child: SessionEqButtonRow()),
          ElevatedButton(
            onPressed: () => onSubmit(context),
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
          const SessionEqButtonRow(),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => onSubmit(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.tertiary,
              foregroundColor: context.colors.onTertiary,
              minimumSize: const Size.fromHeight(64),
            ),
            icon: Icon(Icons.next_plan_outlined, color: context.colors.onTertiary),
            label: Text(context.l10n.sessionButtonSubmit),
          ),
        ],
      );
    }
  }
}
