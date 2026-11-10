import 'package:eq_trainer/data/playback_hold.dart';

/// A [PlaybackHold] that counts its calls and holds nothing.
class RecordingHold implements PlaybackHold {
  int pauses = 0;
  int resumes = 0;

  @override
  void pause() => pauses++;

  @override
  void resume() => resumes++;
}
