import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../models/playback_state.dart';
import '../models/sonos_speaker.dart';
import '../models/zone_group.dart';
import '../services/sonos_api.dart';
import '../services/ssdp_discovery.dart';

/// Overall status of the discovery/connection lifecycle, for the UI to render.
enum DiscoveryStatus { idle, searching, ready, empty, error }

/// App-wide state: discovers speakers, tracks zone groups, polls the selected
/// group's playback, and exposes control commands.
///
/// This is the single source of truth the widget tree listens to via
/// `provider`. All Sonos I/O flows through here so the UI stays declarative.
class SonosController extends ChangeNotifier {
  SonosController({SonosApi? api, SsdpDiscovery? discovery})
      : _api = api ?? SonosApi(),
        _discovery = discovery ?? SsdpDiscovery();

  final SonosApi _api;
  final SsdpDiscovery _discovery;

  static const _pollInterval = Duration(seconds: 2);
  static const _topologyRefreshEvery = 15; // poll ticks between topology reloads

  DiscoveryStatus _status = DiscoveryStatus.idle;
  DiscoveryStatus get status => _status;

  String? _error;
  String? get error => _error;

  List<ZoneGroup> _groups = const [];
  List<ZoneGroup> get groups => _groups;

  String? _selectedGroupId;
  final Set<String> _hosts = {};
  final Map<String, PlaybackState> _playback = {};

  Timer? _pollTimer;
  int _pollTick = 0;
  bool _disposed = false;

  /// The group the Now Playing view is bound to, re-resolved each refresh so it
  /// survives topology changes.
  ZoneGroup? get selectedGroup {
    if (_selectedGroupId == null) return null;
    for (final g in _groups) {
      if (g.id == _selectedGroupId) return g;
    }
    return null;
  }

  /// Playback snapshot for [group], or an empty default while it loads.
  PlaybackState playbackFor(ZoneGroup group) =>
      _playback[group.id] ?? const PlaybackState();

  // ---- Lifecycle ----------------------------------------------------------

  /// Discovers speakers and loads the topology. Safe to call again to rescan.
  Future<void> initialize() async {
    _setStatus(DiscoveryStatus.searching);
    _error = null;
    try {
      final hosts = await _discovery.discover();
      _hosts
        ..clear()
        ..addAll(hosts);
      if (_hosts.isEmpty) {
        _setStatus(DiscoveryStatus.empty);
        return;
      }
      await _loadTopology();
      if (_groups.isEmpty) {
        _setStatus(DiscoveryStatus.empty);
        return;
      }
      _selectedGroupId ??= _groups.first.id;
      // Populate playback before flipping to ready so the first frame already
      // shows what's playing rather than an empty shell.
      await _refreshSelectedPlayback();
      _setStatus(DiscoveryStatus.ready);
      _startPolling();
      unawaited(loadFavorites());
    } catch (e) {
      _error = e.toString();
      _setStatus(DiscoveryStatus.error);
    }
  }

