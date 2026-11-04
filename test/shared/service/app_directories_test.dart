import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/shared/service/app_directories.dart';

void main() {
  // Tests run in debug mode on a desktop host, here and on every CI runner.
  test('a desktop debug build is kept apart from an installed copy', () {
    expect(usesSeparateDebugData, isTrue);
    final support = p.join('support', 'eq_trainer');
    expect(appDataPath(support), equals(p.join(support, 'debug')));
  });
}
