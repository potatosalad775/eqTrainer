// Cuts a release in one step: checks, then one commit that bumps `version:` in
// pubspec.yaml and dates the CHANGELOG.md entry, then tag vX.Y.Z, push, and
// publish the GitHub release. Publishing starts .github/workflows/build.yml,
// which builds every platform, attaches the downloads, uploads the Play bundle
// and then adds the entry to appcast.xml. Nothing is built here.
//
//   fvm dart run tool/release.dart <patch | minor | major | X.Y.Z> [--prerelease] [--yes]
//
//   --prerelease  publish as a pre-release, which the workflow keeps out of
//                 appcast.xml, so installed copies are not told about it
//   --yes         don't ask before pushing
//
// Needs a clean master that is up to date with origin, the GitHub CLI signed in
// (`gh auth login`), and a `## vX.Y.Z [YYYY-MM-DD]` entry in CHANGELOG.md, already
// committed. Its date is rewritten to today.

import 'dart:io';

import 'changelog.dart';

const _usage = 'Usage: fvm dart run tool/release.dart '
    '<patch | minor | major | X.Y.Z> [--prerelease] [--yes]';
const _branch = 'master';

/// [current] (`X.Y.Z`) after [bump], which is `patch`, `minor`, `major` or an
/// explicit `X.Y.Z`.
String nextVersion(String current, String bump) {
  final semver = RegExp(r'^\d+\.\d+\.\d+$');
  if (semver.hasMatch(bump)) return bump;
  if (!semver.hasMatch(current)) {
    throw FormatException('pubspec.yaml: version "$current" is not X.Y.Z');
  }
  final parts = current.split('.').map(int.parse).toList();
  switch (bump) {
    case 'major':
      return '${parts[0] + 1}.0.0';
    case 'minor':
      return '${parts[0]}.${parts[1] + 1}.0';
    case 'patch':
      return '${parts[0]}.${parts[1]}.${parts[2] + 1}';
  }
  throw const FormatException(_usage);
}

/// The build number after [current]: today as YYMMDD, which is what earlier
/// releases used. Play refuses a versionCode that does not go up, so a second
/// release on one day takes the next number instead.
int nextBuildNumber(int current, DateTime today) {
  final dated = (today.year % 100) * 10000 + today.month * 100 + today.day;
  return dated > current ? dated : current + 1;
}

final _versionLine = RegExp(r'^version:[ \t]*(\d+\.\d+\.\d+)\+(\d+)', multiLine: true);

/// The `X.Y.Z` and build number of a pubspec.
(String, int) pubspecVersion(String pubspec) {
  final match = _versionLine.firstMatch(pubspec);
  if (match == null) {
    throw const FormatException(
        'pubspec.yaml has no "version: X.Y.Z+BUILD" line');
  }
  return (match.group(1)!, int.parse(match.group(2)!));
}

