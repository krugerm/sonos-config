# Sonos Config Tool — Phase 2: Config & EQ API Methods — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `SonosApi` with typed methods for every Phase-1-scoped configuration operation — topology/bonding, room/device identity, and audio tuning — each grounded in the device's own SCPD signature.

**Architecture:** Additive only. New methods on the existing `SonosApi`; a new `FakeSoapClient` test harness that records SOAP calls and returns canned responses (no hardware). The existing playback app keeps building. Depends on nothing from Phase 1 (pure service layer); Phase 3 actions will consume these methods.

**Tech Stack:** Dart, `package:xml`, `package:http`, `flutter_test`.

## Global Constraints

- Dart SDK `>=3.4.0 <4.0.0`, Flutter `>=3.22.0` — verbatim from `pubspec.yaml`.
- No new package dependencies.
- `flutter analyze` clean; `flutter test` green.
- `InstanceID` is always `'0'`; single-channel ops use `Channel: 'Master'` (project convention).
- All services used (`DeviceProperties`, `RenderingControl`) already exist in the `SonosService` enum — no `soap_client.dart` change needed.

### SCPD-verified signatures (captured from the live Beam, 2026-07-04)

DeviceProperties:
- `SetZoneAttributes(DesiredZoneName, DesiredIcon, DesiredConfiguration, DesiredTargetRoomName)`
- `GetZoneAttributes() -> CurrentZoneName, CurrentIcon, CurrentConfiguration, CurrentTargetRoomName`
- `SetLEDState(DesiredLEDState)` / `GetLEDState() -> CurrentLEDState`  (values `"On"`/`"Off"`)
- `SetButtonLockState(DesiredButtonLockState)` / `GetButtonLockState() -> CurrentButtonLockState`  (`"On"`/`"Off"`)
- `CreateStereoPair(ChannelMapSet)` / `SeparateStereoPair(ChannelMapSet)`
- `AddHTSatellite(HTSatChanMapSet)` / `RemoveHTSatellite(SatRoomUUID)`

RenderingControl (all take `InstanceID`):
- `GetBass() -> CurrentBass` / `SetBass(DesiredBass)`  (range −10..10)
- `GetTreble() -> CurrentTreble` / `SetTreble(DesiredTreble)`  (−10..10)
- `GetLoudness(Channel) -> CurrentLoudness` / `SetLoudness(Channel, DesiredLoudness)`  (0/1)
- `GetEQ(EQType) -> CurrentValue` / `SetEQ(EQType, DesiredValue)`  (EQType `NightMode`, `DialogLevel`; value 0/1)
- `GetVolume(Channel) -> CurrentVolume` / `SetVolume(Channel, DesiredVolume)`  (balance via `LF`/`RF`)

---

### Task 1: FakeSoapClient harness + topology/bonding API methods

**Files:**
- Create: `test/support/fake_soap_client.dart`
- Modify: `lib/src/services/sonos_api.dart` (add methods in a new `// ---- Bonding / topology config ----` section)
- Test: `test/sonos_api_config_test.dart`

**Interfaces:**
- Produces (harness): `class FakeSoapClient extends SoapClient` recording `List<SoapCall> calls` where `SoapCall = ({String host, SonosService service, String action, Map<String,String> args})`; constructed with `FakeSoapClient([XmlElement Function(String action)? responder])`; helper `XmlElement soapResponse(String innerXml)`.
- Produces (api): `Future<void> addHtSatellite(String primaryHost, String htSatChanMapSet)`, `removeHtSatellite(String primaryHost, String satRoomUuid)`, `createStereoPair(String primaryHost, String channelMapSet)`, `separateStereoPair(String primaryHost, String channelMapSet)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/support/fake_soap_client.dart
import 'package:personal_sonos/src/services/soap_client.dart';
import 'package:xml/xml.dart';

typedef SoapCall = ({
  String host,
  SonosService service,
  String action,
  Map<String, String> args,
});

/// Builds a response element whose `.arg(name)` finds direct children.
XmlElement soapResponse(String innerXml) =>
    XmlDocument.parse('<Response>$innerXml</Response>').rootElement;

/// A [SoapClient] that records calls and returns canned responses instead of
/// hitting the network.
class FakeSoapClient extends SoapClient {
  FakeSoapClient([this._responder]);

  final XmlElement Function(String action)? _responder;
  final List<SoapCall> calls = [];

  SoapCall get lastCall => calls.last;

  @override
  Future<XmlElement> invoke(
    String host,
    SonosService service,
    String action, {
    Map<String, String> arguments = const {},
  }) async {
    calls.add((host: host, service: service, action: action, args: arguments));
    return _responder?.call(action) ?? soapResponse('');
  }
}
```

