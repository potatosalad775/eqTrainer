import 'package:eq_trainer/ui/core/app_dimens.dart';
import 'package:eq_trainer/ui/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/l10n/l10n.dart';
import 'package:eq_trainer/ui/config/config_page.dart';
import 'package:eq_trainer/ui/playlist/playlist_page.dart';
import 'package:eq_trainer/ui/settings/settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  Widget build(BuildContext context) {
    final navBarProvider = Provider.of<NavBarProvider>(context);
    final l10n = context.l10n;
    final (titleStart, titleEnd) = switch (navBarProvider.currentIndex) {
      0 => (l10n.mainAppbarTitleConfig1, l10n.mainAppbarTitleConfig2),
      1 => (l10n.mainAppbarTitlePlaylist1, l10n.mainAppbarTitlePlaylist2),
      _ => (l10n.mainAppbarTitleSetting1, l10n.mainAppbarTitleSetting2),
    };

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 4,
        shadowColor: context.colors.shadow,
        toolbarHeight: AppDimens.appBarHeight,
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.maxWidgetWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.verticalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  titleStart,
                ),
                Text(
                  titleEnd,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.maxWidgetWidth),
          child: IndexedStack(
            index: navBarProvider.currentIndex,
            children: const [
              ConfigPage(),
              PlaylistPage(),
              SettingsPage(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navBarProvider.currentIndex,
        onDestinationSelected: (index) {
          navBarProvider.currentIndex = index;
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home), label: context.l10n.mainNavbarMain),
          NavigationDestination(
              icon: const Icon(Icons.music_note),
              label: context.l10n.mainNavbarPlaylist),
          NavigationDestination(
              icon: const Icon(Icons.settings),
              label: context.l10n.mainNavbarSettings),
        ],
        backgroundColor: context.colors.surfaceContainerHigh,
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}

class NavBarProvider extends ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  set currentIndex(int value) {
    _currentIndex = value;
    notifyListeners();
  }
}
