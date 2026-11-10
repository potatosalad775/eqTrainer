import 'package:eq_trainer/ui/session/widgets/session_graph_chart.dart';
import 'package:eq_trainer/ui/session/widgets/session_graph_tooltip.dart';
import 'package:eq_trainer/data/misc_settings_provider.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';

class SessionGraph extends StatelessWidget {
  const SessionGraph({super.key});

  @override
  Widget build(BuildContext context) {
    // Only built once the layout is applied: the page shows a spinner until
    // the session is ready, and a failure replaces the whole page.
    //
    // The layout is selected along with the pick because a band count change
    // puts the picker back on graph 0, which may already be where it was; the
    // tooltip still has to be redrawn for the new layout's frequencies.
    return Selector<SessionStore, (BandLayout, int)>(
      selector: (context, s) => (s.layout, s.currentGraphIndex),
      builder: (context, picked, _) {
        final (_, graphIndex) = picked;
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    const SessionGraphChart(),
                    if (context.watch<MiscSettingsProvider>().frequencyToolTip)
                      SessionGraphTooltip(
                        constraints: constraints,
                        graphIndex: graphIndex,
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
