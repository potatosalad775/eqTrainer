/// Something that has to stand aside while audio can play.
///
/// [pause] and [resume] are counted by the implementer, so holds nest: it
/// carries on only once every [pause] has been matched by a [resume].
abstract interface class PlaybackHold {
  void pause();
  void resume();
}
