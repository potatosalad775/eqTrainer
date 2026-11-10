import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/clip_queue.dart';

void main() {
  group('ClipQueue', () {
    test('starts on the first clip', () {
      final queue = ClipQueue(['/a', '/b', '/c']);
      expect(queue.current, '/a');
      expect(queue.length, 3);
      expect(queue.isEmpty, isFalse);
      expect(queue.paths, ['/a', '/b', '/c']);
    });

    test('does not change when the list it was made from does', () {
      final source = ['/a', '/b'];
      final queue = ClipQueue(source);
      source.add('/c');
      source[0] = '/x';
      expect(queue.paths, ['/a', '/b']);
    });

    test('hands out paths that cannot be edited', () {
      final queue = ClipQueue(['/a']);
      expect(() => queue.paths.add('/b'), throwsUnsupportedError);
    });

    group('stepForward', () {
      test('moves to the next clip and wraps after the last', () {
        final queue = ClipQueue(['/a', '/b', '/c']);
        queue.stepForward();
        expect(queue.current, '/b');
        queue.stepForward();
        expect(queue.current, '/c');
        queue.stepForward();
        expect(queue.current, '/a');
      });

      test('stays on a single clip', () {
        final queue = ClipQueue(['/a']);
        queue.stepForward();
        expect(queue.current, '/a');
      });
    });

    group('stepBack', () {
      test('wraps to the last clip from the first, then walks back', () {
        final queue = ClipQueue(['/a', '/b', '/c']);
        queue.stepBack();
        expect(queue.current, '/c');
        queue.stepBack();
        expect(queue.current, '/b');
        queue.stepBack();
        expect(queue.current, '/a');
      });

      test('stays on a single clip', () {
        final queue = ClipQueue(['/a']);
        queue.stepBack();
        expect(queue.current, '/a');
      });
    });

    group('empty', () {
      test('has no current clip and ignores every move', () {
        final queue = ClipQueue([]);
        expect(queue.isEmpty, isTrue);
        expect(queue.length, 0);
        expect(queue.current, isNull);
        queue.stepForward();
        queue.stepBack();
        queue.replaceCurrent('/x');
        queue.removeCurrent(forward: true);
        queue.removeCurrent(forward: false);
        expect(queue.current, isNull);
        expect(queue.paths, isEmpty);
      });
    });

    group('replaceCurrent', () {
      test('repoints the current entry and leaves the rest alone', () {
        final queue = ClipQueue(['/a.m4a', '/b.flac']);
        queue.replaceCurrent('/a.opus');
        expect(queue.paths, ['/a.opus', '/b.flac']);
        expect(queue.current, '/a.opus');
      });

      test('repoints the entry the cursor is on, not the first', () {
        final queue = ClipQueue(['/a', '/b.m4a', '/c']);
        queue.stepForward();
        queue.replaceCurrent('/b.opus');
        expect(queue.paths, ['/a', '/b.opus', '/c']);
      });
    });

    group('removeCurrent going forward', () {
      test('lands on the clip that followed it', () {
        final queue = ClipQueue(['/a', '/b', '/c']);
        queue.stepForward();
        queue.removeCurrent(forward: true);
        expect(queue.paths, ['/a', '/c']);
        expect(queue.current, '/c');
      });

      test('wraps to the first clip when the last was removed', () {
        final queue = ClipQueue(['/a', '/b', '/c']);
        queue.stepBack();
        queue.removeCurrent(forward: true);
        expect(queue.paths, ['/a', '/b']);
        expect(queue.current, '/a');
      });

      test('works from the first clip', () {
        final queue = ClipQueue(['/a', '/b', '/c']);
        queue.removeCurrent(forward: true);
        expect(queue.paths, ['/b', '/c']);
        expect(queue.current, '/b');
      });
    });

    group('removeCurrent going back', () {
      test('lands on the clip before it', () {
        final queue = ClipQueue(['/a', '/b', '/c']);
        queue.stepForward();
        queue.removeCurrent(forward: false);
        expect(queue.paths, ['/a', '/c']);
        expect(queue.current, '/a');
      });

      test('wraps to the last clip when the first was removed', () {
        final queue = ClipQueue(['/a', '/b', '/c']);
        queue.removeCurrent(forward: false);
        expect(queue.paths, ['/b', '/c']);
        expect(queue.current, '/c');
      });

      test('works from the last clip', () {
        final queue = ClipQueue(['/a', '/b', '/c']);
        queue.stepBack();
        queue.removeCurrent(forward: false);
        expect(queue.paths, ['/a', '/b']);
        expect(queue.current, '/b');
      });
    });

    group('removing down to nothing', () {
      for (final forward in [true, false]) {
        test('is empty after the last clip goes, ${forward ? 'forward' : 'back'}',
            () {
          final queue = ClipQueue(['/a', '/b']);
          queue.removeCurrent(forward: forward);
          expect(queue.length, 1);
          queue.removeCurrent(forward: forward);
          expect(queue.isEmpty, isTrue);
          expect(queue.current, isNull);
          // Moving on an emptied queue is as safe as on one never filled.
          queue.stepForward();
          queue.stepBack();
          expect(queue.current, isNull);
        });
      }
    });

    test('keeps stepping correctly after a removal', () {
      final queue = ClipQueue(['/a', '/b', '/c', '/d']);
      queue.stepForward();
      queue.removeCurrent(forward: true); // now on /c
      queue.stepForward();
      expect(queue.current, '/d');
      queue.stepForward();
      expect(queue.current, '/a');
      queue.stepBack();
      queue.stepBack();
      expect(queue.current, '/c');
    });
  });
}
