# Sonos Config Tool — Phase 1: Domain Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the immutable domain model (`Device` / `Room` / `Group` / `Household`) and the pure `parseHousehold` function that turns real `GetZoneGroupState` XML into that model, with capability derivation — all offline and fully tested.

**Architecture:** Pure Dart models + one parser function, no I/O, no Flutter widgets. New files only — the existing playback app keeps building. This is the read-only-map foundation the later phases (API, actions, stores, UI) build on. See spec: `docs/superpowers/specs/2026-07-04-sonos-config-tool-design.md`.

**Tech Stack:** Dart, `package:xml` (already a dependency), `flutter_test`.

## Global Constraints

- Dart SDK `>=3.4.0 <4.0.0`, Flutter `>=3.22.0` (from `pubspec.yaml`) — verbatim.
- No new package dependencies (YAGNI; `xml` is already present).
- `flutter analyze` must stay clean; `flutter test` must stay green.
- `InstanceID` is always `0`, volume channel is always `Master` (project convention) — not used in this phase but holds project-wide.
- Immutable models: all fields `final`, `const` constructors, value equality by identity fields.
- Files live under `lib/src/models/` and `lib/src/services/`; tests under `test/`.

---

### Task 1: BondRole enum + Capabilities derivation

**Files:**
- Create: `lib/src/models/bond_role.dart`
- Create: `lib/src/models/capabilities.dart`
- Test: `test/capabilities_test.dart`

**Interfaces:**
- Produces: `enum BondRole { standalone, coordinator, sub, surroundLeft, surroundRight, stereoLeft, stereoRight }`
- Produces: `class Capabilities` with bool fields `canBondSub, canAddSurrounds, canStereoPair, hasBassTreble, hasLoudness, hasNightMode, hasLed, hasButtonLock`, and `factory Capabilities.forModel(String? model, BondRole role)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/capabilities_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/capabilities.dart';

void main() {
  group('Capabilities.forModel', () {
    test('Sonos Beam is a home-theater primary', () {
      final c = Capabilities.forModel('Sonos Beam', BondRole.coordinator);
      expect(c.canBondSub, isTrue);
      expect(c.canAddSurrounds, isTrue);
      expect(c.hasNightMode, isTrue);
      expect(c.canStereoPair, isFalse);
      expect(c.hasBassTreble, isTrue);
      expect(c.hasLed, isTrue);
    });

    test('Sonos One SL is a stereo-pairable standard speaker', () {
      final c = Capabilities.forModel('Sonos One SL', BondRole.surroundLeft);
      expect(c.canStereoPair, isTrue);
      expect(c.canBondSub, isFalse);
      expect(c.hasNightMode, isFalse);
      expect(c.hasBassTreble, isTrue);
      expect(c.hasLoudness, isTrue);
    });

    test('Sonos Sub has no speaker EQ but has an LED', () {
      final c = Capabilities.forModel('Sonos Sub', BondRole.sub);
      expect(c.hasBassTreble, isFalse);
      expect(c.hasLoudness, isFalse);
      expect(c.canStereoPair, isFalse);
      expect(c.canBondSub, isFalse);
      expect(c.hasLed, isTrue);
      expect(c.hasButtonLock, isTrue);
    });

    test('unknown model is conservative but keeps LED/button controls', () {
      final c = Capabilities.forModel(null, BondRole.standalone);
      expect(c.canBondSub, isFalse);
      expect(c.canStereoPair, isFalse);
      expect(c.hasBassTreble, isFalse);
      expect(c.hasLed, isTrue);
      expect(c.hasButtonLock, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/capabilities_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:personal_sonos/src/models/capabilities.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/models/bond_role.dart

/// How a device currently sits in the topology.
///
/// [standalone] = not bonded (a lone speaker, visible or an unbonded Sub).
/// [coordinator] = a room's primary that has bonded satellites.
/// The remaining roles describe a currently-bonded satellite's channel.
enum BondRole {
  standalone,
  coordinator,
  sub,
  surroundLeft,
  surroundRight,
  stereoLeft,
  stereoRight,
}
```

