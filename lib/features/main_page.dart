import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/config/config_page.dart';
import 'package:eq_trainer/features/playlist/playlist_page.dart';
import 'package:eq_trainer/features/settings/settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const List<List<String>> _pageTitle = [
    ["MAIN_APPBAR_TITLE_CONFIG_1", "MAIN_APPBAR_TITLE_CONFIG_2"],
    ["MAIN_APPBAR_TITLE_PLAYLIST_1", "MAIN_APPBAR_TITLE_PLAYLIST_2"],
    ["MAIN_APPBAR_TITLE_SETTING_1", "MAIN_APPBAR_TITLE_SETTING_2"],
  ];

  @override
  Widget build(BuildContext context) {
    final navBarProvider = Provider.of<NavBarProvider>(context);

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
                  tr(_pageTitle[navBarProvider.currentIndex][0], context: context),
                ),
                Text(
                  tr(_pageTitle[navBarProvider.currentIndex][1], context: context),
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
              icon: const Icon(Icons.home), label: "MAIN_NAVBAR_MAIN".tr()),
          NavigationDestination(
              icon: const Icon(Icons.music_note),
              label: "MAIN_NAVBAR_PLAYLIST".tr()),
          NavigationDestination(
              icon: const Icon(Icons.settings),
              label: "MAIN_NAVBAR_SETTINGS".tr()),
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
