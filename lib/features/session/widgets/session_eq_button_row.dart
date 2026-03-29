import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';
import 'package:eq_trainer/shared/player/player_isolate.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionEqButtonRow extends StatelessWidget {
  const SessionEqButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerIsolate>();
    final sessionController = context.read<SessionController>();
    final pEQState = context.select<PlayerIsolate, bool>((p) => p.fetchEQState);

    return Row(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: pEQState ? () { sessionController.setEqEnabled(player, false); } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              minimumSize: const Size(100, 64),
            ),
            child: const Text("SESSION_BUTTON_ORIGINAL").tr(),
          ),
        ),
        Expanded(
          child: ElevatedButton(
            onPressed: !pEQState ? () { sessionController.setEqEnabled(player, true); } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              minimumSize: const Size(100, 64),
            ),
            child: const Text("SESSION_BUTTON_EQ_FILTERED").tr(),
          ),
        ),
      ],
    );
  }
}