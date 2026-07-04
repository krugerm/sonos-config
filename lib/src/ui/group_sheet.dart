import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sonos_speaker.dart';
import '../models/zone_group.dart';
import '../state/sonos_controller.dart';

/// Bottom sheet to add/remove rooms from [group] for synchronised playback.
class GroupSheet extends StatelessWidget {
  const GroupSheet({super.key, required this.groupId});

  final String groupId;

  static Future<void> show(BuildContext context, ZoneGroup group) {
    final controller = context.read<SonosController>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: GroupSheet(groupId: group.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SonosController>();
    final theme = Theme.of(context);

    final group =
        controller.groups.where((g) => g.id == groupId).firstOrNull;
    if (group == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('This group is no longer available.')),
      );
    }

    // Every visible room across the household, de-duplicated by uuid.
    final rooms = <String, SonosSpeaker>{};
    for (final g in controller.groups) {
      for (final m in g.members) {
        rooms.putIfAbsent(m.uuid, () => m);
      }
    }
    final memberUuids = group.members.map((m) => m.uuid).toSet();
    final sorted = rooms.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('Group with ${group.coordinator.name}',
                style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Rooms you switch on will play in sync.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final room in sorted)
                  _RoomToggle(
                    room: room,
                    inGroup: memberUuids.contains(room.uuid),
                    isCoordinator: room.uuid == group.coordinator.uuid,
                    onChanged: (add) {
                      if (add) {
                        controller.joinGroup(room, group);
                      } else {
                        controller.leaveGroup(room);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RoomToggle extends StatelessWidget {
  const _RoomToggle({
    required this.room,
    required this.inGroup,
    required this.isCoordinator,
    required this.onChanged,
  });

  final SonosSpeaker room;
  final bool inGroup;
  final bool isCoordinator;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(room.name),
      subtitle: isCoordinator ? const Text('Group coordinator') : null,
      secondary: const Icon(Icons.speaker),
      value: inGroup,
      // The coordinator anchors the group; toggle the others around it.
      onChanged: isCoordinator ? null : (v) => onChanged(v),
    );
  }
}
