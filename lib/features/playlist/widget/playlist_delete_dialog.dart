import 'package:eq_trainer/l10n/l10n.dart';
import 'package:flutter/material.dart';

class PlaylistDeleteDialog extends StatelessWidget {
  const PlaylistDeleteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.playlistAudioAlertDeleteTitle),
      content: Text(context.l10n.playlistAudioAlertDeleteContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.playlistAudioAlertDeleteNo),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.playlistAudioAlertDeleteYes),
        ),
      ],
    );
  }
}