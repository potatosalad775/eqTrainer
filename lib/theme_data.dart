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

/// Static layout constants. Replaces the old ratio-based `k*` constants.
class AppDimensions {
  AppDimensions._();
  static const double appBarHeight           = 100.0;
  static const double appBarFontSize         = 28.0;
  static const double navBarHeight           = 72.0;
  static const double maxWidgetWidth         = 600.0;
  static const double cardDropDownMenuHeight = 0.4;  // still relative (fraction of screen height)
  static const double controlSpacer         = 0.05;  // still relative (fraction of screen width)
  static const double sessionPickerLandscapeWidth = 0.1;
}

/// BuildContext shortcuts — avoids repeated Theme.of / MediaQuery calls.
extension AppContext on BuildContext {
  ColorScheme get colors    => Theme.of(this).colorScheme;
  TextTheme   get textTheme => Theme.of(this).textTheme;
}

// Legacy ratio constants — kept for any remaining call sites during migration.
// Prefer AppDimensions.* for new code.
const double kAppbarHeight = 0.15;
const double kAppbarFontSize = 0.04;
const double kNavbarHeight = 0.1;
const double kCardDropDownMenuHeight = 0.4;
const double kControlSpacer = 0.05;
const double kSessionPickerLandscapeWidth = 0.1;
const double kMaxWidgetWidth = 600.0;