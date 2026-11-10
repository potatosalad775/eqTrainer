import 'package:equatable/equatable.dart';

/// Which kinds of graph a round can ask about.
enum FilterType { peak, dip, peakDip }

/// What a session was configured with, frozen at the moment it started.
///
/// The config page edits a `SessionParameter`; a session takes a copy of it
/// so that nothing the user does afterwards, and nothing the session does, can
/// reach the other. [startingBand] is only where the session begins: the band
/// count it ends at belongs to the session.
///
/// The valid choices are defined here once. The config page offers exactly
/// these, and `SessionParameter` refuses anything else.
class SessionSettings extends Equatable {
  const SessionSettings({
    required this.startingBand,
    required this.gain,
    required this.qFactor,
    required this.filterType,
    required this.threshold,
  });

  /// The fewest and most bands a session can have. The band ladder stops here.
  static const int minBands = 2;
  static const int maxBands = 25;

  /// Every band count, [minBands] to [maxBands] inclusive.
  static final List<int> bandCounts = List.unmodifiable([
    for (var i = minBands; i <= maxBands; i++) i,
  ]);

  static const List<int> gains = [3, 4, 5, 6, 8, 10, 15];
  static const List<double> qFactors = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0];
  static const List<int> thresholds = [1, 3, 5, 10];

  final int startingBand;
  final int gain;
  final double qFactor;
  final FilterType filterType;
  final int threshold;

  @override
  List<Object?> get props => [startingBand, gain, qFactor, filterType, threshold];
}
