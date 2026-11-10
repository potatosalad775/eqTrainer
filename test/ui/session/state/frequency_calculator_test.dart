import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/ui/session/state/frequency_calculator.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';

void main() {
  FrequencyGraphData compute(int bands, FilterType type) =>
      FrequencyCalculator.compute(BandLayout(bands, type));

  group('FrequencyCalculator.compute', () {
    test('centerFreqLinearList has exactly one entry per band', () {
      expect(compute(4, FilterType.peakDip).centerFreqLinearList.length, equals(4));
    });

    test('linear frequencies are evenly spaced', () {
      final linears = compute(5, FilterType.peakDip).centerFreqLinearList;
      expect(linears, hasLength(5));
      final gap = linears[1] - linears[0];
      for (int i = 1; i < linears.length - 1; i++) {
        expect(linears[i + 1] - linears[i], closeTo(gap, 1e-9));
      }
    });

    // The linear list is the graph's x axis, 0..60, with each band centred in
    // an equal-width slot. So it is symmetric about 30 and never touches the
    // edges, which is what keeps the bell curves inside the chart.
    test('linear frequencies are slot centres symmetric about 30', () {
      for (final bands in [2, 3, 7, 25]) {
        final linears = compute(bands, FilterType.peakDip).centerFreqLinearList;
        final halfSlot = 30 / bands;

        expect(linears.first, closeTo(halfSlot, 1e-9));
        expect(linears.last, closeTo(60 - halfSlot, 1e-9));
        for (var i = 0; i < bands; i++) {
          expect(linears[i] + linears[bands - 1 - i], closeTo(60, 1e-9),
              reason: '$bands bands: pair $i is not symmetric about 30');
        }
      }
    });

    // The bell for band i must peak on that band's own x position; a graph
    // whose curves peaked elsewhere would be lying about which band is which.
    test('each bell peaks at its own band centre with the full height', () {
      final result = compute(5, FilterType.peak);

      for (var i = 0; i < 5; i++) {
        final centre = result.centerFreqLinearList[i];
        final spots = result.graphBarDataList[i].spots;
        // Spots sit on integer x, so the peak is the sample nearest the centre.
        final peak = spots.reduce((a, b) => a.y >= b.y ? a : b);
        expect(peak.x, closeTo(centre, 0.5),
            reason: 'band $i peaks at x=${peak.x}, centre is $centre');
        // Height is the calculator's fixed amplitude of 2; the nearest
        // integer sample is at most half a step off the true peak.
        expect(peak.y, closeTo(2.0, 0.1));
      }
    });

    test('peakDip interleaves peak then dip for each band', () {
      final result = compute(3, FilterType.peakDip);

      for (var i = 0; i < 3; i++) {
        final peak = result.graphBarDataList[2 * i].spots;
        final dip = result.graphBarDataList[2 * i + 1].spots;
        // The dip is the peak mirrored through zero, at the same x positions.
        for (var j = 0; j < peak.length; j++) {
          expect(peak[j].x, equals(dip[j].x));
          expect(dip[j].y, closeTo(-peak[j].y, 1e-9));
        }
        expect(peak.map((s) => s.y).reduce(max), greaterThan(1.5));
      }
    });

    test('FilterType.peak produces graphBarDataList.length == startingBand', () {
      final result = compute(4, FilterType.peak);
      expect(result.graphBarDataList.length, equals(4));
    });

    test('FilterType.dip produces graphBarDataList.length == startingBand', () {
      final result = compute(4, FilterType.dip);
      expect(result.graphBarDataList.length, equals(4));
    });

    test('FilterType.peakDip produces graphBarDataList.length == 2 * startingBand', () {
      final result = compute(4, FilterType.peakDip);
      expect(result.graphBarDataList.length, equals(8));
    });

    test('each graph spot list has 61 points (j = 0..60)', () {
      final result = compute(2, FilterType.peak);
      for (final bar in result.graphBarDataList) {
        expect(bar.spots.length, equals(61));
      }
    });

    test('peak spots have positive y values', () {
      final result = compute(2, FilterType.peak);
      // All peak spot y values should be >= 0
      for (final bar in result.graphBarDataList) {
        for (final spot in bar.spots) {
          expect(spot.y, greaterThanOrEqualTo(0.0));
        }
      }
    });

    test('dip spots have non-positive y values', () {
      final result = compute(2, FilterType.dip);
      // All dip spot y values should be <= 0
      for (final bar in result.graphBarDataList) {
        for (final spot in bar.spots) {
          expect(spot.y, lessThanOrEqualTo(0.0));
        }
      }
    });

    test('works for minimum startingBand of 2', () {
      final result = compute(2, FilterType.peakDip);
      expect(result.centerFreqLinearList.length, equals(2));
    });

    test('works for maximum startingBand of 25', () {
      final result = compute(25, FilterType.peakDip);
      expect(result.centerFreqLinearList.length, equals(25));
    });
  });
}
