import 'dart:io';
import 'package:eq_trainer/features/playlist/widget/playlist_item_tile.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/features/import/import_page.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<IAudioClipRepository>();

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
            itemBuilder: (context, index) => PlaylistItemTile(
              key: ValueKey('${clips[index].fileName}_${clips[index].ogAudioName}'),
              index: index,
              currentClip: clips[index],
            ),
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ImportPage()));
        },
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