```dart
// test/sonos_api_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/services/soap_client.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'support/fake_soap_client.dart';

void main() {
  late FakeSoapClient soap;
  late SonosApi api;
  setUp(() {
    soap = FakeSoapClient();
    api = SonosApi(client: soap);
  });

  group('bonding / topology', () {
    test('addHtSatellite posts HTSatChanMapSet to DeviceProperties', () async {
      await api.addHtSatellite('10.0.0.1', 'PRIMARY:LF,RF;SUB:SW');
      expect(soap.lastCall.host, '10.0.0.1');
      expect(soap.lastCall.service, SonosService.deviceProperties);
      expect(soap.lastCall.action, 'AddHTSatellite');
      expect(soap.lastCall.args, {'HTSatChanMapSet': 'PRIMARY:LF,RF;SUB:SW'});
    });

    test('removeHtSatellite posts the satellite room UUID', () async {
      await api.removeHtSatellite('10.0.0.1', 'RINCON_SUB');
      expect(soap.lastCall.action, 'RemoveHTSatellite');
      expect(soap.lastCall.args, {'SatRoomUUID': 'RINCON_SUB'});
    });

    test('createStereoPair posts the channel map set', () async {
      await api.createStereoPair('10.0.0.1', 'L:LF,LF;R:RF,RF');
      expect(soap.lastCall.action, 'CreateStereoPair');
      expect(soap.lastCall.args, {'ChannelMapSet': 'L:LF,LF;R:RF,RF'});
    });

    test('separateStereoPair posts the channel map set', () async {
      await api.separateStereoPair('10.0.0.1', 'L:LF,LF;R:RF,RF');
      expect(soap.lastCall.action, 'SeparateStereoPair');
      expect(soap.lastCall.args, {'ChannelMapSet': 'L:LF,LF;R:RF,RF'});
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sonos_api_config_test.dart`
Expected: FAIL — `addHtSatellite` is not defined on `SonosApi`.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/src/services/sonos_api.dart`, immediately after the existing
`leaveGroup` method (end of the `// ---- Grouping ----` section):

```dart
  // ---- Bonding / topology config ----------------------------------------

  /// Bonds a satellite (surround or Sub) into a home-theater [primaryHost].
  /// [htSatChanMapSet] e.g. `RINCON_BEAM:LF,RF;RINCON_SUB:SW`.
  Future<void> addHtSatellite(String primaryHost, String htSatChanMapSet) =>
      _soap
          .invoke(primaryHost, SonosService.deviceProperties, 'AddHTSatellite',
              arguments: {'HTSatChanMapSet': htSatChanMapSet})
          .then((_) {});

  /// Unbonds the satellite identified by [satRoomUuid] from [primaryHost].
  Future<void> removeHtSatellite(String primaryHost, String satRoomUuid) =>
      _soap
          .invoke(
              primaryHost, SonosService.deviceProperties, 'RemoveHTSatellite',
              arguments: {'SatRoomUUID': satRoomUuid})
          .then((_) {});

  /// Creates a stereo pair. [channelMapSet] e.g. `L_UUID:LF,LF;R_UUID:RF,RF`.
  Future<void> createStereoPair(String primaryHost, String channelMapSet) =>
      _soap
          .invoke(primaryHost, SonosService.deviceProperties, 'CreateStereoPair',
              arguments: {'ChannelMapSet': channelMapSet})
          .then((_) {});

  /// Splits a stereo pair back into two standalone players.
  Future<void> separateStereoPair(String primaryHost, String channelMapSet) =>
      _soap
          .invoke(primaryHost, SonosService.deviceProperties,
              'SeparateStereoPair',
              arguments: {'ChannelMapSet': channelMapSet})
          .then((_) {});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/sonos_api_config_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add test/support/fake_soap_client.dart lib/src/services/sonos_api.dart test/sonos_api_config_test.dart
git commit -m "Add bonding/topology config API methods + fake SOAP harness"
```

