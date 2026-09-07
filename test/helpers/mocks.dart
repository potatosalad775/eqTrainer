import 'package:mocktail/mocktail.dart';
import 'package:eq_trainer/shared/player/player_service.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/playlist_service.dart';

/// The mocktail doubles shared across the unit suites.
///
/// `AudioState` is deliberately absent: it is a `final class`, so it cannot be
/// mocked. Construct a real one — `AudioState(androidBackend: ..., outputDevice:
/// null)` needs no engine.
class MockIAudioClipRepository extends Mock implements IAudioClipRepository {}

class MockAppDirectories extends Mock implements AppDirectories {}

class MockPlayerService extends Mock implements PlayerService {}

class MockPlaylistService extends Mock implements PlaylistService {}
