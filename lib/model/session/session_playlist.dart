import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/audio_clip.dart';

// SessionAudioData - Playlist of Audio Clips required for Session
class SessionPlaylist extends ChangeNotifier {
  int currentPlayingAudioIndex = 0;
  List<String> audioClipPathList = [];

  // Load Audio Clip files from Hive Database
  List<String> getAudioClipPathList() {
    final audioClipBox = Hive.box<AudioClip>(audioClipBoxName);
    audioClipPathList = [];
    if(audioClipBox.isEmpty) return [];

    audioClipBox.values.where((element) => element.isEnabled)
      .forEach((element) {
        if(Platform.isWindows) {
          audioClipPathList.add("${audioClipDir.path}\\${element.fileName}");
        } else {
          audioClipPathList.add("${audioClipDir.path}/${element.fileName}");
        }
      });

    return audioClipPathList;
  }
}