---

### Task 2: Room & device identity API methods

**Files:**
- Modify: `lib/src/services/sonos_api.dart` (new `// ---- Identity / device settings ----` section)
- Test: `test/sonos_api_config_test.dart` (add a group)

**Interfaces:**
- Consumes: `FakeSoapClient`, `soapResponse` (Task 1).
- Produces:
  - `Future<ZoneAttributes> getZoneAttributes(String host)` where
    `class ZoneAttributes { final String name; final String icon; final String configuration; final String targetRoomName; }`
  - `Future<void> renameRoom(String host, String newName)` (reads current attrs, preserves icon/config/target)
  - `Future<bool> getLedOn(String host)` / `Future<void> setLedOn(String host, bool on)`
  - `Future<bool> getButtonLock(String host)` / `Future<void> setButtonLock(String host, bool locked)`

- [ ] **Step 1: Write the failing test**

Add this group inside `main()` in `test/sonos_api_config_test.dart`:

```dart
  group('identity / device', () {
    test('getZoneAttributes parses all four fields', () async {
      soap = FakeSoapClient((action) => soapResponse(
          '<CurrentZoneName>TV Room</CurrentZoneName>'
          '<CurrentIcon>x-rincon-roomicon:tv</CurrentIcon>'
          '<CurrentConfiguration>1</CurrentConfiguration>'
          '<CurrentTargetRoomName></CurrentTargetRoomName>'));
      api = SonosApi(client: soap);
      final attrs = await api.getZoneAttributes('10.0.0.1');
      expect(attrs.name, 'TV Room');
      expect(attrs.icon, 'x-rincon-roomicon:tv');
      expect(attrs.configuration, '1');
    });

    test('renameRoom preserves icon/config while changing the name', () async {
      soap = FakeSoapClient((action) => action == 'GetZoneAttributes'
          ? soapResponse('<CurrentZoneName>Old</CurrentZoneName>'
              '<CurrentIcon>x-rincon-roomicon:tv</CurrentIcon>'
              '<CurrentConfiguration>1</CurrentConfiguration>'
              '<CurrentTargetRoomName></CurrentTargetRoomName>')
          : soapResponse(''));
      api = SonosApi(client: soap);
      await api.renameRoom('10.0.0.1', 'Living Room');
      final set = soap.calls.firstWhere((c) => c.action == 'SetZoneAttributes');
      expect(set.args['DesiredZoneName'], 'Living Room');
      expect(set.args['DesiredIcon'], 'x-rincon-roomicon:tv');
      expect(set.args['DesiredConfiguration'], '1');
    });

    test('getLedOn maps "On" to true', () async {
      soap = FakeSoapClient(
          (action) => soapResponse('<CurrentLEDState>On</CurrentLEDState>'));
      api = SonosApi(client: soap);
      expect(await api.getLedOn('10.0.0.1'), isTrue);
    });

    test('setLedOn sends On/Off', () async {
      await api.setLedOn('10.0.0.1', false);
      expect(soap.lastCall.action, 'SetLEDState');
      expect(soap.lastCall.args, {'DesiredLEDState': 'Off'});
    });

    test('setButtonLock sends On/Off', () async {
      await api.setButtonLock('10.0.0.1', true);
      expect(soap.lastCall.action, 'SetButtonLockState');
      expect(soap.lastCall.args, {'DesiredButtonLockState': 'On'});
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sonos_api_config_test.dart`
Expected: FAIL — `ZoneAttributes` / `getZoneAttributes` undefined.

