import 'package:eq_trainer/main.dart';
import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/model/session_data.dart';

class SessionPickerLandscape extends StatefulWidget {
  const SessionPickerLandscape({Key? key}) : super(key: key);

  @override
  State<SessionPickerLandscape> createState() => _SessionPickerLandscapeState();
}

class _SessionPickerLandscapeState extends State<SessionPickerLandscape> {
  @override
  Widget build(BuildContext context) {
    final freqData = context.read<SessionFrequencyData>();
    final stateData = context.watch<SessionStateData>();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceVariant,
      width: (MediaQuery.of(context).size.width * reactiveElementData.sessionPickerLandscapeWidth).clamp(80, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // increase currentPickerValue, which represents index of selected graph
          ElevatedButton(
            onPressed: () {
              freqData.currentPickerValue = (freqData.currentPickerValue - 1).clamp(1, freqData.graphBarDataList.length);
              stateData.selectedGraphValue = freqData.currentPickerValue;
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(50, 50),
              shape: const CircleBorder(),
            ),
            child: const Icon(
              Icons.keyboard_arrow_up,
              size: 35,
            ),
          ),
          // horizontal scrollable number picker for currentPickerValue
          NumberPicker(
            value: freqData.currentPickerValue,
            minValue: 1,
            maxValue: freqData.graphBarDataList.length,
            step: 1,
            axis: Axis.vertical,
            itemHeight: (MediaQuery.of(context).size.height) * 0.18,
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
          // decrease currentPickerValue, which represents index of selected graph
          ElevatedButton(
            onPressed: () {
              freqData.currentPickerValue = (freqData.currentPickerValue + 1).clamp(1, freqData.graphBarDataList.length);
              stateData.selectedGraphValue = freqData.currentPickerValue;
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(50, 50),
              shape: const CircleBorder(),
            ),
            child: const Icon(
              Icons.keyboard_arrow_down,
              size: 35,
            ),
          ),
        ],
      ),
    );
  }
}
