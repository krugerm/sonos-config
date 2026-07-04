import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../models/room.dart';
import '../state/household_store.dart';
import 'device_detail_page.dart';
import 'room_detail_page.dart';

/// Home screen: the read-only system map plus entry points into configuration.
class SystemMapPage extends StatelessWidget {
  const SystemMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sonos Config'),
        actions: [
          IconButton(
            tooltip: 'Rescan',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<HouseholdStore>().initialize(),
          ),
        ],
      ),
      body: Consumer<HouseholdStore>(
        builder: (context, store, _) {
          switch (store.status) {
            case HouseholdStatus.idle:
            case HouseholdStatus.searching:
              return const _Centered(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Searching for Sonos players…'),
              ]));
            case HouseholdStatus.empty:
              return _Message(
                icon: Icons.speaker_group_outlined,
                text: 'No Sonos players found on this network.',
                onRetry: () => context.read<HouseholdStore>().initialize(),
              );
            case HouseholdStatus.error:
              return _Message(
                icon: Icons.error_outline,
                text: store.error ?? 'Something went wrong.',
                onRetry: () => context.read<HouseholdStore>().initialize(),
              );
            case HouseholdStatus.ready:
              return _SystemList(store: store);
          }
        },
      ),
    );
  }
}

class _SystemList extends StatelessWidget {
  const _SystemList({required this.store});

  final HouseholdStore store;

  @override
  Widget build(BuildContext context) {
    final household = store.household!;
    final rooms = household.visibleRooms;
    final unbonded = household.unbondedInvisibleDevices;

    return RefreshIndicator(
      onRefresh: store.refresh,
      child: ListView(
        children: [
          const _SectionHeader('Rooms'),
          for (final room in rooms) _RoomTile(room: room),
          if (unbonded.isNotEmpty) ...[
            const _SectionHeader('Unbonded devices'),
            for (final d in unbonded) _DeviceTile(device: d),
          ],
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final members = room.devices.length;
    return ListTile(
      leading: const Icon(Icons.meeting_room_outlined),
      title: Text(room.name),
      subtitle: Text(room.coordinator.model ??
          '$members device${members == 1 ? '' : 's'}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RoomDetailPage(coordinatorUuid: room.coordinator.uuid),
      )),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.subdirectory_arrow_right),
      title: Text(device.model ?? device.roomName),
      subtitle: const Text('Unbonded — tap to configure'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DeviceDetailPage(device: device),
      )),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title.toUpperCase(),
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.primary, letterSpacing: 1)),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(child: child);
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.icon, required this.text, required this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Rescan')),
          ],
        ),
      ),
    );
  }
}
