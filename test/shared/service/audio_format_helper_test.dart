import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';

/// Formats SoLoud decodes natively. Nothing in this set should ever be
/// converted under Smart: converting one costs disk space and, for the lossy
/// ones, a generation of quality, in exchange for nothing the engine needed.
const _native = ['.wav', '.mp3', '.flac', '.ogg', '.opus', '.oga'];

/// Foreign formats that are lossless. Smart sends these to FLAC, so nothing is
/// thrown away that the user still had.
const _foreignLossless = ['.aiff', '.aif', '.alac', '.caf'];

/// Foreign formats that are already lossy. Smart sends these to Opus: a
/// lossless container cannot recover what the source already discarded, it
/// would only make the file bigger.
const _foreignLossy = ['.m4a', '.aac', '.mp4', '.wma', '.amr', '.webm'];

const _foreign = [..._foreignLossless, ..._foreignLossy];

void main() {
  // ---------------------------------------------------------------------------
  // targetExtForImport — Smart
  // ---------------------------------------------------------------------------
  group('targetExtForImport (Smart)', () {
    const mode = ImportFormat.smart;

    for (final ext in _native) {
      test('keeps natively playable $ext as-is', () {
        expect(targetExtForImport(ext, mode), isNull);
      });
    }

    for (final ext in _foreignLossless) {
      test('converts lossless $ext to .flac', () {
        expect(targetExtForImport(ext, mode), equals('.flac'));
      });
    }

    for (final ext in _foreignLossy) {
      test('converts lossy $ext to .opus', () {
        expect(targetExtForImport(ext, mode), equals('.opus'));
      });
    }

    test('never transcodes something the engine can already play', () {
      for (final ext in _native) {
        expect(
          targetExtForImport(ext, mode),
          isNull,
          reason: '$ext is playable and must not be re-encoded',
        );
      }
    });

    test('is case-insensitive', () {
      expect(targetExtForImport('.MP3', mode), isNull);
      expect(targetExtForImport('.OPUS', mode), isNull);
      expect(targetExtForImport('.M4A', mode), equals('.opus'));
      expect(targetExtForImport('.AIFF', mode), equals('.flac'));
    });
  });

  // ---------------------------------------------------------------------------
  // targetExtForImport — explicit single-format modes
  //
  // Unlike Smart, these convert everything that is not already the requested
  // format, including formats the engine plays natively. That is the point:
  // the user asked for a uniform library.
  // ---------------------------------------------------------------------------
  group('targetExtForImport (explicit formats)', () {
    const cases = {
      ImportFormat.allFlac: '.flac',
      ImportFormat.allOpus: '.opus',
      ImportFormat.allWav: '.wav',
    };

    cases.forEach((mode, target) {
      test('mode $mode keeps $target as-is', () {
        expect(targetExtForImport(target, mode), isNull);
      });

      test('mode $mode converts everything else to $target', () {
        for (final ext in [..._native, ..._foreign]) {
          if (ext == target) continue;
          expect(
            targetExtForImport(ext, mode),
            equals(target),
            reason: '$ext should convert to $target under mode $mode',
          );
        }
      });
    });
  });

  // ---------------------------------------------------------------------------
  // targetExtForImport — retired modes
  //
  // allM4a and keepOriginal are gone from the settings UI but still sit in
  // users' Hive boxes. They must keep importing, and they must not resurrect
  // m4a: allM4a's whole purpose was to produce the one format the engine
  // cannot read.
  // ---------------------------------------------------------------------------
  group('targetExtForImport (retired modes behave as Smart)', () {
    for (final mode in [ImportFormat.allM4a, ImportFormat.keepOriginal]) {
      test('mode $mode matches Smart on every known extension', () {
        for (final ext in [..._native, ..._foreign]) {
          expect(
            targetExtForImport(ext, mode),
            equals(targetExtForImport(ext, ImportFormat.smart)),
            reason: '$ext diverged from Smart under mode $mode',
          );
        }
      });

      test('mode $mode never targets .m4a', () {
        for (final ext in [..._native, ..._foreign]) {
          expect(targetExtForImport(ext, mode), isNot(equals('.m4a')));
        }
      });
    }

    test('an unrecognized stored value falls back to Smart', () {
      for (final ext in [..._native, ..._foreign]) {
        expect(
          targetExtForImport(ext, 999),
          equals(targetExtForImport(ext, ImportFormat.smart)),
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ImportFormat.normalize
  // ---------------------------------------------------------------------------
  group('ImportFormat.normalize', () {
    test('maps retired ordinals onto Smart', () {
      expect(ImportFormat.normalize(ImportFormat.allM4a),
          equals(ImportFormat.smart));
      expect(ImportFormat.normalize(ImportFormat.keepOriginal),
          equals(ImportFormat.smart));
    });

    test('leaves supported ordinals alone', () {
      for (final mode in ImportFormat.selectable) {
        expect(ImportFormat.normalize(mode), equals(mode));
      }
    });

    test('maps anything unrecognized onto Smart', () {
      for (final bogus in [-1, 6, 99, 1000]) {
        expect(ImportFormat.normalize(bogus), equals(ImportFormat.smart));
      }
    });

    test('every selectable value is one the UI can offer', () {
      expect(
        ImportFormat.selectable,
        equals([
          ImportFormat.smart,
          ImportFormat.allFlac,
          ImportFormat.allOpus,
          ImportFormat.allWav,
        ]),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // trimOutputExt
  //
  // A trim always re-encodes, so unlike an import there is no keep-as-is
  // option and the target always matters.
  // ---------------------------------------------------------------------------
  group('trimOutputExt', () {
    test('Smart keeps a lossless source lossless, in FLAC', () {
      for (final ext in ['.wav', '.flac', '.aiff', '.aif', '.alac', '.caf']) {
        expect(
          trimOutputExt(ext, ImportFormat.smart),
          equals('.flac'),
          reason: '$ext is lossless and should trim to .flac',
        );
      }
    });

    test('Smart sends a lossy source to Opus rather than a bigger container',
        () {
      for (final ext in _foreignLossy) {
        expect(trimOutputExt(ext, ImportFormat.smart), equals('.opus'));
      }
      expect(trimOutputExt('.mp3', ImportFormat.smart), equals('.opus'));
      expect(trimOutputExt('.ogg', ImportFormat.smart), equals('.opus'));
      expect(trimOutputExt('.opus', ImportFormat.smart), equals('.opus'));
    });

    test('an explicit format setting overrides the source lossiness', () {
      // A lossless source under an explicit Opus setting still goes to Opus.
      expect(trimOutputExt('.wav', ImportFormat.allOpus), equals('.opus'));
      expect(trimOutputExt('.flac', ImportFormat.allWav), equals('.wav'));
      expect(trimOutputExt('.mp3', ImportFormat.allFlac), equals('.flac'));
      expect(trimOutputExt('.m4a', ImportFormat.allWav), equals('.wav'));
    });

    test('retired modes trim as Smart does', () {
      for (final mode in [ImportFormat.allM4a, ImportFormat.keepOriginal]) {
        for (final ext in [..._native, ..._foreign]) {
          expect(
            trimOutputExt(ext, mode),
            equals(trimOutputExt(ext, ImportFormat.smart)),
          );
        }
      }
    });

    test('never trims to a format the engine cannot read', () {
      for (final mode in [...ImportFormat.selectable, ImportFormat.allM4a]) {
        for (final ext in [..._native, ..._foreign]) {
          expect(isNativelyPlayable(trimOutputExt(ext, mode)), isTrue,
              reason: 'trim target under mode $mode must be playable');
        }
      }
    });

    test('is case-insensitive', () {
      expect(trimOutputExt('.WAV', ImportFormat.smart), equals('.flac'));
      expect(trimOutputExt('.MP3', ImportFormat.smart), equals('.opus'));
    });
  });

  // ---------------------------------------------------------------------------
  // targetExtForPath
  // ---------------------------------------------------------------------------
  group('targetExtForPath', () {
    test('extracts extension from full path', () {
      expect(
        targetExtForPath('/some/dir/track.m4a', ImportFormat.smart),
        equals('.opus'),
      );
      expect(
        targetExtForPath('/some/dir/track.aiff', ImportFormat.smart),
        equals('.flac'),
      );
    });

    test('returns null for a natively playable format', () {
      expect(targetExtForPath('/clips/audio.mp3', ImportFormat.smart), isNull);
      expect(targetExtForPath('/clips/audio.opus', ImportFormat.smart), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // isNativelyPlayable
  // ---------------------------------------------------------------------------
  group('isNativelyPlayable', () {
    test('accepts every format SoLoud decodes, Ogg Opus included', () {
      for (final ext in _native) {
        expect(isNativelyPlayable(ext), isTrue, reason: '$ext should play');
      }
    });

    test('rejects the foreign formats that need a platform decoder', () {
      for (final ext in _foreign) {
        expect(isNativelyPlayable(ext), isFalse, reason: '$ext is foreign');
      }
    });

    test('is case-insensitive', () {
      expect(isNativelyPlayable('.OPUS'), isTrue);
      expect(isNativelyPlayable('.M4A'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // importPickerExtensions
  // ---------------------------------------------------------------------------
  group('importPickerExtensions', () {
    test('offers every natively playable format', () {
      for (final ext in _native) {
        expect(
          importPickerExtensions,
          contains(ext.replaceFirst('.', '')),
          reason: '$ext plays natively and should be offerable',
        );
      }
    });

    test('carries no leading dots', () {
      for (final ext in importPickerExtensions) {
        expect(ext.startsWith('.'), isFalse);
      }
    });

    test('has no duplicates', () {
      expect(importPickerExtensions.toSet().length,
          equals(importPickerExtensions.length));
    });
  });

  // ---------------------------------------------------------------------------
  // isLossless
  // ---------------------------------------------------------------------------
  group('isLossless', () {
    test('recognizes lossless formats', () {
      for (final ext in ['.wav', '.flac', '.aiff', '.aif', '.alac', '.caf']) {
        expect(isLossless(ext), isTrue, reason: '$ext should be lossless');
      }
    });

    test('rejects lossy formats', () {
      for (final ext in ['.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wma']) {
        expect(isLossless(ext), isFalse, reason: '$ext should be lossy');
      }
    });
  });
}
