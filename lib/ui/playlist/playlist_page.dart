import 'package:eq_trainer/ui/playlist/widget/playlist_item_tile.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/ui/import/import_page.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';

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
                child: Text(
                  repo.hasUnreadableData
                      ? context.l10n.playlistLibraryUnreadable
                      : context.l10n.playlistEmptyText,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: clips.length,
            itemBuilder: (context, index) => PlaylistItemTile(
              key: ValueKey(clips[index].id),
              index: index,
              currentClip: clips[index],
            ),
            onReorderItem: (int oldIndex, int newIndex) async {
              await repo.reorder(oldIndex, newIndex);
            },
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 84),
              child: Center(
                child: Column(
                  children: [
                    if (repo.hasUnreadableData)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          context.l10n.playlistLibraryUnreadable,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Text(context.l10n.playlistFooter),
                  ],
                ),
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
