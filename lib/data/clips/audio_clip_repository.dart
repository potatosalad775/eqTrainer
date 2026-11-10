import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:eq_trainer/domain/audio_clip.dart';

// Define repository abstraction in repository layer to avoid cyclic deps
abstract class IAudioClipRepository {
  /// True when part of the library could not be read this launch, so the list
  /// may be incomplete.
  bool get hasUnreadableData;
  Future<void> addClip(AudioClip clip);
  // Return all clips (synchronous). ClipLibrary pairs them with files.
  List<AudioClip> getAllClips();
  // Subscribe to changes as a stream, including initial snapshot.
  Stream<List<AudioClip>> watchClips();
  // Delete/toggle by id rather than list index: the index a widget was
  // built with can go stale across an `await` (e.g. a confirmation dialog)
  // if the library changes in the meantime, silently acting on the wrong record.
  Future<void> deleteById(String id);
  Future<void> toggleEnabledById(String id);
  // Repoint a record at a different backing file, keeping everything else.
  // Used by ClipFormatMigration when it rewrites a clip to another format.
  Future<void> updateFileNameById(String id, String fileName);
  // Move the clip at [oldIndex] to [newIndex].
  Future<void> reorder(int oldIndex, int newIndex);
}

/// The clip library, held in memory and saved whole to one JSON file.
///
/// A library is small enough that rewriting it on every change costs nothing,
/// and one list makes order trivial. Open exactly one per file: each instance
/// keeps its own copy, so a second would overwrite the first one's changes.
///
/// Readers see a change immediately, while its save is in flight, so a dragged
/// clip does not snap back for a frame. A completed write means the change is
/// on disk, which is what lets [ClipFormatMigration] delete a source file right
/// after repointing its record. A failed write throws and rolls the change back.
class AudioClipRepository implements IAudioClipRepository {
  AudioClipRepository._(this._file, this._clips, this._hasUnreadableData);

  /// Loads [file]. A missing file is an empty library.
  ///
  /// An unreadable one is copied aside before the next save can replace it, and
  /// the library starts empty so the app still opens. Saves are atomic, so this
  /// takes outside damage rather than a crash.
  static Future<AudioClipRepository> open(File file) async {
    try {
      final clips = await file.exists() ? await _read(file) : const <AudioClip>[];
      return AudioClipRepository._(file, clips, false);
    } catch (e) {
      debugPrint('[AudioClipRepository] "${file.path}" is unreadable ($e).');
      try {
        await file.copy('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      } catch (_) {}
      return AudioClipRepository._(file, const [], true);
    }
  }

  final File _file;
  final _changes = StreamController<List<AudioClip>>.broadcast(sync: true);
  List<AudioClip> _clips;
  bool _hasUnreadableData;

  // Writes run strictly one at a time, so each sees the result of the last and
  // two saves never share the temp file.
  Future<void> _tail = Future.value();

  static Future<List<AudioClip>> _read(File file) async {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return List.unmodifiable([
      for (final clip in json['clips'] as List<dynamic>)
        AudioClip.fromJson(clip as Map<String, dynamic>),
    ]);
  }

  /// Flags the library as incomplete, for a problem found outside this class.
  void markUnreadable() => _hasUnreadableData = true;

  @override
  bool get hasUnreadableData => _hasUnreadableData;

  @override
  List<AudioClip> getAllClips() => _clips;

  @override
  Stream<List<AudioClip>> watchClips() => Stream.multi((controller) {
        controller.add(_clips);
        final sub = _changes.stream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });

  @override
  Future<void> addClip(AudioClip clip) => _commit((clips) => [...clips, clip]);

  @override
  Future<void> deleteById(String id) => _commit((clips) =>
      clips.any((c) => c.id == id) ? clips.where((c) => c.id != id).toList() : null);

  @override
  Future<void> toggleEnabledById(String id) =>
      _replace(id, (clip) => clip.copyWith(isEnabled: !clip.isEnabled));

  @override
  Future<void> updateFileNameById(String id, String fileName) =>
      _replace(id, (clip) => clip.copyWith(fileName: fileName));

  @override
  Future<void> reorder(int oldIndex, int newIndex) => _commit((clips) {
        if (oldIndex < 0 || oldIndex >= clips.length) return null;
        final target = newIndex.clamp(0, clips.length - 1);
        if (oldIndex == target) return null;
        final moved = [...clips];
        moved.insert(target, moved.removeAt(oldIndex));
        return moved;
      });

  /// Merges clips read from the old Hive box into the library, then proves the
  /// result reached the disk.
  ///
  /// Safe to repeat. A clip already here wins over its old record, since it may
  /// have been converted since, and a clip only here (imported while the old box
  /// was unreadable) is kept.
  Future<void> mergeLegacy(List<AudioClip> legacy) async {
    await _commit((clips) {
      final current = {for (final clip in clips) clip.id: clip};
      final legacyIds = {for (final clip in legacy) clip.id};
      return [
        for (final clip in legacy) current[clip.id] ?? clip,
        ...clips.where((clip) => !legacyIds.contains(clip.id)),
      ];
    });
    if (!listEquals(await _read(_file), _clips)) {
      throw const FileSystemException('saved library does not match');
    }
  }

  Future<void> _replace(String id, AudioClip Function(AudioClip) change) =>
      _commit((clips) => clips.any((c) => c.id == id)
          ? [for (final clip in clips) clip.id == id ? change(clip) : clip]
          : null);

  /// Queues [change], which returns the new list, or null if nothing changed.
  Future<void> _commit(List<AudioClip>? Function(List<AudioClip>) change) {
    final result = _tail.then((_) async {
      final previous = _clips;
      final next = change(previous);
      if (next == null) return;
      _publish(List.unmodifiable(next));
      try {
        await _save();
      } catch (_) {
        _publish(previous);
        rethrow;
      }
    });
    // A failed write fails its own caller, not the writes queued behind it.
    _tail = result.catchError((_) {});
    return result;
  }

  void _publish(List<AudioClip> clips) {
    _clips = clips;
    _changes.add(clips);
  }

  /// Writes to a temp file and renames it over the real one, so a crash leaves
  /// either the old library or the new one, never half of either.
  Future<void> _save() async {
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({'clips': _clips}),
      flush: true,
    );
    await temp.rename(_file.path);
  }
}
