import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/changelog.dart';
import '../../tool/release.dart';

const _changelog = '''
# CHANGELOG

## v2.7.0 [2026-11-11]
- Added a thing.
- Fixed <another> & more.

## v2.6.0 [2026-09-01]
- Older.
''';

void main() {
  group('changelog', () {
    test('finds an entry with or without the v', () {
      const notes = '- Added a thing.\n- Fixed <another> & more.';
      expect(changelogNotes(_changelog, '2.7.0'), notes);
      expect(changelogNotes(_changelog, 'v2.7.0'), notes);
      expect(changelogNotes(_changelog, '2.6.0'), '- Older.');
    });

    test('reads CRLF files', () {
      expect(changelogNotes(_changelog.replaceAll('\n', '\r\n'), '2.6.0'),
          '- Older.');
    });

    test('has no notes for a missing or empty entry', () {
      expect(changelogNotes(_changelog, '9.9.9'), isNull);
      expect(changelogNotes('## v1.0.0 [2026-01-01]\n\n', '1.0.0'), isNull);
    });

    test('refuses a malformed heading rather than hiding its entry', () {
      expect(() => parseChangelog('## 2.7.0\n- x'), throwsFormatException);
      expect(() => parseChangelog('## v2.7.0 [soon]\n- x'),
          throwsFormatException);
    });

    test('dates only the entry being released', () {
      final stamped = stampChangelogDate(_changelog, '2.7.0', '2026-12-24');
      expect(stamped, contains('## v2.7.0 [2026-12-24]'));
      expect(stamped, contains('## v2.6.0 [2026-09-01]'));
    });

    test('the real file parses, and every entry fits Play', () {
      for (final entry
          in parseChangelog(File('CHANGELOG.md').readAsStringSync())) {
        expect(entry.notes, isNotEmpty, reason: entry.version);
        expect(playNotes(entry.notes).length,
            lessThanOrEqualTo(playNotesLimit),
            reason: entry.version);
      }
    });
  });

  group('play notes', () {
    test('drop lines tagged for other platforms, keep the rest', () {
      expect(
          playNotes('- For everyone.\n'
              '- [Windows] Added an installer.\n'
              '- [Windows, Linux] Desktop only.\n'
              '- [Desktop] One copy at a time.\n'
              '- Also for everyone.'),
          '- For everyone.\n- Also for everyone.');
    });

    test('keep a line tagged for Android, without the tag', () {
      expect(playNotes('- [Android] Fixed the backend.'),
          '- Fixed the backend.');
      expect(playNotes('- [Android, iOS] Fixed rotation.'),
          '- Fixed rotation.');
    });

    test('are empty when nothing is for Android', () {
      expect(playNotes('- [Linux] Dropped GStreamer.'), isEmpty);
    });

    test('refuse an unknown tag rather than guess', () {
      expect(() => playNotes('- [Widnows] Typo.'), throwsFormatException);
    });

    test('leave links and mid-line brackets alone', () {
      const notes = '- [Docs](https://example.com) moved.\n- See [Windows].';
      expect(playNotes(notes), notes);
    });
  });

  group('version', () {
    test('bumps', () {
      expect(nextVersion('2.6.3', 'patch'), '2.6.4');
      expect(nextVersion('2.6.3', 'minor'), '2.7.0');
      expect(nextVersion('2.6.3', 'major'), '3.0.0');
      expect(nextVersion('2.6.3', '4.5.6'), '4.5.6');
      expect(() => nextVersion('2.6.3', 'huge'), throwsFormatException);
    });

    test('build number is the date, but always goes up', () {
      expect(nextBuildNumber(260901, DateTime(2026, 11, 11)), 261111);
      expect(nextBuildNumber(261111, DateTime(2026, 11, 11)), 261112);
    });

    test('rewrites only the version line, keeping line endings', () {
      const pubspec = 'name: eq_trainer\r\nversion: 2.6.0+260901\r\n\r\n'
          'environment:\r\n';
      expect(pubspecVersion(pubspec), ('2.6.0', 260901));
      expect(
          setPubspecVersion(pubspec, '2.7.0', 261111),
          'name: eq_trainer\r\nversion: 2.7.0+261111\r\n\r\n'
          'environment:\r\n');
      expect(() => setPubspecVersion('name: x\n', '1.0.0', 1),
          throwsFormatException);
    });
  });
}
