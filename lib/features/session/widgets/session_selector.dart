import 'package:eq_trainer/features/session/widgets/session_eq_button_row.dart';
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

  void onSubmit(BuildContext context) {
    final sessionController = context.read<SessionController>();

    sessionController.submitAnswer(
      player: context.read<PlayerIsolate>(),
      sessionStore: context.read<SessionStore>(),
      sessionParameter: context.read<SessionParameter>(),
      onResult: (isCorrect, correctIndex) {
        toastification.show(
          type: isCorrect ? ToastificationType.success : ToastificationType.error,
          style: ToastificationStyle.flatColored,
          description: Text(isCorrect 
            ? "SESSION_SNACKBAR_CORRECT" 
            : "SESSION_SNACKBAR_INCORRECT").tr(
              namedArgs: {'_INDEX': correctIndex.toString()}
            ),
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
            label: Text("SESSION_BUTTON_SUBMIT".tr()),
          ),
        ],
      );
    }
  }
}
