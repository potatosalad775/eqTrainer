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

class ReactiveElementData {
  double get appbarHeight => 0.15;
  double get appbarFontSize => 0.04;
  double get navbarHeight => 0.1;
  double get cardDropDownMenuHeight => 0.4;
  double get controlSpacer => 0.05;
  double get sessionPickerLandscapeWidth => 0.1;
}