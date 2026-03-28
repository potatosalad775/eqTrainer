import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';

void main() {
  // ---------------------------------------------------------------------------
  // targetExtForImport — Smart mode
  // ---------------------------------------------------------------------------
  group('targetExtForImport (Smart)', () {
    const mode = ImportFormat.smart;

    test('keeps .wav as-is', () {
      expect(targetExtForImport('.wav', mode), isNull);
    });

    test('keeps .m4a as-is', () {
      expect(targetExtForImport('.m4a', mode), isNull);
    });

    test('converts lossy .mp3 to .m4a', () {
      expect(targetExtForImport('.mp3', mode), equals('.m4a'));
    });

    test('converts lossy .ogg to .m4a', () {
      expect(targetExtForImport('.ogg', mode), equals('.m4a'));
    });

    test('converts lossy .wma to .m4a', () {
      expect(targetExtForImport('.wma', mode), equals('.m4a'));
    });

    test('converts lossy .opus to .m4a', () {
      expect(targetExtForImport('.opus', mode), equals('.m4a'));
    });

    test('converts lossy .aac to .m4a', () {
      expect(targetExtForImport('.aac', mode), equals('.m4a'));
    });

    test('converts lossy .mp4 to .m4a', () {
      expect(targetExtForImport('.mp4', mode), equals('.m4a'));
    });

    test('converts lossy .oga to .m4a', () {
      expect(targetExtForImport('.oga', mode), equals('.m4a'));
    });

    test('converts lossy .amr to .m4a', () {
      expect(targetExtForImport('.amr', mode), equals('.m4a'));
    });

    test('converts lossy .webm to .m4a', () {
      expect(targetExtForImport('.webm', mode), equals('.m4a'));
    });

    test('converts lossless .flac to .wav', () {
      expect(targetExtForImport('.flac', mode), equals('.wav'));
    });

    test('converts lossless .aiff to .wav', () {
      expect(targetExtForImport('.aiff', mode), equals('.wav'));
    });

    test('converts lossless .aif to .wav', () {
      expect(targetExtForImport('.aif', mode), equals('.wav'));
    });

    test('converts lossless .alac to .wav', () {
      expect(targetExtForImport('.alac', mode), equals('.wav'));
    });

    test('converts lossless .caf to .wav', () {
      expect(targetExtForImport('.caf', mode), equals('.wav'));
    });

    test('is case-insensitive', () {
      expect(targetExtForImport('.MP3', mode), equals('.m4a'));
      expect(targetExtForImport('.FLAC', mode), equals('.wav'));
      expect(targetExtForImport('.WAV', mode), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // targetExtForImport — All M4A mode
  // ---------------------------------------------------------------------------
  group('targetExtForImport (All M4A)', () {
    const mode = ImportFormat.allM4a;

    test('keeps .m4a as-is', () {
      expect(targetExtForImport('.m4a', mode), isNull);
    });

    test('converts .wav to .m4a', () {
      expect(targetExtForImport('.wav', mode), equals('.m4a'));
    });

    test('converts .mp3 to .m4a', () {
      expect(targetExtForImport('.mp3', mode), equals('.m4a'));
    });

    test('converts .flac to .m4a', () {
      expect(targetExtForImport('.flac', mode), equals('.m4a'));
    });

    test('converts .aiff to .m4a', () {
      expect(targetExtForImport('.aiff', mode), equals('.m4a'));
    });

    test('converts .alac to .m4a', () {
      expect(targetExtForImport('.alac', mode), equals('.m4a'));
    });

    test('converts .ogg to .m4a', () {
      expect(targetExtForImport('.ogg', mode), equals('.m4a'));
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

    test('converts .m4a to .wav', () {
      expect(targetExtForImport('.m4a', mode), equals('.wav'));
    });

    test('converts .mp3 to .wav', () {
      expect(targetExtForImport('.mp3', mode), equals('.wav'));
    });

    test('converts .flac to .wav', () {
      expect(targetExtForImport('.flac', mode), equals('.wav'));
    });

    test('converts .ogg to .wav', () {
      expect(targetExtForImport('.ogg', mode), equals('.wav'));
    });

    test('converts .aiff to .wav', () {
      expect(targetExtForImport('.aiff', mode), equals('.wav'));
    });
  });

  // ---------------------------------------------------------------------------
  // targetExtForImport — Keep Original mode
  // ---------------------------------------------------------------------------
  group('targetExtForImport (Keep Original)', () {
    const mode = ImportFormat.keepOriginal;

    test('keeps .wav as-is (natively fast)', () {
      expect(targetExtForImport('.wav', mode), isNull);
    });

    test('keeps .m4a as-is (natively fast)', () {
      expect(targetExtForImport('.m4a', mode), isNull);
    });

    test('keeps .mp3 as-is (natively playable)', () {
      expect(targetExtForImport('.mp3', mode), isNull);
    });

    test('keeps .flac as-is (natively playable)', () {
      expect(targetExtForImport('.flac', mode), isNull);
    });

    test('converts unsupported lossless .aiff to .wav', () {
      expect(targetExtForImport('.aiff', mode), equals('.wav'));
    });

    test('converts unsupported lossless .aif to .wav', () {
      expect(targetExtForImport('.aif', mode), equals('.wav'));
    });

    test('converts unsupported lossless .alac to .wav', () {
      expect(targetExtForImport('.alac', mode), equals('.wav'));
    });

    test('converts unsupported lossless .caf to .wav', () {
      expect(targetExtForImport('.caf', mode), equals('.wav'));
    });

    test('converts unsupported lossy .ogg to .m4a', () {
      expect(targetExtForImport('.ogg', mode), equals('.m4a'));
    });

    test('converts unsupported lossy .aac to .m4a', () {
      expect(targetExtForImport('.aac', mode), equals('.m4a'));
    });

    test('converts unsupported lossy .mp4 to .m4a', () {
      expect(targetExtForImport('.mp4', mode), equals('.m4a'));
    });

    test('converts unsupported lossy .opus to .m4a', () {
      expect(targetExtForImport('.opus', mode), equals('.m4a'));
    });

    test('converts unsupported lossy .wma to .m4a', () {
      expect(targetExtForImport('.wma', mode), equals('.m4a'));
    });

    test('converts unsupported lossy .amr to .m4a', () {
      expect(targetExtForImport('.amr', mode), equals('.m4a'));
    });

    test('converts unsupported lossy .webm to .m4a', () {
      expect(targetExtForImport('.webm', mode), equals('.m4a'));
    });

    test('converts unsupported lossy .oga to .m4a', () {
      expect(targetExtForImport('.oga', mode), equals('.m4a'));
    });
  });

  // ---------------------------------------------------------------------------
  // trimOutputExt
  // ---------------------------------------------------------------------------
  group('trimOutputExt', () {
    test('keeps .wav as .wav', () {
      expect(trimOutputExt('.wav'), equals('.wav'));
    });

    test('keeps .m4a as .m4a', () {
      expect(trimOutputExt('.m4a'), equals('.m4a'));
    });

    test('lossless .flac outputs .wav', () {
      expect(trimOutputExt('.flac'), equals('.wav'));
    });

    test('lossless .aiff outputs .wav', () {
      expect(trimOutputExt('.aiff'), equals('.wav'));
    });

    test('lossless .alac outputs .wav', () {
      expect(trimOutputExt('.alac'), equals('.wav'));
    });

    test('lossless .caf outputs .wav', () {
      expect(trimOutputExt('.caf'), equals('.wav'));
    });

    test('lossy .mp3 outputs .m4a', () {
      expect(trimOutputExt('.mp3'), equals('.m4a'));
    });

    test('lossy .ogg outputs .m4a', () {
      expect(trimOutputExt('.ogg'), equals('.m4a'));
    });

    test('lossy .aac outputs .m4a', () {
      expect(trimOutputExt('.aac'), equals('.m4a'));
    });

    test('lossy .wma outputs .m4a', () {
      expect(trimOutputExt('.wma'), equals('.m4a'));
    });

    test('is case-insensitive', () {
      expect(trimOutputExt('.WAV'), equals('.wav'));
      expect(trimOutputExt('.FLAC'), equals('.wav'));
      expect(trimOutputExt('.MP3'), equals('.m4a'));
    });
  });

  // ---------------------------------------------------------------------------
  // targetExtForPath
  // ---------------------------------------------------------------------------
  group('targetExtForPath', () {
    test('extracts extension from full path', () {
      expect(
        targetExtForPath('/some/dir/track.mp3', ImportFormat.smart),
        equals('.m4a'),
      );
    });

    test('returns null for already-optimal format', () {
      expect(
        targetExtForPath('/clips/audio.wav', ImportFormat.smart),
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