```dart
// lib/src/models/capabilities.dart
import 'bond_role.dart';

/// What a device supports, derived from its model and current [BondRole].
///
/// The UI enables actions off these flags instead of hard-coding model names.
class Capabilities {
  const Capabilities({
    required this.canBondSub,
    required this.canAddSurrounds,
    required this.canStereoPair,
    required this.hasBassTreble,
    required this.hasLoudness,
    required this.hasNightMode,
    required this.hasLed,
    required this.hasButtonLock,
  });

  final bool canBondSub;
  final bool canAddSurrounds;
  final bool canStereoPair;
  final bool hasBassTreble;
  final bool hasLoudness;
  final bool hasNightMode;
  final bool hasLed;
  final bool hasButtonLock;

  /// Derives capabilities from a Sonos [model] string (e.g. `Sonos Beam`) and
  /// the device's [role]. [model] may be null before device enrichment, in
  /// which case only the universally-safe controls (LED, button lock) are on.
  factory Capabilities.forModel(String? model, BondRole role) {
    final m = (model ?? '').toLowerCase();
    final known = m.isNotEmpty;
    const htNeedles = ['beam', 'arc', 'ray', 'playbar', 'playbase', 'amp'];
    final isHomeTheater = htNeedles.any(m.contains);
    final isSub = m.contains('sub');
    final isStandardSpeaker = known && !isSub && !isHomeTheater;

    return Capabilities(
      canBondSub: isHomeTheater,
      canAddSurrounds: isHomeTheater,
      canStereoPair: isStandardSpeaker,
      hasBassTreble: known && !isSub,
      hasLoudness: known && !isSub,
      hasNightMode: isHomeTheater,
      hasLed: true,
      hasButtonLock: true,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/capabilities_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/models/bond_role.dart lib/src/models/capabilities.dart test/capabilities_test.dart
git commit -m "Add BondRole + model-derived Capabilities"
```

---

### Task 2: Device model

**Files:**
- Create: `lib/src/models/device.dart`
- Test: `test/device_test.dart`

**Interfaces:**
- Consumes: `BondRole` (Task 1), `Capabilities` (Task 1).
- Produces: `class Device` with fields `uuid, roomName, host, model, firmware, invisible, bondRole`; getter `Capabilities get capabilities`; `Device copyWith({...})`; value equality on `uuid` + `host`.

- [ ] **Step 1: Write the failing test**

```dart
// test/device_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';

void main() {
  group('Device', () {
    const beam = Device(
      uuid: 'RINCON_BEAM',
      roomName: 'TV Room',
      host: '192.168.50.185',
      model: 'Sonos Beam',
      firmware: '95.1-78010',
      bondRole: BondRole.coordinator,
    );

    test('capabilities are derived from model + role', () {
      expect(beam.capabilities.canBondSub, isTrue);
      expect(beam.capabilities.canStereoPair, isFalse);
    });

    test('copyWith updates model and re-derives capabilities', () {
      final asSub = beam.copyWith(model: 'Sonos Sub', bondRole: BondRole.sub);
      expect(asSub.capabilities.hasBassTreble, isFalse);
      expect(asSub.uuid, 'RINCON_BEAM'); // uuid is immutable identity
    });

    test('equality is by uuid + host', () {
      expect(beam, const Device(
        uuid: 'RINCON_BEAM', roomName: 'X', host: '192.168.50.185',
        bondRole: BondRole.standalone,
      ));
      expect(beam == beam.copyWith(host: '10.0.0.1'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/device_test.dart`
Expected: FAIL — `device.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/models/device.dart
import 'bond_role.dart';
import 'capabilities.dart';

/// One physical Sonos player.
class Device {
  const Device({
    required this.uuid,
    required this.roomName,
    required this.host,
    required this.bondRole,
    this.model,
    this.firmware,
    this.invisible = false,
  });

  final String uuid;
  final String roomName;
  final String host;

  /// Model name from `device_description.xml` (e.g. `Sonos Beam`). Null until
  /// the device is enriched with its description (a later phase).
  final String? model;

  /// Firmware version (`SoftwareVersion` from topology), e.g. `95.1-78010`.
  final String? firmware;

  /// True for bonded satellites and invisible bridges — not shown on their own
  /// as a room, but still a real, possibly-actionable device.
  final bool invisible;

  final BondRole bondRole;

  /// Derived on read so it tracks [model]/[bondRole] through [copyWith].
  Capabilities get capabilities => Capabilities.forModel(model, bondRole);

  Device copyWith({
    String? roomName,
    String? host,
    String? model,
    String? firmware,
    bool? invisible,
    BondRole? bondRole,
  }) {
    return Device(
      uuid: uuid,
      roomName: roomName ?? this.roomName,
      host: host ?? this.host,
      model: model ?? this.model,
      firmware: firmware ?? this.firmware,
      invisible: invisible ?? this.invisible,
      bondRole: bondRole ?? this.bondRole,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Device && other.uuid == uuid && other.host == host;

  @override
  int get hashCode => Object.hash(uuid, host);

  @override
  String toString() => 'Device($roomName/${bondRole.name} @ $host)';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/device_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/models/device.dart test/device_test.dart
git commit -m "Add Device model with derived capabilities"
```

