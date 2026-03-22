import 'package:eq_trainer/features/session/widgets/session_graph_chart.dart';
import 'package:eq_trainer/features/session/widgets/session_graph_tooltip.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';
import 'package:eq_trainer/features/session/data/graph_state.dart';

class SessionGraph extends StatelessWidget {
  const SessionGraph({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<SessionStore>();
    return ValueListenableBuilder<GraphState>(
      valueListenable: store.graphStateNotifier,
      builder: (context, value, _) {
        if (value == GraphState.ready) {
          return Selector<SessionStore, int>(
            selector: (context, s) => s.currentPickerValue,
            builder: (context, pickerValue, _) {
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          const SessionGraphChart(),
                          if (savedMiscSettingsValue.frequencyToolTip) 
                            SessionGraphTooltip(
                              constraints: constraints, 
                              pickerValue: pickerValue
                            ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          );
        } else if (value == GraphState.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("SESSION_ALERT_ERROR_TITLE".tr(), style: context.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text("SESSION_ALERT_ERROR_CONTENT".tr()),
              ],
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