String setPubspecVersion(String pubspec, String version, int build) {
  pubspecVersion(pubspec);
  return pubspec.replaceFirst(_versionLine, 'version: $version+$build');
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

// Everything below runs the release.

final _root = Directory.fromUri(Platform.script.resolve('..')).path;

Never _fail(String message) {
  stderr.writeln('error: $message');
  exit(1);
}

/// Runs a command with its output on the terminal; exits on failure, with
/// [hint] if given. Only `fvm` goes through a shell, since it is a batch file
/// on Windows: its arguments here hold nothing a shell would split or read.
Future<void> _step(String title, String command, List<String> args,
    {String hint = ''}) async {
  stdout.writeln('\n==> $title');
  final process = await Process.start(
    command,
    args,
    workingDirectory: _root,
    runInShell: command == 'fvm',
    mode: ProcessStartMode.inheritStdio,
  );
  if (await process.exitCode != 0) {
    _fail('$title failed${hint.isEmpty ? '' : '\n  $hint'}');
  }
}

/// A command's trimmed stdout, or null when it fails.
String? _read(String command, List<String> args) {
  final result = Process.runSync(command, args, workingDirectory: _root);
  return result.exitCode == 0 ? (result.stdout as String).trim() : null;
}

File _file(String name) => File('$_root/$name');

Future<void> main(List<String> args) async {
  final flags = args.where((arg) => arg.startsWith('--')).toSet();
  final positional = args.where((arg) => !arg.startsWith('--')).toList();
  final unknown = flags.difference({'--prerelease', '--yes'});
  if (positional.length != 1 || unknown.isNotEmpty) _fail(_usage);
  final prerelease = flags.contains('--prerelease');

  final now = DateTime.now();
  final today = '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';
  final pubspec = _file('pubspec.yaml').readAsStringSync();
  final String current, version;
  final int build;
  try {
    final (name, number) = pubspecVersion(pubspec);
    current = name;
    version = nextVersion(current, positional.single);
    build = nextBuildNumber(number, now);
  } on FormatException catch (error) {
    _fail(error.message);
  }
  final tag = 'v$version';

  // Everything that can stop a release, before anything changes.
  if (_read('git', ['branch', '--show-current']) != _branch) {
    _fail('Release from $_branch.');
  }
  if (_read('git', ['status', '--porcelain', '--untracked-files=no']) != '') {
    _fail('Commit or stash your changes first.');
  }
  if (_read('gh', ['auth', 'status']) == null) {
    _fail('The GitHub CLI is not signed in: gh auth login');
  }
  await _step('Fetch origin', 'git', ['fetch', 'origin', _branch, '--tags']);
  if (_read('git', ['rev-list', '--count', 'HEAD..origin/$_branch']) != '0') {
    _fail('$_branch is behind origin/$_branch: pull first.');
  }
  if (_read('git', ['rev-parse', '--verify', '--quiet', 'refs/tags/$tag']) !=
      null) {
    _fail('$tag already exists.');
  }
  // The changelog entry is the release's notes everywhere: the tag must carry it.
  if (_read('git', ['ls-files', 'CHANGELOG.md']) != 'CHANGELOG.md') {
    _fail('CHANGELOG.md is not committed.');
  }
  final changelog = _file('CHANGELOG.md').readAsStringSync();
  final String notes, forPlay;
  try {
    final entry = changelogNotes(changelog, version);
    if (entry == null) {
      _fail('CHANGELOG.md has no "## $tag [YYYY-MM-DD]" entry: '
          'add and commit one first.');
    }
    notes = entry;
    forPlay = playNotes(notes);
  } on FormatException catch (error) {
    _fail(error.message);
  }
  // Only what Play gets counts: lines tagged for other platforms are not sent.
  if (forPlay.length > playNotesLimit) {
    _fail('The $tag notes for Play are ${forPlay.length} characters; '
        'Play takes at most $playNotesLimit.');
  }
  await _step('Analyze', 'fvm', ['flutter', 'analyze']);
  await _step('Tests', 'fvm', ['flutter', 'test', 'test/']);

  stdout.writeln(
    '\neqTrainer $current -> $version+$build${prerelease ? ' (pre-release)' : ''}'
    '\n\n$notes\n\n'
    '${forPlay == notes ? '' : forPlay.isEmpty ? 'Play gets no notes: no line is for Android.\n\n' : 'Play gets:\n$forPlay\n\n'}'
    'Pushes the release commit and tag to origin and publishes the GitHub release, which\n'
    'builds every platform, attaches the downloads and uploads the Play bundle'
    '${prerelease ? '.\nappcast.xml stays as it is.' : ',\nthen adds this entry to appcast.xml on $_branch.'}',
  );
  if (!flags.contains('--yes')) {
    stdout.write('Release $tag? [y/N] ');
    final answer = stdin.readLineSync()?.trim() ?? '';
    if (!RegExp(r'^y(es)?$', caseSensitive: false).hasMatch(answer)) {
      _fail('Cancelled; nothing changed.');
    }
  }

  _file('pubspec.yaml')
      .writeAsStringSync(setPubspecVersion(pubspec, version, build));
  _file('CHANGELOG.md')
      .writeAsStringSync(stampChangelogDate(changelog, version, today));

  // Files, not -m and --notes: no argument then needs quoting on any platform.
  final temp = Directory.systemTemp.createTempSync('eqtrainer-release-');
  final message = File('${temp.path}/message.txt')
    ..writeAsStringSync('chore(release): $tag\n');
  final notesFile = File('${temp.path}/notes.md')
    ..writeAsStringSync('$notes\n');

  const undo = 'Undo the edits with: git checkout -- pubspec.yaml CHANGELOG.md';
  await _step('Commit', 'git',
      ['commit', '-F', message.path, 'pubspec.yaml', 'CHANGELOG.md'],
      hint: undo);
  await _step('Tag $tag', 'git', ['tag', tag],
      hint: 'The release commit is local and untagged.');
  final push = ['push', '--atomic', 'origin', _branch, 'refs/tags/$tag'];
  await _step('Push', 'git', push,
      hint: 'The release commit and $tag are local. Retry: git ${push.join(' ')}');
  // gh puts these notes above the generated ones (merged PRs and the compare link).
  final release = [
    'release', 'create', tag, '--verify-tag', '--notes-file', notesFile.path, //
    '--generate-notes', '--title', tag, if (prerelease) '--prerelease',
  ];
  await _step('Publish the GitHub release', 'gh', release,
      hint: '$tag is pushed. Retry: gh ${release.join(' ')}');
  temp.deleteSync(recursive: true);

  final repo = _read('gh', ['repo', 'view', '--json', 'url', '--jq', '.url']);
  stdout.writeln('\n$tag published. The build workflow attaches the downloads'
      '${repo == null ? '.' : ': $repo/actions'}'
      '${prerelease ? '' : '\nIt commits appcast.xml to $_branch when it is done: pull before your next push.'}');
}