---

### Task 3: Room, Group, and Household models

**Files:**
- Create: `lib/src/models/room.dart`
- Create: `lib/src/models/group.dart`
- Create: `lib/src/models/household.dart`
- Test: `test/household_model_test.dart`

**Interfaces:**
- Consumes: `Device` (Task 2), `BondRole` (Task 1).
- Produces:
  - `class Room { String name; Device coordinator; List<Device> satellites; List<Device> get devices; }`
  - `class Group { String id; String coordinatorUuid; List<Room> rooms; bool get isBonded; }`
  - `class Household { List<Group> groups; List<Room> get rooms; List<Device> get devices; List<Room> get visibleRooms; List<Device> get unbondedInvisibleDevices; Device? deviceByUuid(String); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/household_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/models/group.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/models/room.dart';

void main() {
  const beam = Device(uuid: 'BEAM', roomName: 'TV Room', host: '10.0.0.1',
      bondRole: BondRole.coordinator, model: 'Sonos Beam');
  const sub = Device(uuid: 'SUB', roomName: 'TV Room', host: '10.0.0.2',
      bondRole: BondRole.sub, invisible: true, model: 'Sonos Sub');
  const orphanSub = Device(uuid: 'SUB2', roomName: 'Sub', host: '10.0.0.9',
      bondRole: BondRole.standalone, invisible: true);

  final tvRoom = Room(name: 'TV Room', coordinator: beam, satellites: const [sub]);
  final orphan = Room(name: 'Sub', coordinator: orphanSub, satellites: const []);

  test('Room.devices is coordinator followed by satellites', () {
    expect(tvRoom.devices.map((d) => d.uuid), ['BEAM', 'SUB']);
  });

  test('Household flattens rooms and devices', () {
    final h = Household(groups: [
      Group(id: 'G1', coordinatorUuid: 'BEAM', rooms: [tvRoom]),
      Group(id: 'G2', coordinatorUuid: 'SUB2', rooms: [orphan]),
    ]);
    expect(h.rooms.length, 2);
    expect(h.devices.map((d) => d.uuid), ['BEAM', 'SUB', 'SUB2']);
    expect(h.deviceByUuid('SUB')!.host, '10.0.0.2');
    expect(h.deviceByUuid('NOPE'), isNull);
  });

  test('visibleRooms hides invisible-only rooms; orphan device surfaced', () {
    final h = Household(groups: [
      Group(id: 'G1', coordinatorUuid: 'BEAM', rooms: [tvRoom]),
      Group(id: 'G2', coordinatorUuid: 'SUB2', rooms: [orphan]),
    ]);
    expect(h.visibleRooms.map((r) => r.name), ['TV Room']);
    expect(h.unbondedInvisibleDevices.map((d) => d.uuid), ['SUB2']);
  });

  test('Group.isBonded is false for a single-room group', () {
    expect(Group(id: 'G1', coordinatorUuid: 'BEAM', rooms: [tvRoom]).isBonded,
        isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/household_model_test.dart`
Expected: FAIL — `room.dart` / `group.dart` / `household.dart` do not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/models/room.dart
import 'device.dart';

/// A coordinator device plus its bonded satellites (sub / surrounds), shown as
/// one configurable unit.
class Room {
  const Room({
    required this.name,
    required this.coordinator,
    required this.satellites,
  });

  final String name;
  final Device coordinator;
  final List<Device> satellites;

