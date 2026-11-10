// Checks the import rules of the three layers under lib/: ui, domain and data.
// The rules and the reasons for them are in docs/adr/0002-three-layers-enforced-by-test.md.
//
// This test reads import and export directives only. It does not look for
// BuildContext in domain or data; the rule that those layers take only
// package:flutter/foundation.dart from Flutter covers it in practice.
//
// Known violations are listed in [_knownViolations]. The list can only shrink:
// a violation that is not on it fails the test, and so does an entry that no
// longer occurs. Fix the code, then delete the entry.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Each entry is 'lib/relative/path.dart -> offending import uri'.
const _knownViolations = <String>{
  // Rule 1: ui must not import dart:io.
  'lib/ui/core/upgrader_service.dart -> dart:io',
  'lib/ui/import/import_page.dart -> dart:io',
  'lib/ui/import/widget/editor_clip_save_button.dart -> dart:io',
  'lib/ui/settings/audio_settings_page.dart -> dart:io',
  // Rule 1: ui must not import package:path.
  'lib/ui/import/import_page.dart -> package:path/path.dart',
  // Rule 4: domain and data take only package:flutter/foundation.dart.
  'lib/data/misc_settings_provider.dart -> package:flutter/material.dart',
  'lib/data/clips/clip_format_migration.dart -> package:flutter/scheduler.dart',
};

const _mainUri = 'package:eq_trainer/main.dart';

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Returns the rule a [uri] imported from a file in [layer] breaks, or null.
String? _brokenRule(String layer, String uri) {
  if (uri == _mainUri) {
    return 'rule 5: nothing in ui, domain or data imports main.dart';
  }
  switch (layer) {
    case 'ui':
      if (uri == 'dart:io' ||
          uri.startsWith('package:path/') ||
          uri.startsWith('package:shared_preferences/') ||
          uri == 'package:eq_trainer/data/app_directories.dart') {
        return 'rule 1: ui must not import dart:io, package:path, '
            'shared_preferences or AppDirectories';
      }
    case 'data':
      if (uri.startsWith('package:eq_trainer/ui/')) {
        return 'rule 2: data must not import ui';
      }
      if (_isNonFoundationFlutter(uri)) {
        return 'rule 4: data may use only package:flutter/foundation.dart '
            'from Flutter';
      }
    case 'domain':
      if (uri.startsWith('package:eq_trainer/ui/') ||
          uri.startsWith('package:eq_trainer/data/') ||
          uri == 'dart:io') {
        return 'rule 3: domain must not import ui, data or dart:io';
      }
      if (_isNonFoundationFlutter(uri)) {
        return 'rule 4: domain may use only package:flutter/foundation.dart '
            'from Flutter';
      }
  }
  return null;
}

bool _isNonFoundationFlutter(String uri) =>
    uri.startsWith('package:flutter/') &&
    uri != 'package:flutter/foundation.dart';

void main() {
  test('layers import only what their rules allow', () {
    final found = <String, String>{}; // 'file -> uri' to the rule broken

    for (final layer in const ['ui', 'domain', 'data']) {
      final dir = Directory('lib/$layer');
      expect(dir.existsSync(), isTrue, reason: 'lib/$layer is missing');
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (path.endsWith('.g.dart')) continue;
        final source = entity.readAsStringSync();
        for (final match in _directive.allMatches(source)) {
          final uri = match.group(1)!;
          final rule = _brokenRule(layer, uri);
          if (rule != null) found['$path -> $uri'] = rule;
        }
      }
    }

    final unlisted = found.keys.where((k) => !_knownViolations.contains(k));
    final stale = _knownViolations.where((k) => !found.containsKey(k));

    final problems = <String>[
      for (final k in unlisted) 'New violation: $k\n  ${found[k]}',
      for (final k in stale)
        'No longer occurs, delete it from _knownViolations: $k',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
