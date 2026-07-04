import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/sonos_api.dart';

/// A snapshot of a single device's tunable settings.
class DeviceSettings {
  const DeviceSettings({
    this.volume = 0,
    this.bass = 0,
    this.treble = 0,
    this.balance = 0,
    this.loudness = false,
    this.nightMode = false,
    this.speechEnhancement = false,
    this.ledOn = true,
    this.buttonLocked = false,
  });

  final int volume;
  final int bass;
  final int treble;
  final int balance;
  final bool loudness;
  final bool nightMode;
  final bool speechEnhancement;
  final bool ledOn;
  final bool buttonLocked;

  DeviceSettings copyWith({
    int? volume,
    int? bass,
    int? treble,
    int? balance,
    bool? loudness,
    bool? nightMode,
    bool? speechEnhancement,
    bool? ledOn,
    bool? buttonLocked,
  }) {
    return DeviceSettings(
      volume: volume ?? this.volume,
      bass: bass ?? this.bass,
      treble: treble ?? this.treble,
      balance: balance ?? this.balance,
      loudness: loudness ?? this.loudness,
      nightMode: nightMode ?? this.nightMode,
      speechEnhancement: speechEnhancement ?? this.speechEnhancement,
      ledOn: ledOn ?? this.ledOn,
      buttonLocked: buttonLocked ?? this.buttonLocked,
    );
  }
}

/// Loads and writes per-device audio + device settings on demand, reading only
/// what the device's [Device.capabilities] support.
class DeviceSettingsStore extends ChangeNotifier {
  DeviceSettingsStore(this._api);

  final SonosApi _api;

  DeviceSettings settings = const DeviceSettings();
  bool loading = false;

  Future<void> load(Device device) async {
    loading = true;
    notifyListeners();
    final host = device.host;
    final caps = device.capabilities;
    var s = const DeviceSettings();
    try {
      s = s.copyWith(volume: await _api.getVolume(host));
      if (caps.hasBassTreble) {
        s = s.copyWith(
          bass: await _api.getBass(host),
          treble: await _api.getTreble(host),
        );
      }
      if (caps.hasLoudness) {
        s = s.copyWith(loudness: await _api.getLoudness(host));
      }
      if (caps.hasNightMode) {
        s = s.copyWith(
          nightMode: await _api.getNightMode(host),
          speechEnhancement: await _api.getSpeechEnhancement(host),
        );
      }
      if (caps.hasLed) s = s.copyWith(ledOn: await _api.getLedOn(host));
      if (caps.hasButtonLock) {
        s = s.copyWith(buttonLocked: await _api.getButtonLock(host));
      }
    } catch (_) {
      // Leave whatever was read; the UI shows defaults for the rest.
    }
    settings = s;
    loading = false;
    notifyListeners();
  }

  Future<void> setVolume(Device d, int v) async {
    await _api.setVolume(d.host, v);
    _update(settings.copyWith(volume: v.clamp(0, 100)));
  }

  Future<void> setBass(Device d, int v) async {
    await _api.setBass(d.host, v);
    _update(settings.copyWith(bass: v.clamp(-10, 10)));
  }

  Future<void> setTreble(Device d, int v) async {
    await _api.setTreble(d.host, v);
    _update(settings.copyWith(treble: v.clamp(-10, 10)));
  }

  Future<void> setBalance(Device d, int v) async {
    await _api.setBalance(d.host, v);
    _update(settings.copyWith(balance: v.clamp(-100, 100)));
  }

  Future<void> setLoudness(Device d, bool on) async {
    await _api.setLoudness(d.host, on);
    _update(settings.copyWith(loudness: on));
  }

  Future<void> setNightMode(Device d, bool on) async {
    await _api.setNightMode(d.host, on);
    _update(settings.copyWith(nightMode: on));
  }

  Future<void> setSpeechEnhancement(Device d, bool on) async {
    await _api.setSpeechEnhancement(d.host, on);
    _update(settings.copyWith(speechEnhancement: on));
  }

  Future<void> setLed(Device d, bool on) async {
    await _api.setLedOn(d.host, on);
    _update(settings.copyWith(ledOn: on));
  }

  Future<void> setButtonLock(Device d, bool locked) async {
    await _api.setButtonLock(d.host, locked);
    _update(settings.copyWith(buttonLocked: locked));
  }

  void _update(DeviceSettings s) {
    settings = s;
    notifyListeners();
  }
}