  /// Coordinator first, then bonded satellites.
  List<Device> get devices => [coordinator, ...satellites];
}
```

```dart
// lib/src/models/group.dart
import 'room.dart';

/// A party-mode set of rooms playing in sync (`x-rincon:` joins). Distinct from
/// bonding: bonded devices live inside a single [Room].
class Group {
  const Group({
    required this.id,
    required this.coordinatorUuid,
    required this.rooms,
  });

  final String id;
  final String coordinatorUuid;
  final List<Room> rooms;

  /// True when more than one room plays in sync in this group.
  bool get isBonded => rooms.length > 1;
}
```

```dart
// lib/src/models/household.dart
import 'bond_role.dart';
import 'device.dart';
import 'group.dart';
import 'room.dart';

/// An immutable snapshot of the whole Sonos system at one poll.
class Household {
  const Household({required this.groups});

  final List<Group> groups;

  List<Room> get rooms => [for (final g in groups) ...g.rooms];

  List<Device> get devices => [for (final r in rooms) ...r.devices];

  /// Rooms a user can meaningfully select — those with a visible coordinator.
  List<Room> get visibleRooms =>
      rooms.where((r) => !r.coordinator.invisible).toList();

  /// Invisible, unbonded devices (a lone Sub or bridge) — surfaced separately so
  /// the config UI can offer to bond them, rather than hiding them.
  List<Device> get unbondedInvisibleDevices => devices
      .where((d) => d.invisible && d.bondRole == BondRole.standalone)
      .toList();

