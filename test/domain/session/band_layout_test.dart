import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';

void main() {
  group('graphCount', () {
    test('is the band count in peak and in dip mode', () {
      expect(BandLayout(4, FilterType.peak).graphCount, 4);
      expect(BandLayout(4, FilterType.dip).graphCount, 4);
    });

    test('is twice the band count in peak-and-dip mode', () {
      expect(BandLayout(4, FilterType.peakDip).graphCount, 8);
    });
  });

  group('bandOf and isDip', () {
    test('peak mode: graph i is band i and never a dip', () {
      final layout = BandLayout(3, FilterType.peak);
      for (var i = 0; i < 3; i++) {
        expect(layout.bandOf(i), i);
        expect(layout.isDip(i), isFalse);
      }
    });

    test('dip mode: graph i is band i and always a dip', () {
      final layout = BandLayout(3, FilterType.dip);
      for (var i = 0; i < 3; i++) {
        expect(layout.bandOf(i), i);
        expect(layout.isDip(i), isTrue);
      }
    });

    test('peak-and-dip mode: each band has a peak, then a dip', () {
      final layout = BandLayout(3, FilterType.peakDip);
      expect([for (var i = 0; i < 6; i++) layout.bandOf(i)], [0, 0, 1, 1, 2, 2]);
      expect([for (var i = 0; i < 6; i++) layout.isDip(i)],
          [false, true, false, true, false, true]);
    });

    test('a graph index outside the layout is refused', () {
      final layout = BandLayout(3, FilterType.peakDip);
      expect(() => layout.bandOf(6), throwsRangeError);
      expect(() => layout.isDip(-1), throwsRangeError);
      expect(() => BandLayout(3, FilterType.peak).bandOf(3), throwsRangeError);
    });
  });

  group('centerFrequencies', () {
    test('there is one per band, whatever the filter type', () {
      for (final type in FilterType.values) {
        expect(BandLayout(5, type).centerFrequencies, hasLength(5));
      }
    });

    test('stay within 20 Hz to 20 kHz', () {
      for (final freq in BandLayout(10, FilterType.peak).centerFrequencies) {
        expect(freq, greaterThanOrEqualTo(20.0));
        expect(freq, lessThanOrEqualTo(20000.0));
      }
    });

    test('follow a geometric progression at every step', () {
      final freqs = BandLayout(6, FilterType.peak).centerFrequencies;
      final ratio = freqs[1] / freqs[0];
      for (var i = 1; i < freqs.length - 1; i++) {
        expect(freqs[i + 1] / freqs[i], closeTo(ratio, 1e-6),
            reason: 'step $i broke the progression');
      }
    });

    // Every band gets an equal share of the 20 Hz to 20 kHz span on a log
    // axis and sits at the centre of its slot. That fixes both ends exactly:
    // the first centre is 20 Hz times half a slot, the last is 20 kHz divided
    // by half a slot, and the list is geometrically symmetric about the
    // midpoint of the span, sqrt(20 * 20000) = 632 Hz.
    test('are the centres of equal log-width slots', () {
      for (final bands in [2, 3, 7, 25]) {
        final freqs = BandLayout(bands, FilterType.peak).centerFrequencies;
        final halfSlot = pow(1000, 1 / (2 * bands)).toDouble();

        expect(freqs.first, closeTo(20 * halfSlot, 1e-6),
            reason: '$bands bands: first centre');
        expect(freqs.last, closeTo(20000 / halfSlot, 1e-6),
            reason: '$bands bands: last centre');
        for (var i = 0; i < bands; i++) {
          expect(freqs[i] * freqs[bands - 1 - i], closeTo(20 * 20000, 1e-3),
              reason: '$bands bands: pair $i is not symmetric about 632 Hz');
        }
      }
    });

    test('cannot be changed by a caller', () {
      final layout = BandLayout(3, FilterType.peak);
      expect(() => layout.centerFrequencies.add(1), throwsUnsupportedError);
    });
  });

  group('frequencyOf', () {
    test('a peak and a dip of the same band share its frequency', () {
      final layout = BandLayout(3, FilterType.peakDip);
      expect(layout.frequencyOf(2), layout.centerFrequencies[1]);
      expect(layout.frequencyOf(3), layout.centerFrequencies[1]);
    });

    test("in peak mode graph i is band i's frequency", () {
      final layout = BandLayout(4, FilterType.peak);
      for (var i = 0; i < 4; i++) {
        expect(layout.frequencyOf(i), layout.centerFrequencies[i]);
      }
    });
  });

  group('signedGain', () {
    test('is positive for a peak and negative for a dip', () {
      final layout = BandLayout(2, FilterType.peakDip);
      expect(layout.signedGain(0, 6), 6.0);
      expect(layout.signedGain(1, 6), -6.0);
    });

    test('is negative for every graph in dip mode, positive in peak mode', () {
      expect(BandLayout(2, FilterType.dip).signedGain(1, 4), -4.0);
      expect(BandLayout(2, FilterType.peak).signedGain(1, 4), 4.0);
    });
  });

  test('layouts with the same band count and filter type are equal', () {
    expect(BandLayout(3, FilterType.peak), equals(BandLayout(3, FilterType.peak)));
    expect(BandLayout(3, FilterType.peak),
        isNot(equals(BandLayout(4, FilterType.peak))));
    expect(BandLayout(3, FilterType.peak),
        isNot(equals(BandLayout(3, FilterType.dip))));
  });
}
