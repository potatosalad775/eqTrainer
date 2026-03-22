import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A scroll-snap number picker supporting both horizontal and vertical axes.
///
/// Sizing: the picker fills its parent in the scroll direction (use [Expanded]
/// or a fixed-size parent to constrain it). The cross-axis dimension is
/// [crossAxisExtent] (defaults to [itemExtent]).
class CustomNumberPicker extends StatefulWidget {
  const CustomNumberPicker({
    super.key,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
    this.axis = Axis.vertical,
    this.itemExtent = 50.0,
    this.crossAxisExtent,
    this.selectedTextStyle,
    this.textStyle,
    // Number of items to move per 60 logical pixels of scroll-wheel delta.
    // 1.0 means a typical mouse-wheel click (~60 px) moves exactly one item.
    this.mouseWheelSensitivity = 1.0,
  });

  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;
  final Axis axis;
  /// Extent of each item along the scroll axis (px).
  final double itemExtent;
  /// Extent perpendicular to the scroll axis. Defaults to [itemExtent].
  final double? crossAxisExtent;
  final TextStyle? selectedTextStyle;
  final TextStyle? textStyle;
  final double mouseWheelSensitivity;

  @override
  State<CustomNumberPicker> createState() => _CustomNumberPickerState();
}

class _CustomNumberPickerState extends State<CustomNumberPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late double _currentOffset; // fractional index: 0.0 = minValue
  double _dragStartOffset = 0;
  double _dragAccum = 0;
  DateTime? _lastDiscreteWheelTime; // used for velocity-step calculation

  Animation<double>? _activeAnimation;
  VoidCallback? _activeListener;
  int _animationId = 0;

  double get _maxOffset => (widget.maxValue - widget.minValue).toDouble();

  @override
  void initState() {
    super.initState();
    _currentOffset = (widget.value - widget.minValue).toDouble();
    _animationController = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(CustomNumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final targetIndex = (widget.value - widget.minValue)
          .clamp(0, widget.maxValue - widget.minValue);
      _animateToIndex(targetIndex, callOnChanged: false);
    }
    if (oldWidget.maxValue != widget.maxValue) {
      final maxIdx = widget.maxValue - widget.minValue;
      final clamped = _currentOffset.round().clamp(0, maxIdx);
      if (clamped != _currentOffset.round()) {
        _animateToIndex(clamped);
      }
    }
  }

  @override
  void dispose() {
    _detachActiveAnimation();
    _animationController.dispose();
    super.dispose();
  }

  void _detachActiveAnimation() {
    if (_activeAnimation != null && _activeListener != null) {
      _activeAnimation!.removeListener(_activeListener!);
    }
    _activeAnimation = null;
    _activeListener = null;
  }

  void _animateToIndex(int index, {bool callOnChanged = true}) {
    _animationController.stop();
    _detachActiveAnimation();

    final target = index.toDouble();
    final distance = (target - _currentOffset).abs();
    if (distance < 0.001) {
      _currentOffset = target;
      return;
    }

    final id = ++_animationId;
    final startOffset = _currentOffset;
    final durationMs = (distance * 120).clamp(80, 350).toInt();
    _animationController.duration = Duration(milliseconds: durationMs);
    _animationController.reset();

    final animation = Tween<double>(begin: startOffset, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    void listener() => setState(() => _currentOffset = animation.value);
    _activeAnimation = animation;
    _activeListener = listener;
    animation.addListener(listener);

    _animationController.forward().then((_) {
      if (id != _animationId) return;
      _detachActiveAnimation();
      _currentOffset = target;
      if (callOnChanged) {
        final newValue = widget.minValue + index;
        if (newValue != widget.value) {
          widget.onChanged(newValue);
        }
      }
    });
  }

  void _onDragStart(double position) {
    _animationController.stop();
    _detachActiveAnimation();
    _dragStartOffset = _currentOffset;
    _dragAccum = 0;
  }

  void _onDragUpdate(double delta) {
    // Dragging in positive direction (down/right) → decreasing index
    _dragAccum += delta;
    setState(() {
      _currentOffset =
          (_dragStartOffset - _dragAccum / widget.itemExtent).clamp(0.0, _maxOffset);
    });
  }

  void _onDragEnd(double velocityPixelsPerSecond) {
    const double momentumFactor = 0.12;
    final projected =
        _currentOffset - velocityPixelsPerSecond * momentumFactor / widget.itemExtent;
    final targetIndex =
        projected.round().clamp(0, widget.maxValue - widget.minValue);
    _animateToIndex(targetIndex);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;

    // For horizontal: prefer dx (macOS trackpad horizontal swipe), else dy.
    // For vertical: always use dy.
    final rawDelta =
        widget.axis == Axis.horizontal && dx.abs() > dy.abs() ? dx : dy;

    if (rawDelta.abs() < 1.0) return; // ignore zero/dust events

    // Snap immediately on every event regardless of delta size — this prevents
    // small-delta events (e.g. from mice that send <30px per click) from
    // accumulating fractionally and snapping back to the original value.
    // Step size is throttled by inter-event timing so fast-firing devices
    // (trackpads at ~60fps) stay at step 1 while a deliberate wheel spin
    // can jump 2–3 items.
    final direction = rawDelta > 0 ? 1 : -1;
    final now = DateTime.now();
    final step = _computeWheelStep(now);
    _lastDiscreteWheelTime = now;

    _animationController.stop();
    _detachActiveAnimation();

    final targetIndex = (_currentOffset.round() + direction * step)
        .clamp(0, widget.maxValue - widget.minValue);
    _animateToIndex(targetIndex);
  }

  /// Returns 1–3 based on how quickly scroll events are arriving.
  ///
  /// < 50 ms  → step 1 (very fast, likely trackpad — keep controlled)
  /// 50–100 ms → step 3 (fast wheel spin)
  /// 100–200 ms → step 2 (moderate wheel)
  /// > 200 ms or first event → step 1 (slow / deliberate single click)
  int _computeWheelStep(DateTime now) {
    if (_lastDiscreteWheelTime == null) return 1;
    final elapsedMs =
        now.difference(_lastDiscreteWheelTime!).inMilliseconds;
    if (elapsedMs < 50) return 1;
    if (elapsedMs < 100) return 3;
    if (elapsedMs < 200) return 2;
    return 1;
  }

  double _scaleForDistance(double distanceInItemUnits) {
    return (1.0 - distanceInItemUnits.abs() * 0.3).clamp(0.5, 1.0);
  }

  List<Widget> _buildItems(double totalScrollExtent) {
    final items = <Widget>[];
    final center = totalScrollExtent / 2;
    final halfVisible = (totalScrollExtent / (2 * widget.itemExtent)).ceil() + 1;
    final centerItemIndex = _currentOffset.round();

    for (int i = -halfVisible; i <= halfVisible; i++) {
      final valueIndex = centerItemIndex + i;
      if (valueIndex < 0 || valueIndex > widget.maxValue - widget.minValue) {
        continue;
      }

      final distanceFromCenter = valueIndex - _currentOffset;
      final isSelected = distanceFromCenter.abs() < 0.5;
      final scale = isSelected ? 1.0 : _scaleForDistance(distanceFromCenter);
      final positionAlongAxis = distanceFromCenter * widget.itemExtent;
      final pos = center + positionAlongAxis - widget.itemExtent / 2;

      Widget textWidget = Text(
        '${widget.minValue + valueIndex}',
        style: isSelected ? widget.selectedTextStyle : widget.textStyle,
      );

      if (!isSelected) {
        textWidget = Transform.scale(scale: scale, child: textWidget);
      }

      Widget itemBox = SizedBox(
        width: widget.axis == Axis.horizontal ? widget.itemExtent : null,
        height: widget.axis == Axis.vertical ? widget.itemExtent : null,
        child: Center(child: textWidget),
      );

      Widget positioned;
      if (widget.axis == Axis.vertical) {
        positioned = Positioned(
          left: 0,
          right: 0,
          top: pos,
          child: itemBox,
        );
      } else {
        positioned = Positioned(
          top: 0,
          bottom: 0,
          left: pos,
          child: itemBox,
        );
      }

      items.add(positioned);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final crossExtent = widget.crossAxisExtent ?? widget.itemExtent;

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        // opaque so the entire widget area responds to gestures,
        // not just pixels occupied by text.
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: widget.axis == Axis.vertical
            ? (d) => _onDragStart(d.localPosition.dy)
            : null,
        onVerticalDragUpdate: widget.axis == Axis.vertical
            ? (d) => _onDragUpdate(d.primaryDelta ?? 0)
            : null,
        onVerticalDragEnd: widget.axis == Axis.vertical
            ? (d) => _onDragEnd(d.primaryVelocity ?? 0)
            : null,
        onHorizontalDragStart: widget.axis == Axis.horizontal
            ? (d) => _onDragStart(d.localPosition.dx)
            : null,
        onHorizontalDragUpdate: widget.axis == Axis.horizontal
            ? (d) => _onDragUpdate(d.primaryDelta ?? 0)
            : null,
        onHorizontalDragEnd: widget.axis == Axis.horizontal
            ? (d) => _onDragEnd(d.primaryVelocity ?? 0)
            : null,
        // LayoutBuilder lets the picker fill its parent in the scroll direction
        // instead of hard-coding a fixed multiple of itemExtent.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scrollExtent = widget.axis == Axis.vertical
                ? (constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : crossExtent * 3)
                : (constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : crossExtent * 3);

            return ClipRect(
              child: SizedBox(
                width: widget.axis == Axis.horizontal
                    ? scrollExtent
                    : crossExtent,
                height: widget.axis == Axis.vertical
                    ? scrollExtent
                    : crossExtent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: _buildItems(scrollExtent),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
