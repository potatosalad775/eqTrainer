import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/session/state/session_controller.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionEqButtonRow extends StatelessWidget {
  const SessionEqButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final sessionController = context.read<SessionController>();
    final pEQState = context.select<PlayerService, bool>((p) => p.fetchEQState);

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
            child: Text(context.l10n.sessionButtonOriginal),
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
            child: Text(context.l10n.sessionButtonEqFiltered),
          ),
        ),
      ],
    );
  }
}