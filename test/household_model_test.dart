import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/models/group.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/models/room.dart';

const beam = Device(
    uuid: 'BEAM',
    roomName: 'TV Room',
    host: '10.0.0.1',
    bondRole: BondRole.coordinator,
    model: 'Sonos Beam');
const sub = Device(
    uuid: 'SUB',
    roomName: 'TV Room',
    host: '10.0.0.2',
    bondRole: BondRole.sub,
    invisible: true,
    model: 'Sonos Sub');
const orphanSub = Device(
    uuid: 'SUB2',
    roomName: 'Sub',
    host: '10.0.0.9',
    bondRole: BondRole.standalone,
    invisible: true);

const tvRoom = Room(name: 'TV Room', coordinator: beam, satellites: [sub]);
const orphan = Room(name: 'Sub', coordinator: orphanSub, satellites: []);

const household = Household(groups: [
  Group(id: 'G1', coordinatorUuid: 'BEAM', rooms: [tvRoom]),
  Group(id: 'G2', coordinatorUuid: 'SUB2', rooms: [orphan]),
]);

void main() {
  test('Room.devices is coordinator followed by satellites', () {
    expect(tvRoom.devices.map((d) => d.uuid), ['BEAM', 'SUB']);
  });

  test('Household flattens rooms and devices', () {
    expect(household.rooms.length, 2);
    expect(household.devices.map((d) => d.uuid), ['BEAM', 'SUB', 'SUB2']);
    expect(household.deviceByUuid('SUB')!.host, '10.0.0.2');
    expect(household.deviceByUuid('NOPE'), isNull);
  });

  test('visibleRooms hides invisible-only rooms; orphan device surfaced', () {
    expect(household.visibleRooms.map((r) => r.name), ['TV Room']);
    expect(household.unbondedInvisibleDevices.map((d) => d.uuid), ['SUB2']);
  });

  test('Group.isBonded is false for a single-room group', () {
    expect(
        const Group(id: 'G1', coordinatorUuid: 'BEAM', rooms: [tvRoom])
            .isBonded,
        isFalse);
  });
}
