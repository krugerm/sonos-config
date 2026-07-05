import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/sonos_api.dart';

/// A snapshot of a single device's tunable settings.
///
/// Home-theater tuning (sub/surround) is read from and written to the device's
/// own host, which for a home-theater primary (e.g. a Beam) is the coordinator
/// that owns that EQ.
class DeviceSettings {
  const DeviceSettings({
    this.volume = 0,
    this.muted = false,
    this.bass = 0,
    this.treble = 0,
    this.balance = 0,
    this.loudness = false,
    this.nightMode = false,
    this.speechEnhancement = false,
    this.subGain = 0,
    this.subPolarityInverted = false,
    this.surroundEnabled = false,
    this.surroundLevel = 0,
    this.musicSurroundLevel = 0,
    this.heightLevel = 0,
    this.audioDelay = 0,
    this.outputFixed = false,
    this.trueplay = false,
    this.ledOn = true,
    this.buttonLocked = false,
  });

  final int volume;
  final bool muted;
  final int bass;
  final int treble;
  final int balance;
  final bool loudness;
  final bool nightMode;
  final bool speechEnhancement;
  final int subGain;
  final bool subPolarityInverted;
  final bool surroundEnabled;
  final int surroundLevel;
  final int musicSurroundLevel;
  final int heightLevel;
  final int audioDelay;
  final bool outputFixed;
  final bool trueplay;
  final bool ledOn;
  final bool buttonLocked;

  DeviceSettings copyWith({
    int? volume,
    bool? muted,
    int? bass,
    int? treble,
    int? balance,
    bool? loudness,
    bool? nightMode,
    bool? speechEnhancement,
    int? subGain,
    bool? subPolarityInverted,
    bool? surroundEnabled,
    int? surroundLevel,
    int? musicSurroundLevel,
    int? heightLevel,
    int? audioDelay,
    bool? outputFixed,
    bool? trueplay,
    bool? ledOn,
    bool? buttonLocked,
  }) {
    return DeviceSettings(
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      bass: bass ?? this.bass,
      treble: treble ?? this.treble,
      balance: balance ?? this.balance,
      loudness: loudness ?? this.loudness,
      nightMode: nightMode ?? this.nightMode,
      speechEnhancement: speechEnhancement ?? this.speechEnhancement,
      subGain: subGain ?? this.subGain,
      subPolarityInverted: subPolarityInverted ?? this.subPolarityInverted,
      surroundEnabled: surroundEnabled ?? this.surroundEnabled,
      surroundLevel: surroundLevel ?? this.surroundLevel,
      musicSurroundLevel: musicSurroundLevel ?? this.musicSurroundLevel,
      heightLevel: heightLevel ?? this.heightLevel,
      audioDelay: audioDelay ?? this.audioDelay,
      outputFixed: outputFixed ?? this.outputFixed,
      trueplay: trueplay ?? this.trueplay,
      ledOn: ledOn ?? this.ledOn,
      buttonLocked: buttonLocked ?? this.buttonLocked,
    );
  }
}

/// Loads and writes per-device settings on demand, reading only what the
/// device's [Device.capabilities] support.
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
      s = s.copyWith(
        volume: await _api.getVolume(host),
        muted: await _api.getMute(host),
      );
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
      if (caps.hasSubTuning) {
        s = s.copyWith(
          subGain: await _api.getEq(host, SonosApi.eqSubGain),
          subPolarityInverted:
              await _api.getEq(host, SonosApi.eqSubPolarity) == 1,
        );
      }
      if (caps.hasSurroundTuning) {
        s = s.copyWith(
          surroundEnabled:
              await _api.getEq(host, SonosApi.eqSurroundEnable) == 1,
          surroundLevel: await _api.getEq(host, SonosApi.eqSurroundLevel),
          musicSurroundLevel:
              await _api.getEq(host, SonosApi.eqMusicSurroundLevel),
          heightLevel: await _api.getEq(host, SonosApi.eqHeightChannelLevel),
          audioDelay: await _api.getEq(host, SonosApi.eqAudioDelay),
        );
      }
      if (caps.hasFixedOutput) {
        s = s.copyWith(outputFixed: await _api.getOutputFixed(host));
      }
      if (caps.hasTrueplay) {
        s = s.copyWith(trueplay: await _api.getTrueplay(host));
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

  Future<void> setMuted(Device d, bool on) async {
    await _api.setMute(d.host, on);
    _update(settings.copyWith(muted: on));
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

  Future<void> setSubGain(Device d, int v) async {
    await _api.setEq(d.host, SonosApi.eqSubGain, v.clamp(-15, 15));
    _update(settings.copyWith(subGain: v.clamp(-15, 15)));
  }

  Future<void> setSubPolarityInverted(Device d, bool on) async {
    await _api.setEq(d.host, SonosApi.eqSubPolarity, on ? 1 : 0);
    _update(settings.copyWith(subPolarityInverted: on));
  }

  Future<void> setSurroundEnabled(Device d, bool on) async {
    await _api.setEq(d.host, SonosApi.eqSurroundEnable, on ? 1 : 0);
    _update(settings.copyWith(surroundEnabled: on));
  }

  Future<void> setSurroundLevel(Device d, int v) async {
    await _api.setEq(d.host, SonosApi.eqSurroundLevel, v.clamp(-15, 15));
    _update(settings.copyWith(surroundLevel: v.clamp(-15, 15)));
  }

  Future<void> setMusicSurroundLevel(Device d, int v) async {
    await _api.setEq(d.host, SonosApi.eqMusicSurroundLevel, v.clamp(-15, 15));
    _update(settings.copyWith(musicSurroundLevel: v.clamp(-15, 15)));
  }

  Future<void> setHeightLevel(Device d, int v) async {
    await _api.setEq(d.host, SonosApi.eqHeightChannelLevel, v.clamp(-10, 10));
    _update(settings.copyWith(heightLevel: v.clamp(-10, 10)));
  }

  Future<void> setAudioDelay(Device d, int v) async {
    await _api.setEq(d.host, SonosApi.eqAudioDelay, v.clamp(0, 5));
    _update(settings.copyWith(audioDelay: v.clamp(0, 5)));
  }

  Future<void> setOutputFixed(Device d, bool on) async {
    await _api.setOutputFixed(d.host, on);
    _update(settings.copyWith(outputFixed: on));
  }

  Future<void> setTrueplay(Device d, bool on) async {
    await _api.setTrueplay(d.host, on);
    _update(settings.copyWith(trueplay: on));
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
