import 'package:flutter/material.dart';

import '../../models/playback_state.dart';

/// Previous / play-pause / next control cluster.
class TransportControls extends StatelessWidget {
  const TransportControls({
    super.key,
    required this.transport,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
  });

  final TransportState transport;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = transport.isPlaying;
    final isBusy = transport == TransportState.transitioning;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 40,
          onPressed: onPrevious,
          icon: const Icon(Icons.skip_previous_rounded),
          tooltip: 'Previous',
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 48,
            color: scheme.onPrimary,
            onPressed: onPlayPause,
            icon: isBusy
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: scheme.onPrimary,
                    ),
                  )
                : Icon(isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
            tooltip: isPlaying ? 'Pause' : 'Play',
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          iconSize: 40,
          onPressed: onNext,
          icon: const Icon(Icons.skip_next_rounded),
          tooltip: 'Next',
        ),
      ],
    );
  }
}
