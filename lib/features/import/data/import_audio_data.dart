import 'package:flutter/foundation.dart';

class ImportAudioData extends ChangeNotifier {
  /// Sentinel for "the whole clip", used until the source's real duration is
  /// known. Any real audio file is far shorter, so the editor's
  /// `position < clipEndTime` checks hold before the load completes.
  static const _unbounded = Duration(days: 3650);

  Duration _clipStartTime = Duration.zero;
  Duration _clipEndTime = _unbounded;

  Duration get clipStartTime => _clipStartTime;
  Duration get clipEndTime => _clipEndTime;

  set clipStartTime(Duration value) {
    _clipStartTime = value;
    notifyListeners();
  }

  set clipEndTime(Duration value) {
    _clipEndTime = value;
    notifyListeners();
  }

}
