import 'package:flutter/material.dart';
import 'package:eq_trainer/main.dart';

class MaxWidthCenterBox extends StatelessWidget {
  final Widget child;
  final double? ratio;
  const MaxWidthCenterBox({super.key, required this.child, this.ratio});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: reactiveElementData.maximumWidgetWidth * (ratio ?? 1.0),
        ),
        child: child,
      ),
    );
  }
}
