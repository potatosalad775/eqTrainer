import 'package:flutter/material.dart';

TextStyle filterButtonStyle = const TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w500
);

class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

const double kAppbarHeight = 0.15;
const double kAppbarFontSize = 0.04;
const double kNavbarHeight = 0.1;
const double kCardDropDownMenuHeight = 0.4;
const double kControlSpacer = 0.05;
const double kSessionPickerLandscapeWidth = 0.1;
const double kMaxWidgetWidth = 600.0;