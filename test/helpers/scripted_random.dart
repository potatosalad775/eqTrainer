import 'dart:math';

/// A [Random] that returns the numbers it was given, in order.
///
/// For tests where which graph comes up matters. Each value is what
/// `nextInt` returns, whatever its `max`; a value outside `0..max` or a script
/// that runs out fails loudly, so a test that draws more often than it
/// planned to is caught rather than quietly handed a number.
class ScriptedRandom implements Random {
  ScriptedRandom(Iterable<int> script) : _script = List.of(script);

  final List<int> _script;
  var _next = 0;

  /// How many scripted values have not been drawn yet.
  int get remaining => _script.length - _next;

  @override
  int nextInt(int max) {
    if (_next >= _script.length) {
      throw StateError('ScriptedRandom ran out after ${_script.length} draws');
    }
    final value = _script[_next++];
    if (value < 0 || value >= max) {
      throw StateError('scripted $value is outside 0..${max - 1}');
    }
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}
