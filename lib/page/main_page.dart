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
    // Add bottom padding if device doesn't already have it.
    double bottomPaddingValue = MediaQuery.of(context).viewPadding.bottom == 0 ? 11 : 0;
    double sidePaddingValue = MediaQuery.of(context).size.width <= reactiveElementData.maximumWidgetWidth
        ? 0 : (MediaQuery.of(context).size.width - reactiveElementData.maximumWidgetWidth) / 2;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        scrolledUnderElevation: 4,
        shadowColor: Theme.of(context).colorScheme.shadow,
        toolbarHeight: (MediaQuery.of(context).size.height *
                reactiveElementData.appbarHeight)
            .clamp(90, 120),
        titleSpacing: 13 +
            (MediaQuery.of(context).size.width <= reactiveElementData.maximumWidgetWidth
            ? 0
            : (MediaQuery.of(context).size.width -
                reactiveElementData.maximumWidgetWidth) / 2
            ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(pageTitle[navBarProvider.currentIndex][0], context: context),
              style: TextStyle(
                fontSize: (MediaQuery.of(context).size.height *
                        reactiveElementData.appbarFontSize)
                    .clamp(24, 32),
              ),
            ),
            Text(
              tr(pageTitle[navBarProvider.currentIndex][1], context: context),
              style: TextStyle(
                fontSize: (MediaQuery.of(context).size.height *
                        reactiveElementData.appbarFontSize)
                    .clamp(24, 32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: reactiveElementData.maximumWidgetWidth,
          ),
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: navBarProvider.currentIndex,
                  children: const [
                    ConfigPage(),
                    PlaylistPage(),
                    SettingsPage(),
                  ],
                ),
              ),
              // SizedBox to hide scrolled contents under BottomNavigationBar
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 40)
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: bottomPaddingValue,
          left: 11 + sidePaddingValue,
          right: 11 + sidePaddingValue,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          child: NavigationBar(
            selectedIndex: navBarProvider.currentIndex,
            onDestinationSelected: (index) {
              navBarProvider.currentIndex = index;
            },
            height: 72,
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
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            //selectedItemColor: Theme.of(context).colorScheme.surfaceTint,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      extendBody: false,
      resizeToAvoidBottomInset: false,
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
