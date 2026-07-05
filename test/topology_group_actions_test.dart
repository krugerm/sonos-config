import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/actions/group_actions.dart';
import 'package:personal_sonos/src/actions/topology_actions.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/models/group.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/models/room.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'support/fake_soap_client.dart';

Room _room(String uuid, String name, {List<Device> sats = const []}) => Room(
      name: name,
      coordinator: Device(
          uuid: uuid,
          roomName: name,
          host: '10.0.0.1',
          bondRole: BondRole.coordinator),
      satellites: sats,
    );

void main() {
  group('JoinGroupAction', () {
    final action = JoinGroupAction(
        memberHost: '10.0.0.2',
        memberUuid: 'KIT',
        memberRoomName: 'Kitchen',
        coordinatorUuid: 'TV',
        targetRoomName: 'TV Room');

    test('apply sends x-rincon to the coordinator', () async {
      final soap = FakeSoapClient();
      await action.apply(SonosApi(client: soap));
      expect(soap.lastCall.action, 'SetAVTransportURI');
      expect(soap.lastCall.args['CurrentURI'], 'x-rincon:TV');
    });

    test('isSettled when both rooms share a group', () {
      final grouped = Household(groups: [
        Group(id: 'g', coordinatorUuid: 'TV', rooms: [
          _room('TV', 'TV Room'),
          _room('KIT', 'Kitchen'),
        ]),
      ]);
      final separate = Household(groups: [
        Group(id: 'a', coordinatorUuid: 'TV', rooms: [_room('TV', 'TV Room')]),
        Group(
            id: 'b', coordinatorUuid: 'KIT', rooms: [_room('KIT', 'Kitchen')]),
      ]);
      expect(action.isSettled(grouped), isTrue);
      expect(action.isSettled(separate), isFalse);
    });

    test('inverse ungroups the member', () {
      expect(
          action.inverse(const Household(groups: [])), isA<LeaveGroupAction>());
    });
  });

  group('LeaveGroupAction', () {
    final action = LeaveGroupAction(
        memberHost: '10.0.0.2',
        memberUuid: 'KIT',
        memberRoomName: 'Kitchen',
        priorCoordinatorUuid: 'TV',
        priorTargetName: 'TV Room');

    test('apply becomes standalone coordinator', () async {
      final soap = FakeSoapClient();
      await action.apply(SonosApi(client: soap));
      expect(soap.lastCall.action, 'BecomeCoordinatorOfStandaloneGroup');
    });

    test('isSettled when the member is its own single-room group', () {
      final solo = Household(groups: [
        Group(
            id: 'b', coordinatorUuid: 'KIT', rooms: [_room('KIT', 'Kitchen')]),
      ]);
      expect(action.isSettled(solo), isTrue);
    });

    test('reversible only when a prior coordinator is known', () {
      expect(action.isReversible, isTrue);
      final noPrior = LeaveGroupAction(
          memberHost: 'h', memberUuid: 'X', memberRoomName: 'X');
      expect(noPrior.isReversible, isFalse);
      expect(noPrior.inverse(const Household(groups: [])), isNull);
    });
  });

  group('Add/RemoveSurroundAction', () {
    final add = AddSurroundAction(
        primaryHost: '10.0.0.1',
        primaryUuid: 'BEAM',
        satUuid: 'ONE',
        channel: 'LR',
        roomName: 'TV Room',
        satName: 'One SL');

    Household withRole(BondRole role) => Household(groups: [
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
                    uuid: 'ONE',
                    roomName: 'TV Room',
                    host: '10.0.0.2',
                    invisible: true,
                    bondRole: role),
              ],
            ),
          ]),
        ]);

    test('add posts the LR channel map', () async {
      final soap = FakeSoapClient();
      await add.apply(SonosApi(client: soap));
      expect(soap.lastCall.action, 'AddHTSatellite');
      expect(soap.lastCall.args['HTSatChanMapSet'], 'BEAM:LF,RF;ONE:LR');
    });

    test('add isSettled once the speaker is a surround', () {
      expect(add.isSettled(withRole(BondRole.surroundLeft)), isTrue);
      expect(add.isSettled(withRole(BondRole.standalone)), isFalse);
    });

    test('remove undoes add and vice versa', () {
      expect(add.inverse(withRole(BondRole.surroundLeft)),
          isA<RemoveSurroundAction>());
      final remove = add.inverse(withRole(BondRole.surroundLeft));
      expect(remove.inverse(withRole(BondRole.standalone)),
          isA<AddSurroundAction>());
    });

    test('remove posts RemoveHTSatellite and settles when not a surround',
        () async {
      final remove = RemoveSurroundAction(
          primaryHost: '10.0.0.1',
          primaryUuid: 'BEAM',
          satUuid: 'ONE',
          channel: 'LR',
          roomName: 'TV Room',
          satName: 'One SL');
      final soap = FakeSoapClient();
      await remove.apply(SonosApi(client: soap));
      expect(soap.lastCall.action, 'RemoveHTSatellite');
      expect(remove.isSettled(withRole(BondRole.standalone)), isTrue);
      expect(remove.isSettled(withRole(BondRole.surroundLeft)), isFalse);
    });
  });
}
