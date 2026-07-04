import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/zone_group.dart';
import '../state/sonos_controller.dart';
import 'now_playing_panel.dart';
import 'speaker_list_panel.dart';
import 'widgets/status_view.dart';

/// Root screen. Adapts between a master–detail layout on wide screens (tablet /
/// desktop) and a stacked list → Now Playing flow on phones.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _wideBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SonosController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Sonos'),
        actions: [
          IconButton(
            tooltip: 'Rescan network',
            onPressed: controller.status == DiscoveryStatus.searching
                ? null
                : () => controller.initialize(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: switch (controller.status) {
        DiscoveryStatus.idle ||
        DiscoveryStatus.searching =>
          const StatusView(
            icon: Icons.wifi_find,
            title: 'Looking for speakers',
            message: 'Searching your local network for Sonos players…',
            busy: true,
          ),
        DiscoveryStatus.empty => StatusView(
            icon: Icons.speaker,
            title: 'No speakers found',
            message:
                'Make sure this device is on the same Wi-Fi as your Sonos '
                'system, then scan again.',
            onRetry: () => controller.initialize(),
          ),
        DiscoveryStatus.error => StatusView(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: controller.error ?? 'Unknown error',
            onRetry: () => controller.initialize(),
          ),
        DiscoveryStatus.ready => LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              return wide
                  ? _WideLayout(controller: controller)
                  : SpeakerListPanel(
                      onSelect: (group) => _openNowPlaying(context, group),
                    );
            },
          ),
      },
    );
  }

  void _openNowPlaying(BuildContext context, ZoneGroup group) {
    final controller = context.read<SonosController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: _NowPlayingPage(groupId: group.id),
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.controller});

  final SonosController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedGroup;
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: SpeakerListPanel(onSelect: (_) {}),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? const StatusView(
                  icon: Icons.touch_app,
                  title: 'Pick a room',
                  message: 'Select a speaker on the left to start controlling '
                      'playback.',
                )
              : NowPlayingPanel(group: selected),
        ),
      ],
    );
  }
}

/// Full-screen Now Playing for the phone flow. Re-resolves the group by id so
/// it keeps updating as the topology refreshes.
class _NowPlayingPage extends StatelessWidget {
  const _NowPlayingPage({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SonosController>();
    final group = controller.groups.where((g) => g.id == groupId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(group?.displayName ?? 'Now Playing')),
      body: group == null
          ? const StatusView(
              icon: Icons.speaker,
              title: 'Room unavailable',
              message: 'This group is no longer part of your Sonos system.',
            )
          : NowPlayingPanel(group: group),
    );
  }
}
