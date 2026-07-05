import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../models/room.dart';
import '../state/household_store.dart';
import 'device_detail_page.dart';
import 'room_detail_page.dart';
import 'theme.dart';
import 'widgets.dart';

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
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Sonos Config',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Mike Kruger · MIT License\n\n'
                  'Unofficial — not affiliated with or endorsed by Sonos, Inc. '
                  '"Sonos" is a trademark of Sonos, Inc.',
              children: const [
                SizedBox(height: 12),
                Text('Discover and configure the Sonos speakers on your local '
                    'network. Playback is out of scope — use your music app for '
                    'that.'),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<HouseholdStore>(
        builder: (context, store, _) {
          switch (store.status) {
            case HouseholdStatus.idle:
            case HouseholdStatus.searching:
              return const _Busy(label: 'Searching for Sonos players…');
            case HouseholdStatus.empty:
              return _Message(
                icon: Icons.wifi_find_outlined,
                title: 'No speakers found',
                body:
                    'Make sure this device is on the same Wi-Fi as your Sonos '
                    'system, then rescan.',
                onRetry: () => context.read<HouseholdStore>().initialize(),
              );
            case HouseholdStatus.error:
              return _Message(
                icon: Icons.error_outline,
                title: 'Discovery failed',
                body: store.error ?? 'Something went wrong.',
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
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Eyebrow('Rooms · ${rooms.length}'),
          for (final room in rooms)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _RoomCard(room: room),
            ),
          if (unbonded.isNotEmpty) ...[
            const Eyebrow('Unbonded devices'),
            for (final d in unbonded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _DeviceCard(device: d),
              ),
          ],
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              RoomDetailPage(coordinatorUuid: room.coordinator.uuid),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Avatar(icon: Icons.meeting_room_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${room.coordinator.model ?? 'Sonos player'}  ·  ${room.coordinator.host}',
                          style: monoStyle(context,
                              size: 11.5,
                              color: scheme.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: scheme.onSurface.withValues(alpha: 0.35)),
                ],
              ),
              if (room.satellites.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in room.satellites) RoleChip(s.bondRole),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DeviceDetailPage(device: device),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _Avatar(icon: Icons.link_off, tint: scheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.model ?? device.roomName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Unbonded  ·  ${device.host}',
                        style: monoStyle(context,
                            size: 11.5,
                            color: scheme.onSurface.withValues(alpha: 0.55))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, this.tint});

  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 18),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.primary),
            const SizedBox(height: 18),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Rescan'),
            ),
          ],
        ),
      ),
    );
  }
}
