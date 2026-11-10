import 'dart:async';
import 'dart:io';
import 'package:eq_trainer/ui/core/third_party_licenses.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:upgrader/upgrader.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/main_page.dart';
import 'package:eq_trainer/data/audio_state.dart';
import 'package:eq_trainer/data/locale_provider.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/data/clips/audio_clip_repository.dart';
import 'package:eq_trainer/data/app_directories.dart';
import 'package:eq_trainer/data/clips/audio_clip_service.dart';
import 'package:eq_trainer/data/clips/clip_format_migration.dart';
import 'package:eq_trainer/data/clips/clip_library.dart';
import 'package:eq_trainer/data/clips/clip_recompress_service.dart';
import 'package:eq_trainer/data/clips/import_workflow_service.dart';
import 'package:eq_trainer/data/legacy/legacy_clip_migration.dart';
import 'package:eq_trainer/data/legacy/legacy_settings_migration.dart';
import 'package:eq_trainer/data/clips/playlist_service.dart';
import 'package:eq_trainer/ui/core/upgrader_service.dart';
import 'package:eq_trainer/domain/session_parameter.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';
import 'package:eq_trainer/ui/session/state/session_controller.dart';

Future<void> main() async {
  // Initialize Packages
  WidgetsFlutterBinding.ensureInitialized();

  // Prepare Document Directory
  appSupportDir = await resolveAppDataDir();
  // shared_preferences has one file per app, so debug gets its own keys instead.
  // Must come before the first getInstance.
  if (usesSeparateDebugData) SharedPreferences.setPrefix('debug.');

  // Load Hive - only ever read now, to migrate what older versions stored in it
  await Hive.initFlutter(appSupportDir.path);

  // Load Settings - older versions kept these in Hive, so move them first
  final prefs = await SharedPreferences.getInstance();
  await migrateLegacySettings(prefs);
  final localeProvider = await LocaleProvider.load();
  final miscSettings = await MiscSettingsProvider.load();

  // Load Playlist Data - the one instance everything shares, see AudioClipRepository
  final clipRepository = await AudioClipRepository.open(
    File(p.join(appSupportDir.path, audioClipFileName)),
  );
  await migrateLegacyClips(clipRepository, prefs, boxDirectory: appSupportDir.path);
  // Records and files together, over that one repository
  final clipLibrary = ClipLibrary(clipRepository, AppDirectories());

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

  // Convert any pre-SoLoud .m4a clips to whatever the user's import-format
  // setting would produce for them today. Deliberately not awaited: it is a
  // no-op scan on every launch but the first one after updating, and blocking
  // startup behind a full library's worth of decode-and-encode would hold the
  // app on a blank screen. It commits one clip at a time, so a clip the user
  // reaches mid-run is either fully converted or untouched.
  //
  // Handed to the widget tree as well: the screens that play audio pause it
  // while they are open, so the run never competes with playback for CPU.
  final clipFormatMigration = ClipFormatMigration(
    clipLibrary,
    importFormat: miscSettings.importFormat,
  );
  unawaited(clipFormatMigration.run());

  runApp(
    ToastificationWrapper(
      child: App(
        upgrader: upgrader,
        clipFormatMigration: clipFormatMigration,
        localeProvider: localeProvider,
        miscSettings: miscSettings,
        androidBackend: readAndroidBackend(prefs),
        clipRepository: clipRepository,
        clipLibrary: clipLibrary,
      ),
    ),
  );
}

class App extends StatefulWidget {
  const App({
    super.key,
    required this.upgrader,
    required this.clipFormatMigration,
    required this.localeProvider,
    required this.miscSettings,
    required this.androidBackend,
    required this.clipRepository,
    required this.clipLibrary,
  });

  final Upgrader upgrader;
  final ClipFormatMigration clipFormatMigration;
  final LocaleProvider localeProvider;
  final MiscSettingsProvider miscSettings;
  final AndroidAudioBackend androidBackend;
  final AudioClipRepository clipRepository;
  final ClipLibrary clipLibrary;

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
    _audioState = AudioState.initialize(androidBackend: widget.androidBackend);
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
        ChangeNotifierProvider<MiscSettingsProvider>.value(value: widget.miscSettings),
        ChangeNotifierProvider<LocaleProvider>.value(value: widget.localeProvider),

        // UI-level
        ChangeNotifierProvider<NavBarProvider>(create: (_) => NavBarProvider()),
        ChangeNotifierProvider<AudioState>.value(value: _audioState),

        // Directories
        Provider<AppDirectories>(create: (_) => AppDirectories()),

        // Repository
        Provider<IAudioClipRepository>.value(value: widget.clipRepository),
        // Built over the repository above, so there is still exactly one.
        Provider<ClipLibrary>.value(value: widget.clipLibrary),

        // Services
        Provider<AudioClipService>(create: (ctx) => AudioClipService(
          ctx.read<IAudioClipRepository>(),
          ctx.read<AppDirectories>(),
        )),
        Provider<PlaylistService>(create: (ctx) => PlaylistService(
          ctx.read<IAudioClipRepository>(),
          ctx.read<AppDirectories>(),
        )),
        Provider<ImportWorkflowService>(create: (_) => ImportWorkflowService()),
        // .value, not create: the run was started in main() before the tree
        // existed, and main() owns it — the provider must not dispose it.
        ChangeNotifierProvider<ClipFormatMigration>.value(
          value: widget.clipFormatMigration,
        ),
        Provider<ClipRecompressService>(create: (ctx) => ClipRecompressService(
          ctx.read<ClipLibrary>(),
        )),

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
        themeMode: context.watch<MiscSettingsProvider>().themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: context.watch<LocaleProvider>().locale,
        home: UpgradeAlert(
          upgrader: widget.upgrader,
          child: const MainPage()
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  void applyAudioState(AudioState newState) {
    final oldState = _audioState;
    oldState.stopDevicePolling();
    setState(() {
      _audioState = newState;
    });
    _audioState.startDevicePolling();
    // Deferred so Provider<AudioState>.value has rebuilt and detached its
    // listener from oldState before we dispose it.
    WidgetsBinding.instance.addPostFrameCallback((_) => oldState.dispose());
  }
}

const String audioClipFileName = "audio_clips.json";

late Directory appSupportDir;