import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/zone_group.dart';
import '../state/sonos_controller.dart';
import 'widgets/album_art.dart';

/// Bottom sheet listing Sonos favorites; tapping one plays it on [group].
class FavoritesSheet extends StatelessWidget {
  const FavoritesSheet({super.key, required this.group});

  final ZoneGroup group;

  static Future<void> show(BuildContext context, ZoneGroup group) {
    final controller = context.read<SonosController>();
    // Refresh in the background so a newly-added favorite shows up.
    controller.loadFavorites();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: FavoritesSheet(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SonosController>();
    final favorites = controller.favorites;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Sonos Favorites', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Text('→ ${group.displayName}',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (favorites.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No favorites found.\nAdd some in the Sonos app to see them here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: favorites.length,
                  itemBuilder: (context, i) {
                    final fav = favorites[i];
                    return ListTile(
                      leading: AlbumArt(url: fav.albumArtUri, size: 48, radius: 8),
                      title: Text(fav.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: (fav.subtitle == null || fav.subtitle!.isEmpty)
                          ? null
                          : Text(fav.subtitle!,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.play_arrow_rounded),
                      onTap: () async {
                        // Capture the app-level messenger before we pop the
                        // sheet so we can report the real outcome after the
                        // async call, without touching a defunct context.
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.of(context).pop();
                        final started =
                            await controller.playFavorite(group, fav);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(started
                                ? 'Playing "${fav.title}" on '
                                    '${group.displayName}'
                                : "Can't play \"${fav.title}\" from here — "
                                    'this favorite has no direct stream (open '
                                    'it in the Sonos app)'),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