  Device? deviceByUuid(String uuid) {
    for (final d in devices) {
      if (d.uuid == uuid) return d;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/household_model_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/models/room.dart lib/src/models/group.dart lib/src/models/household.dart test/household_model_test.dart
git commit -m "Add Room, Group, and Household snapshot models"
```

---

### Task 4: `parseHousehold` — real topology XML → Household

**Files:**
- Create: `lib/src/services/household_parser.dart`
- Test: `test/household_parser_test.dart`

**Interfaces:**
- Consumes: all models from Tasks 1–3.
- Produces: `Household parseHousehold(String zoneGroupStateXml)`.

This uses `findElements` (direct children) so that `<Satellite>` nodes are read as satellites of their member, not as members — and bonded-satellite channels come from the primary member's `HTSatChanMapSet`. Fixtures are real 2026 captures from the user's Beam.

- [ ] **Step 1: Write the failing test**

```dart
// test/household_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/services/household_parser.dart';

void main() {
  // Real capture: Beam home theater with the Sub bonded (SW) and two One SL
  // surrounds (LR/RR) as <Satellite> children of the Beam.
  const bondedHt = '''
<ZoneGroupState><ZoneGroups>
  <ZoneGroup Coordinator="RINCON_BEAM" ID="RINCON_BEAM:287">
    <ZoneGroupMember UUID="RINCON_BEAM" ZoneName="TV Room" SoftwareVersion="95.1-78010"
      Location="http://192.168.50.185:1400/xml/device_description.xml"
      HTSatChanMapSet="RINCON_BEAM:LF,RF;RINCON_LR:LR;RINCON_RR:RR;RINCON_SUB:SW">
      <Satellite UUID="RINCON_LR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.50.52:1400/xml/device_description.xml"/>
      <Satellite UUID="RINCON_RR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.50.34:1400/xml/device_description.xml"/>
      <Satellite UUID="RINCON_SUB" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.50.18:1400/xml/device_description.xml"/>
    </ZoneGroupMember>
  </ZoneGroup>
</ZoneGroups></ZoneGroupState>''';

  // Real capture: same household BEFORE bonding — Sub floats in its own
  // invisible group; Beam has only the two surrounds.
  const unbondedSub = '''
<ZoneGroupState><ZoneGroups>
  <ZoneGroup Coordinator="RINCON_SUB" ID="RINCON_SUB:208">
    <ZoneGroupMember UUID="RINCON_SUB" ZoneName="Sub" Invisible="1" SoftwareVersion="86.7-77050"
      Location="http://192.168.50.18:1400/xml/device_description.xml"/>
  </ZoneGroup>
  <ZoneGroup Coordinator="RINCON_BEAM" ID="RINCON_BEAM:287">
    <ZoneGroupMember UUID="RINCON_BEAM" ZoneName="TV Room" SoftwareVersion="95.1-78010"
      Location="http://192.168.50.185:1400/xml/device_description.xml"
      HTSatChanMapSet="RINCON_BEAM:LF,RF;RINCON_LR:LR;RINCON_RR:RR">
      <Satellite UUID="RINCON_LR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.50.52:1400/xml/device_description.xml"/>
      <Satellite UUID="RINCON_RR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.50.34:1400/xml/device_description.xml"/>
    </ZoneGroupMember>
  </ZoneGroup>
</ZoneGroups></ZoneGroupState>''';

  // Two standalone rooms grouped in party mode (synthetic).
  const partyGroup = '''
<ZoneGroupState><ZoneGroups>
  <ZoneGroup Coordinator="RINCON_KIT" ID="RINCON_KIT:5">
    <ZoneGroupMember UUID="RINCON_KIT" ZoneName="Kitchen"
      Location="http://10.0.0.5:1400/x"/>
    <ZoneGroupMember UUID="RINCON_DEN" ZoneName="Den"
      Location="http://10.0.0.6:1400/x"/>
  </ZoneGroup>
</ZoneGroups></ZoneGroupState>''';

  test('bonded home theater: one room, three bonded satellites with roles', () {
    final h = parseHousehold(bondedHt);
    expect(h.visibleRooms.length, 1);
    final tv = h.visibleRooms.single;
    expect(tv.name, 'TV Room');
    expect(tv.coordinator.uuid, 'RINCON_BEAM');
    expect(tv.coordinator.bondRole, BondRole.coordinator);
    expect(tv.coordinator.host, '192.168.50.185');
    expect(tv.coordinator.firmware, '95.1-78010');

    final roles = {for (final s in tv.satellites) s.uuid: s.bondRole};
    expect(roles['RINCON_SUB'], BondRole.sub);
    expect(roles['RINCON_LR'], BondRole.surroundLeft);
    expect(roles['RINCON_RR'], BondRole.surroundRight);
    expect(tv.satellites.every((s) => s.invisible), isTrue);
  });

  test('unbonded Sub is a standalone invisible device, not a room', () {
    final h = parseHousehold(unbondedSub);
    expect(h.visibleRooms.map((r) => r.name), ['TV Room']);
    final orphans = h.unbondedInvisibleDevices;
    expect(orphans.map((d) => d.uuid), ['RINCON_SUB']);
    expect(orphans.single.bondRole, BondRole.standalone);
    // The Beam still has exactly the two surrounds, no Sub.
    final tv = h.visibleRooms.single;
    expect(tv.satellites.map((d) => d.bondRole).toSet(),
        {BondRole.surroundLeft, BondRole.surroundRight});
  });

  test('party group: one group with two visible rooms', () {
    final h = parseHousehold(partyGroup);
    expect(h.groups.single.isBonded, isTrue);
    expect(h.visibleRooms.map((r) => r.name).toSet(), {'Kitchen', 'Den'});
    expect(h.groups.single.rooms.every((r) => r.satellites.isEmpty), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/household_parser_test.dart`
Expected: FAIL — `household_parser.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/services/household_parser.dart
import 'package:xml/xml.dart';

import '../models/bond_role.dart';
import '../models/device.dart';
import '../models/group.dart';
import '../models/household.dart';
import '../models/room.dart';

/// Parses `ZoneGroupTopology.GetZoneGroupState` XML into an immutable
/// [Household]. Pure — no I/O. Model names are not in this payload; they are
/// filled in later by device enrichment, so [Device.model] is null here.
Household parseHousehold(String zoneGroupStateXml) {
  final doc = XmlDocument.parse(zoneGroupStateXml);
  final groups = <Group>[];

  for (final groupEl in doc.findAllElements('ZoneGroup')) {
    final coordUuid = groupEl.getAttribute('Coordinator') ?? '';
    final groupId = groupEl.getAttribute('ID') ?? coordUuid;

    final rooms = <Room>[];
    // Direct children only: each ZoneGroupMember is a room's primary device.
    for (final memberEl in groupEl.findElements('ZoneGroupMember')) {
      final primary = _deviceFromElement(memberEl, BondRole.standalone);
      if (primary == null) continue;

      final chanMap = memberEl.getAttribute('HTSatChanMapSet');
      final satellites = <Device>[];
      for (final satEl in memberEl.findElements('Satellite')) {
        final channels = _channelsFor(chanMap, satEl.getAttribute('UUID'));
        final sat = _deviceFromElement(satEl, _roleFromChannels(channels));
        if (sat != null) satellites.add(sat);
      }

      final role =
          satellites.isEmpty ? BondRole.standalone : BondRole.coordinator;
      rooms.add(Room(
        name: primary.roomName,
        coordinator: primary.copyWith(bondRole: role),
        satellites: satellites,
      ));
    }

    if (rooms.isEmpty) continue;
    groups.add(Group(id: groupId, coordinatorUuid: coordUuid, rooms: rooms));
  }

  return Household(groups: groups);
}

Device? _deviceFromElement(XmlElement el, BondRole role) {
  final uuid = el.getAttribute('UUID');
  final name = el.getAttribute('ZoneName');
  final location = el.getAttribute('Location');
  if (uuid == null || name == null || location == null) return null;
  final host = Uri.tryParse(location)?.host;
  if (host == null || host.isEmpty) return null;

  return Device(
    uuid: uuid,
    roomName: name,
    host: host,
    firmware: el.getAttribute('SoftwareVersion'),
    invisible: el.getAttribute('Invisible') == '1' ||
        el.getAttribute('IsZoneBridge') == '1',
    bondRole: role,
  );
}

/// Looks up the channel spec for [uuid] inside a primary's `HTSatChanMapSet`,
/// e.g. `RINCON_BEAM:LF,RF;RINCON_SUB:SW` -> `SW` for `RINCON_SUB`.
String? _channelsFor(String? chanMap, String? uuid) {
  if (chanMap == null || uuid == null) return null;
  for (final part in chanMap.split(';')) {
    final idx = part.indexOf(':');
    if (idx > 0 && part.substring(0, idx) == uuid) {
      return part.substring(idx + 1);
    }
  }
  return null;
}

BondRole _roleFromChannels(String? channels) {
  final c = (channels ?? '').toUpperCase();
  if (c.contains('SW')) return BondRole.sub;
  if (c.contains('LR')) return BondRole.surroundLeft;
  if (c.contains('RR')) return BondRole.surroundRight;
  if (c.contains('LF')) return BondRole.stereoLeft;
  if (c.contains('RF')) return BondRole.stereoRight;
  return BondRole.standalone;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/household_parser_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run the full suite + analyze**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests (existing playback tests + the 4 new files) green.

- [ ] **Step 6: Commit**

```bash
git add lib/src/services/household_parser.dart test/household_parser_test.dart
git commit -m "Add parseHousehold: topology XML to Household snapshot"
```

---

## Self-Review

**Spec coverage (Phase 1 slice):**
- Domain model §2 (Device/Room/Group + derived Capabilities) → Tasks 1–3. ✓
- Room-vs-Group-vs-Device distinction → Tasks 2–4 (`Group.rooms`, `Room.satellites`, `Household.visibleRooms`). ✓
- Capability derivation §2 → Task 1. ✓
- Household parsed from `GetZoneGroupState` §2 → Task 4. ✓
- Config-tool nuance: unbonded Sub surfaced (not hidden as in the old playback app) → Task 3 `unbondedInvisibleDevices`, Task 4 test. ✓
- Testing §6 (household parser + capability derivation with real fixtures, phantom-Sub-as-standalone) → Tasks 1 & 4. ✓
- Deferred to later phases (correctly out of Phase 1 scope): SOAP config/EQ methods (P2), `ConfigAction`/executor (P3), stores + device enrichment for `model` (P4), UI + playback removal (P5). Stereo-pair topology parsing needs a real captured fixture before asserting; `_roleFromChannels` handles LF/RF generically but is not asserted here — tracked for P2/P3 when a pair can be created via the tool.

**Placeholder scan:** none — every step has full code, real fixtures, and exact commands.

**Type consistency:** `BondRole` variants, `Capabilities.forModel(String?, BondRole)`, `Device.copyWith`, `Room.devices`, `Group.isBonded`, `Household.{rooms,devices,visibleRooms,unbondedInvisibleDevices,deviceByUuid}`, and `parseHousehold(String)` are used consistently across tasks and match the Interfaces blocks.
