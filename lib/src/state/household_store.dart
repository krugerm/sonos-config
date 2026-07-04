import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/household.dart';
import '../services/device_info.dart';
import '../services/sonos_api.dart';
import '../services/ssdp_discovery.dart';

/// Discovery/connection lifecycle for the UI to render.
enum HouseholdStatus { idle, searching, ready, empty, error }

/// The read-only system map: discovers players, loads the [Household] topology,
/// enriches devices with their model names, and polls to stay current.
///
/// Its [refresh] is what the `ActionExecutor` polls to verify a change settled.
class HouseholdStore extends ChangeNotifier {
  HouseholdStore({
    SonosApi? api,
    SsdpDiscovery? discovery,
    Future<String?> Function(String host)? fetchModel,
    this.pollInterval = const Duration(seconds: 5),
  })  : _api = api ?? SonosApi(),
        _discovery = discovery ?? SsdpDiscovery(),
        _fetchModel = fetchModel ?? fetchDeviceModel;

  final SonosApi _api;
  final SsdpDiscovery _discovery;
  final Future<String?> Function(String host) _fetchModel;
  final Duration pollInterval;

  HouseholdStatus status = HouseholdStatus.idle;
  Household? household;
  String? error;

  final Set<String> _hosts = {};
  final Map<String, String?> _modelCache = {};
  Timer? _timer;
  bool _disposed = false;

  /// Discovers players, loads the first snapshot, and starts polling.
  Future<void> initialize() async {
    _set(HouseholdStatus.searching);
    error = null;
    try {
      final hosts = await _discovery.discover();
      _hosts
        ..clear()
        ..addAll(hosts);
      if (_hosts.isEmpty) {
        _set(HouseholdStatus.empty);
        return;
      }
      final hh = await refresh();
      if (hh.devices.isEmpty) {
        _set(HouseholdStatus.empty);
        return;
      }
      _set(HouseholdStatus.ready);
      _startPolling();
    } catch (e) {
      error = e.toString();
      _set(HouseholdStatus.error);
    }
  }

  /// Re-polls any reachable player, enriches, updates [household], and returns
  /// the fresh snapshot. Tolerant of a single player being unreachable.
  Future<Household> refresh() async {
    for (final host in _hosts.toList()) {
      try {
        final raw = await _api.getHousehold(host);
        if (raw.devices.isEmpty) continue;
        for (final d in raw.devices) {
          _hosts.add(d.host);
        }
        final enriched = await _enrich(raw);
        household = enriched;
        _notify();
        return enriched;
      } catch (_) {
        // Try the next known host.
      }
    }
    return household ?? const Household(groups: []);
  }

  Future<Household> _enrich(Household h) async {
    final missing =
        h.devices.where((d) => !_modelCache.containsKey(d.uuid)).toList();
    await Future.wait(missing.map((d) async {
      _modelCache[d.uuid] = await _fetchModel(d.host);
    }));
    return h.withModels(_modelCache);
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => refresh());
  }

  void _set(HouseholdStatus s) {
    status = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _api.close();
    _discovery.close();
    super.dispose();
  }
}
