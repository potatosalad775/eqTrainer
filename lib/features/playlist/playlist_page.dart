import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/features/import/import_page.dart';
import 'package:eq_trainer/features/playlist/widget/playlist_control_view.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:path/path.dart' as p;

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<IAudioClipRepository>();
    final dirs = context.read<AppDirectories>();
    // Add bottom padding if device doesn't already have it.
    final bottomPaddingValue = MediaQuery.viewPaddingOf(context).bottom == 0 ? 40.0 : 0.0;

    return Scaffold(
      body: StreamBuilder<List<AudioClip>>(
        stream: repo.watchClips(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final clips = snap.data!;
          if (clips.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Text("PLAYLIST_EMPTY_TEXT".tr()),
              ),
            );
          }
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: clips.length,
            itemBuilder: (context, index) {
              final currentClip = clips[index];
              final clipDuration = Duration(milliseconds: (currentClip.duration * 1000).toInt());
              return Card(
                key: ValueKey(currentClip.fileName),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
                  subtitle: Text(clipDuration.toString().substring(2, 10)),
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
                      // Play Button
                      IconButton(
                        onPressed: () async {
                          final base = await dirs.getClipsPath();
                          final filePath = p.join(base, currentClip.fileName);
                          if (!context.mounted) return;
                          showModalBottomSheet(
                            isDismissible: false,
                            enableDrag: false,
                            useSafeArea: true,
                            context: context,
                            isScrollControlled: true,
                            builder: (context) =>
                                PlaylistControlView(filePath: filePath),
                          );
                        },
                        icon: const Icon(Icons.play_arrow),
                      ),
                      // More Menu Button
                      PopupMenuButton<int>(
                        onSelected: (value) async {
                          if (value == 1) {
                            final confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (context) => const _DeleteAlertDialog(),
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
            },
            onReorder: (int oldIndex, int newIndex) async {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final oldItem = clips[oldIndex];
              final newItem = clips[newIndex];
              await repo.updateAt(oldIndex, newItem);
              await repo.updateAt(newIndex, oldItem);
            },
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14 + 70),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("PLAYLIST_FOOTER").tr(),
                  if (Platform.isWindows || Platform.isLinux)
                    const SizedBox(height: 12),
                  if (Platform.isWindows || Platform.isLinux)
                    const Text("PLAYLIST_FOOTER_WINLINUX_1").tr(),
                  if (Platform.isWindows || Platform.isLinux)
                    const Text("PLAYLIST_FOOTER_WINLINUX_2").tr(),
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(13, 4, 13, 0),
            proxyDecorator: _tempProxyDecorator,
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPaddingValue),
        child: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ImportPage()));
          },
        ),
      ),
    );
  }

  static Widget _tempProxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return Material(
      type: MaterialType.transparency,
      child: child,
    );
  }
}

class _DeleteAlertDialog extends StatelessWidget {
  // ignore: unused_element
  const _DeleteAlertDialog();

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
