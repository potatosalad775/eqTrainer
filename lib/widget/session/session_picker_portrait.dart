import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/model/session_data.dart';

class SessionPickerPortrait extends StatefulWidget {
  const SessionPickerPortrait({super.key});

  @override
  State<SessionPickerPortrait> createState() => _SessionPickerPortraitState();
}

class _SessionPickerPortraitState extends State<SessionPickerPortrait> {
  @override
  Widget build(BuildContext context) {
    final freqData = context.read<SessionFrequencyData>();
    final stateData = context.watch<SessionStateData>();

    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // decrease currentPickerValue, which represents index of selected graph
          ElevatedButton(
            onPressed: () {
              freqData.currentPickerValue = (freqData.currentPickerValue - 1).clamp(1, freqData.graphBarDataList.length);
              stateData.selectedGraphValue = freqData.currentPickerValue;
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
            value: freqData.currentPickerValue,
            minValue: 1,
            maxValue: freqData.graphBarDataList.length,
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
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 20,
            ),
            onChanged: (value) {
              freqData.currentPickerValue = value;
              freqData.swapGraphColor(freqData.previousPickerValue - 1, freqData.currentPickerValue - 1);
              freqData.previousPickerValue = value;
              stateData.selectedGraphValue = freqData.currentPickerValue;
            },
          ),
          // increase currentPickerValue, which represents index of selected graph
          ElevatedButton(
            onPressed: () {
              freqData.currentPickerValue = (freqData.currentPickerValue + 1).clamp(1, freqData.graphBarDataList.length);
              stateData.selectedGraphValue = freqData.currentPickerValue;
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
    );
  }
}
