import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/page/config_page.dart';
import 'package:eq_trainer/page/playlist_page.dart';
import 'package:eq_trainer/page/settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  List<List<String>> pageTitle = [
    ["MAIN_APPBAR_TITLE_CONFIG_1", "MAIN_APPBAR_TITLE_CONFIG_2"],
    ["MAIN_APPBAR_TITLE_PLAYLIST_1", "MAIN_APPBAR_TITLE_PLAYLIST_2"],
    ["MAIN_APPBAR_TITLE_SETTING_1", "MAIN_APPBAR_TITLE_SETTING_2"],
  ];

  @override
  Widget build(BuildContext context) {
    var navBarProvider = Provider.of<NavBarProvider>(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        scrolledUnderElevation: 4,
        shadowColor: Theme.of(context).colorScheme.shadow,
        toolbarHeight: (MediaQuery.of(context).size.height * reactiveElementData.appbarHeight).clamp(56, 150),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(pageTitle[navBarProvider.currentIndex][0], context: context),
              style: TextStyle(
                fontSize: (MediaQuery.of(context).size.height * reactiveElementData.appbarFontSize).clamp(14, 48),
              ),
            ),
            Text(
              tr(pageTitle[navBarProvider.currentIndex][1], context: context),
              style: TextStyle(
                fontSize: (MediaQuery.of(context).size.height * reactiveElementData.appbarFontSize).clamp(14, 48),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: navBarProvider.currentIndex,
        children: const [
          ConfigPage(),
          PlaylistPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navBarProvider.currentIndex,
        onDestinationSelected: (index) {
          navBarProvider.currentIndex = index;
        },
        height: (MediaQuery.of(context).size.height * reactiveElementData.navbarHeight).clamp(56, 80),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home), label: "MAIN_NAVBAR_MAIN".tr()),
          NavigationDestination(icon: const Icon(Icons.music_note), label: "MAIN_NAVBAR_PLAYLIST".tr()),
          NavigationDestination(icon: const Icon(Icons.settings), label: "MAIN_NAVBAR_SETTINGS".tr()),
        ],
        //backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        //selectedItemColor: Theme.of(context).colorScheme.surfaceTint,
      ),
    );
  }
}

class NavBarProvider extends ChangeNotifier {
  int _currentIndex = 0;
  get currentIndex => _currentIndex;
  set currentIndex(value) {
    _currentIndex = value;
    notifyListeners();
  }
}