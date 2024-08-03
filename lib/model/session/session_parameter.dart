import 'package:flutter/material.dart';
import 'package:eq_trainer/page/session_page.dart';

// SessionParameter - Manage Variables required for Session
class SessionParameter extends ChangeNotifier {
  int _startingBand = 3;
  int _gain = 6;
  double _qFactor = 1;
  FilterType _filterType = FilterType.peakDip;
  int _threshold = 3;

  int get startingBand => _startingBand;
  set startingBand(int value) {
    _startingBand = value.clamp(2, 25);
    notifyListeners();
  }
  int get gain => _gain;
  set gain(int value) {
    _gain = value;
    notifyListeners();
  }
  double get qFactor => _qFactor;
  set qFactor(double value) {
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
    _threshold = value;
    notifyListeners();
  }
}