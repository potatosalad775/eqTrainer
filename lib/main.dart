import 'dart:io';
import 'package:eq_trainer/shared/service/third_party_licenses.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:upgrader/upgrader.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:window_size/window_size.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:eq_trainer/features/main_page.dart';
import 'package:eq_trainer/shared/model/audio_clip.dart';
import 'package:eq_trainer/shared/service/audio_format_helper.dart';
import 'package:eq_trainer/shared/model/audio_state.dart';
import 'package:eq_trainer/shared/model/setting_data.dart';
import 'package:eq_trainer/shared/repository/audio_clip_repository.dart';
import 'package:eq_trainer/shared/service/app_directories.dart';
import 'package:eq_trainer/shared/service/audio_clip_service.dart';
import 'package:eq_trainer/shared/service/import_workflow_service.dart';
import 'package:eq_trainer/shared/service/playlist_service.dart';
import 'package:eq_trainer/shared/service/upgrader_service.dart';
import 'package:eq_trainer/features/session/data/session_parameter.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/model/session_controller.dart';

// Opens a Hive box, recreating it from scratch if it fails to open (e.g. a
// corrupt file left by a crash mid-write) instead of crash-looping on every
// launch. For boxes holding data worth trying to recover (audioClipBox), the
// corrupt file is copied aside first so it isn't silently lost.
Future<Box<T>> _openBoxSafely<T>(String name, {bool backupOnCorruption = false}) async {
  try {
    return await Hive.openBox<T>(name);
  } catch (e) {
    debugPrint('[Hive] Box "$name" failed to open ($e); recreating.');
    if (backupOnCorruption) {
      final file = File(p.join(appSupportDir.path, '${name.toLowerCase()}.hive'));
      if (await file.exists()) {
        try {
          await file.copy('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
        } catch (_) {}
      }
    }
    await Hive.deleteBoxFromDisk(name);
    return Hive.openBox<T>(name);
  }
}

Future<void> main() async {
  // Initialize Packages
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('eqTrainer');
    setWindowMinSize(const Size(400, 480));
  }

  // Prepare Document Directory
  appSupportDir = await getApplicationSupportDirectory();

  // Load Hive - settings data & playlist database
  await Hive.initFlutter(appSupportDir.path);
  Hive.registerAdapter(BackendDataAdapter());
  Hive.registerAdapter(MiscSettingsAdapter());

  // Load Backend Setting value (opened and closed once — not needed after startup)
  final backendBox = await _openBoxSafely<BackendData>(backendBoxName);
  backendList = backendBox.get(backendKey)?.backendList ?? [];
  await backendBox.close();

  // Load Miscellaneous Settings (kept open — FrequencyTooltipCard accesses it at runtime)
  final miscSettingsBox = await _openBoxSafely<MiscSettings>(miscSettingsBoxName);
  // volumeCompensation defaults to true, matching the Hive field's own
  // defaultValue (setting_data.dart) — otherwise a fresh install and an
  // upgraded install disagree on the default and get opposite answer-leak
  // protection from loudness cues.
  savedMiscSettingsValue = miscSettingsBox.get(miscSettingsKey) ?? MiscSettings(false, ImportFormat.allM4a, true);

  // Load Playlist Data
  Hive.registerAdapter(AudioClipAdapter());
  await _openBoxSafely<AudioClip>(audioClipBoxName, backupOnCorruption: true);

  // Set Android System UI Style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemStatusBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
  ));
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: [SystemUiOverlay.top]);

  // Register additional licenses for bundled native libraries
  registerThirdPartyLicenses();

  // Prepare Upgrader
  final upgrader = await UpgraderService().getInstance();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ko')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      assetLoader: const YamlAssetLoader(),
      child: ToastificationWrapper(
        child: App(
          upgrader: upgrader,
        ),
      ),
    ),
  );
}

class App extends StatefulWidget {
  const App({super.key, required this.upgrader});

  final Upgrader upgrader;

  static AppState of(BuildContext context) {
    return context.findAncestorStateOfType<AppState>()!;
  }

  @override
  State<App> createState() => AppState();
}

class AppState extends State<App> with WidgetsBindingObserver {
  late AudioState _audioState;

  @override
  void initState() {
    super.initState();
    _audioState = AudioState.initialize(backendList: backendList);
    _audioState.startDevicePolling();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Device polling itself is already desktop-only (see
    // AudioState.startDevicePolling) because creating a parallel
    // AudioDeviceContext can interfere with an active AAudio playback device
    // on Android. This resume-triggered refresh needs the same gate.
    if (state == AppLifecycleState.resumed &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      _audioState.refreshDevices();
    }
  }

  @override
  void didChangeDependencies() {
    // Detect Device Screen Info
    final deviceScreenData = MediaQueryData.fromView(View.of(context));
    // Lock Orientation into Portrait if Screen's shortest side is too short.
    // Note: the landscape branch below is intentionally inert on iPhone —
    // ios/Runner/Info.plist's UISupportedInterfaceOrientations only declares
    // portrait for iPhone (landscape is iPad-only), which is the actual
    // source of truth iOS enforces; this is a deliberate product choice
    // (training UI isn't designed for iPhone landscape), not a bug.
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
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),

        // UI-level
        ChangeNotifierProvider<NavBarProvider>(create: (_) => NavBarProvider()),
        ChangeNotifierProvider<AudioState>.value(value: _audioState),

        // Directories
        Provider<AppDirectories>(create: (_) => AppDirectories()),

        // Repository
        Provider<AudioClipRepository>(create: (_) => AudioClipRepository()),
        // Expose as interface as well for flexible injection
        Provider<IAudioClipRepository>(create: (ctx) => ctx.read<AudioClipRepository>()),

        // Services
        Provider<AudioClipService>(create: (ctx) => AudioClipService(
          ctx.read<IAudioClipRepository>(),
          ctx.read<AppDirectories>(),
        )),
        Provider<PlaylistService>(create: (ctx) => PlaylistService(
          ctx.read<IAudioClipRepository>(),
          ctx.read<AppDirectories>(),
        )),
        Provider<ImportWorkflowService>(create: (_) => const ImportWorkflowService()),

        // Session parameters and data notifiers
        ChangeNotifierProvider<SessionParameter>(create: (_) => SessionParameter()),

        // Session store (depends on freq/state/result)
        ChangeNotifierProvider<SessionStore>(
          create: (ctx) => SessionStore(),
        ),

        // Controller
        Provider<SessionController>(create: (_) => SessionController()),
      ],
      builder: (context, child) => MaterialApp(
        title: 'eq_trainer',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: context.watch<ThemeProvider>().themeMode,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: UpgradeAlert(
          upgrader: widget.upgrader,
          child: const MainPage()
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  void applyAudioState(AudioState newState, {List<String>? savedBackendList}) {
    final oldState = _audioState;
    oldState.stopDevicePolling();
    if (savedBackendList != null) {
      backendList = savedBackendList;
    }
    setState(() {
      _audioState = newState;
    });
    _audioState.startDevicePolling();
    // Deferred so Provider<AudioState>.value has rebuilt and detached its
    // listener from oldState before we dispose it.
    WidgetsBinding.instance.addPostFrameCallback((_) => oldState.dispose());
  }
}

const String backendBoxName = "backendBox";
const String backendKey = "backendKey";
const String miscSettingsBoxName = "miscSettingsBox";
const String miscSettingsKey = "miscSettingsKey";
const String audioClipBoxName = "audioClipBox";

late Directory appSupportDir;

//AndroidAudioBackend? androidAudioBackend;
late List<String> backendList;
late final MiscSettings savedMiscSettingsValue;