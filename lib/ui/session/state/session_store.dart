import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eq_trainer/ui/session/state/frequency_calculator.dart';
import 'package:eq_trainer/ui/session/state/session_state.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:eq_trainer/domain/session/session_results.dart';

/// What the session screen shows: the state, the graphs, the picker, the
/// running counts and the playlist cursor. The rules behind them (which graph
/// is the answer, the score, the band ladder) are `SessionRounds`'.
class SessionStore extends ChangeNotifier {
  SessionStore();

  // Session state management (replaces SessionStateData)
  SessionState _sessionState = SessionState.init;
  SessionState get sessionState => _sessionState;

  void setSessionState(SessionState state) {
    _sessionState = state;
    notifyListeners();
  }

  // Graph data snapshot
  List<LineChartBarData> _graphBarDataList = const [];
  List<LineChartBarData> get graphBarDataList => _graphBarDataList;

  BandLayout? _layout;

  /// What the graphs currently on screen mean. Only valid once
  /// [applyLayout] has run.
  BandLayout get layout =>
      _layout ?? (throw StateError('the layout is not set before applyLayout'));

  List<double> _centerFreqLinearList = const [];
  List<double> get centerFreqLinearList => _centerFreqLinearList;

  // Picker value - single source of truth (replaces SessionStateData.selectedPickerNum)
  int _currentPickerValue = 1;
  int get currentPickerValue => _currentPickerValue;

  // The picker counts from 1 and graph indices from 0. These two are the only
  // places that offset is written.
  static int graphIndexOf(int pickerValue) => pickerValue - 1;
  static int pickerValueOf(int graphIndex) => graphIndex + 1;

  /// The picked graph, 0-based, as the domain counts them.
  int get currentGraphIndex => graphIndexOf(_currentPickerValue);

  void setPickerValue(int newValue) {
    if (newValue == _currentPickerValue) return;
    if (_graphBarDataList.isEmpty) return;
    if (newValue < 1 || newValue > _graphBarDataList.length) return;

    _currentPickerValue = newValue;
    notifyListeners();
  }

  /// The counts so far this session, for the app bar. The controller keeps the
  /// session's own copy, which is what the result page gets.
  SessionResults _results = SessionResults.empty();
  SessionResults get results => _results;

  void setResults(SessionResults results) {
    _results = results;
    notifyListeners();
  }

  // Playlist paths and index
  List<String> _playlistPaths = const [];
  List<String> get playlistPaths => _playlistPaths;

  int _currentPlayingAudioIndex = 0;
  int get currentPlayingAudioIndex => _currentPlayingAudioIndex;

  String? get currentClipPath =>
      (_playlistPaths.isNotEmpty && _currentPlayingAudioIndex >= 0 && _currentPlayingAudioIndex < _playlistPaths.length)
          ? _playlistPaths[_currentPlayingAudioIndex]
          : null;

  // --- Frequency/Graph lifecycle ---

  /// Shows [layout]'s graphs and puts the picker back on the first.
  void applyLayout(BandLayout layout) {
    final computed = FrequencyCalculator.compute(layout);

    _layout = layout;
    _centerFreqLinearList = List<double>.from(computed.centerFreqLinearList);
    _graphBarDataList = List<LineChartBarData>.from(computed.graphBarDataList);

    // Reset picker to 1 and ensure first graph highlighted (blue) by calculator
    resetPickerValue();

    // Notify listeners so widgets that depend on the graph data (e.g. the
    // picker's max value) rebuild: resetPickerValue() alone early-returns
    // without notifying when the picker was already at 1, which would leave
    // the picker range stale after a band count change.
    notifyListeners();
  }

  void updatePickerValue(int newValue) {
    setPickerValue(newValue);
  }

  void resetPickerValue() {
    setPickerValue(1);
  }

  bool _disposed = false;

  /// Whether the session page that owned this store has closed. Work that
  /// finishes after an await checks it, since writing to a disposed notifier
  /// asserts.
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // --- Playlist controls ---
  void setPlaylistPaths(List<String> paths) {
    _playlistPaths = List<String>.from(paths);
    _currentPlayingAudioIndex = 0;
    notifyListeners();
  }

  void clearPlaylist() {
    _playlistPaths = const [];
    _currentPlayingAudioIndex = 0;
    notifyListeners();
  }

  /// Repoints the entry at [index] at [path].
  ///
  /// The snapshot taken at launch goes stale when a background task rewrites
  /// a clip to another format mid-session (see
  /// `ClipLibrary.resolvePath`). Writing the resolved path back means
  /// the lookup is paid once per clip rather than on every visit to it.
  void updatePathAt(int index, String path) {
    if (index < 0 || index >= _playlistPaths.length) return;
    if (_playlistPaths[index] == path) return;
    _playlistPaths = List<String>.from(_playlistPaths)..[index] = path;
    notifyListeners();
  }

  void setCurrentPlayingIndex(int index) {
    if (_playlistPaths.isEmpty) {
      _currentPlayingAudioIndex = 0;
    } else {
      _currentPlayingAudioIndex = index.clamp(0, _playlistPaths.length - 1);
    }
    notifyListeners();
  }

  void nextTrack() {
    if (_playlistPaths.isEmpty) return;
    _currentPlayingAudioIndex = (_currentPlayingAudioIndex + 1) % _playlistPaths.length;
    notifyListeners();
  }

  void previousTrack({Duration threshold = const Duration(seconds: 3), Duration? currentPosition}) {
    if (_playlistPaths.isEmpty) return;
    // If we're past the threshold into the current track, restart it rather than go back.
    if (currentPosition != null && currentPosition > threshold) return;
    if (_currentPlayingAudioIndex == 0) {
      _currentPlayingAudioIndex = _playlistPaths.length - 1;
    } else {
      _currentPlayingAudioIndex -= 1;
    }
    notifyListeners();
  }
}