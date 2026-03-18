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

    test('log frequencies follow geometric progression', () {
      param.startingBand = 6;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      final freqs = result.centerFreqLogList;
      // Each step should multiply by the same ratio
      if (freqs.length >= 3) {
        final ratio1 = freqs[1] / freqs[0];
        final ratio2 = freqs[2] / freqs[1];
        expect(ratio1, closeTo(ratio2, 1e-6));
      }
    });

    test('linear frequencies are evenly spaced', () {
      param.startingBand = 5;
      final result = FrequencyCalculator.compute(sessionParameter: param);
      final linears = result.centerFreqLinearList;
      if (linears.length >= 2) {
        final gap = linears[1] - linears[0];
        for (int i = 1; i < linears.length - 1; i++) {
          expect(linears[i + 1] - linears[i], closeTo(gap, 1e-9));
        }
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
