import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/actions/rename_action.dart';
import 'package:personal_sonos/src/actions/topology_actions.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/models/group.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/models/room.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'support/fake_soap_client.dart';

Household _tvRoom({required BondRole subRole}) => Household(groups: [
      Group(id: 'g', coordinatorUuid: 'BEAM', rooms: [
        Room(
          name: 'TV Room',
          coordinator: const Device(
              uuid: 'BEAM',
              roomName: 'TV Room',
              host: '10.0.0.1',
              bondRole: BondRole.coordinator),
          satellites: [
            Device(
                uuid: 'SUB',
                roomName: 'TV Room',
                host: '10.0.0.2',
                invisible: true,
                bondRole: subRole),
          ],
        ),
      ]),
    ]);

Household _twoRooms(List<String> visibleUuids) => Household(groups: [
      for (final u in visibleUuids)
        Group(id: u, coordinatorUuid: u, rooms: [
          Room(
              name: u,
              coordinator: Device(
                  uuid: u,
                  roomName: u,
                  host: '10.0.0.9',
                  bondRole: BondRole.standalone),
              satellites: const []),
        ]),
    ]);

void main() {
  group('BondSubAction', () {
    final action = BondSubAction(
        primaryHost: '10.0.0.1',
        primaryUuid: 'BEAM',
        subUuid: 'SUB',
        roomName: 'TV Room');

    test('apply posts the SW channel map', () async {
      final soap = FakeSoapClient();
      await action.apply(SonosApi(client: soap));
      expect(soap.lastCall.action, 'AddHTSatellite');
      expect(soap.lastCall.args['HTSatChanMapSet'], 'BEAM:LF,RF;SUB:SW');
    });

    test('isSettled true only once the Sub reports a sub role', () {
      expect(action.isSettled(_tvRoom(subRole: BondRole.sub)), isTrue);
      expect(action.isSettled(_tvRoom(subRole: BondRole.standalone)), isFalse);
    });

    test('inverse is an UnbondSubAction for the same Sub', () {
      final inv = action.inverse(_tvRoom(subRole: BondRole.sub));
      expect(inv, isA<UnbondSubAction>());
      expect((inv as UnbondSubAction).subUuid, 'SUB');
    });
  });

  group('UnbondSubAction', () {
    final action = UnbondSubAction(
        primaryHost: '10.0.0.1',
        primaryUuid: 'BEAM',
        subUuid: 'SUB',
        roomName: 'TV Room');

    test('apply removes the satellite by UUID', () async {
      final soap = FakeSoapClient();
      await action.apply(SonosApi(client: soap));
      expect(soap.lastCall.action, 'RemoveHTSatellite');
      expect(soap.lastCall.args['SatRoomUUID'], 'SUB');
    });

    test('isSettled true when the Sub is no longer a sub', () {
      expect(action.isSettled(_tvRoom(subRole: BondRole.standalone)), isTrue);
      expect(action.isSettled(_tvRoom(subRole: BondRole.sub)), isFalse);
    });
  });

  group('CreateStereoPairAction', () {
    final action = CreateStereoPairAction(
        leftHost: '10.0.0.1',
        leftUuid: 'L',
        rightUuid: 'R',
        leftName: 'Left',
        rightName: 'Right');

    test('apply posts the LF/RF channel map', () async {
      final soap = FakeSoapClient();
      await action.apply(SonosApi(client: soap));
      expect(soap.lastCall.action, 'CreateStereoPair');
      expect(soap.lastCall.args['ChannelMapSet'], 'L:LF,LF;R:RF,RF');
    });

    test('isSettled when the right speaker is no longer its own room', () {
      expect(action.isSettled(_twoRooms(['L'])), isTrue);
      expect(action.isSettled(_twoRooms(['L', 'R'])), isFalse);
    });
  });

  group('RenameRoomAction', () {
    final action = RenameRoomAction(
        host: '10.0.0.1',
        uuid: 'BEAM',
        currentName: 'TV Room',
        newName: 'Lounge');

    test('apply reads current attrs then sets the new name', () async {
      final soap = FakeSoapClient((a) => soapResponse(
          '<CurrentZoneName>TV Room</CurrentZoneName><CurrentIcon>i</CurrentIcon>'
          '<CurrentConfiguration>1</CurrentConfiguration><CurrentTargetRoomName></CurrentTargetRoomName>'));
      await action.apply(SonosApi(client: soap));
      final set = soap.calls.firstWhere((c) => c.action == 'SetZoneAttributes');
      expect(set.args['DesiredZoneName'], 'Lounge');
      expect(set.args['DesiredIcon'], 'i');
    });

    test('isSettled when the room reports the new name', () {
      const renamed = Household(groups: [
        Group(id: 'g', coordinatorUuid: 'BEAM', rooms: [
          Room(
              name: 'Lounge',
              coordinator: Device(
                  uuid: 'BEAM',
                  roomName: 'Lounge',
                  host: '10.0.0.1',
                  bondRole: BondRole.standalone),
              satellites: []),
        ]),
      ]);
      expect(action.isSettled(renamed), isTrue);
      expect(action.isSettled(_tvRoom(subRole: BondRole.sub)), isFalse);
    });
  });
}
