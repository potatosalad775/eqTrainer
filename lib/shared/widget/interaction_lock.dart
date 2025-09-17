import 'package:flutter/material.dart';

class InteractionLock extends StatelessWidget {
  final bool locked;
  final Widget child;
  final Color scrimColor;
  final double scrimOpacity;
  final Widget? progress;
  final bool useOverlay;

  const InteractionLock({
    super.key,
    required this.locked,
    required this.child,
    this.scrimColor = Colors.black,
    this.scrimOpacity = 0.02,
    this.progress,
    this.useOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: locked,
          child: child,
        ),
        if (locked) ...[
          if (useOverlay) ...[
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: ColoredBox(
                  color: scrimColor.withValues(alpha: scrimOpacity),
                ),
              ),
            ),
          ],
          const Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ]
      ],
    );
  }
}