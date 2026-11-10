import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:eq_trainer/ui/playlist/playlist_page.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/domain/audio_clip.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';

import '../../helpers/mocks.dart';

/// A library that could not be read must say so. An empty list on its own looks
/// exactly like the clips being gone for good. A clip whose file is gone must
/// say so too, and must not be deleted for it (ADR 0003).
void main() {
  late Directory dir;
  late Directory clipsDir;
  late AudioClipRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('eqt_playlist_page_');
    clipsDir = Directory(p.join(dir.path, 'clips'))..createSync();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpPage(WidgetTester tester) async {
    final dirs = MockAppDirectories();
    when(() => dirs.getClipsPath()).thenAnswer((_) async => clipsDir.path);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<IAudioClipRepository>.value(value: repo),
        Provider<ClipLibrary>.value(value: ClipLibrary(repo, dirs)),
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

  group('a clip whose file is missing', () {
    /// The file checks are real IO, which the test clock does not advance, and
    /// each step of a chain of them resumes only when the fake clock's
    /// microtasks are flushed. So alternate a little real time with pumps until
    /// [condition] holds, and fail with [reason] if it never does.
    ///
    /// Before asserting that something is absent, wait for a sign that the
    /// refresh has finished, or the assertion can pass before it ran.
    Future<void> waitFor(
      WidgetTester tester,
      bool Function() condition, {
      String? reason,
    }) async {
      // 1000 rounds of at least 5 ms: about 5 seconds before giving up.
      for (var i = 0; i < 1000; i++) {
        if (condition()) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      if (condition()) return;
      fail('Timed out waiting for ${reason ?? 'the condition'}.');
    }

    int labels() => find.text(l10n.playlistAudioFileMissing).evaluate().length;

    /// Returns once every save queued so far has finished. The repository
    /// shows a change before its save is done, and the temp directory cannot be
    /// removed under a save in flight. Saves run one at a time, so a change that
    /// does nothing, queued behind them, finishes after they do.
    Future<void> saved(WidgetTester tester) async {
      var done = false;
      // Not inside runAsync: the queue was started in the test's fake zone, so
      // it only advances when that zone is pumped.
      unawaited(repo.deleteById('no-such-clip').then((_) => done = true));
      await waitFor(tester, () => done, reason: 'the library to be saved');
    }

    Future<void> addClip(
      WidgetTester tester,
      String name, {
      bool file = true,
    }) async {
      if (file) File(p.join(clipsDir.path, name)).writeAsBytesSync([1]);
      await tester.runAsync(
        () => repo.addClip(AudioClip(name, 'song-$name', 1, true)),
      );
    }

    /// The button of the tile at [index], which is the only one by default.
    IconButton button(IconData icon, [int index = 0]) =>
        find.widgetWithIcon(IconButton, icon).evaluate().elementAt(index).widget
            as IconButton;
    const toggleIcon = Icons.radio_button_checked;
    const previewIcon = Icons.play_arrow;

    testWidgets('shows the label and disables the toggle and preview',
        (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav', file: false);
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the missing label');

      expect(find.text('00:01.00'), findsNothing);
      expect(button(toggleIcon).onPressed, isNull);
      expect(button(previewIcon).onPressed, isNull);
    });

    testWidgets('shows the label in the error colour', (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav', file: false);
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the missing label');

      final finder = find.text(l10n.playlistAudioFileMissing);
      expect(
        tester.widget<Text>(finder).style?.color,
        Theme.of(tester.element(finder)).colorScheme.error,
      );
    });

    testWidgets('is not what a clip with its file looks like', (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav');
      // Its label appearing is the sign that the refresh has finished.
      await addClip(tester, 'b.wav', file: false);
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the missing label');

      expect(find.text('00:01.00'), findsOneWidget);
      expect(button(toggleIcon, 0).onPressed, isNotNull);
      expect(button(previewIcon, 0).onPressed, isNotNull);
      expect(button(toggleIcon, 1).onPressed, isNull);
      expect(button(previewIcon, 1).onPressed, isNull);
    });

    testWidgets('can still be deleted, which removes its record',
        (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav', file: false);
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the missing label');

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.playlistAudioActionDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.playlistAudioAlertDeleteYes));
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () =>
            repo.getAllClips().isEmpty &&
            find.text('song-a.wav').evaluate().isEmpty,
        reason: 'the clip to be deleted',
      );
      await saved(tester);

      expect(repo.getAllClips(), isEmpty);
      expect(find.text('song-a.wav'), findsNothing);
    });

    testWidgets('keeps its record when the page shows it', (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav', file: false);
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the missing label');

      expect(repo.getAllClips(), hasLength(1));
    });

    testWidgets('can still be dragged to reorder', (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav', file: false);
      await addClip(tester, 'b.wav');
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the missing label');

      final gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(toggleIcon).first));
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => repo.getAllClips().map((c) => c.id).join(',') == 'b,a',
        reason: 'the clips to be reordered',
      );
      await saved(tester);

      expect(repo.getAllClips().map((c) => c.id), ['b', 'a']);
    });

    testWidgets('appears once its file is removed and the list changes',
        (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav');
      // Its label appearing is the sign that the first refresh has finished,
      // so a.wav is not removed under it.
      await addClip(tester, 's.wav', file: false);
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the first label');

      File(p.join(clipsDir.path, 'a.wav')).deleteSync();
      // Nothing watches the disk, so the page does not know yet. No refresh is
      // expected, so there is nothing to wait for.
      await tester.pump();
      expect(labels(), 1);

      await addClip(tester, 'b.wav');
      await waitFor(tester, () => labels() == 2, reason: 'a second label');

      expect(find.text('00:01.00'), findsOneWidget);
    });

    testWidgets('clears when its file comes back and the list changes',
        (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav', file: false);
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the missing label');

      File(p.join(clipsDir.path, 'a.wav')).writeAsBytesSync([1]);
      await addClip(tester, 'b.wav');
      await waitFor(tester, () => labels() == 0, reason: 'the label to clear');

      expect(find.text('00:01.00'), findsNWidgets(2));
    });

    testWidgets('is noticed when a preview finds the file gone',
        (tester) async {
      await open(tester);
      await addClip(tester, 'a.wav');
      // Its label appearing is the sign that the first refresh has finished,
      // so a.wav is not removed under it.
      await addClip(tester, 's.wav', file: false);
      await pumpPage(tester);
      await waitFor(tester, () => labels() == 1, reason: 'the first label');
      expect(button(previewIcon, 0).onPressed, isNotNull);

      File(p.join(clipsDir.path, 'a.wav')).deleteSync();
      await tester.tap(find.byIcon(previewIcon).first);
      await waitFor(tester, () => labels() == 2, reason: 'a second label');

      expect(button(previewIcon, 0).onPressed, isNull);
      expect(button(toggleIcon, 0).onPressed, isNull);
      expect(repo.getAllClips(), hasLength(2));
    });
  });
}
