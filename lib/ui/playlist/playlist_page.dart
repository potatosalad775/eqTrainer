import 'dart:async';

import 'package:eq_trainer/ui/playlist/widget/playlist_item_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/ui/import/import_page.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  late final IAudioClipRepository _repo;
  late final ClipLibrary _library;
  late final Stream<List<AudioClip>> _clips;
  StreamSubscription<List<AudioClip>>? _clipsSub;

  // Which clips have no file, kept apart from the list. The list is drawn
  // straight from the repository stream, which publishes a change before its
  // save finishes so that a dragged clip does not snap back. Waiting on the
  // disk in that path would bring the snap back.
  Set<String> _missing = const {};

  // Each refresh takes the next number, and only the latest may apply its
  // result, so a slow check cannot overwrite a newer one.
  int _refreshes = 0;

  @override
  void initState() {
    super.initState();
    _repo = context.read<IAudioClipRepository>();
    _library = context.read<ClipLibrary>();
    _clips = _repo.watchClips();
    // The stream starts with the current list, so this also covers the first
    // build. The disk is not watched, so a file that goes missing is noticed
    // at the next change to the list, or when a tile asks.
    _clipsSub = _clips.listen((_) => unawaited(_refreshMissing()));
  }

  @override
  void dispose() {
    unawaited(_clipsSub?.cancel());
    super.dispose();
  }

  Future<void> _refreshMissing() async {
    final refresh = ++_refreshes;
    final Set<String> missing;
    try {
      missing = await _library.missingClipIds();
    } catch (e) {
      // Keep what is shown. A failed check says nothing about the files.
      debugPrint('[PlaylistPage] could not check for missing clips: $e');
      return;
    }
    if (!mounted || refresh != _refreshes || setEquals(missing, _missing)) {
      return;
    }
    setState(() => _missing = missing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<AudioClip>>(
        stream: _clips,
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
                  _repo.hasUnreadableData
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
              isMissing: _missing.contains(clips[index].id),
              onRefreshMissing: () => unawaited(_refreshMissing()),
            ),
            onReorderItem: (int oldIndex, int newIndex) async {
              await _repo.reorder(oldIndex, newIndex);
            },
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 84),
              child: Center(
                child: Column(
                  children: [
                    if (_repo.hasUnreadableData)
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
