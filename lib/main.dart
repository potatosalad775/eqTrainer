import 'dart:io';
import 'package:coast_audio/coast_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:store_checker/store_checker.dart';
import 'package:window_size/window_size.dart';
import 'package:media_kit/media_kit.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/page/main_page.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/model/audio_state.dart';
import 'package:eq_trainer/model/setting_data.dart';

Future<void> main() async {
  // Initialize Packages
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isAndroid) installationSource = await StoreChecker.getSource;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('eqTrainer');
    setWindowMinSize(const Size(400, 480));
  }

  // Prepare Document Directory
  appSupportDir = await getApplicationSupportDirectory();
  if (Platform.isWindows) {
    audioClipDir = await Directory("${appSupportDir.path}\\audioclip").create(recursive: true);
  } else {
    audioClipDir = await Directory("${appSupportDir.path}/audioclip").create(recursive: true);
  }

  // Load Hive - settings data & playlist database
  await Hive.initFlutter(appSupportDir.path);
  Hive.registerAdapter(BackendDataAdapter());
  Hive.registerAdapter(MiscSettingsAdapter());

  // Load Backend Setting value
  final backendBox = await Hive.openBox<BackendData>(backendBoxName);
  backendList = backendBox.get(backendKey)?.backendList ?? [];
  backendBox.close();

  // Load Miscellaneous Settings
  final miscSettingsBox = await Hive.openBox<MiscSettings>(miscSettingsBoxName);
  savedMiscSettingsValue = miscSettingsBox.get(miscSettingsKey) ?? MiscSettings(false);
  miscSettingsBox.close();

  // Load Playlist Data
  Hive.registerAdapter(AudioClipAdapter());
  await Hive.openBox<AudioClip>(audioClipBoxName);

  runApp(
    EasyDynamicThemeWidget(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ko')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true,
        assetLoader: const YamlAssetLoader(),
        child: const App(),
      ),
    )
  );
}

class App extends StatefulWidget {
  const App({super.key});

  static AppState of(BuildContext context) {
    return context.findAncestorStateOfType<AppState>()!;
  }

  @override
  State<App> createState() => AppState();
}

class AppState extends State<App> {
  late AudioState _audioState;

  @override
  void initState() {
    super.initState();
    _audioState = AudioState.initialize(backendList: backendList);
    _upgrader.initialize();
  }

  @override
  Widget build(BuildContext context) {
    // Detect Device Screen Info
    final deviceScreenData = MediaQueryData.fromView(View.of(context));
    // Lock Orientation into Portrait if Screen's shortest side is too short
    if(deviceScreenData.size.shortestSide < 300) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NavBarProvider>(create: (_) => NavBarProvider()),
        ChangeNotifierProvider<AudioState>.value(value: _audioState),
      ],
      child: MaterialApp(
        title: 'eq_trainer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF375778)),
          fontFamily: 'PretendardVariable',
          typography: Typography.material2021(platform: defaultTargetPlatform),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF375778),
            brightness: Brightness.dark,
          ),
          fontFamily: 'PretendardVariable',
          typography: Typography.material2021(platform: defaultTargetPlatform),
          useMaterial3: true,
        ),
        themeMode: EasyDynamicTheme.of(context).themeMode,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: UpgradeAlert(
          upgrader: _upgrader,
          child: const MainPage()
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  void applyAudioState(AudioState state) {
    setState(() {
      _audioState = state;
    });
  }

  final _upgrader = Upgrader(
    messages: CustomUpgraderMessages(),
    storeController: UpgraderStoreController(
      onAndroid: () {
        if(installationSource == Source.IS_INSTALLED_FROM_PLAY_STORE) {
          return UpgraderPlayStore();
        } else {
          return UpgraderAppcastStore(appcastURL: appcastURL);
        }
      },
      onFuchsia: () => UpgraderAppcastStore(appcastURL: appcastURL),
      oniOS: () => UpgraderAppcastStore(appcastURL: appcastURL),
      onLinux: () => UpgraderAppcastStore(appcastURL: appcastURL),
      onMacOS: () => UpgraderAppcastStore(appcastURL: appcastURL),
      onWindows: () => UpgraderAppcastStore(appcastURL: appcastURL),
    ),
  );
}

//const mainFormat = AudioFormat(sampleRate: 48000, channels: 2);
//final mainSessionData = SessionParameter();
final reactiveElementData = ReactiveElementData();

String backendBoxName = "backendBox";
String backendKey = "backendKey";
String miscSettingsBoxName = "miscSettingsBox";
String miscSettingsKey = "miscSettingsKey";
String audioClipBoxName = "audioClipBox";

late Directory appSupportDir;
late Directory audioClipDir;

//AndroidAudioBackend? androidAudioBackend;
late final List<AudioDeviceBackend> backendList;
late final MiscSettings savedMiscSettingsValue;
Source? installationSource;

const appcastURL = "https://raw.githubusercontent.com/potatosalad775/eqTrainer/master/appcast.xml";
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