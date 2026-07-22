import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

class UpgraderService {
  final appcastURL = "https://raw.githubusercontent.com/potatosalad775/eqTrainer/master/appcast.xml";

  Future<String?> _getInstallationSource() async {
    if (!Platform.isAndroid) return null;
    // StoreChecker.getSource is an async getter — it must be awaited. The old
    // code stored the unresolved Future in a field and compared it to a Source
    // enum, which was never equal, so Play Store installs always fell through
    // to the direct-APK appcast flow.
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.installerStore;
  }

  Future<Upgrader> getInstance() async {
    final osVersion = await getOsVersion(UpgraderOS());
    final installationSource = await _getInstallationSource();
    return Upgrader(
      messages: CustomUpgraderMessages(),
      storeController: UpgraderStoreController(
        onAndroid: () {
          // If the app was installed from the Play Store, use the Play Store upgrader.
          if(installationSource == "com.android.vending") {
            return UpgraderPlayStore();
          } else {
            return UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion.toString());
          }
        },
        onFuchsia: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion.toString()),
        oniOS: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion.toString()),
        onLinux: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion.toString()),
        onMacOS: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion.toString()),
        onWindows: () => UpgraderAppcastStore(appcastURL: appcastURL, osVersion: osVersion.toString()),
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
      if (version != null) osVersionString = version;
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