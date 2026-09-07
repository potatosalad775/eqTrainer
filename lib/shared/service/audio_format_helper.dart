import 'package:path/path.dart' as p;

/// Import format setting values stored in MiscSettings.importFormat.
///
/// The numbering is historical: [allM4a] and [keepOriginal] are retired but
/// their ordinals stay reserved, because a Hive box written before the SoLoud
/// migration can still hold them. See `MiscSettingsProvider` for the mapping
/// applied on read.
abstract final class ImportFormat {
  /// Convert only what the engine cannot play, and pick the target by whether
  /// the source was lossy or lossless. The default.
  static const int smart = 0;

  /// Retired. Convert-everything-to-AAC made sense when coast_audio decoded
  /// m4a fastest; SoLoud cannot decode it at all. The constant stays so a
  /// stored value from before the migration is still recognized — it is
  /// migrated to [smart], and the settings UI no longer offers it.
  static const int allM4a = 1;

  /// Convert everything to WAV. Uncompressed and lossless, so it is the safe
  /// fallback, but a library of it is large.
  static const int allWav = 2;

  /// Retired for the same reason as [allM4a], but by convergence rather than
  /// breakage: now that SoLoud reads mp3 and ogg natively, "keep the original
  /// unless it has to be converted" *is* [smart]. Offering both would be two
  /// dropdown entries with identical behavior. Migrated to [smart].
  static const int keepOriginal = 3;

  /// Convert everything to FLAC. Lossless like WAV, roughly half the size.
  static const int allFlac = 4;

  /// Convert everything to Opus. Lossy, so a lossless source loses something
  /// permanently — offered because at the bitrate used it is transparent and
  /// far smaller than the alternatives.
  static const int allOpus = 5;

  /// The values the settings UI offers, in display order.
  static const List<int> selectable = [smart, allFlac, allOpus, allWav];

  /// Maps a stored value onto one that is still offered. Retired ordinals
  /// collapse onto their nearest surviving equivalent rather than silently
  /// falling through to a default branch somewhere downstream.
  static int normalize(int stored) {
    switch (stored) {
      case allM4a:
      case keepOriginal:
        return smart;
      case smart:
      case allWav:
      case allFlac:
      case allOpus:
        return stored;
      default:
        return smart;
    }
  }
}

const _losslessExts = {'.wav', '.flac', '.aiff', '.aif', '.alac', '.caf'};

/// Formats SoLoud decodes natively, so they can be imported untouched and
/// streamed from disk.
///
/// `.opus` and `.oga` are here because the fork's file-load path decodes Ogg
/// Opus, Ogg Vorbis and Ogg FLAC through libopus/libvorbisfile/libFLAC rather
/// than stb_vorbis.
const _nativePlayableExts = {
  '.wav',
  '.mp3',
  '.flac',
  '.ogg',
  '.opus',
  '.oga',
};

/// Extensions offered in the import file picker: everything the engine plays,
/// plus the foreign formats audio_decoder can convert through platform codecs.
const importPickerExtensions = [
  'wav',
  'mp3',
  'flac',
  'ogg',
  'opus',
  'oga',
  'm4a',
  'aac',
  'mp4',
  'wma',
  'aiff',
  'aif',
  'alac',
  'caf',
];

/// Returns `true` if [ext] (with leading dot, lowercase) is a lossless format.
bool isLossless(String ext) => _losslessExts.contains(ext);

/// Returns `true` if [ext] is one SoLoud can decode without conversion.
bool isNativelyPlayable(String ext) =>
    _nativePlayableExts.contains(ext.toLowerCase());

/// Returns the target extension for an import, or `null` to keep the file
/// as-is.
///
/// Smart never transcodes something the engine can already play: doing so
/// costs disk space and, for a lossy source, a generation of quality, in
/// exchange for nothing. Only foreign formats are converted, and the target
/// follows the source's lossiness — a lossy source has nothing to gain from a
/// lossless container, and a lossless one should not be silently degraded.
///
/// The explicit modes convert everything that is not already in the requested
/// format, including formats the engine plays natively.
String? targetExtForImport(String sourceExt, int importFormat) {
  final ext = sourceExt.toLowerCase();

  switch (ImportFormat.normalize(importFormat)) {
    case ImportFormat.smart:
      if (_nativePlayableExts.contains(ext)) return null;
      return isLossless(ext) ? '.flac' : '.opus';

    case ImportFormat.allFlac:
      return ext == '.flac' ? null : '.flac';

    case ImportFormat.allOpus:
      return ext == '.opus' ? null : '.opus';

    case ImportFormat.allWav:
      return ext == '.wav' ? null : '.wav';

    default:
      return null;
  }
}

/// Returns the output extension for trimming a clip whose source is
/// [sourceExt], under the user's [importFormat] setting.
///
/// A trim always re-encodes, so unlike an import it cannot keep the original
/// bytes and the target always matters. Under Smart the target follows the
/// source's lossiness: a lossless source stays lossless in FLAC, and a lossy
/// one goes to Opus at a generous bitrate rather than to a lossless container,
/// which would only make the file bigger without recovering anything. An
/// explicit format setting is honoured as-is.
String trimOutputExt(String sourceExt, int importFormat) {
  switch (ImportFormat.normalize(importFormat)) {
    case ImportFormat.allFlac:
      return '.flac';
    case ImportFormat.allOpus:
      return '.opus';
    case ImportFormat.allWav:
      return '.wav';
    case ImportFormat.smart:
    default:
      return isLossless(sourceExt.toLowerCase()) ? '.flac' : '.opus';
  }
}

/// Convenience: extracts extension from [filePath] and calls
/// [targetExtForImport].
String? targetExtForPath(String filePath, int importFormat) {
  return targetExtForImport(p.extension(filePath).toLowerCase(), importFormat);
}
