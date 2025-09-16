import 'package:flutter/foundation.dart';

// SessionStateData - Used for controlling content to show user
class SessionStateData extends ChangeNotifier {
  SessionState _sessionState = SessionState.loading;
  int currentSessionPoint = 0;
  int _selectedPickerNum = 1;

  SessionState get sessionState => _sessionState;
  set sessionState(SessionState sessionState) {
    _sessionState = sessionState;
    notifyListeners();
  }

  int get selectedPickerNum => _selectedPickerNum;
  set selectedPickerNum(int value) {
    _selectedPickerNum = value;
    notifyListeners();
  }
}
enum SessionState { loading, ready, playlistEmpty, error }