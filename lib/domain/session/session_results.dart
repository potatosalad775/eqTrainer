import 'package:equatable/equatable.dart';

/// The frequency ranges results are grouped into, lowest first.
///
/// The bounds are in Hz. A range includes its lower bound and excludes its
/// upper one.
enum ResultBand {
  subBass(20, 80),
  midBass(80, 200),
  lowerMidrange(200, 800),
  centreMidrange(800, 1500),
  upperMidrange(1500, 5000),
  treble(5000, 10000),
  upperTreble(10000, 20000);

  const ResultBand(this.lowerHz, this.upperHz);

  final int lowerHz;
  final int upperHz;

  /// The band a round at [frequency] is filed under.
  ///
  /// Anything that fits no range, which the session's own frequencies never
  /// do, goes in the top band.
  static ResultBand of(double frequency) {
    for (final band in values) {
      if (band.lowerHz <= frequency && frequency < band.upperHz) return band;
    }
    return upperTreble;
  }
}

/// How a session went, as counts. Widgets decide how to show them.
class SessionResults extends Equatable {
  const SessionResults._(this._rounds, this._correct);

  /// A session with no rounds yet.
  factory SessionResults.empty() => SessionResults._(
        List.filled(ResultBand.values.length, 0, growable: false),
        List.filled(ResultBand.values.length, 0, growable: false),
      );

  final List<int> _rounds;
  final List<int> _correct;

  /// These results plus one answered round, filed under [band].
  SessionResults withRound(ResultBand band, {required bool isCorrect}) {
    final rounds = List<int>.of(_rounds, growable: false);
    final correct = List<int>.of(_correct, growable: false);
    rounds[band.index]++;
    if (isCorrect) correct[band.index]++;
    return SessionResults._(rounds, correct);
  }

  int get rounds => _rounds.fold(0, (a, b) => a + b);
  int get correct => _correct.fold(0, (a, b) => a + b);
  int get incorrect => rounds - correct;

  int roundsIn(ResultBand band) => _rounds[band.index];
  int correctIn(ResultBand band) => _correct[band.index];

  /// Share of rounds answered correctly, 0 to 100, or null before any round.
  double? get percentage => rounds == 0 ? null : correct * 100 / rounds;

  double? percentageIn(ResultBand band) {
    final inBand = roundsIn(band);
    return inBand == 0 ? null : correctIn(band) * 100 / inBand;
  }

  @override
  List<Object?> get props => [_rounds, _correct];
}
