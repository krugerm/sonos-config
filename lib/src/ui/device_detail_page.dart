import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../state/device_settings_store.dart';

/// Read-only diagnostics plus capability-gated settings for one device.
class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({super.key, required this.device});

  final Device device;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  double? _volume, _bass, _treble, _balance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DeviceSettingsStore>().load(widget.device);
    });
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final caps = device.capabilities;
    return Scaffold(
      appBar: AppBar(title: Text(device.model ?? device.roomName)),
      body: Consumer<DeviceSettingsStore>(
        builder: (context, store, _) {
          final s = store.settings;
          final api = store; // for setters
          return ListView(
            children: [
              _DiagnosticsCard(device: device),
              if (store.loading) const LinearProgressIndicator(),
              _section(context, 'Audio'),
              _slider(
                label: 'Volume',
                value: _volume ?? s.volume.toDouble(),
                min: 0,
                max: 100,
                display: '${(_volume ?? s.volume.toDouble()).round()}',
                onChanged: (v) => setState(() => _volume = v),
                onChangeEnd: (v) {
                  api.setVolume(device, v.round());
                  setState(() => _volume = null);
                },
              ),
              if (caps.hasBassTreble) ...[
                _slider(
                  label: 'Bass',
                  value: _bass ?? s.bass.toDouble(),
                  min: -10,
                  max: 10,
                  divisions: 20,
                  display: '${(_bass ?? s.bass.toDouble()).round()}',
                  onChanged: (v) => setState(() => _bass = v),
                  onChangeEnd: (v) {
                    api.setBass(device, v.round());
                    setState(() => _bass = null);
                  },
                ),
                _slider(
                  label: 'Treble',
                  value: _treble ?? s.treble.toDouble(),
                  min: -10,
                  max: 10,
                  divisions: 20,
                  display: '${(_treble ?? s.treble.toDouble()).round()}',
                  onChanged: (v) => setState(() => _treble = v),
                  onChangeEnd: (v) {
                    api.setTreble(device, v.round());
                    setState(() => _treble = null);
                  },
                ),
              ],
              if (caps.canStereoPair)
                _slider(
                  label: 'Balance (L–R)',
                  value: _balance ?? s.balance.toDouble(),
                  min: -100,
                  max: 100,
                  display: _balanceLabel(_balance ?? s.balance.toDouble()),
                  onChanged: (v) => setState(() => _balance = v),
                  onChangeEnd: (v) {
                    api.setBalance(device, v.round());
                    setState(() => _balance = null);
                  },
                ),
              if (caps.hasLoudness)
                SwitchListTile(
                  title: const Text('Loudness'),
                  value: s.loudness,
                  onChanged: (v) => api.setLoudness(device, v),
                ),
              if (caps.hasNightMode) ...[
                _section(context, 'Home theater'),
                SwitchListTile(
                  title: const Text('Night mode'),
                  subtitle: const Text('Reduce loud effects at low volume'),
                  value: s.nightMode,
                  onChanged: (v) => api.setNightMode(device, v),
                ),
                SwitchListTile(
                  title: const Text('Speech enhancement'),
                  value: s.speechEnhancement,
                  onChanged: (v) => api.setSpeechEnhancement(device, v),
                ),
              ],
              _section(context, 'Device'),
              if (caps.hasLed)
                SwitchListTile(
                  title: const Text('Status light'),
                  value: s.ledOn,
                  onChanged: (v) => api.setLed(device, v),
                ),
              if (caps.hasButtonLock)
                SwitchListTile(
                  title: const Text('Lock touch controls'),
                  value: s.buttonLocked,
                  onChanged: (v) => api.setButtonLock(device, v),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 1)),
      );

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    int? divisions,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  String _balanceLabel(double v) {
    final r = v.round();
    if (r == 0) return 'C';
    return r < 0 ? 'L${-r}' : 'R$r';
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Model', device.model ?? 'Unknown'),
      ('Room', device.roomName),
      ('IP address', device.host),
      ('Firmware', device.firmware ?? '—'),
      ('UUID', device.uuid),
    ];
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 96,
                        child: Text(k,
                            style: Theme.of(context).textTheme.labelMedium)),
                    Expanded(child: Text(v)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
