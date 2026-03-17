import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';

void main() {
  group('SessionStore', () {
    late SessionStore store;

    setUp(() {
      store = SessionStore();
    });

    // -------------------------------------------------------------------------
    // resultPercentage
    // -------------------------------------------------------------------------
    group('resultPercentage', () {
      test('returns 0.0 when no sessions have been played', () {
        expect(store.resultPercentage, equals(0.0));
      });

      test('returns 100.0 when all answers are correct', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        expect(store.resultPercentage, equals(100.0));
      });

      test('returns 0.0 when all answers are incorrect', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        expect(store.resultPercentage, equals(0.0));
      });

      test('returns 50.0 for half correct', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        expect(store.resultPercentage, equals(50.0));
      });
    });

    // -------------------------------------------------------------------------
    // getResultPercentagePerFreq
    // -------------------------------------------------------------------------
    group('getResultPercentagePerFreq', () {
      test('returns "-" for negative index', () {
        expect(store.getResultPercentagePerFreq(-1), equals('-'));
      });

      test('returns "-" for index >= 7', () {
        expect(store.getResultPercentagePerFreq(7), equals('-'));
      });

      test('returns "-" when no attempts for that band', () {
        expect(store.getResultPercentagePerFreq(0), equals('-'));
      });

      test('returns "100.00%" when all attempts for a band are correct', () {
        // 440 Hz falls in band 3 (Centre-Midrange: 200–800 Hz? No, 800–1500)
        // 440 Hz: 200 <= 440 < 800 → band 2 (Lower-Midrange)
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        expect(store.getResultPercentagePerFreq(2), equals('100.00%'));
      });

      test('returns "0.00%" when all attempts for a band are incorrect', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        expect(store.getResultPercentagePerFreq(2), equals('0.00%'));
      });

      test('returns "50.00%" for half correct in a band', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        expect(store.getResultPercentagePerFreq(2), equals('50.00%'));
      });
    });

    // -------------------------------------------------------------------------
    // applySubmission — counters
    // -------------------------------------------------------------------------
    group('applySubmission', () {
      test('correct answer increments resultCorrect', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        expect(store.resultCorrect, equals(1));
      });

      test('correct answer increments elapsedSession', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        expect(store.elapsedSession, equals(1));
      });

      test('correct answer increments currentSessionPoint', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        expect(store.currentSessionPoint, equals(1));
      });

      test('incorrect answer increments resultIncorrect', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        expect(store.resultIncorrect, equals(1));
      });

      test('incorrect answer increments elapsedSession', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        expect(store.elapsedSession, equals(1));
      });

      test('incorrect answer decrements currentSessionPoint', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        expect(store.currentSessionPoint, equals(-1));
      });

      test('multiple mixed answers accumulate correctly', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        expect(store.elapsedSession, equals(3));
        expect(store.resultCorrect, equals(2));
        expect(store.resultIncorrect, equals(1));
        expect(store.currentSessionPoint, equals(1)); // +1 -1 +1
      });
    });

    // -------------------------------------------------------------------------
    // applySubmission — frequency band routing
    // -------------------------------------------------------------------------
    group('applySubmission — frequency band index', () {
      // Band boundaries:
      // 0: Sub-Bass       20 <= f < 80
      // 1: Mid-Bass       80 <= f < 200
      // 2: Lower-Midrange 200 <= f < 800
      // 3: Centre-Midrange 800 <= f < 1500
      // 4: Upper-Midrange 1500 <= f < 5000
      // 5: Treble         5000 <= f < 10000
      // 6: Upper-Treble   f >= 10000

      void applyAndCheckBand(double freq, int expectedBand) {
        final freshStore = SessionStore();
        freshStore.applySubmission(centerFreq: freq, isCorrect: true);
        expect(freshStore.elapsedSessionPerFreq[expectedBand], equals(1),
            reason: '$freq Hz should map to band $expectedBand');
      }

      test('20 Hz → band 0 (Sub-Bass)', () => applyAndCheckBand(20.0, 0));
      test('50 Hz → band 0 (Sub-Bass)', () => applyAndCheckBand(50.0, 0));
      test('79 Hz → band 0 (Sub-Bass boundary)', () => applyAndCheckBand(79.0, 0));
      test('80 Hz → band 1 (Mid-Bass boundary)', () => applyAndCheckBand(80.0, 1));
      test('100 Hz → band 1 (Mid-Bass)', () => applyAndCheckBand(100.0, 1));
      test('199 Hz → band 1 (Mid-Bass boundary)', () => applyAndCheckBand(199.0, 1));
      test('200 Hz → band 2 (Lower-Midrange boundary)', () => applyAndCheckBand(200.0, 2));
      test('440 Hz → band 2 (Lower-Midrange)', () => applyAndCheckBand(440.0, 2));
      test('799 Hz → band 2 (Lower-Midrange boundary)', () => applyAndCheckBand(799.0, 2));
      test('800 Hz → band 3 (Centre-Midrange boundary)', () => applyAndCheckBand(800.0, 3));
      test('1000 Hz → band 3 (Centre-Midrange)', () => applyAndCheckBand(1000.0, 3));
      test('1499 Hz → band 3 (Centre-Midrange boundary)', () => applyAndCheckBand(1499.0, 3));
      test('1500 Hz → band 4 (Upper-Midrange boundary)', () => applyAndCheckBand(1500.0, 4));
      test('3000 Hz → band 4 (Upper-Midrange)', () => applyAndCheckBand(3000.0, 4));
      test('4999 Hz → band 4 (Upper-Midrange boundary)', () => applyAndCheckBand(4999.0, 4));
      test('5000 Hz → band 5 (Treble boundary)', () => applyAndCheckBand(5000.0, 5));
      test('8000 Hz → band 5 (Treble)', () => applyAndCheckBand(8000.0, 5));
      test('9999 Hz → band 5 (Treble boundary)', () => applyAndCheckBand(9999.0, 5));
      test('10000 Hz → band 6 (Upper-Treble boundary)', () => applyAndCheckBand(10000.0, 6));
      test('16000 Hz → band 6 (Upper-Treble)', () => applyAndCheckBand(16000.0, 6));
      test('19999 Hz → band 6 (Upper-Treble)', () => applyAndCheckBand(19999.0, 6));
    });

    // -------------------------------------------------------------------------
    // resetResult
    // -------------------------------------------------------------------------
    group('resetResult', () {
      test('resets all counters to zero', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        store.applySubmission(centerFreq: 440.0, isCorrect: false);
        store.resetResult();

        expect(store.elapsedSession, equals(0));
        expect(store.resultCorrect, equals(0));
        expect(store.resultIncorrect, equals(0));
        expect(store.currentSessionPoint, equals(0));
      });

      test('resets per-band counters to zero', () {
        store.applySubmission(centerFreq: 440.0, isCorrect: true);
        store.resetResult();

        for (final count in store.elapsedSessionPerFreq) {
          expect(count, equals(0));
        }
        for (final count in store.correctAnswerPerFreq) {
          expect(count, equals(0));
        }
      });
    });

    // -------------------------------------------------------------------------
    // Session point helpers
    // -------------------------------------------------------------------------
    group('session point helpers', () {
      test('incrementSessionPoint adds 1', () {
        store.incrementSessionPoint();
        expect(store.currentSessionPoint, equals(1));
      });

      test('decrementSessionPoint subtracts 1', () {
        store.decrementSessionPoint();
        expect(store.currentSessionPoint, equals(-1));
      });

      test('resetSessionPoint sets to 0', () {
        store.incrementSessionPoint();
        store.incrementSessionPoint();
        store.resetSessionPoint();
        expect(store.currentSessionPoint, equals(0));
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
