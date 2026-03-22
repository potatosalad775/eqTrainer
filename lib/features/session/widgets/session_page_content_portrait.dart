import 'package:eq_trainer/features/session/widgets/session_control.dart';
import 'package:eq_trainer/features/session/widgets/session_graph.dart';
import 'package:eq_trainer/features/session/widgets/session_picker.dart';
import 'package:eq_trainer/features/session/widgets/session_position_slider.dart';
import 'package:eq_trainer/features/session/widgets/session_selector.dart';
import 'package:flutter/material.dart';

class SessionPageContentPortrait extends StatelessWidget {
  const SessionPageContentPortrait({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(
          child: SessionGraph(),
        ),
        SessionPicker(isPortrait: true),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.fromLTRB(30, 10, 30, 0),
          child: SessionPositionSlider(),
        ),
        SessionControl(),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.all(15),
          child: SessionSelector(isPortrait: true),
        ),
      ],
    );
  }
}