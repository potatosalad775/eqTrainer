import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:eq_trainer/shared/widget/custom_number_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    // Picker is wrapped in Expanded so it fills available space between the
    // arrow buttons. crossAxisExtent pins the opposite dimension explicitly.
    final picker = isPortrait
        ? Expanded(
            child: CustomNumberPicker(
              value: currentPickerValue,
              minValue: 1,
              maxValue: store.graphBarDataList.length,
              axis: Axis.horizontal,
              itemExtent: size.width * 0.2,
              crossAxisExtent: size.height * 0.1,
              selectedTextStyle: selectedStyle,
              textStyle: normalStyle,
              onChanged: (value) => store.updatePickerValue(value),
            ),
          )
        : Expanded(
            child: CustomNumberPicker(
              value: currentPickerValue,
              minValue: 1,
              maxValue: store.graphBarDataList.length,
              axis: Axis.vertical,
              itemExtent: size.height * 0.15,
              crossAxisExtent: size.width * 0.1,
              selectedTextStyle: selectedStyle,
              textStyle: normalStyle,
              onChanged: (value) => store.updatePickerValue(value),
            ),
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
        padding: const EdgeInsets.symmetric(vertical: AppDimens.verticalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [prevButton, picker, nextButton],
        ),
      );
    }
  }
}
