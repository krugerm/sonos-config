import 'package:flutter/material.dart';

/// A mute button + slider row used for group and per-speaker volume.
class VolumeControl extends StatelessWidget {
  const VolumeControl({
    super.key,
    required this.volume,
    required this.muted,
    required this.onChanged,
    this.onToggleMute,
    this.label,
    this.dense = false,
  });

  final int volume;
  final bool muted;
  final ValueChanged<int> onChanged;
  final VoidCallback? onToggleMute;
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final effective = muted ? 0 : volume;
    final icon = muted || volume == 0
        ? Icons.volume_off
        : volume < 50
            ? Icons.volume_down
            : Icons.volume_up;

    return Row(
      children: [
        IconButton(
          onPressed: onToggleMute,
          icon: Icon(icon),
          tooltip: muted ? 'Unmute' : 'Mute',
          visualDensity: dense ? VisualDensity.compact : null,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(label!, style: Theme.of(context).textTheme.labelMedium),
                ),
              Slider(
                value: effective.toDouble().clamp(0, 100),
                max: 100,
                onChanged: (v) => onChanged(v.round()),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$effective',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}
