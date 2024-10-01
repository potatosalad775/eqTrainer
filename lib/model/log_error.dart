import 'dart:io';
import '../main.dart';

Future<void> logError(String failLog) async {
  File file = await File("${appSupportDir.path}${Platform.pathSeparator}log${Platform.pathSeparator}recentLog.txt").create(recursive: true);
  await file.writeAsString(failLog);
}