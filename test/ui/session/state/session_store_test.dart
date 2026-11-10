import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';

void main() {
  group('SessionStore', () {
    late SessionStore store;

    setUp(() {
      store = SessionStore();
    });

    // -------------------------------------------------------------------------
    // Layout and picker
    // -------------------------------------------------------------------------
    group('applyLayout', () {
      test('shows one curve per graph of the layout', () {
        store.applyLayout(BandLayout(4, FilterType.peakDip));
        expect(store.graphBarDataList, hasLength(8));
        expect(store.centerFreqLinearList, hasLength(4));
        expect(store.layout, equals(BandLayout(4, FilterType.peakDip)));
      });

      test('puts the picker back on the first graph', () {
        store.applyLayout(BandLayout(4, FilterType.peak));
        store.setPickerValue(3);
        store.applyLayout(BandLayout(5, FilterType.peak));
        expect(store.currentPickerValue, 1);
        expect(store.currentGraphIndex, 0);
      });

      test('notifies even when the picker was already on the first graph', () {
        store.applyLayout(BandLayout(4, FilterType.peak));
        var notifications = 0;
        store.addListener(() => notifications++);
        store.applyLayout(BandLayout(5, FilterType.peak));
        expect(notifications, greaterThan(0));
      });

      test('has no layout to give before one is applied', () {
        expect(() => store.layout, throwsStateError);
      });
    });

    group('picker', () {
      setUp(() => store.applyLayout(BandLayout(3, FilterType.peak)));

      test('counts from 1, and the graph index from 0', () {
        store.setPickerValue(3);
        expect(store.currentPickerValue, 3);
        expect(store.currentGraphIndex, 2);
        expect(SessionStore.graphIndexOf(3), 2);
        expect(SessionStore.pickerValueOf(2), 3);
      });

      test('ignores a value outside the graphs', () {
        store.setPickerValue(4);
        store.setPickerValue(0);
        expect(store.currentPickerValue, 1);
      });

      test('does nothing before any graphs are shown', () {
        final fresh = SessionStore();
        fresh.setPickerValue(2);
        expect(fresh.currentPickerValue, 1);
      });
    });

    group('results', () {
      test('start empty', () {
        expect(store.results.rounds, 0);
      });

      test('hold the latest counts and notify', () {
        var notifications = 0;
        store.addListener(() => notifications++);
        final results = SessionResults.empty()
            .withRound(ResultBand.treble, isCorrect: true);

        store.setResults(results);

        expect(store.results, same(results));
        expect(notifications, 1);
      });
    });

    // -------------------------------------------------------------------------
    // Playlist management
    // -------------------------------------------------------------------------
    group('setPlaylistPaths', () {
      test('stores the provided paths', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac']);
        expect(store.playlistPaths, equals(['/a.flac', '/b.flac']));
      });

      test('resets currentPlayingAudioIndex to 0', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac', '/c.flac']);
        store.nextTrack(); // index → 1
        store.setPlaylistPaths(['/x.flac']);
        expect(store.currentPlayingAudioIndex, equals(0));
      });
    });

    group('clearPlaylist', () {
      test('empties playlistPaths', () {
        store.setPlaylistPaths(['/a.flac']);
        store.clearPlaylist();
        expect(store.playlistPaths, isEmpty);
      });

      test('currentClipPath is null after clear', () {
        store.setPlaylistPaths(['/a.flac']);
        store.clearPlaylist();
        expect(store.currentClipPath, isNull);
      });
    });

    group('setCurrentPlayingIndex', () {
      test('clamps to 0 when playlist is empty', () {
        store.setCurrentPlayingIndex(5);
        expect(store.currentPlayingAudioIndex, equals(0));
      });

      test('clamps to last index when value is too large', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac', '/c.flac']);
        store.setCurrentPlayingIndex(100);
        expect(store.currentPlayingAudioIndex, equals(2));
      });

      test('clamps to 0 when value is negative', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac']);
        store.setCurrentPlayingIndex(-1);
        expect(store.currentPlayingAudioIndex, equals(0));
      });

      test('sets valid index within bounds', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac', '/c.flac']);
        store.setCurrentPlayingIndex(2);
        expect(store.currentPlayingAudioIndex, equals(2));
      });
    });

    // The launch snapshot goes stale when a background pass rewrites a clip
    // to another format mid-session; the resolved path is written back here
    // so the lookup is paid once per clip rather than on every visit.
    group('updatePathAt', () {
      test('repoints the entry it names and leaves the rest alone', () {
        store.setPlaylistPaths(['/a.m4a', '/b.flac']);
        store.updatePathAt(0, '/a.opus');
        expect(store.playlistPaths, equals(['/a.opus', '/b.flac']));
      });

      test('is what currentClipPath reads back', () {
        store.setPlaylistPaths(['/a.m4a', '/b.flac']);
        store.updatePathAt(0, '/a.opus');
        expect(store.currentClipPath, equals('/a.opus'));
      });

      test('ignores an out-of-range index', () {
        store.setPlaylistPaths(['/a.flac']);
        store.updatePathAt(5, '/x.flac');
        store.updatePathAt(-1, '/x.flac');
        expect(store.playlistPaths, equals(['/a.flac']));
      });

      test('does not notify when the path is unchanged', () {
        store.setPlaylistPaths(['/a.flac']);
        var notifications = 0;
        store.addListener(() => notifications++);
        store.updatePathAt(0, '/a.flac');
        expect(notifications, isZero);
      });
    });

    group('nextTrack', () {
      test('is no-op when playlist is empty', () {
        store.nextTrack();
        expect(store.currentPlayingAudioIndex, equals(0));
      });

      test('advances index by 1', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac', '/c.flac']);
        store.nextTrack();
        expect(store.currentPlayingAudioIndex, equals(1));
      });

      test('wraps around from last to first', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac']);
        store.nextTrack(); // 0 → 1
        store.nextTrack(); // 1 → 0 (wrap)
        expect(store.currentPlayingAudioIndex, equals(0));
      });
    });

    group('previousTrack', () {
      test('is no-op when playlist is empty', () {
        store.previousTrack();
        expect(store.currentPlayingAudioIndex, equals(0));
      });

      test('decrements index by 1', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac', '/c.flac']);
        store.nextTrack(); // 0 → 1
        store.previousTrack(); // 1 → 0
        expect(store.currentPlayingAudioIndex, equals(0));
      });

      test('wraps from first to last', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac', '/c.flac']);
        store.previousTrack(); // 0 → 2 (wrap)
        expect(store.currentPlayingAudioIndex, equals(2));
      });

      // Deep into a track, "previous" means restart it, not jump back. The
      // store only decides whether to move the index; the caller seeks.
      test('stays on the current track when past the restart threshold', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac', '/c.flac']);
        store.nextTrack(); // 0 → 1
        store.previousTrack(currentPosition: const Duration(seconds: 10));
        expect(store.currentPlayingAudioIndex, equals(1));
      });

      test('goes back when still inside the restart threshold', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac', '/c.flac']);
        store.nextTrack(); // 0 → 1
        store.previousTrack(currentPosition: const Duration(seconds: 1));
        expect(store.currentPlayingAudioIndex, equals(0));
      });

      test('exactly at the threshold still goes back', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac']);
        store.nextTrack();
        store.previousTrack(
          threshold: const Duration(seconds: 3),
          currentPosition: const Duration(seconds: 3),
        );
        expect(store.currentPlayingAudioIndex, equals(0));
      });

      test('honours a custom threshold', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac']);
        store.nextTrack();
        store.previousTrack(
          threshold: const Duration(seconds: 1),
          currentPosition: const Duration(seconds: 2),
        );
        expect(store.currentPlayingAudioIndex, equals(1));
      });

      test('does not notify when it decides to restart instead', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac']);
        store.nextTrack();
        var notifications = 0;
        store.addListener(() => notifications++);
        store.previousTrack(currentPosition: const Duration(seconds: 10));
        expect(notifications, isZero);
      });
    });

    group('currentClipPath', () {
      test('returns null when playlist is empty', () {
        expect(store.currentClipPath, isNull);
      });

      test('returns path at currentPlayingAudioIndex', () {
        store.setPlaylistPaths(['/a.flac', '/b.flac']);
        expect(store.currentClipPath, equals('/a.flac'));
        store.nextTrack();
        expect(store.currentClipPath, equals('/b.flac'));
      });
    });
  });
}
