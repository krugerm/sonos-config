import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playback_state.dart';
import '../models/zone_group.dart';
import '../state/sonos_controller.dart';
import 'widgets/album_art.dart';

/// The list of zone groups (rooms). Selecting one drives the Now Playing view.
class SpeakerListPanel extends StatelessWidget {
  const SpeakerListPanel({super.key, required this.onSelect});

  /// Called after a group is selected — lets a narrow layout navigate to the
  /// Now Playing page; on wide layouts it can be a no-op.
  final ValueChanged<ZoneGroup> onSelect;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SonosController>();
    final selected = controller.selectedGroup;

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: controller.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final group = controller.groups[index];
        final state = controller.playbackFor(group);
        return _GroupTile(
          group: group,
          state: state,
          selected: group.id == selected?.id,
          onTap: () {
            controller.selectGroup(group);
            onSelect(group);
          },
          onPlayPause: () => controller.togglePlayPause(group),
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.state,
    required this.selected,
    required this.onTap,
    required this.onPlayPause,
  });

  final ZoneGroup group;
  final PlaybackState state;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playing = state.transport.isPlaying;

    final subtitle = state.hasTrack
        ? '${state.title}${state.artist != null && state.artist!.isNotEmpty ? ' — ${state.artist}' : ''}'
        : group.isSingle
            ? 'Idle'
            : group.roomsSummary;

    return Card(
      margin: EdgeInsets.zero,
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AlbumArt(url: state.albumArtUri, size: 56, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (playing) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.graphic_eq,
                              size: 16, color: scheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onPlayPause,
                icon: Icon(playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill),
                iconSize: 34,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
