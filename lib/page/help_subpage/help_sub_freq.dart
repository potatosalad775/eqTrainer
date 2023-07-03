import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HelpSubPageFreq extends StatelessWidget {
  const HelpSubPageFreq({super.key});

  @override
  Widget build(BuildContext context) {
    final PageController pageController = PageController(
      initialPage: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("HELP_SUB_FREQ_TITLE").tr(),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: pageController,
                scrollDirection: Axis.horizontal,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Image(image: AssetImage('assets/image/freq_low.png')),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: const Text(
                          "HELP_SUB_FREQ_P1_PHOTO_DESC_1",
                          textAlign: TextAlign.center,
                        ).tr(),
                      ),
                      const Image(image: AssetImage('assets/image/freq_high.png')),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: const Text(
                          "HELP_SUB_FREQ_P1_PHOTO_DESC_2",
                          textAlign: TextAlign.center,
                        ).tr(),
                      ),
                      const Text("HELP_SUB_FREQ_P1_PARAGRAPH_1").tr(),
                      const SizedBox(height: 16),
                      const Text("HELP_SUB_FREQ_P1_PARAGRAPH_2").tr(),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Image(image: AssetImage('assets/image/fr_chart.png')),
                      const SizedBox(height: 16),
                      const Text("HELP_SUB_FREQ_P2_PARAGRAPH_1").tr(),
                      const SizedBox(height: 16),
                      const Text("HELP_SUB_FREQ_P2_PARAGRAPH_2").tr(),
                      const SizedBox(height: 16),
                      const Text("HELP_SUB_FREQ_P2_FREQ_INFO").tr(),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SmoothPageIndicator(
                controller: pageController,
                count: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
