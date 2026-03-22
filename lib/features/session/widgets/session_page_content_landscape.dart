import 'package:eq_trainer/features/session/widgets/session_control.dart';
import 'package:eq_trainer/features/session/widgets/session_graph.dart';
import 'package:eq_trainer/features/session/widgets/session_picker.dart';
import 'package:eq_trainer/features/session/widgets/session_position_slider.dart';
import 'package:eq_trainer/features/session/widgets/session_selector.dart';
import 'package:eq_trainer/shared/widget/device_dropdown.dart';
import 'package:flutter/material.dart';

class SessionPageContentLandscape extends StatelessWidget {
  const SessionPageContentLandscape({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: const Row(
        children: [
          Expanded(
            child: SessionGraph(),
          ),
          SessionPicker(isPortrait: false),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  DeviceDropdown(),
                  Spacer(),
                  SessionPositionSlider(),
                  SessionControl(),
                  SizedBox(height: 32),
                  SessionSelector(isPortrait: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}