import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../actions/rename_action.dart';
import '../actions/topology_actions.dart';
import '../models/bond_role.dart';
import '../models/room.dart';
import '../state/household_store.dart';
import 'action_runner.dart';
import 'device_detail_page.dart';
import 'theme.dart';
import 'ui_util.dart';
import 'widgets.dart';

/// Configuration for a single room: rename, Sub bonding, and its devices.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({super.key, required this.coordinatorUuid});

  final String coordinatorUuid;

  @override
  Widget build(BuildContext context) {
    return Consumer<HouseholdStore>(
      builder: (context, store, _) {
        final room = store.household?.visibleRooms
            .firstWhereOrNull((r) => r.coordinator.uuid == coordinatorUuid);
        if (room == null) {
          return const Scaffold(
            body: Center(child: Text('This room is no longer available.')),
          );
        }
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: Text(room.name)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const Eyebrow('Configuration'),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename room'),
                subtitle: Text(room.name),
                onTap: () => _rename(context, room),
              ),
              ..._subSection(context, store, room),
              const Eyebrow('Devices'),
              for (final d in room.devices)
                ListTile(
                  leading: Icon(_roleIcon(d.bondRole),
                      color: scheme.onSurface.withValues(alpha: 0.7)),
                  title: Text(d.model ?? d.roomName),
                  subtitle: Text(d.host,
                      style: monoStyle(context,
                          size: 11.5,
                          color: scheme.onSurface.withValues(alpha: 0.55))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoleChip(d.bondRole),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right,
                          color: scheme.onSurface.withValues(alpha: 0.35)),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DeviceDetailPage(device: d),
                  )),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _subSection(
      BuildContext context, HouseholdStore store, Room room) {
    if (!room.coordinator.capabilities.canBondSub) return const [];

    final bondedSub =
        room.satellites.firstWhereOrNull((d) => d.bondRole == BondRole.sub);
    if (bondedSub != null) {
      return [
        ListTile(
          leading: const Icon(Icons.speaker),
          title: const Text('Sub'),
          subtitle: const Text('Bonded as subwoofer'),
          trailing: OutlinedButton(
            onPressed: () => runConfigAction(
              context,
              UnbondSubAction(
                primaryHost: room.coordinator.host,
                primaryUuid: room.coordinator.uuid,
                subUuid: bondedSub.uuid,
                roomName: room.name,
              ),
            ),
            child: const Text('Unbond'),
          ),
        ),
      ];
    }

    final availableSub = store.household?.unbondedInvisibleDevices
        .firstWhereOrNull((d) => (d.model ?? '').toLowerCase().contains('sub'));
    if (availableSub != null) {
      return [
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: Text('Bond ${availableSub.model ?? 'Sub'}'),
          subtitle: const Text('An unbonded Sub is available'),
          trailing: FilledButton(
            onPressed: () => runConfigAction(
              context,
              BondSubAction(
                primaryHost: room.coordinator.host,
                primaryUuid: room.coordinator.uuid,
                subUuid: availableSub.uuid,
                roomName: room.name,
              ),
            ),
            child: const Text('Bond'),
          ),
        ),
      ];
    }
    return const [];
  }

  Future<void> _rename(BuildContext context, Room room) async {
    final controller = TextEditingController(text: room.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Room name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == room.name) return;
    if (!context.mounted) return;
    await runConfigAction(
      context,
      RenameRoomAction(
        host: room.coordinator.host,
        uuid: room.coordinator.uuid,
        currentName: room.name,
        newName: newName,
      ),
    );
  }

  IconData _roleIcon(BondRole role) => switch (role) {
        BondRole.sub => Icons.speaker,
        BondRole.surroundLeft || BondRole.surroundRight => Icons.surround_sound,
        _ => Icons.speaker,
      };
}
