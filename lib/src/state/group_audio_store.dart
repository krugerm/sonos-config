import 'package:flutter/foundation.dart';

import '../services/sonos_api.dart';

/// Group (party-mode) volume and mute for a room, addressed to its coordinator
/// via `GroupRenderingControl`. Loaded on demand when a room detail opens.
class GroupAudioStore extends ChangeNotifier {
  GroupAudioStore(this._api);

  final SonosApi _api;

  int volume = 0;
  bool muted = false;
  bool loading = false;
  String? _host;

  Future<void> load(String coordinatorHost) async {
    _host = coordinatorHost;
    loading = true;
    notifyListeners();
    try {
      volume = await _api.getGroupVolume(coordinatorHost);
      muted = await _api.getGroupMute(coordinatorHost);
    } catch (_) {
      // Leave defaults; the UI still renders.
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setVolume(int v) async {
    final host = _host;
    if (host == null) return;
    await _api.setGroupVolume(host, v);
    volume = v.clamp(0, 100);
    notifyListeners();
  }

  Future<void> setMuted(bool m) async {
    final host = _host;
    if (host == null) return;
    await _api.setGroupMute(host, m);
    muted = m;
    notifyListeners();
  }
}
