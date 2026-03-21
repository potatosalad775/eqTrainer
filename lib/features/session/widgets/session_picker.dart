import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/theme_data.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';

class SessionPicker extends StatelessWidget {
  const SessionPicker({super.key, required this.isPortrait});
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final store = context.read<SessionStore>();
    final currentPickerValue = context.select<SessionStore, int>((s) => s.currentPickerValue);
    final size = MediaQuery.of(context).size;

    final selectedStyle = TextStyle(
      color: context.colors.secondary,
      fontWeight: FontWeight.bold,
      fontSize: 40,
    );
    final normalStyle = TextStyle(
      color: context.colors.onSurface,
      fontSize: 20,
    );

    final picker = isPortrait
        ? NumberPicker(
            value: currentPickerValue,
            minValue: 1,
            maxValue: store.graphBarDataList.length,
            step: 1,
            axis: Axis.horizontal,
            itemWidth: size.width * 0.18,
            itemHeight: size.height * 0.08,
            selectedTextStyle: selectedStyle,
            textStyle: normalStyle,
            onChanged: (value) => store.updatePickerValue(value),
          )
        : NumberPicker(
            value: currentPickerValue,
            minValue: 1,
            maxValue: store.graphBarDataList.length,
            step: 1,
            axis: Axis.vertical,
            itemHeight: size.height * 0.18,
            selectedTextStyle: selectedStyle,
            textStyle: normalStyle,
            onChanged: (value) => store.updatePickerValue(value),
          );

    final buttonSize = isPortrait ? const Size(40, 40) : const Size(50, 50);

    final prevButton = ElevatedButton(
      onPressed: () => store.setPickerValue(currentPickerValue - 1),
      style: ElevatedButton.styleFrom(
        minimumSize: buttonSize,
        shape: const CircleBorder(),
      ),
      child: Icon(
        isPortrait ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_up,
        size: 35,
      ),
    );

    final nextButton = ElevatedButton(
      onPressed: () => store.setPickerValue(currentPickerValue + 1),
      style: ElevatedButton.styleFrom(
        minimumSize: buttonSize,
        shape: const CircleBorder(),
      ),
      child: Icon(
        isPortrait ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
        size: 35,
      ),
    );

    if (isPortrait) {
      return Container(
        color: context.colors.surfaceContainerHighest,
        child: RepaintBoundary(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [prevButton, picker, nextButton],
          ),
        ),
      );
    } else {
      return Container(
        color: context.colors.surfaceContainerHighest,
        width: (size.width * kSessionPickerLandscapeWidth).clamp(80, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [prevButton, picker, nextButton],
        ),
      );
    }
  }
}
