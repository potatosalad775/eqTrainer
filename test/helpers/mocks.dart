import 'package:mocktail/mocktail.dart';
import 'package:eq_trainer/data/player_service.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/app_directories.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';

/// The mocktail doubles shared across the unit suites.
///
/// `OutputSelection` is deliberately absent: construct a real one over a
/// `FakeOutputDevices` (`fake_output_devices.dart`), which needs no engine.
class MockIAudioClipRepository extends Mock implements IAudioClipRepository {}

class MockAppDirectories extends Mock implements AppDirectories {}

class MockClipLibrary extends Mock implements ClipLibrary {}

class MockPlayerService extends Mock implements PlayerService {}
