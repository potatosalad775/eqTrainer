import 'package:flutter/material.dart';

/// A reusable player control row: Previous | Play/Pause | [third action].
///
/// Each action callback is provided by the caller. The third button supports
/// any icon (e.g. [Icons.skip_next] or [Icons.close]).
class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.isPlaying,
    required this.onPrevious,
    required this.onPlayPause,
    required this.thirdIcon,
    required this.onThird,
  });

  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final IconData thirdIcon;
  final VoidCallback onThird;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: onPrevious,
          iconSize: 56,
          icon: const Icon(Icons.skip_previous),
          enableFeedback: false,
        ),
        IconButton(
          onPressed: onPlayPause,
          iconSize: 64,
          icon: Icon(isPlaying
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_fill_rounded),
          enableFeedback: false,
        ),
        IconButton(
          onPressed: onThird,
          iconSize: 56,
          icon: Icon(thirdIcon),
          enableFeedback: false,
        ),
      ],
    );
  }
}
