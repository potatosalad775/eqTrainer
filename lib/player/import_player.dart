import 'package:eq_trainer/player/player_isolate.dart';

class ImportPlayer extends PlayerIsolate {
  String _filePath = "";

  set filePath(String value) {
    _filePath = value;
  }

  String get filePath => _filePath;

  ImportPlayer();
}

