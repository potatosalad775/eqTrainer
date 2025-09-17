import 'package:flutter/material.dart';
import 'package:eq_trainer/service/playlist_service.dart';

// SessionAudioData - Playlist of Audio Clips required for Session
class SessionPlaylist extends ChangeNotifier {
  SessionPlaylist({required PlaylistService playlistService})
      : _playlistService = playlistService;

  final PlaylistService _playlistService;

  int currentPlayingAudioIndex = 0;
  List<String> audioClipPathList = [];

  // Load Audio Clip files via PlaylistService (decoupled from Hive/path)
  Future<List<String>> getAudioClipPathList() async {
    audioClipPathList = await _playlistService.listEnabledClipPaths();
    return audioClipPathList;
  }
}