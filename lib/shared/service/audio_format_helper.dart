import 'package:path/path.dart' as p;

/// Import format setting values stored in MiscSettings.importFormat.
abstract final class ImportFormat {
  static const int smart = 0;

  /// Retired. Convert-everything-to-AAC made sense when coast_audio decoded
  /// m4a fastest; SoLoud cannot decode it at all. The constant stays so a
  /// stored value from before the migration is still recognized — it is
  /// treated as [smart] everywhere, and the settings UI no longer offers it.
  static const int allM4a = 1;

  static const int allWav = 2;

  /// Retired for the same reason as [allM4a], but by convergence rather than
  /// breakage: now that SoLoud reads mp3 and ogg natively, "keep the original
  /// unless it has to be converted" *is* [smart]. Offering both would be two
  /// dropdown entries with identical behavior. Still recognized as a stored
  /// value, still treated as [smart].
  static const int keepOriginal = 3;
}

const _losslessExts = {'.wav', '.flac', '.aiff', '.aif', '.alac', '.caf'};

/// Formats SoLoud decodes natively, so they can be imported untouched and
/// streamed from disk.
const _nativePlayableExts = {'.wav', '.mp3', '.flac', '.ogg'};

/// Returns `true` if [ext] (with leading dot, lowercase) is a lossless format.
bool isLossless(String ext) => _losslessExts.contains(ext);

/// Returns the target extension (`'.wav'`, or `null` for keep-as-is) based on
/// the source extension and the user's import format setting.
///
/// WAV is the only conversion target. Under coast_audio the choice was between
/// wav and m4a on lossless/lossy grounds, because both decoded fast; now m4a
/// is the one common format the engine cannot read, so converting *to* it
/// would mean a decode on every load — and re-encoding a lossy source into AAC
/// lost a generation for nothing.
String? targetExtForImport(String sourceExt, int importFormat) {
  final ext = sourceExt.toLowerCase();

  switch (importFormat) {
    // Convert only what the engine genuinely cannot read. The two retired
    // modes land here too: a stored value from before the migration should
    // keep importing rather than hit an unrecognized case.
    case ImportFormat.smart:
    case ImportFormat.allM4a:
    case ImportFormat.keepOriginal:
      return _nativePlayableExts.contains(ext) ? null : '.wav';

    case ImportFormat.allWav:
      return ext == '.wav' ? null : '.wav';

    default:
      return null;
  }
}

/// Returns the output extension for trimming, which is always `'.wav'`.
///
/// `AudioDecoder.trimAudio()` writes `.wav` or `.m4a`, and trimming to m4a
/// would re-encode a lossy source lossily *and* produce a clip SoLoud cannot
/// decode. The parameter is kept so call sites read the same as before.
String trimOutputExt(String sourceExt) => '.wav';

/// Convenience: extracts extension from [filePath] and calls [targetExtForImport].
String? targetExtForPath(String filePath, int importFormat) {
  return targetExtForImport(p.extension(filePath).toLowerCase(), importFormat);
}
