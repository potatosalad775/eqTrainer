import 'dart:io';
import 'package:eq_trainer/model/setting_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:store_checker/store_checker.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_coast_audio_miniaudio/flutter_coast_audio_miniaudio.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/page/main_page.dart';
import 'package:eq_trainer/model/session_data.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';

Future<void> main() async {
  // Initialize Packages
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  if (Platform.isAndroid) installationSource = await StoreChecker.getSource;

  // Prepare Document Directory
  appSupportDir = await getApplicationSupportDirectory();
  audioClipDir = await Directory("${appSupportDir.path}/audioclip").create(recursive: true);

  // Load Hive - audio backend info & playlist database
  await Hive.initFlutter(appSupportDir.path);
  Hive.registerAdapter(SettingDataAdapter());
  Hive.registerAdapter(AndroidAudioBackendAdapter());
  Hive.registerAdapter(AudioClipAdapter());
  var settingBox = await Hive.openBox<SettingData>(settingBoxName);
  await Hive.openBox<AudioClip>(audioClipBoxName);

  // Load Setting value
  if(settingBox.isNotEmpty) { androidAudioBackend = settingBox.get(audioBackendKey)?.androidAudioBackend; }

  // Initialize Player
  MabLibrary.initialize();
  if(androidAudioBackend == null || androidAudioBackend == AndroidAudioBackend.aaudio) {
    MabDeviceContext.enableSharedInstance(backends: backendsAAUDIO);
  }
  else {
    MabDeviceContext.enableSharedInstance(backends: backendsOPENSL);
  }

  runApp(
    EasyDynamicThemeWidget(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ko')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true,
        assetLoader: const YamlAssetLoader(),
        child: const MyApp(),
      ),
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Detect Device Screen Info
    final deviceScreenData = MediaQueryData.fromView(View.of(context));
    // Lock Orientation into Portrait if Screen's shortest side is too short
    if(deviceScreenData.size.shortestSide < 550) {
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
        ChangeNotifierProvider<IsolatedMusicPlayer>(create: (_) => IsolatedMusicPlayer(format: mainFormat)),
        ChangeNotifierProvider<SessionData>.value(value: mainSessionData),
        ChangeNotifierProvider<SessionAudioData>(create: (_) => SessionAudioData()),
        ChangeNotifierProvider<SessionFrequencyData>(create: (_) => SessionFrequencyData()),
        ChangeNotifierProvider<SessionResultData>(create: (_) => SessionResultData()),
        ChangeNotifierProvider<SessionStateData>(create: (_) => SessionStateData()),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: FlexColorScheme.themedSystemNavigationBar(
          context,
          systemNavBarStyle: FlexSystemNavBarStyle.transparent,
          opacity: 1,
        ),
        child: MaterialApp(
          title: 'eq_trainer',
          theme: FlexThemeData.light(
            scheme: FlexScheme.sanJuanBlue,
            blendLevel: 2,
            appBarElevation: 0.5,
            fontFamily: 'PretendardVariable',
            typography: Typography.material2021(platform: defaultTargetPlatform),
          ),
          darkTheme: FlexThemeData.dark(
            scheme: FlexScheme.sanJuanBlue,
            blendLevel: 7,
            appBarElevation: 0.5,
            fontFamily: 'PretendardVariable',
            typography: Typography.material2021(platform: defaultTargetPlatform)
          ),
          themeMode: EasyDynamicTheme.of(context).themeMode,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const MainPage(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

final backendsOPENSL = [
  MabBackend.coreAudio,
  MabBackend.openSl,
];

final backendsAAUDIO = [
  MabBackend.coreAudio,
  MabBackend.aaudio,
];

const mainFormat = AudioFormat(sampleRate: 48000, channels: 2);
final mainSessionData = SessionData();
final reactiveElementData = ReactiveElementData();

String settingBoxName = "settingBox";
String audioBackendKey = "audioBackendKey";
String audioClipBoxName = "audioClipBox";

late Directory appSupportDir;
late Directory audioClipDir;

AndroidAudioBackend? androidAudioBackend;
Source? installationSource;