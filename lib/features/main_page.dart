import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/theme_data.dart';
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
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final viewPaddingBottom = mq.viewPadding.bottom;
    final sidePaddingValue = sw <= kMaxWidgetWidth ? 0.0 : (sw - kMaxWidgetWidth) / 2;
    final bottomPaddingValue = viewPaddingBottom == 0 ? 11.0 : 0.0;
    final toolbarHeight = (sh * kAppbarHeight).clamp(90.0, 120.0);
    final appBarFontSize = (sh * kAppbarFontSize).clamp(24.0, 32.0);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        scrolledUnderElevation: 4,
        shadowColor: colors.shadow,
        toolbarHeight: toolbarHeight,
        titleSpacing: 13 + sidePaddingValue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(_pageTitle[navBarProvider.currentIndex][0], context: context),
              style: TextStyle(fontSize: appBarFontSize),
            ),
            Text(
              tr(_pageTitle[navBarProvider.currentIndex][1], context: context),
              style: TextStyle(fontSize: appBarFontSize, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxWidgetWidth),
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
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: bottomPaddingValue,
          left: 11 + sidePaddingValue,
          right: 11 + sidePaddingValue,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
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
            backgroundColor: colors.surfaceContainerHigh,
          ),
        ),
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
