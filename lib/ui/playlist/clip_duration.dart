/// A clip's length for the playlist: `MM:SS.cc` under an hour, `H:MM:SS.cc`
/// from one hour up. Hundredths are truncated, not rounded.
String formatClipDuration(double seconds) {
  final centis = (seconds * 1000).toInt() ~/ 10;
  final hours = centis ~/ 360000;
  final minutes = centis ~/ 6000 % 60;
  final secs = centis ~/ 100 % 60;
  final cc = (centis % 100).toString().padLeft(2, '0');
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return hours == 0 ? '$mm:$ss.$cc' : '$hours:$mm:$ss.$cc';
}
