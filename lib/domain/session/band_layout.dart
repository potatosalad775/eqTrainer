import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';

/// The graphs a round chooses between, and what each of them means.
///
/// A graph is one selectable curve. Graph indices are 0-based here; the picker
/// shows them 1-based and the UI converts in one place. In peak-and-dip mode
/// every band has two graphs, so a band's peak is graph `2 * band` and its dip
/// is graph `2 * band + 1`.
class BandLayout extends Equatable {
  BandLayout(this.bandCount, this.filterType)
      : assert(bandCount >= 1),
        centerFrequencies = _centerFrequencies(bandCount);

  final int bandCount;
  final FilterType filterType;

  /// The centre of each band in Hz, lowest first.
  ///
  /// The bands split 20 Hz to 20 kHz into equal widths on a log axis and each
  /// one sits at the middle of its slot.
  final List<double> centerFrequencies;

  int get graphCount =>
      filterType == FilterType.peakDip ? bandCount * 2 : bandCount;

  int bandOf(int graphIndex) {
    _check(graphIndex);
    return filterType == FilterType.peakDip ? graphIndex ~/ 2 : graphIndex;
  }

  bool isDip(int graphIndex) {
    _check(graphIndex);
    return switch (filterType) {
      FilterType.dip => true,
      FilterType.peak => false,
      FilterType.peakDip => graphIndex.isOdd,
    };
  }

  double frequencyOf(int graphIndex) => centerFrequencies[bandOf(graphIndex)];

  /// [gainDb] as the filter should get it: negative for a dip.
  double signedGain(int graphIndex, double gainDb) =>
      isDip(graphIndex) ? -gainDb : gainDb;

  void _check(int graphIndex) {
    RangeError.checkValidIndex(graphIndex, centerFrequencies, 'graphIndex', graphCount);
  }

  static List<double> _centerFrequencies(int bandCount) {
    final multiplier = pow(1000, 1 / (2 * bandCount)).toDouble();
    var frequency = 20 * multiplier;
    final result = <double>[];
    for (var i = 0; i < bandCount; i++) {
      result.add(frequency);
      frequency *= pow(multiplier, 2);
    }
    return List.unmodifiable(result);
  }

  @override
  List<Object?> get props => [bandCount, filterType];
}
