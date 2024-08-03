import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/page/session_page.dart';
import 'package:eq_trainer/model/session/session_frequency.dart';

class SessionPickerPortrait extends StatefulWidget {
  const SessionPickerPortrait({super.key});

  @override
  State<SessionPickerPortrait> createState() => _SessionPickerPortraitState();
}

class _SessionPickerPortraitState extends State<SessionPickerPortrait> {
  @override
  Widget build(BuildContext context) {
    final freqData = context.read<SessionFrequencyData>();
    final sessionState = context.read<SessionStateData>();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: RepaintBoundary(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // decrease currentPickerValue, which represents index of selected graph
            ElevatedButton(
              onPressed: () {
                if(sessionState.selectedPickerNum > 1) {
                  setState(() {
                    sessionState.selectedPickerNum -= 1;
                    freqData.updatePickerValue(sessionState.selectedPickerNum);
                  });
                }
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
              value: sessionState.selectedPickerNum,
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
            // increase currentPickerValue, which represents index of selected graph
            ElevatedButton(
              onPressed: () {
                if(sessionState.selectedPickerNum < freqData.graphBarDataList.length) {
                  setState(() {
                    sessionState.selectedPickerNum += 1;
                    freqData.updatePickerValue(sessionState.selectedPickerNum);
                  });
                }
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
