import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/page/import_page.dart';
import 'package:eq_trainer/widget/playlist_control_view.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/service/app_directories.dart';
import 'package:path/path.dart' as p;

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  @override
  Widget build(BuildContext context) {
    // Add bottom padding if device doesn't already have it.
    double bottomPaddingValue = MediaQuery.of(context).viewPadding.bottom == 0 ? 40 : 0;

    return Scaffold(
      body: ValueListenableBuilder(
          valueListenable: Hive.box<AudioClip>(audioClipBoxName).listenable(),
          builder: (context, Box<AudioClip> box, _) {
            if (box.values.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Text("PLAYLIST_EMPTY_TEXT".tr()),
                ),
              );
            } else {
              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: box.values.length,
                itemBuilder: (context, index) {
                  final dirs = context.read<AppDirectories>();
                  AudioClip? currentClip = box.getAt(index);
                  Duration clipDuration = Duration(
                      milliseconds: (currentClip!.duration * 1000).toInt());
                  return Card(
                    key: Key("$index"),
                    elevation: 0,
                    margin: EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: ListTile(
                      minLeadingWidth: 0,
                      minVerticalPadding: 12,
                      contentPadding: EdgeInsets.fromLTRB(14, 0, 14, 0),
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
                            onPressed: () async {
                              // Show popup screen
                              showModalBottomSheet(
                                  isDismissible: false,
                                  enableDrag: false,
                                  useSafeArea: true,
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return FutureBuilder<String>(
                                      future: dirs.getClipsPath(),
                                      builder: (context, snap) {
                                        if (!snap.hasData) {
                                          return const SizedBox(
                                            height: 160,
                                            child: Center(child: CircularProgressIndicator()),
                                          );
                                        }
                                        final base = snap.data!;
                                        final filePath = p.join(base, box.getAt(index)!.fileName);
                                        return PlaylistControlView(filePath: filePath);
                                      },
                                    );
                                  });
                            },
                            icon: const Icon(Icons.play_arrow),
                          ),
                          // More Menu Button
                          PopupMenuButton<int>(
                            onSelected: (value) async {
                              if (value == 1) {
                                bool? confirmDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => _deleteAlertDialog(),
                                );
                                if (confirmDelete == true) {
                                  box.deleteAt(index);
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 1,
                                child: Text(
                                  "PLAYLIST_AUDIO_ACTION_DELETE".tr()),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert),
                          ),
                        ],
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
                  // Added another '40' bottom padding since main navigation bar is floating
                  // Added another '70' bottom padding since Add FAB is present
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14 + 40 + 70),
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
            }
          }),
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

  Widget _deleteAlertDialog() {
    return AlertDialog(
      title: Text("PLAYLIST_AUDIO_ALERT_DELETE_TITLE".tr()),
      content: Text("PLAYLIST_AUDIO_ALERT_DELETE_CONTENT".tr()),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text("PLAYLIST_AUDIO_ALERT_DELETE_NO".tr()),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: Text("PLAYLIST_AUDIO_ALERT_DELETE_YES".tr()),
        ),
      ],
    );
  }

  /*
  Widget _proxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(1, 6, animValue)!;
        final double scale = lerpDouble(1, 1.04, animValue)!;
        return Transform.scale(
          scale: scale,
          // Create a Card based on the color and the content of the dragged one
          // and set its elevation to the animated value.
          child: Card(
            elevation: elevation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
  */

  // Flutter Issue Tracker: https://github.com/flutter/flutter/issues/63527
  Widget _tempProxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return Material(
      type: MaterialType.transparency,
      child: child,
    );
  }
}
