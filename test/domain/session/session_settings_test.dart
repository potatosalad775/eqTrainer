import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';

void main() {
  group('SessionSettings choices', () {
    test('band counts run from 2 to 25 inclusive', () {
      expect(SessionSettings.minBands, 2);
      expect(SessionSettings.maxBands, 25);
      expect(SessionSettings.bandCounts, [for (var i = 2; i <= 25; i++) i]);
    });

    test('gains, Q factors and thresholds are the ones the config offers', () {
      expect(SessionSettings.gains, [3, 4, 5, 6, 8, 10, 15]);
      expect(SessionSettings.qFactors, [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]);
      expect(SessionSettings.thresholds, [1, 3, 5, 10]);
    });

    test('the lists cannot be changed by a caller', () {
      expect(() => SessionSettings.bandCounts.add(26), throwsUnsupportedError);
    });
  });

  group('SessionSettings equality', () {
    SessionSettings make({int gain = 6, FilterType type = FilterType.peakDip}) =>
        SessionSettings(
          startingBand: 3,
          gain: gain,
          qFactor: 1.0,
          filterType: type,
          threshold: 3,
        );

    test('settings with the same values are equal', () {
      expect(make(), equals(make()));
      expect(make().hashCode, make().hashCode);
    });

    test('a different value makes them differ', () {
      expect(make(), isNot(equals(make(gain: 5))));
      expect(make(), isNot(equals(make(type: FilterType.dip))));
    });
  });
}
