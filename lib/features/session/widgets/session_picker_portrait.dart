import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/features/session/model/session_store.dart';

class SessionPickerPortrait extends StatefulWidget {
  const SessionPickerPortrait({super.key});

  @override
  State<SessionPickerPortrait> createState() => _SessionPickerPortraitState();
}

class _SessionPickerPortraitState extends State<SessionPickerPortrait> {
  @override
  Widget build(BuildContext context) {
    final store = context.read<SessionStore>();
    final currentPickerValue = context.select<SessionStore, int>((s) => s.currentPickerValue);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: RepaintBoundary(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // decrease currentPickerValue, which represents index of selected graph
            ElevatedButton(
              onPressed: () {
                store.updatePickerValue(currentPickerValue - 1);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(40, 40),
                shape: const CircleBorder(),
              ),
              child: const Icon(
                Icons.keyboard_arrow_left,
                size: 35,
              ),
            ),
            // horizontal scrollable number picker for currentPickerValue
            NumberPicker(
              value: currentPickerValue,
              minValue: 1,
              maxValue: store.graphBarDataList.length,
              step: 1,
              axis: Axis.horizontal,
              itemWidth: (MediaQuery.of(context).size.width) * 0.18,
              itemHeight: (MediaQuery.of(context).size.height) * 0.08,
              selectedTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 40,
              ),
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
              ),
              onChanged: (value) {
                setState(() {
                  store.updatePickerValue(value);
                });
              },
            ),
            // increase currentPickerValue, which represents index of selected graph
            ElevatedButton(
              onPressed: () {
                store.updatePickerValue(currentPickerValue + 1);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(40, 40),
                shape: const CircleBorder(),
              ),
              child: const Icon(
                Icons.keyboard_arrow_right,
                size: 35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
