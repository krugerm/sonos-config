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
  // In-drag slider values (committed on change-end).
  double? _volume, _bass, _treble, _balance;
  double? _subGain, _surround, _musicSurround, _height, _audioDelay;

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
              SwitchListTile(
                title: const Text('Mute'),
                value: s.muted,
                onChanged: (v) => store.setMuted(device, v),
              ),
              if (caps.hasBassTreble) ...[
                _levelSlider(
                    'Bass', _bass, s.bass, (v) => setState(() => _bass = v),
                    (v) {
                  store.setBass(device, v);
                  setState(() => _bass = null);
                }),
                _levelSlider('Treble', _treble, s.treble,
                    (v) => setState(() => _treble = v), (v) {
                  store.setTreble(device, v);
                  setState(() => _treble = null);
                }),
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
              if (caps.isHomeTheater) ...[
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
                _slider(
                  label: 'Sub level',
                  value: _subGain ?? s.subGain.toDouble(),
                  min: -15,
                  max: 15,
                  divisions: 30,
                  display: _signed(_subGain ?? s.subGain.toDouble()),
                  onChanged: (v) => setState(() => _subGain = v),
                  onChangeEnd: (v) {
                    store.setSubGain(device, v.round());
                    setState(() => _subGain = null);
                  },
                ),
                SwitchListTile(
                  title: const Text('Sub phase inverted'),
                  value: s.subPolarityInverted,
                  onChanged: (v) => store.setSubPolarityInverted(device, v),
                ),
                SwitchListTile(
                  title: const Text('Surround speakers'),
                  value: s.surroundEnabled,
                  onChanged: (v) => store.setSurroundEnabled(device, v),
                ),
                _slider(
                  label: 'Surround (TV)',
                  value: _surround ?? s.surroundLevel.toDouble(),
                  min: -15,
                  max: 15,
                  divisions: 30,
                  display: _signed(_surround ?? s.surroundLevel.toDouble()),
                  onChanged: (v) => setState(() => _surround = v),
                  onChangeEnd: (v) {
                    store.setSurroundLevel(device, v.round());
                    setState(() => _surround = null);
                  },
                ),
                _slider(
                  label: 'Surround (music)',
                  value: _musicSurround ?? s.musicSurroundLevel.toDouble(),
                  min: -15,
                  max: 15,
                  divisions: 30,
                  display: _signed(
                      _musicSurround ?? s.musicSurroundLevel.toDouble()),
                  onChanged: (v) => setState(() => _musicSurround = v),
                  onChangeEnd: (v) {
                    store.setMusicSurroundLevel(device, v.round());
                    setState(() => _musicSurround = null);
                  },
                ),
                _slider(
                  label: 'Height',
                  value: _height ?? s.heightLevel.toDouble(),
                  min: -10,
                  max: 10,
                  divisions: 20,
                  display: _signed(_height ?? s.heightLevel.toDouble()),
                  onChanged: (v) => setState(() => _height = v),
                  onChangeEnd: (v) {
                    store.setHeightLevel(device, v.round());
                    setState(() => _height = null);
                  },
                ),
                _slider(
                  label: 'Audio delay',
                  value: _audioDelay ?? s.audioDelay.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  display:
                      '${(_audioDelay ?? s.audioDelay.toDouble()).round()}',
                  onChanged: (v) => setState(() => _audioDelay = v),
                  onChangeEnd: (v) {
                    store.setAudioDelay(device, v.round());
                    setState(() => _audioDelay = null);
                  },
                ),
              ],
              const Eyebrow('Device'),
              if (caps.hasTrueplay)
                SwitchListTile(
                  title: const Text('Trueplay tuning'),
                  value: s.trueplay,
                  onChanged: (v) => store.setTrueplay(device, v),
                ),
              if (caps.hasFixedOutput)
                SwitchListTile(
                  title: const Text('Fixed line-out level'),
                  value: s.outputFixed,
                  onChanged: (v) => store.setOutputFixed(device, v),
                ),
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

  Widget _levelSlider(String label, double? drag, int value,
      ValueChanged<double> onChanged, ValueChanged<int> commit) {
    return _slider(
      label: label,
      value: drag ?? value.toDouble(),
      min: -10,
      max: 10,
      divisions: 20,
      display: _signed(drag ?? value.toDouble()),
      onChanged: onChanged,
      onChangeEnd: (v) => commit(v.round()),
    );
  }

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
          SizedBox(width: 110, child: Text(label)),
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
