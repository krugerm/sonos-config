import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../actions/config_action.dart';
import '../actions/group_actions.dart';
import '../actions/rename_action.dart';
import '../actions/topology_actions.dart';
import '../models/bond_role.dart';
import '../models/household.dart';
import '../models/room.dart';
import '../state/group_audio_store.dart';
import '../state/household_store.dart';
import 'action_runner.dart';
import 'device_detail_page.dart';
import 'theme.dart';
import 'ui_util.dart';
import 'widgets.dart';

/// Configuration for a single room: rename, grouping, bonding, and its devices.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({super.key, required this.coordinatorUuid});

  final String coordinatorUuid;

  @override
  Widget build(BuildContext context) {
    return Consumer<HouseholdStore>(
      builder: (context, store, _) {
        final household = store.household;
        final room = household?.visibleRooms
            .firstWhereOrNull((r) => r.coordinator.uuid == coordinatorUuid);
        if (household == null || room == null) {
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
              _GroupAudioSection(host: room.coordinator.host),
              ..._groupingSection(context, household, room),
              ..._homeTheaterSection(context, household, room),
              ..._stereoPairSection(context, household, room),
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

  // ---- Grouping (party mode) ----------------------------------------------

  List<Widget> _groupingSection(
      BuildContext context, Household household, Room room) {
    final group =
        household.groups.firstWhereOrNull((g) => g.rooms.any((r) => r == room));
    final partners = group == null
        ? const <Room>[]
        : group.rooms.where((r) => r != room).toList();
    final others = household.visibleRooms
        .where((r) => r != room && !partners.contains(r))
        .toList();

    return [
      const Eyebrow('Grouping'),
      if (partners.isEmpty)
        const ListTile(
          leading: Icon(Icons.link_off),
          title: Text('Not grouped'),
          subtitle: Text('Playing on its own'),
        )
      else ...[
        for (final p in partners)
          ListTile(
            leading: const Icon(Icons.link),
            title: Text('Grouped with ${p.name}'),
          ),
        ListTile(
          leading: const Icon(Icons.group_remove),
          title: const Text('Ungroup this room'),
          trailing: OutlinedButton(
            onPressed: () => runConfigAction(
              context,
              LeaveGroupAction(
                memberHost: room.coordinator.host,
                memberUuid: room.coordinator.uuid,
                memberRoomName: room.name,
              ),
            ),
            child: const Text('Ungroup'),
          ),
        ),
      ],
      if (others.isNotEmpty)
        ListTile(
          leading: const Icon(Icons.group_add),
          title: const Text('Group with…'),
          onTap: () => _pickAndRun<Room>(
            context,
            title: 'Group with',
            options: others,
            labelOf: (r) => r.name,
            actionOf: (target) => JoinGroupAction(
              memberHost: room.coordinator.host,
              memberUuid: room.coordinator.uuid,
              memberRoomName: room.name,
              coordinatorUuid: target.coordinator.uuid,
              targetRoomName: target.name,
            ),
          ),
        ),
    ];
  }

  // ---- Home theater: Sub + surrounds --------------------------------------

  List<Widget> _homeTheaterSection(
      BuildContext context, Household household, Room room) {
    if (!room.coordinator.capabilities.canBondSub) return const [];
    final coord = room.coordinator;
    final widgets = <Widget>[const Eyebrow('Home theater')];

    // Sub
    final bondedSub =
        room.satellites.firstWhereOrNull((d) => d.bondRole == BondRole.sub);
    if (bondedSub != null) {
      widgets.add(ListTile(
        leading: const Icon(Icons.speaker),
        title: const Text('Sub'),
        subtitle: const Text('Bonded as subwoofer'),
        trailing: OutlinedButton(
          onPressed: () => runConfigAction(
              context,
              UnbondSubAction(
                  primaryHost: coord.host,
                  primaryUuid: coord.uuid,
                  subUuid: bondedSub.uuid,
                  roomName: room.name)),
          child: const Text('Unbond'),
        ),
      ));
    } else {
      final availableSub = household.unbondedInvisibleDevices.firstWhereOrNull(
          (d) => (d.model ?? '').toLowerCase().contains('sub'));
      if (availableSub != null) {
        widgets.add(ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: Text('Bond ${availableSub.model ?? 'Sub'}'),
          subtitle: const Text('An unbonded Sub is available'),
          trailing: FilledButton(
            onPressed: () => runConfigAction(
                context,
                BondSubAction(
                    primaryHost: coord.host,
                    primaryUuid: coord.uuid,
                    subUuid: availableSub.uuid,
                    roomName: room.name)),
            child: const Text('Bond'),
          ),
        ));
      }
    }

    // Surrounds
    final surrounds = room.satellites
        .where((d) =>
            d.bondRole == BondRole.surroundLeft ||
            d.bondRole == BondRole.surroundRight)
        .toList();
    for (final s in surrounds) {
      final channel = s.bondRole == BondRole.surroundLeft ? 'LR' : 'RR';
      widgets.add(ListTile(
        leading: const Icon(Icons.surround_sound),
        title: Text(s.model ?? 'Surround'),
        subtitle: Text(roleLongLabel(s.bondRole)),
        trailing: OutlinedButton(
          onPressed: () => runConfigAction(
              context,
              RemoveSurroundAction(
                  primaryHost: coord.host,
                  primaryUuid: coord.uuid,
                  satUuid: s.uuid,
                  channel: channel,
                  roomName: room.name,
                  satName: s.model ?? 'Surround')),
          child: const Text('Remove'),
        ),
      ));
    }
    if (surrounds.length < 2) {
      final hasLeft = surrounds.any((d) => d.bondRole == BondRole.surroundLeft);
      final channel = hasLeft ? 'RR' : 'LR';
      final candidates = _standaloneSpeakers(household, room);
      if (candidates.isNotEmpty) {
        widgets.add(ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: Text('Add ${hasLeft ? 'right' : 'left'} surround…'),
          onTap: () => _pickAndRun<Room>(
            context,
            title: 'Add surround',
            options: candidates,
            labelOf: (r) => r.name,
            actionOf: (r) => AddSurroundAction(
              primaryHost: coord.host,
              primaryUuid: coord.uuid,
              satUuid: r.coordinator.uuid,
              channel: channel,
              roomName: room.name,
              satName: r.coordinator.model ?? r.name,
            ),
          ),
        ));
      }
    }
    return widgets;
  }

  // ---- Stereo pairing -----------------------------------------------------

  List<Widget> _stereoPairSection(
      BuildContext context, Household household, Room room) {
    final coord = room.coordinator;
    final pairedRight = room.satellites.firstWhereOrNull((d) =>
        d.bondRole == BondRole.stereoLeft ||
        d.bondRole == BondRole.stereoRight);
    if (pairedRight != null) {
      return [
        const Eyebrow('Stereo pair'),
        ListTile(
          leading: const Icon(Icons.hearing),
          title: Text('Paired with ${pairedRight.model ?? 'speaker'}'),
          trailing: OutlinedButton(
            onPressed: () => runConfigAction(
                context,
                SeparateStereoPairAction(
                    leftHost: coord.host,
                    leftUuid: coord.uuid,
                    rightUuid: pairedRight.uuid,
                    leftName: coord.model ?? room.name,
                    rightName: pairedRight.model ?? 'speaker')),
            child: const Text('Split'),
          ),
        ),
      ];
    }
    if (!coord.capabilities.canStereoPair || room.satellites.isNotEmpty) {
      return const [];
    }
    final candidates = _standaloneSpeakers(household, room);
    if (candidates.isEmpty) return const [];
    return [
      const Eyebrow('Stereo pair'),
      ListTile(
        leading: const Icon(Icons.hearing),
        title: const Text('Pair with…'),
        subtitle: const Text('Combine two speakers into a left/right pair'),
        onTap: () => _pickAndRun<Room>(
          context,
          title: 'Stereo-pair with',
          options: candidates,
          labelOf: (r) => r.name,
          actionOf: (r) => CreateStereoPairAction(
            leftHost: coord.host,
            leftUuid: coord.uuid,
            rightUuid: r.coordinator.uuid,
            leftName: coord.model ?? room.name,
            rightName: r.coordinator.model ?? r.name,
          ),
        ),
      ),
    ];
  }

  /// Visible single-speaker rooms that can be paired/bonded (excludes [room]).
  List<Room> _standaloneSpeakers(Household household, Room room) =>
      household.visibleRooms
          .where((r) =>
              r != room &&
              r.satellites.isEmpty &&
              r.coordinator.capabilities.canStereoPair)
          .toList();

  // ---- Helpers ------------------------------------------------------------

  Future<void> _pickAndRun<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    required ConfigAction Function(T) actionOf,
  }) async {
    final chosen = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final o in options)
              ListTile(
                title: Text(labelOf(o)),
                onTap: () => Navigator.of(context).pop(o),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    await runConfigAction(context, actionOf(chosen));
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

/// Group (party-mode) volume + mute for the room, loaded on demand.
class _GroupAudioSection extends StatefulWidget {
  const _GroupAudioSection({required this.host});

  final String host;

  @override
  State<_GroupAudioSection> createState() => _GroupAudioSectionState();
}

class _GroupAudioSectionState extends State<_GroupAudioSection> {
  double? _drag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GroupAudioStore>().load(widget.host);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GroupAudioStore>();
    final value = (_drag ?? store.volume.toDouble()).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Group audio'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              const SizedBox(width: 96, child: Text('Volume')),
              Expanded(
                child: Slider(
                  value: value,
                  max: 100,
                  label: 'Group volume: ${value.round()}',
                  onChanged: (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    store.setVolume(v.round());
                    setState(() => _drag = null);
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('${value.round()}',
                    textAlign: TextAlign.end,
                    style: monoStyle(context, size: 12)),
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Mute'),
          value: store.muted,
          onChanged: store.setMuted,
        ),
      ],
    );
  }
}
