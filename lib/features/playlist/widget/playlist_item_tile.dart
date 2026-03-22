import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/playlist/widget/playlist_control_view.dart';
import 'package:eq_trainer/features/playlist/widget/playlist_delete_dialog.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class PlaylistItemTile extends StatelessWidget {
  const PlaylistItemTile({
    super.key,
    required this.index,
    required this.currentClip,
  });

  final int index;
  final AudioClip currentClip;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<IAudioClipRepository>();
    final dirs = context.read<AppDirectories>();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: context.colors.surfaceContainer,
      child: ListTile(
        minLeadingWidth: 0,
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        title: Text(
          currentClip.ogAudioName,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
        subtitle: Text(
          Duration(milliseconds: (currentClip.duration * 1000).toInt()).toString().substring(2, 10)
        ),
        leading: ReorderableDragStartListener(
          index: index,
          child: IconButton(
            onPressed: () async {
              await repo.toggleEnabledAt(index);
            },
            icon: Icon(currentClip.isEnabled
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async {
                final base = await dirs.getClipsPath();
                final filePath = p.join(base, currentClip.fileName);
                if (!context.mounted) return;
                unawaited(showModalBottomSheet(
                  isDismissible: false,
                  enableDrag: false,
                  useSafeArea: true,
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => PlaylistControlView(filePath: filePath),
                ));
              },
              icon: const Icon(Icons.play_arrow),
            ),
            PopupMenuButton<int>(
              onSelected: (value) async {
                if (value == 1) {
                  final confirmDelete = await showDialog<bool>(
                    context: context,
                    builder: (context) => const PlaylistDeleteDialog(),
                  );
                  if (confirmDelete == true) {
                    await repo.deleteAt(index);
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 1,
                  child: Text("PLAYLIST_AUDIO_ACTION_DELETE".tr()),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }
}