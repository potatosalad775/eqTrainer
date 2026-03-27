import 'package:path/path.dart' as p;

/// Import format setting values stored in MiscSettings.importFormat.
abstract final class ImportFormat {
  static const int smart = 0;
  static const int allM4a = 1;
  static const int allWav = 2;
  static const int keepOriginal = 3;
}

const _losslessExts = {'.wav', '.flac', '.aiff', '.aif', '.alac', '.caf'};

/// Formats coast_audio can play natively (fast or slow).
const _nativePlayableExts = {'.wav', '.m4a', '.mp3', '.flac'};

/// Returns `true` if [ext] (with leading dot, lowercase) is a lossless format.
bool isLossless(String ext) => _losslessExts.contains(ext);

/// Returns the target extension (`'.wav'`, `'.m4a'`, or `null` for keep-as-is)
/// based on the source extension and the user's import format setting.
String? targetExtForImport(String sourceExt, int importFormat) {
  final ext = sourceExt.toLowerCase();

  switch (importFormat) {
    case ImportFormat.smart:
      if (ext == '.wav' || ext == '.m4a') return null; // already fast
      return isLossless(ext) ? '.wav' : '.m4a';

    case ImportFormat.allM4a:
      return ext == '.m4a' ? null : '.m4a';

    case ImportFormat.allWav:
      return ext == '.wav' ? null : '.wav';

    case ImportFormat.keepOriginal:
      if (_nativePlayableExts.contains(ext)) return null; // coast_audio can handle it
      // Must convert unsupported formats: lossless → wav, lossy → m4a
      return isLossless(ext) ? '.wav' : '.m4a';

    default:
      return null;
  }
}

/// Returns the output extension for trimming (always `'.wav'` or `'.m4a'`).
///
/// `AudioDecoder.trimAudio()` only supports `.wav` and `.m4a` output.
String trimOutputExt(String sourceExt) {
  final ext = sourceExt.toLowerCase();
  if (ext == '.wav' || ext == '.m4a') return ext;
  return isLossless(ext) ? '.wav' : '.m4a';
}

/// Convenience: extracts extension from [filePath] and calls [targetExtForImport].
String? targetExtForPath(String filePath, int importFormat) {
  return targetExtForImport(p.extension(filePath).toLowerCase(), importFormat);
}
