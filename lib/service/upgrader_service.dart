import 'dart:io';
import 'package:upgrader/upgrader.dart';
import 'package:store_checker/store_checker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:version/version.dart';

class UpgraderService {
  final appcastURL = "https://raw.githubusercontent.com/potatosalad775/eqTrainer/master/appcast.xml";
  var installationSource = (Platform.isAndroid) ? StoreChecker.getSource : Source.IS_INSTALLED_FROM_OTHER_SOURCE;

  Future<Upgrader> getInstance() async {
    final osVersion = await getOsVersion(UpgraderOS());await Upgrader.clearSavedSettings();
    return Upgrader(
      messages: CustomUpgraderMessages(),
      storeController: UpgraderStoreController(
        onAndroid: () {
          if(installationSource == Source.IS_INSTALLED_FROM_PLAY_STORE) {
            return UpgraderPlayStore();
          } else {
            return UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion);
          }
        },
        onFuchsia: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion),
        oniOS: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion),
        onLinux: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion),
        onMacOS: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion),
        onWindows: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion),
      ),
    );
  }

  Future<Version> getOsVersion(UpgraderOS upgraderOS) async {
    final deviceInfo = DeviceInfoPlugin();
    String? osVersionString;
    Version osVersion;

    if (upgraderOS.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      osVersionString = androidInfo.version.baseOS;
    } else if (upgraderOS.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      osVersionString = iosInfo.systemVersion;
    } else if (upgraderOS.isFuchsia) {
      osVersionString = '';
    } else if (upgraderOS.isLinux) {
      final info = await deviceInfo.linuxInfo;
      osVersionString = info.version;
    } else if (upgraderOS.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      final release = info.osRelease;

      // For macOS the release string looks like: Version 13.2.1 (Build 22D68)
      // We need to parse out the actual OS version number.

      String regExpSource = r"[\w]*[\s]*(?<version>[^\s]+)";
      final regExp = RegExp(regExpSource, caseSensitive: false);
      final match = regExp.firstMatch(release);
      final version = match?.namedGroup('version');
      osVersionString = version;
    } else if (upgraderOS.isWeb) {
      osVersionString = '0.0.0';
    } else if (upgraderOS.isWindows) {
      final info = await deviceInfo.windowsInfo;
      osVersionString = info.displayVersion;
    }

    // If the OS version string is not valid, don't use it.
    try {
      osVersion = osVersionString?.isNotEmpty == true
          ? Version.parse(osVersionString!)
          : Version(0, 0, 0);
    } catch (e) {
      osVersion = Version(0, 0, 0);
    }

    return osVersion;
  }
}

class CustomUpgraderMessages extends UpgraderMessages {
  @override
  String? message(UpgraderMessage messageKey) {
    super.message(messageKey);
    switch (messageKey) {
      case UpgraderMessage.body:
        return "UPDATE_ALERT_MESSAGE_BODY".tr();
      case UpgraderMessage.buttonTitleIgnore:
        return "UPDATE_ALERT_BUTTON_IGNORE".tr();
      case UpgraderMessage.buttonTitleLater:
        return "UPDATE_ALERT_BUTTON_LATER".tr();
      case UpgraderMessage.buttonTitleUpdate:
        return "UPDATE_ALERT_BUTTON_UPDATE".tr();
      case UpgraderMessage.prompt:
        return "UPDATE_ALERT_MESSAGE_PROMPT".tr();
      case UpgraderMessage.releaseNotes:
        return "UPDATE_ALERT_RELEASE_NOTE".tr();
      case UpgraderMessage.title:
        return "UPDATE_ALERT_MESSAGE_TITLE".tr();
    }
  }
}