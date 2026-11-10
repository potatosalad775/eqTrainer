import 'package:flutter/foundation.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';

/// What the config page is editing, kept for the whole life of the app.
///
/// A setter takes only a value the config page offers (see [SessionSettings])
/// and ignores anything else, so a bad value can never reach a session. A
/// session does not read this directly: it takes a [snapshot] when it starts.
class SessionParameter extends ChangeNotifier {
  int _startingBand = 3;
  int _gain = 6;
  double _qFactor = 1;
  FilterType _filterType = FilterType.peakDip;
  int _threshold = 3;

  int get startingBand => _startingBand;
  set startingBand(int value) {
    if (!SessionSettings.bandCounts.contains(value)) return;
    _startingBand = value;
    notifyListeners();
  }

  int get gain => _gain;
  set gain(int value) {
    if (!SessionSettings.gains.contains(value)) return;
    _gain = value;
    notifyListeners();
  }

  double get qFactor => _qFactor;
  set qFactor(double value) {
    if (!SessionSettings.qFactors.contains(value)) return;
    _qFactor = value;
    notifyListeners();
  }

  FilterType get filterType => _filterType;
  set filterType(FilterType value) {
    _filterType = value;
    notifyListeners();
  }

  int get threshold => _threshold;
  set threshold(int value) {
    if (!SessionSettings.thresholds.contains(value)) return;
    _threshold = value;
    notifyListeners();
  }

  /// The values as they are now, for a session to keep.
  SessionSettings snapshot() => SessionSettings(
        startingBand: _startingBand,
        gain: _gain,
        qFactor: _qFactor,
        filterType: _filterType,
        threshold: _threshold,
      );
}
