import 'package:eq_trainer/shared/player/player_service.dart';

/// The player behind the import editor's preview/trim controls.
///
/// A distinct type only so the editor's widgets can `context.read` it without
/// colliding with the session's player in the provider tree. The source path
/// it exposes as `filePath` is [PlayerService]'s own, set by `launch()` —
/// under coast_audio this class had to track it separately.
class ImportPlayer extends PlayerService {
  ImportPlayer();
}
