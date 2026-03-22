import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class PlaylistDeleteDialog extends StatelessWidget {
  const PlaylistDeleteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("PLAYLIST_AUDIO_ALERT_DELETE_TITLE".tr()),
      content: Text("PLAYLIST_AUDIO_ALERT_DELETE_CONTENT".tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text("PLAYLIST_AUDIO_ALERT_DELETE_NO".tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text("PLAYLIST_AUDIO_ALERT_DELETE_YES".tr()),
        ),
      ],
    );
  }
}