import 'package:flutter/material.dart';

/// Album art with a graceful music-note placeholder for missing/broken URLs.
class AlbumArt extends StatelessWidget {
  const AlbumArt({super.key, this.url, this.size = 72, this.radius = 12});

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: size,
      height: size,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note,
        size: size * 0.45,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    final hasUrl = url != null && url!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: hasUrl
          ? Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
            )
          : placeholder,
    );
  }
}
