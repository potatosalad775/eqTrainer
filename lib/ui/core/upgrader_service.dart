import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

class UpgraderService {
  final appcastURL = "https://raw.githubusercontent.com/potatosalad775/eqTrainer/master/appcast.xml";

  Future<String?> _getInstallationSource() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
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
    return _LocalizedUpgrader(
      // To test the dialog: fvm flutter run --dart-define=UPGRADER_DISPLAY_ALWAYS=true
      debugDisplayAlways: const bool.fromEnvironment('UPGRADER_DISPLAY_ALWAYS'),
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

/// The upgrader is built in main(), before there is a locale to read, so its
/// strings are looked up from the context the alert is shown from.
class _LocalizedUpgrader extends Upgrader {
  _LocalizedUpgrader({super.debugDisplayAlways, super.storeController});

  @override
  UpgraderMessages determineMessages(BuildContext context) =>
      CustomUpgraderMessages(context.l10n);
}

class CustomUpgraderMessages extends UpgraderMessages {
  CustomUpgraderMessages(this._l10n) : super(code: _l10n.localeName);

  final AppLocalizations _l10n;

  @override
  String? message(UpgraderMessage messageKey) {
    switch (messageKey) {
      case UpgraderMessage.body:
        return _l10n.updateAlertMessageBody;
      case UpgraderMessage.buttonTitleIgnore:
        return _l10n.updateAlertButtonIgnore;
      case UpgraderMessage.buttonTitleLater:
        return _l10n.updateAlertButtonLater;
      case UpgraderMessage.buttonTitleUpdate:
        return _l10n.updateAlertButtonUpdate;
      case UpgraderMessage.prompt:
        return _l10n.updateAlertMessagePrompt;
      case UpgraderMessage.releaseNotes:
        return _l10n.updateAlertReleaseNote;
      case UpgraderMessage.title:
        return _l10n.updateAlertMessageTitle;
    }
  }
}