- [ ] **Step 3: Write minimal implementation**

Add near the top of `lib/src/services/sonos_api.dart` (after the imports,
before `class SonosApi`):

```dart
/// Room attributes from `DeviceProperties.GetZoneAttributes`.
class ZoneAttributes {
  const ZoneAttributes({
    required this.name,
    required this.icon,
    required this.configuration,
    required this.targetRoomName,
  });

  final String name;
  final String icon;
  final String configuration;
  final String targetRoomName;
}
```

Add this section after the bonding methods from Task 1:

```dart
  // ---- Identity / device settings ---------------------------------------

  Future<ZoneAttributes> getZoneAttributes(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.deviceProperties, 'GetZoneAttributes');
    return ZoneAttributes(
      name: resp.arg('CurrentZoneName') ?? '',
      icon: resp.arg('CurrentIcon') ?? '',
      configuration: resp.arg('CurrentConfiguration') ?? '',
      targetRoomName: resp.arg('CurrentTargetRoomName') ?? '',
    );
  }

  /// Renames the room at [host]. `SetZoneAttributes` requires all fields, so we
  /// read the current icon/configuration/target and preserve them.
  Future<void> renameRoom(String host, String newName) async {
    final current = await getZoneAttributes(host);
    await _soap.invoke(
        host, SonosService.deviceProperties, 'SetZoneAttributes', arguments: {
      'DesiredZoneName': newName,
      'DesiredIcon': current.icon,
      'DesiredConfiguration': current.configuration,
      'DesiredTargetRoomName': current.targetRoomName,
    });
  }

  Future<bool> getLedOn(String host) async {
    final resp =
        await _soap.invoke(host, SonosService.deviceProperties, 'GetLEDState');
    return resp.arg('CurrentLEDState') == 'On';
  }

  Future<void> setLedOn(String host, bool on) => _soap
      .invoke(host, SonosService.deviceProperties, 'SetLEDState',
          arguments: {'DesiredLEDState': on ? 'On' : 'Off'})
      .then((_) {});

  Future<bool> getButtonLock(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.deviceProperties, 'GetButtonLockState');
    return resp.arg('CurrentButtonLockState') == 'On';
  }

  Future<void> setButtonLock(String host, bool locked) => _soap
      .invoke(host, SonosService.deviceProperties, 'SetButtonLockState',
          arguments: {'DesiredButtonLockState': locked ? 'On' : 'Off'})
      .then((_) {});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/sonos_api_config_test.dart`
