import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';

void main() {
  group('SessionParameter', () {
    late SessionParameter param;

    setUp(() {
      param = SessionParameter();
    });

    test('default values are correct', () {
      expect(param.startingBand, equals(3));
      expect(param.gain, equals(6));
      expect(param.qFactor, equals(1.0));
      expect(param.filterType, equals(FilterType.peakDip));
      expect(param.threshold, equals(3));
    });

    group('startingBand clamping', () {
      test('clamps to minimum of 2 when set below range', () {
        param.startingBand = 0;
        expect(param.startingBand, equals(2));
      });

      test('clamps to minimum of 2 when set to 1', () {
        param.startingBand = 1;
        expect(param.startingBand, equals(2));
      });

      test('clamps to maximum of 25 when set above range', () {
        param.startingBand = 30;
        expect(param.startingBand, equals(25));
      });

      test('clamps to maximum of 25 when set to 26', () {
        param.startingBand = 26;
        expect(param.startingBand, equals(25));
      });

      test('accepts minimum boundary value of 2', () {
        param.startingBand = 2;
        expect(param.startingBand, equals(2));
      });

      test('accepts maximum boundary value of 25', () {
        param.startingBand = 25;
        expect(param.startingBand, equals(25));
      });

      test('accepts a mid-range value', () {
        param.startingBand = 10;
        expect(param.startingBand, equals(10));
      });

      test('clamps negative values to 2', () {
        param.startingBand = -5;
        expect(param.startingBand, equals(2));
      });
    });

    group('gain setter', () {
      test('stores the assigned value', () {
        param.gain = 12;
        expect(param.gain, equals(12));
      });

      test('stores negative gain values', () {
        param.gain = -6;
        expect(param.gain, equals(-6));
      });
    });

    group('qFactor setter', () {
      test('stores the assigned value', () {
        param.qFactor = 2.5;
        expect(param.qFactor, closeTo(2.5, 1e-9));
      });
    });

    group('filterType setter', () {
      test('can be set to FilterType.peak', () {
        param.filterType = FilterType.peak;
        expect(param.filterType, equals(FilterType.peak));
      });

      test('can be set to FilterType.dip', () {
        param.filterType = FilterType.dip;
        expect(param.filterType, equals(FilterType.dip));
      });

      test('can be set to FilterType.peakDip', () {
        param.filterType = FilterType.peakDip;
        expect(param.filterType, equals(FilterType.peakDip));
      });
    });

    group('threshold setter', () {
      test('stores the assigned value', () {
        param.threshold = 5;
        expect(param.threshold, equals(5));
      });
    });
  });
}
