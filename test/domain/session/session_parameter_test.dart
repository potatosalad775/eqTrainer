import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/session_parameter.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';

void main() {
  group('SessionParameter', () {
    late SessionParameter param;
    late int notifications;

    setUp(() {
      param = SessionParameter();
      notifications = 0;
      param.addListener(() => notifications++);
    });

    test('default values are correct', () {
      expect(param.startingBand, equals(3));
      expect(param.gain, equals(6));
      expect(param.qFactor, equals(1.0));
      expect(param.filterType, equals(FilterType.peakDip));
      expect(param.threshold, equals(3));
    });

    test('every offered value is accepted', () {
      for (final value in SessionSettings.bandCounts) {
        param.startingBand = value;
        expect(param.startingBand, value);
      }
      for (final value in SessionSettings.gains) {
        param.gain = value;
        expect(param.gain, value);
      }
      for (final value in SessionSettings.qFactors) {
        param.qFactor = value;
        expect(param.qFactor, value);
      }
      for (final value in SessionSettings.thresholds) {
        param.threshold = value;
        expect(param.threshold, value);
      }
      for (final value in FilterType.values) {
        param.filterType = value;
        expect(param.filterType, value);
      }
    });

    test('a value that is not offered is ignored, not clamped', () {
      param.startingBand = 30;
      param.startingBand = 1;
      param.startingBand = -5;
      expect(param.startingBand, 3);

      param.gain = 7;
      param.gain = 20;
      param.gain = 0;
      expect(param.gain, 6);

      param.qFactor = 2.5;
      expect(param.qFactor, 1.0);

      param.threshold = 2;
      param.threshold = 0;
      expect(param.threshold, 3);
    });

    test('an ignored value does not notify, an accepted one does', () {
      param.startingBand = 30;
      param.gain = 7;
      param.qFactor = 2.5;
      param.threshold = 2;
      expect(notifications, 0);

      param.startingBand = 10;
      expect(notifications, 1);
    });

    group('snapshot', () {
      test('holds the values as they are now', () {
        param.startingBand = 12;
        param.gain = 10;
        param.qFactor = 5.0;
        param.filterType = FilterType.dip;
        param.threshold = 5;

        expect(
          param.snapshot(),
          const SessionSettings(
            startingBand: 12,
            gain: 10,
            qFactor: 5.0,
            filterType: FilterType.dip,
            threshold: 5,
          ),
        );
      });

      test('does not follow later changes', () {
        final before = param.snapshot();
        param.startingBand = 20;
        expect(before.startingBand, 3);
        expect(param.snapshot().startingBand, 20);
      });
    });
  });
}