Expected: PASS (Task 1 + 5 new = 9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/services/sonos_api.dart test/sonos_api_config_test.dart
git commit -m "Add room rename + LED + button-lock API methods"
```

---

### Task 3: Audio tuning API methods (bass/treble/loudness/EQ/balance)

**Files:**
- Modify: `lib/src/services/sonos_api.dart` (new `// ---- Audio tuning ----` section)
- Test: `test/sonos_api_config_test.dart` (add a group)

**Interfaces:**
- Consumes: `FakeSoapClient`, `soapResponse` (Task 1); `_instance`, `_masterChannel` (existing private consts on `SonosApi`).
- Produces:
  - `Future<int> getBass(String host)` / `Future<void> setBass(String host, int level)` (clamped −10..10)
  - `Future<int> getTreble(String host)` / `Future<void> setTreble(String host, int level)` (−10..10)
  - `Future<bool> getLoudness(String host)` / `Future<void> setLoudness(String host, bool on)`
  - `Future<int> getEq(String host, String eqType)` / `Future<void> setEq(String host, String eqType, int value)`
  - `Future<bool> getNightMode(String host)` / `Future<void> setNightMode(String host, bool on)`
  - `Future<bool> getSpeechEnhancement(String host)` / `Future<void> setSpeechEnhancement(String host, bool on)`
  - `Future<int> getBalance(String host)` (−100..100) / `Future<void> setBalance(String host, int balance)`

- [ ] **Step 1: Write the failing test**

Add this group inside `main()` in `test/sonos_api_config_test.dart`:

```dart
  group('audio tuning', () {
    test('setBass clamps to -10..10 and posts DesiredBass', () async {
      await api.setBass('10.0.0.1', 42);
      expect(soap.lastCall.action, 'SetBass');
      expect(soap.lastCall.args['DesiredBass'], '10');
    });

    test('getBass parses CurrentBass', () async {
      soap = FakeSoapClient(
          (action) => soapResponse('<CurrentBass>-4</CurrentBass>'));
      api = SonosApi(client: soap);
      expect(await api.getBass('10.0.0.1'), -4);
    });

    test('setLoudness sends 1/0 on the Master channel', () async {
      await api.setLoudness('10.0.0.1', true);
      expect(soap.lastCall.action, 'SetLoudness');
      expect(soap.lastCall.args['Channel'], 'Master');
      expect(soap.lastCall.args['DesiredLoudness'], '1');
    });

    test('setNightMode uses SetEQ with EQType NightMode', () async {
      await api.setNightMode('10.0.0.1', true);
      expect(soap.lastCall.action, 'SetEQ');
      expect(soap.lastCall.args['EQType'], 'NightMode');
      expect(soap.lastCall.args['DesiredValue'], '1');
    });

    test('getSpeechEnhancement reads DialogLevel EQ', () async {
      soap = FakeSoapClient(
          (action) => soapResponse('<CurrentValue>1</CurrentValue>'));
      api = SonosApi(client: soap);
      expect(await api.getSpeechEnhancement('10.0.0.1'), isTrue);
      expect(soap.lastCall.args['EQType'], 'DialogLevel');
    });

    test('setBalance maps -100 (full left) to LF=100, RF=0', () async {
      await api.setBalance('10.0.0.1', -100);
      final lf = soap.calls.firstWhere((c) => c.args['Channel'] == 'LF');
      final rf = soap.calls.firstWhere((c) => c.args['Channel'] == 'RF');
      expect(lf.args['DesiredVolume'], '100');
      expect(rf.args['DesiredVolume'], '0');
    });

    test('getBalance is right minus left', () async {
      soap = FakeSoapClient((action) => soapResponse(
          '<CurrentVolume>40</CurrentVolume>')); // both channels read 40
      api = SonosApi(client: soap);
      expect(await api.getBalance('10.0.0.1'), 0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sonos_api_config_test.dart`
Expected: FAIL — `setBass` undefined.

- [ ] **Step 3: Write minimal implementation**

Add this section after the identity methods from Task 2:

```dart
  // ---- Audio tuning ------------------------------------------------------

  Future<int> getBass(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetBass', arguments: _instance);
    return resp.argInt('CurrentBass') ?? 0;
  }

  Future<void> setBass(String host, int level) => _soap
      .invoke(host, SonosService.renderingControl, 'SetBass', arguments: {
        ..._instance,
        'DesiredBass': level.clamp(-10, 10).toString(),
      })
      .then((_) {});

  Future<int> getTreble(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetTreble', arguments: _instance);
    return resp.argInt('CurrentTreble') ?? 0;
  }

  Future<void> setTreble(String host, int level) => _soap
      .invoke(host, SonosService.renderingControl, 'SetTreble', arguments: {
        ..._instance,
        'DesiredTreble': level.clamp(-10, 10).toString(),
      })
      .then((_) {});

  Future<bool> getLoudness(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetLoudness',
        arguments: {..._instance, ..._masterChannel});
    return resp.arg('CurrentLoudness') == '1';
  }

  Future<void> setLoudness(String host, bool on) => _soap
      .invoke(host, SonosService.renderingControl, 'SetLoudness', arguments: {
        ..._instance,
        ..._masterChannel,
        'DesiredLoudness': on ? '1' : '0',
      })
      .then((_) {});

  Future<int> getEq(String host, String eqType) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetEQ',
        arguments: {..._instance, 'EQType': eqType});
    return resp.argInt('CurrentValue') ?? 0;
  }

  Future<void> setEq(String host, String eqType, int value) => _soap
      .invoke(host, SonosService.renderingControl, 'SetEQ', arguments: {
        ..._instance,
        'EQType': eqType,
        'DesiredValue': value.toString(),
      })
      .then((_) {});

  Future<bool> getNightMode(String host) async =>
      await getEq(host, 'NightMode') == 1;

  Future<void> setNightMode(String host, bool on) =>
      setEq(host, 'NightMode', on ? 1 : 0);

  Future<bool> getSpeechEnhancement(String host) async =>
      await getEq(host, 'DialogLevel') == 1;

  Future<void> setSpeechEnhancement(String host, bool on) =>
      setEq(host, 'DialogLevel', on ? 1 : 0);

  Future<int> _channelVolume(String host, String channel) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetVolume',
        arguments: {..._instance, 'Channel': channel});
    return resp.argInt('CurrentVolume') ?? 0;
  }

  Future<void> _setChannelVolume(String host, String channel, int vol) => _soap
      .invoke(host, SonosService.renderingControl, 'SetVolume', arguments: {
        ..._instance,
        'Channel': channel,
        'DesiredVolume': vol.clamp(0, 100).toString(),
      })
      .then((_) {});

  /// Balance as −100 (full left) .. 0 (centre) .. 100 (full right), realised by
  /// trimming the quieter of the LF/RF channels.
  Future<int> getBalance(String host) async {
    final left = await _channelVolume(host, 'LF');
    final right = await _channelVolume(host, 'RF');
    return right - left;
  }

  Future<void> setBalance(String host, int balance) async {
    final b = balance.clamp(-100, 100);
    final left = b > 0 ? 100 - b : 100;
    final right = b < 0 ? 100 + b : 100;
    await _setChannelVolume(host, 'LF', left);
    await _setChannelVolume(host, 'RF', right);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/sonos_api_config_test.dart`
Expected: PASS (16 tests total in the file).

- [ ] **Step 5: Run full suite + analyze**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests green.

- [ ] **Step 6: Commit**

```bash
git add lib/src/services/sonos_api.dart test/sonos_api_config_test.dart
git commit -m "Add audio tuning API: bass/treble/loudness/EQ/balance"
```

---

## Self-Review

**Spec coverage (Phase 2 slice):**
- Topology & bonding config (§ config scope) → Task 1 (`addHtSatellite`/`removeHtSatellite`/`createStereoPair`/`separateStereoPair`; `joinGroup`/`leaveGroup` already exist). ✓
- Room & device identity → Task 2 (`renameRoom`, LED, button lock). ✓
- Audio tuning → Task 3 (bass, treble, loudness, night mode, speech enhancement, balance). ✓
- SCPD-first rule (§7) → every method matches the captured signature block above. ✓
- Testing (§6) inject-fakes → `FakeSoapClient` records calls + returns canned XML; no hardware. ✓

**Placeholder scan:** none — full code, exact args, exact commands throughout.

**Type consistency:** `FakeSoapClient`/`SoapCall`/`soapResponse` (Task 1) reused verbatim in Tasks 2–3; `ZoneAttributes` fields (`name/icon/configuration/targetRoomName`) match between `getZoneAttributes` and `renameRoom`; `_instance`/`_masterChannel` are the existing `SonosApi` consts; EQType strings (`NightMode`, `DialogLevel`) consistent between setters/getters.

**Deferred:** `SetEQ` sub-gain / surround-level tuning and non-`Master` loudness are out of Phase 2 scope; `ConfigAction` wrapping of these methods is Phase 3.