  /// Rebuilds groups by querying any reachable player.
  Future<void> _loadTopology() async {
    for (final host in _hosts) {
      try {
        final groups = await _api.getZoneGroups(host);
        if (groups.isNotEmpty) {
          _groups = groups;
          // Learn every member host so we can survive the original one dropping.
          for (final g in groups) {
            for (final m in g.members) {
              _hosts.add(m.host);
            }
          }
          _notify();
          return;
        }
      } catch (_) {
        // Try the next known host.
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _onPollTick());
  }

  Future<void> _onPollTick() async {
    _pollTick++;
    if (_pollTick % _topologyRefreshEvery == 0) {
      await _loadTopology();
    }
    await _refreshSelectedPlayback();
  }

  // ---- Selection ----------------------------------------------------------

  void selectGroup(ZoneGroup group) {
    if (_selectedGroupId == group.id) return;
    _selectedGroupId = group.id;
    _notify();
    unawaited(_refreshSelectedPlayback());
  }

  // ---- Playback polling ---------------------------------------------------

  Future<void> _refreshSelectedPlayback() async {
    final group = selectedGroup;
    if (group == null) return;
    final host = group.coordinator.host;
    try {
      final results = await Future.wait([
        _api.getTransportState(host),
        _api.getGroupVolume(host),
        _api.getGroupMute(host),
      ]);
      var state = (_playback[group.id] ?? const PlaybackState()).copyWith(
        transport: results[0] as TransportState,
        volume: results[1] as int,
        muted: results[2] as bool,
      );
      // Track metadata/position and play mode are separate calls; tolerate
      // either being absent so a single failure doesn't blank the whole tile.
      try {
        state = await _api.getPositionInfo(host, state);
      } catch (_) {}
      try {
        state = state.copyWith(playMode: await _api.getPlayMode(host));
      } catch (_) {}
      _playback[group.id] = state;
      _notify();
    } catch (_) {
      // Transient network hiccup; the next tick will retry.
    }
  }

  // ---- Commands (optimistic where it helps the UI feel responsive) --------

  Future<void> togglePlayPause(ZoneGroup group) async {
    final host = group.coordinator.host;
    final playing = playbackFor(group).transport.isPlaying;
    _updatePlayback(group,
        (s) => s.copyWith(transport: playing ? TransportState.paused : TransportState.playing));
    try {
      playing ? await _api.pause(host) : await _api.play(host);
    } catch (_) {}
    await _refreshSelectedPlayback();
  }

  Future<void> next(ZoneGroup group) async {
    try {
      await _api.next(group.coordinator.host);
    } catch (_) {}
    await _refreshSelectedPlayback();
  }

  Future<void> previous(ZoneGroup group) async {
    try {
      await _api.previous(group.coordinator.host);
    } catch (_) {}
    await _refreshSelectedPlayback();
  }

  Future<void> seek(ZoneGroup group, Duration position) async {
    _updatePlayback(group, (s) => s.copyWith(position: position));
    try {
      await _api.seek(group.coordinator.host, position);
    } catch (_) {}
  }

  /// Sets group volume. Updates local state first so the slider tracks the
  /// finger, then sends the command; polling reconciles.
  Future<void> setGroupVolume(ZoneGroup group, int volume) async {
    final clamped = volume.clamp(0, 100);
    _updatePlayback(group, (s) => s.copyWith(volume: clamped, muted: false));
    try {
      await _api.setGroupVolume(group.coordinator.host, clamped);
    } catch (_) {}
  }

  Future<void> toggleMute(ZoneGroup group) async {
    final muted = playbackFor(group).muted;
    _updatePlayback(group, (s) => s.copyWith(muted: !muted));
    try {
      await _api.setGroupMute(group.coordinator.host, !muted);
    } catch (_) {}
  }

  // ---- Play modes ---------------------------------------------------------

  Future<void> toggleShuffle(ZoneGroup group) async {
    final mode = playbackFor(group).playMode;
    final next = mode.withShuffle(!mode.shuffle);
    _updatePlayback(group, (s) => s.copyWith(playMode: next));
    try {
      await _api.setPlayMode(group.coordinator.host, next);
    } catch (_) {}
  }

  Future<void> cycleRepeat(ZoneGroup group) async {
    final next = playbackFor(group).playMode.cycleRepeat();
    _updatePlayback(group, (s) => s.copyWith(playMode: next));
    try {
      await _api.setPlayMode(group.coordinator.host, next);
    } catch (_) {}
  }

  // ---- Favorites ----------------------------------------------------------

  List<MediaItem> _favorites = const [];
  List<MediaItem> get favorites => _favorites;

  /// Loads Sonos favorites from any reachable player (the list is household-wide).
  Future<void> loadFavorites() async {
    for (final host in _hosts) {
      try {
        final items = await _api.browseFavorites(host);
        _favorites = items;
        _notify();
        return;
      } catch (_) {}
    }
  }

  /// Plays [favorite] on [group]'s coordinator, then refreshes.
  ///
  /// Returns `true` if playback was started. Returns `false` when the favorite
  /// carries no directly-playable `res` URI (e.g. a music-service "shortcut"
  /// favorite that must be resolved through the service's own API) or the
  /// coordinator rejects the URI — so the UI can tell the user honestly rather
  /// than claim success.
  Future<bool> playFavorite(ZoneGroup group, MediaItem favorite) async {
    if (!favorite.isPlayable) return false;
    try {
      await _api.playUri(group.coordinator.host, favorite.uri!,
          metadata: favorite.metadata ?? '');
    } catch (_) {
      return false;
    }
    await _refreshSelectedPlayback();
    return true;
  }

  /// Reads the current play queue for [group].
  Future<List<MediaItem>> loadQueue(ZoneGroup group) async {
    try {
      return await _api.browseQueue(group.coordinator.host);
    } catch (_) {
      return const [];
    }
  }

  // ---- Grouping -----------------------------------------------------------

  /// Adds [speaker] to [target]'s group (drops it from any previous group).
  Future<void> joinGroup(SonosSpeaker speaker, ZoneGroup target) async {
    try {
      await _api.joinGroup(speaker.host, target.coordinator.uuid);
    } catch (_) {}
    await _loadTopology();
  }

  /// Splits [speaker] out into its own standalone group.
  Future<void> leaveGroup(SonosSpeaker speaker) async {
    try {
      await _api.leaveGroup(speaker.host);
    } catch (_) {}
    await _loadTopology();
  }

  /// Sets the volume of a single [speaker] within a group.
  Future<void> setSpeakerVolume(SonosSpeaker speaker, int volume) async {
    try {
      await _api.setVolume(speaker.host, volume.clamp(0, 100));
    } catch (_) {}
  }

  Future<int> speakerVolume(SonosSpeaker speaker) async {
    try {
      return await _api.getVolume(speaker.host);
    } catch (_) {
      return 0;
    }
  }

  // ---- Internals ----------------------------------------------------------

  void _updatePlayback(ZoneGroup group, PlaybackState Function(PlaybackState) f) {
    _playback[group.id] = f(playbackFor(group));
    _notify();
  }

  void _setStatus(DiscoveryStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _api.close();
    _discovery.close();
    super.dispose();
  }
}
