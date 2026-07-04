import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';

void main() {
  group('Device', () {
    const beam = Device(
      uuid: 'RINCON_BEAM',
      roomName: 'TV Room',
      host: '192.168.4.185',
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
        uuid: 'RINCON_BEAM', roomName: 'X', host: '192.168.4.185',
        bondRole: BondRole.standalone,
      ));
      expect(beam == beam.copyWith(host: '10.0.0.1'), isFalse);
    });
  });
}
