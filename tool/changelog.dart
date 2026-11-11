// Reads a version's entry from CHANGELOG.md, the one source of a release's notes:
// tool/release.dart refuses to release a version without one, publishes it as the
// GitHub release's notes and copies it into appcast.xml, and the build workflow
// hands it to Play as "What's new". An entry is a `## vX.Y.Z [YYYY-MM-DD]` heading
// followed by its lines, up to the next `## `.
//
// A line can start with a platform tag, `- [Windows] ...` or `- [Windows, Linux] ...`.
// GitHub and the appcast show it as written; Play only gets the lines for Android.
//
//   fvm dart run tool/changelog.dart <X.Y.Z>          prints the entry's notes; exits 1 when there is none
//   fvm dart run tool/changelog.dart <X.Y.Z> --play   prints them as Play gets them

import 'dart:io';

/// Play rejects release notes longer than this, per language.
const playNotesLimit = 500;

final _heading = RegExp(r'^## v(\d+\.\d+\.\d+) \[(\d{4}-\d{2}-\d{2})\]\s*$');

class ChangelogEntry {
  ChangelogEntry(this.version, this.date, this.notes);

  final String version;
  final String date;
  final String notes;
}

/// The entries of a changelog, in the order written. A `## ` line that is not a
/// well-formed heading throws, so a typo cannot hide an entry from the release.
List<ChangelogEntry> parseChangelog(String text) {
  final entries = <ChangelogEntry>[];
  RegExpMatch? open;
  var lines = <String>[];
  void close() {
    final heading = open;
    if (heading != null) {
      entries.add(ChangelogEntry(
          heading.group(1)!, heading.group(2)!, lines.join('\n').trim()));
    }
    lines = [];
  }

  for (final line in text.split(RegExp(r'\r?\n'))) {
    if (!line.startsWith('## ')) {
      lines.add(line);
      continue;
    }
    final match = _heading.firstMatch(line);
    if (match == null) {
      throw FormatException(
          'CHANGELOG.md: "$line" isn\'t "## vX.Y.Z [YYYY-MM-DD]"');
    }
    close();
    open = match;
  }
  close();
  return entries;
}

/// The notes of [version] (`1.2.3` or `v1.2.3`), or null when there is no entry
/// for it or the entry is empty.
String? changelogNotes(String text, String version) {
  final wanted = version.replaceFirst(RegExp('^v'), '');
  for (final entry in parseChangelog(text)) {
    if (entry.version == wanted) return entry.notes.isEmpty ? null : entry.notes;
  }
  return null;
}

/// The platforms a line can be marked for. `Desktop` is Windows, macOS and Linux.
const platformTags = {'Android', 'iOS', 'Windows', 'macOS', 'Linux', 'Desktop'};

// `- [Windows] ...` or `- [Windows, Linux] ...`, but not a `[link](url)`.
final _tagged = RegExp(r'^(\s*[-*]\s+)\[([^\]]*)\](?!\()\s*(.*)$');

/// [notes] as Play gets them. A line that starts with a platform tag, as in
/// `- [Windows] Added an installer.`, is only for those platforms: it is dropped
/// unless `Android` is among them, and then loses the tag. Untagged lines are for
/// every platform. A tag that is not in [platformTags] throws, so a typo cannot
/// send a line to the wrong place. Empty when no line is for Android.
String playNotes(String notes) {
  final kept = <String>[];
  for (final line in notes.split(RegExp(r'\r?\n'))) {
    final match = _tagged.firstMatch(line);
    if (match == null) {
      kept.add(line);
      continue;
    }
    final tags = match.group(2)!.split(',').map((tag) => tag.trim()).toSet();
    final unknown = tags.difference(platformTags);
    if (unknown.isNotEmpty) {
      throw FormatException('CHANGELOG.md: "[${match.group(2)}]" is not a '
          'platform tag. Use ${platformTags.join(', ')}.');
    }
    if (tags.contains('Android')) kept.add('${match.group(1)}${match.group(3)}');
  }
  return kept.join('\n').trim();
}

/// [text] with the heading of [version] dated [date], so an entry written ahead
/// of time carries the day it shipped. Unchanged when there is no such entry.
String stampChangelogDate(String text, String version, String date) {
  final heading = RegExp(
    '^## v${RegExp.escape(version)} \\[\\d{4}-\\d{2}-\\d{2}\\]',
    multiLine: true,
  );
  return text.replaceFirst(heading, '## v$version [$date]');
}

File changelogFile() =>
    File.fromUri(Platform.script.resolve('../CHANGELOG.md'));

void main(List<String> args) {
  final play = args.contains('--play');
  final versions = args.where((arg) => arg != '--play').toList();
  if (versions.length != 1) {
    stderr.writeln('Usage: dart run tool/changelog.dart <X.Y.Z> [--play]');
    exit(1);
  }
  final label = 'v${versions.single.replaceFirst(RegExp('^v'), '')}';
  String? notes;
  try {
    notes = changelogNotes(changelogFile().readAsStringSync(), versions.single);
    if (notes != null && play) notes = playNotes(notes);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exit(1);
  }
  if (notes == null) {
    stderr.writeln('CHANGELOG.md has no entry for $label');
    exit(1);
  }
  if (notes.isEmpty) {
    stderr.writeln('The $label entry has no line for Android');
    exit(1);
  }
  stdout.writeln(notes);
}
