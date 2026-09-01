import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';

/// Formats SoLoud decodes natively. Nothing in this set should ever be
/// converted on import except by an explicit all-WAV request — converting one
/// costs disk space and, for the lossy ones, a generation of quality, in
/// exchange for nothing the engine needed.
const _native = ['.wav', '.mp3', '.flac', '.ogg'];

/// Formats SoLoud cannot decode. Every one of these must be converted in every
/// mode, or it imports as a clip that will not play. `.m4a` heads the list: it
/// used to be the *preferred* import target under coast_audio.
const _foreign = [
  '.m4a', '.aac', '.mp4', '.wma', '.opus', '.amr', '.webm', '.oga',
  '.aiff', '.aif', '.alac', '.caf',
];

void main() {
  // ---------------------------------------------------------------------------
  // targetExtForImport — Smart mode
  // ---------------------------------------------------------------------------
  group('targetExtForImport (Smart)', () {
    const mode = ImportFormat.smart;

    for (final ext in _native) {
      test('keeps natively playable $ext as-is', () {
        expect(targetExtForImport(ext, mode), isNull);
      });
    }

    for (final ext in _foreign) {
      test('converts $ext to .wav', () {
        expect(targetExtForImport(ext, mode), equals('.wav'));
      });
    }

    test('is case-insensitive', () {
      expect(targetExtForImport('.MP3', mode), isNull);
      expect(targetExtForImport('.FLAC', mode), isNull);
      expect(targetExtForImport('.WAV', mode), isNull);
      expect(targetExtForImport('.M4A', mode), equals('.wav'));
    });
  });

  // ---------------------------------------------------------------------------
  // targetExtForImport — All WAV mode
  // ---------------------------------------------------------------------------
  group('targetExtForImport (All WAV)', () {
    const mode = ImportFormat.allWav;

    test('keeps .wav as-is', () {
      expect(targetExtForImport('.wav', mode), isNull);
    });

    for (final ext in ['.m4a', '.mp3', '.flac', '.ogg', '.aiff']) {
      test('converts $ext to .wav', () {
        expect(targetExtForImport(ext, mode), equals('.wav'));
      });
    }
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
  });

  // ---------------------------------------------------------------------------
  // trimOutputExt
  //
  // AudioDecoder.trimAudio() writes .wav or .m4a. m4a is out on both counts:
  // the engine cannot read it, and trimming a lossy source into it re-encodes
  // for nothing.
  // ---------------------------------------------------------------------------
  group('trimOutputExt', () {
    for (final ext in [..._native, ..._foreign]) {
      test('$ext trims to .wav', () {
        expect(trimOutputExt(ext), equals('.wav'));
      });
    }

    test('is case-insensitive', () {
      expect(trimOutputExt('.WAV'), equals('.wav'));
      expect(trimOutputExt('.FLAC'), equals('.wav'));
      expect(trimOutputExt('.MP3'), equals('.wav'));
    });
  });

  // ---------------------------------------------------------------------------
  // targetExtForPath
  // ---------------------------------------------------------------------------
  group('targetExtForPath', () {
    test('extracts extension from full path', () {
      expect(
        targetExtForPath('/some/dir/track.m4a', ImportFormat.smart),
        equals('.wav'),
      );
    });

    test('returns null for a natively playable format', () {
      expect(
        targetExtForPath('/clips/audio.mp3', ImportFormat.smart),
        isNull,
      );
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
        expect(isLossless(ext), isFalse, reason: '$ext should not be lossless');
      }
    });
  });
}
