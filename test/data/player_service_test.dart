import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/output_selection.dart';
import 'package:eq_trainer/data/player_service.dart';

import '../helpers/fake_encoder.dart';
import '../helpers/fake_output_devices.dart';
import '../helpers/mocks.dart';
import '../helpers/recording_hold.dart';

void main() {
  late OutputSelection output;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    output = OutputSelection(
      prefs: await SharedPreferences.getInstance(),
      devices: FakeOutputDevices([]),
      watchesDevices: false,
    );
  });

  test('constructing a player pauses the hold', () {
    final hold = RecordingHold();
    final player = PlayerService(output, hold: hold);
    expect(hold.pauses, 1);
    expect(hold.resumes, 0);
    player.dispose();
  });

  test('dispose resumes the hold once', () {
    final hold = RecordingHold();
    PlayerService(output, hold: hold).dispose();
    expect(hold.resumes, 1);
  });

  test('shutdown leaves the hold paused', () async {
    final hold = RecordingHold();
    final player = PlayerService(output, hold: hold);
    await player.shutdown();
    expect(hold.resumes, 0);
    player.dispose();
    expect(hold.resumes, 1);
  });

  testWidgets(
      'two players keep a real migration paused until both are disposed',
      (tester) async {
    final migration = ClipFormatMigration(
      MockClipLibrary(),
      importFormat: 0,
      encoder: FakeClipEncoder(),
    );
    final a = PlayerService(output, hold: migration);
    final b = PlayerService(output, hold: migration);
    expect(migration.isPaused, isTrue);

    a.dispose();
    expect(migration.isPaused, isTrue);
    b.dispose();
    expect(migration.isPaused, isFalse);
  });
}
