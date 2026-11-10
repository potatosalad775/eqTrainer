import 'package:eq_trainer/ui/playlist/clip_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = <(double, String)>[
    (205, '03:25.00'),
    (0.5, '00:00.50'),
    (59.999, '00:59.99'),
    (3599.99, '59:59.99'),
    (3600, '1:00:00.00'),
    (3725, '1:02:05.00'),
    (36000, '10:00:00.00'),
  ];

  for (final (seconds, expected) in cases) {
    test('$seconds s is $expected', () {
      expect(formatClipDuration(seconds), expected);
    });
  }
}
