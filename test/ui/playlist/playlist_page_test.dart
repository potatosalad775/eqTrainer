import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:eq_trainer/ui/playlist/playlist_page.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/app_directories.dart';
import 'package:eq_trainer/data/clips/audio_clip_service.dart';

/// A library that could not be read must say so. An empty list on its own looks
/// exactly like the clips being gone for good.
void main() {
  late Directory dir;
  late AudioClipRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('eqt_playlist_page_');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpPage(WidgetTester tester) async {
    final dirs = AppDirectories();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<IAudioClipRepository>.value(value: repo),
        Provider<AppDirectories>.value(value: dirs),
        Provider<AudioClipService>.value(value: AudioClipService(repo, dirs)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlaylistPage(),
      ),
    ));
    await tester.pump();
  }

  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> open(WidgetTester tester, {bool unreadable = false}) async {
    await tester.runAsync(() async {
      repo = await AudioClipRepository.open(File(p.join(dir.path, 'audio_clips.json')));
    });
    if (unreadable) repo.markUnreadable();
  }

  testWidgets('an empty library says it is empty', (tester) async {
    await open(tester);
    await pumpPage(tester);

    expect(find.text(l10n.playlistEmptyText), findsOneWidget);
    expect(find.text(l10n.playlistLibraryUnreadable), findsNothing);
  });

  testWidgets('an unreadable library says so instead of looking empty',
      (tester) async {
    await open(tester, unreadable: true);
    await pumpPage(tester);

    expect(find.text(l10n.playlistLibraryUnreadable), findsOneWidget);
    expect(find.text(l10n.playlistEmptyText), findsNothing);
  });

  testWidgets('clips imported since still show the notice below the list',
      (tester) async {
    await open(tester, unreadable: true);
    await tester.runAsync(() => repo.addClip(AudioClip('a.wav', 'song', 1, true)));
    await pumpPage(tester);

    expect(find.text('song'), findsOneWidget);
    expect(find.text(l10n.playlistLibraryUnreadable), findsOneWidget);
    expect(find.text(l10n.playlistFooter), findsOneWidget);
  });

  testWidgets('a healthy library with clips shows no notice', (tester) async {
    await open(tester);
    await tester.runAsync(() => repo.addClip(AudioClip('a.wav', 'song', 1, true)));
    await pumpPage(tester);

    expect(find.text('song'), findsOneWidget);
    expect(find.text(l10n.playlistLibraryUnreadable), findsNothing);
  });
}
