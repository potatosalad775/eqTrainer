import 'package:eq_trainer/main.dart';
import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/model/session/session_frequency.dart';

class SessionPickerLandscape extends StatefulWidget {
  const SessionPickerLandscape({super.key});

  @override
  State<SessionPickerLandscape> createState() => _SessionPickerLandscapeState();
}

class _SessionPickerLandscapeState extends State<SessionPickerLandscape> {
  @override
  Widget build(BuildContext context) {
    final freqData = context.read<SessionFrequencyData>();
    final sessionState = context.read<SessionStateData>();
    final selectedPickerValue = context.select<SessionStateData, int>((s) => s.selectedPickerNum);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      width: (MediaQuery.of(context).size.width * reactiveElementData.sessionPickerLandscapeWidth).clamp(80, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // increase currentPickerValue, which represents index of selected graph
          ElevatedButton(
            onPressed: () {
              if(selectedPickerValue > 1) {
                setState(() {
                  sessionState.selectedPickerNum -= 1;
                  freqData.updatePickerValue(selectedPickerValue);
                });
              }
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
            value: selectedPickerValue,
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
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
            ),
            onChanged: (value) {
              setState(() {
                sessionState.selectedPickerNum = value;
                freqData.updatePickerValue(value);
              });
            },
          ),
          // decrease currentPickerValue, which represents index of selected graph
          ElevatedButton(
            onPressed: () {
              if(selectedPickerValue < freqData.graphBarDataList.length) {
                setState(() {
                  sessionState.selectedPickerNum += 1;
                  freqData.updatePickerValue(selectedPickerValue);
                });
              }
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
