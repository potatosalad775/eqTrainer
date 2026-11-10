import 'dart:collection';

/// The clips a session plays, in order, with a cursor on the one playing.
///
/// Made once when the session starts and then only edited by the session
/// itself: a clip whose file was rewritten is repointed, and one that cannot be
/// played is dropped. Neither reaches the clip library.
class ClipQueue {
  /// [paths] is copied, so the caller's list can change without moving the
  /// queue. The cursor starts on the first.
  ClipQueue(List<String> paths) : _paths = List<String>.of(paths);

  final List<String> _paths;
  int _cursor = 0;

  /// The paths still in the queue, in order.
  List<String> get paths => UnmodifiableListView(_paths);

  int get length => _paths.length;

  bool get isEmpty => _paths.isEmpty;

  /// The path the cursor is on, or null when the queue is empty.
  String? get current => _paths.isEmpty ? null : _paths[_cursor];

  /// Moves to the next clip, and past the last to the first.
  void stepForward() {
    if (_paths.isEmpty) return;
    _cursor = (_cursor + 1) % _paths.length;
  }

  /// Moves to the previous clip, and before the first to the last.
  void stepBack() {
    if (_paths.isEmpty) return;
    _cursor = (_cursor - 1 + _paths.length) % _paths.length;
  }

  /// Points the current entry at [path]. A rewrite keeps a clip's basename and
  /// changes its extension, so this is how the queue follows it.
  void replaceCurrent(String path) {
    if (_paths.isEmpty) return;
    _paths[_cursor] = path;
  }

  /// Drops the current entry for the rest of the session and moves the cursor
  /// on in the direction of travel: going [forward] it lands on the clip that
  /// followed the dropped one, going back on the one before it. Either wraps.
  /// The queue may end up empty.
  void removeCurrent({required bool forward}) {
    if (_paths.isEmpty) return;
    _paths.removeAt(_cursor);
    if (_paths.isEmpty) {
      _cursor = 0;
    } else if (forward) {
      // The next clip slid into the dropped one's place.
      if (_cursor >= _paths.length) _cursor = 0;
    } else {
      _cursor = (_cursor - 1 + _paths.length) % _paths.length;
    }
  }
}
