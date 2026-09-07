import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/features/session/model/frequency_calculator.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';

void main() {
  group('FrequencyCalculator.compute', () {
    late SessionParameter param;

    setUp(() {
      param = SessionParameter();
    });

    test('centerFreqLogList has exactly startingBand entries', () {
      param.startingBand = 5;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      expect(result.centerFreqLogList.length, equals(5));
    });

    test('centerFreqLinearList has exactly startingBand entries', () {
      param.startingBand = 4;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      expect(result.centerFreqLinearList.length, equals(4));
    });

    test('log frequencies stay within [20, 20000] Hz range', () {
      param.startingBand = 10;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      for (final freq in result.centerFreqLogList) {
        expect(freq, greaterThanOrEqualTo(20.0));
        expect(freq, lessThanOrEqualTo(20000.0));
      }
    });

    test('log frequencies follow a geometric progression at every step', () {
      param.startingBand = 6;
      final freqs =
          FrequencyCalculator.compute(sessionParameter: param).centerFreqLogList;
      expect(freqs, hasLength(6));
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
    // midpoint of the span, sqrt(20 * 20000) ≈ 632 Hz.
    test('log frequencies are the centres of equal log-width slots', () {
      for (final bands in [2, 3, 7, 25]) {
        param.startingBand = bands;
        final freqs = FrequencyCalculator.compute(sessionParameter: param)
            .centerFreqLogList;
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

    test('linear frequencies are evenly spaced', () {
      param.startingBand = 5;
      final linears = FrequencyCalculator.compute(sessionParameter: param)
          .centerFreqLinearList;
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
        param.startingBand = bands;
        final linears = FrequencyCalculator.compute(sessionParameter: param)
            .centerFreqLinearList;
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
      param.startingBand = 5;
      param.filterType = FilterType.peak;
      final result = FrequencyCalculator.compute(sessionParameter: param);

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
      param.startingBand = 3;
      param.filterType = FilterType.peakDip;
      final result = FrequencyCalculator.compute(sessionParameter: param);

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
      param.startingBand = 4;
      param.filterType = FilterType.peak;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      expect(result.graphBarDataList.length, equals(4));
    });

    test('FilterType.dip produces graphBarDataList.length == startingBand', () {
      param.startingBand = 4;
      param.filterType = FilterType.dip;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      expect(result.graphBarDataList.length, equals(4));
    });

    test('FilterType.peakDip produces graphBarDataList.length == 2 * startingBand', () {
      param.startingBand = 4;
      param.filterType = FilterType.peakDip;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      expect(result.graphBarDataList.length, equals(8));
    });

    test('each graph spot list has 61 points (j = 0..60)', () {
      param.startingBand = 2;
      param.filterType = FilterType.peak;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      for (final bar in result.graphBarDataList) {
        expect(bar.spots.length, equals(61));
      }
    });

    test('peak spots have positive y values', () {
      param.startingBand = 2;
      param.filterType = FilterType.peak;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      // All peak spot y values should be >= 0
      for (final bar in result.graphBarDataList) {
        for (final spot in bar.spots) {
          expect(spot.y, greaterThanOrEqualTo(0.0));
        }
      }
    });

    test('dip spots have non-positive y values', () {
      param.startingBand = 2;
      param.filterType = FilterType.dip;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      // All dip spot y values should be <= 0
      for (final bar in result.graphBarDataList) {
        for (final spot in bar.spots) {
          expect(spot.y, lessThanOrEqualTo(0.0));
        }
      }
    });

    test('works for minimum startingBand of 2', () {
      param.startingBand = 2;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      expect(result.centerFreqLogList.length, equals(2));
      expect(result.centerFreqLinearList.length, equals(2));
    });

    test('works for maximum startingBand of 25', () {
      param.startingBand = 25;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      expect(result.centerFreqLogList.length, equals(25));
      expect(result.centerFreqLinearList.length, equals(25));
    });
  });
}
