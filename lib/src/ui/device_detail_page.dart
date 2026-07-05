import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../state/device_settings_store.dart';
import 'theme.dart';
import 'widgets.dart';

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
          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _DiagnosticsCard(device: device),
              ),
              if (store.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: LinearProgressIndicator(),
                ),
              const Eyebrow('Audio'),
              _slider(
                label: 'Volume',
                value: _volume ?? s.volume.toDouble(),
                min: 0,
                max: 100,
                display: '${(_volume ?? s.volume.toDouble()).round()}',
                onChanged: (v) => setState(() => _volume = v),
                onChangeEnd: (v) {
                  store.setVolume(device, v.round());
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
                  display: _signed(_bass ?? s.bass.toDouble()),
                  onChanged: (v) => setState(() => _bass = v),
                  onChangeEnd: (v) {
                    store.setBass(device, v.round());
                    setState(() => _bass = null);
                  },
                ),
                _slider(
                  label: 'Treble',
                  value: _treble ?? s.treble.toDouble(),
                  min: -10,
                  max: 10,
                  divisions: 20,
                  display: _signed(_treble ?? s.treble.toDouble()),
                  onChanged: (v) => setState(() => _treble = v),
                  onChangeEnd: (v) {
                    store.setTreble(device, v.round());
                    setState(() => _treble = null);
                  },
                ),
              ],
              if (caps.canStereoPair)
                _slider(
                  label: 'Balance',
                  value: _balance ?? s.balance.toDouble(),
                  min: -100,
                  max: 100,
                  display: _balanceLabel(_balance ?? s.balance.toDouble()),
                  onChanged: (v) => setState(() => _balance = v),
                  onChangeEnd: (v) {
                    store.setBalance(device, v.round());
                    setState(() => _balance = null);
                  },
                ),
              if (caps.hasLoudness)
                SwitchListTile(
                  title: const Text('Loudness'),
                  value: s.loudness,
                  onChanged: (v) => store.setLoudness(device, v),
                ),
              if (caps.hasNightMode) ...[
                const Eyebrow('Home theater'),
                SwitchListTile(
                  title: const Text('Night mode'),
                  subtitle: const Text('Soften loud effects at low volume'),
                  value: s.nightMode,
                  onChanged: (v) => store.setNightMode(device, v),
                ),
                SwitchListTile(
                  title: const Text('Speech enhancement'),
                  value: s.speechEnhancement,
                  onChanged: (v) => store.setSpeechEnhancement(device, v),
                ),
              ],
              const Eyebrow('Device'),
              if (caps.hasLed)
                SwitchListTile(
                  title: const Text('Status light'),
                  value: s.ledOn,
                  onChanged: (v) => store.setLed(device, v),
                ),
              if (caps.hasButtonLock)
                SwitchListTile(
                  title: const Text('Lock touch controls'),
                  value: s.buttonLocked,
                  onChanged: (v) => store.setButtonLock(device, v),
                ),
            ],
          );
        },
      ),
    );
  }

  String _signed(double v) => v.round() > 0 ? '+${v.round()}' : '${v.round()}';

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
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: '$label: $display',
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(display,
                textAlign: TextAlign.end, style: monoStyle(context, size: 12)),
          ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    device.model ?? device.roomName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                RoleChip(device.bondRole),
              ],
            ),
            const SizedBox(height: 12),
            SpecRow(label: 'Room', value: device.roomName),
            SpecRow(label: 'IP address', value: device.host),
            SpecRow(label: 'Firmware', value: device.firmware ?? '—'),
            SpecRow(label: 'UUID', value: device.uuid),
          ],
        ),
      ),
    );
  }
}
