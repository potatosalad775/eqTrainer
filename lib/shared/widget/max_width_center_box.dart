import 'package:eq_trainer/shared/themes/app_dimens.dart';
import 'package:flutter/material.dart';

class MaxWidthCenterBox extends StatelessWidget {
  const MaxWidthCenterBox({
    super.key, 
    required this.child,
    this.ratio
  });

  final Widget child;
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppDimens.maxWidgetWidth * (ratio ?? 1.0),
        ),
        child: child,
      ),
    );
  }
}
