import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/play_mode.dart';
import '../models/playback_state.dart';
import '../models/sonos_speaker.dart';
import '../models/zone_group.dart';
import '../state/sonos_controller.dart';
import 'favorites_sheet.dart';
import 'group_sheet.dart';
import 'widgets/album_art.dart';
import 'widgets/transport_controls.dart';
import 'widgets/volume_control.dart';

/// The main playback surface for the selected group: art, track, seek bar,
/// transport, group volume, and expandable per-speaker volumes.
class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({super.key, required this.group});

  final ZoneGroup group;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SonosController>();
    final state = controller.playbackFor(group);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: AlbumArt(url: state.albumArtUri, size: 260, radius: 20),
            ),
            const SizedBox(height: 28),
            Text(
              state.hasTrack ? state.title! : 'Nothing playing',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              [state.artist, state.album]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(' • '),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _SeekBar(group: group, state: state),
            const SizedBox(height: 4),
            _PlayModeRow(group: group, mode: state.playMode),
            const SizedBox(height: 4),
            TransportControls(
              transport: state.transport,
              onPlayPause: () => controller.togglePlayPause(group),
              onNext: () => controller.next(group),
              onPrevious: () => controller.previous(group),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => FavoritesSheet.show(context, group),
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Favorites'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => GroupSheet.show(context, group),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(group.isSingle ? 'Group' : 'Grouping'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: VolumeControl(
                  volume: state.volume,
                  muted: state.muted,
                  label: group.isSingle ? 'Volume' : 'Group volume',
                  onChanged: (v) => controller.setGroupVolume(group, v),
                  onToggleMute: () => controller.toggleMute(group),
                ),
              ),
            ),
            if (!group.isSingle) ...[
              const SizedBox(height: 8),
              _PerSpeakerVolumes(group: group),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Shuffle toggle + repeat cycle (off / all / one).
class _PlayModeRow extends StatelessWidget {
  const _PlayModeRow({required this.group, required this.mode});

  final ZoneGroup group;
  final PlayMode mode;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SonosController>();
    final scheme = Theme.of(context).colorScheme;

    Color colorFor(bool active) =>
        active ? scheme.primary : scheme.onSurfaceVariant;

    final repeatIcon = mode.repeat == SonosRepeatMode.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: mode.shuffle ? 'Shuffle on' : 'Shuffle off',
          onPressed: () => controller.toggleShuffle(group),
          icon: Icon(Icons.shuffle_rounded, color: colorFor(mode.shuffle)),
        ),
        const SizedBox(width: 24),
        IconButton(
          tooltip: switch (mode.repeat) {
            SonosRepeatMode.off => 'Repeat off',
            SonosRepeatMode.all => 'Repeat all',
            SonosRepeatMode.one => 'Repeat one',
          },
          onPressed: () => controller.cycleRepeat(group),
          icon: Icon(repeatIcon,
              color: colorFor(mode.repeat != SonosRepeatMode.off)),
        ),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.group, required this.state});

  final ZoneGroup group;
  final PlaybackState state;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final total = state.duration.inSeconds.toDouble();
    final hasDuration = total > 0;
    final current =
        _dragValue ?? state.position.inSeconds.toDouble().clamp(0, total);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: hasDuration ? current.toDouble() : 0,
            max: hasDuration ? total : 1,
            onChanged: hasDuration
                ? (v) => setState(() => _dragValue = v)
                : null,
            onChangeEnd: hasDuration
                ? (v) {
                    context
                        .read<SonosController>()
                        .seek(widget.group, Duration(seconds: v.round()));
                    setState(() => _dragValue = null);
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(Duration(seconds: current.round())),
                  style: Theme.of(context).textTheme.labelSmall),
              Text(hasDuration ? _fmt(state.duration) : '--:--',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${two(s)}';
  }
}

/// Lists each speaker in a multi-room group with its own volume slider.
class _PerSpeakerVolumes extends StatelessWidget {
  const _PerSpeakerVolumes({required this.group});

  final ZoneGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('Speakers in this group'),
        leading: const Icon(Icons.speaker_group),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          for (final speaker in group.members)
            _SpeakerVolumeTile(key: ValueKey(speaker.uuid), speaker: speaker),
        ],
      ),
    );
  }
}

class _SpeakerVolumeTile extends StatefulWidget {
  const _SpeakerVolumeTile({super.key, required this.speaker});

  final SonosSpeaker speaker;

  @override
  State<_SpeakerVolumeTile> createState() => _SpeakerVolumeTileState();
}

class _SpeakerVolumeTileState extends State<_SpeakerVolumeTile> {
  int _volume = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await context.read<SonosController>().speakerVolume(widget.speaker);
    if (mounted) {
      setState(() {
        _volume = v;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Opacity(
        opacity: _loaded ? 1 : 0.5,
        child: VolumeControl(
          dense: true,
          label: widget.speaker.name,
          volume: _volume,
          muted: false,
          onChanged: (v) {
            setState(() => _volume = v);
            context.read<SonosController>().setSpeakerVolume(widget.speaker, v);
          },
        ),
      ),
    );
  }
}
