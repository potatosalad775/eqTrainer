import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/page/import_page.dart';
import 'package:eq_trainer/widget/playlist_control_view.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder(
          valueListenable: Hive.box<AudioClip>(audioClipBoxName).listenable(),
          builder: (context, Box<AudioClip> box, _) {
            if (box.values.isEmpty) {
              return Center(
                child: Text("PLAYLIST_EMPTY_TEXT".tr()),
              );
            } else {
              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.all(5),
                itemCount: box.values.length,
                itemBuilder: (context, index) {
                  AudioClip? currentClip = box.getAt(index);
                  Duration clipDuration = Duration(
                      milliseconds: (currentClip!.duration * 1000).toInt());
                  return Padding(
                    key: Key("$index"),
                    padding: const EdgeInsets.all(3),
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: ListTile(
                        minLeadingWidth: 0,
                        title: Text(
                          currentClip.ogAudioName,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                        ),
                        subtitle:
                            Text(clipDuration.toString().substring(2, 10)),
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: IconButton(
                            onPressed: () {
                              currentClip.isEnabled = !currentClip.isEnabled;
                              box.putAt(index, currentClip);
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
                              onPressed: () {
                                // Show popup screen
                                showModalBottomSheet(
                                    isDismissible: false,
                                    enableDrag: false,
                                    useSafeArea: true,
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) {
                                      if (Platform.isWindows) {
                                        return PlaylistControlView(
                                            filePath:
                                                "${audioClipDir.path}\\${box.getAt(index)?.fileName}");
                                      } else {
                                        return PlaylistControlView(
                                            filePath:
                                                "${audioClipDir.path}/${box.getAt(index)?.fileName}");
                                      }
                                    });
                              },
                              icon: const Icon(Icons.play_arrow),
                            ),
                            // More Menu Button
                            IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => SimpleDialog(
                                    title:
                                        Text("PLAYLIST_AUDIO_ALERT_TITLE".tr()),
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          box.deleteAt(index);
                                          Navigator.of(context).pop();
                                        },
                                        child: Text(
                                            "PLAYLIST_AUDIO_ALERT_ACTION_DELETE"
                                                .tr()),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.more_vert),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                onReorder: (int oldIndex, int newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  setState(() {
                    final oldItem = box.getAt(oldIndex);
                    final newItem = box.getAt(newIndex);

                    box.putAt(oldIndex, newItem!);
                    box.putAt(newIndex, oldItem!);
                  });
                },
                footer: Padding(
                  padding: const EdgeInsets.all(8.0),
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
              );
            }
          }),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ImportPage()));
        },
      ),
    );
  }
}
