import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/models/group.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/models/room.dart';
import 'package:personal_sonos/src/ui/widgets.dart';

const _household = Household(groups: [
  Group(id: 'g', coordinatorUuid: 'BEAM', rooms: [
    Room(
      name: 'TV Room',
      coordinator: Device(
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
            bondRole: BondRole.sub),
      ],
    ),
  ]),
]);

void main() {
  group('Household.withModels', () {
    test('applies models by uuid and feeds capability derivation', () {
      final enriched =
          _household.withModels({'BEAM': 'Sonos Beam', 'SUB': 'Sonos Sub'});
      expect(enriched.deviceByUuid('BEAM')!.model, 'Sonos Beam');
      expect(enriched.deviceByUuid('BEAM')!.capabilities.canBondSub, isTrue);
      expect(enriched.deviceByUuid('SUB')!.model, 'Sonos Sub');
      expect(enriched.deviceByUuid('SUB')!.capabilities.hasBassTreble, isFalse);
    });

    test('leaves devices absent from the map unchanged', () {
      final enriched = _household.withModels({'BEAM': 'Sonos Beam'});
      expect(enriched.deviceByUuid('SUB')!.model, isNull);
    });

    test('preserves structure (rooms, satellites, roles)', () {
      final enriched = _household.withModels(const {});
      expect(enriched.visibleRooms.single.name, 'TV Room');
      expect(enriched.visibleRooms.single.satellites.single.bondRole,
          BondRole.sub);
    });
  });

  group('role labels', () {
    test('every BondRole has a non-empty short and long label', () {
      for (final role in BondRole.values) {
        expect(roleShortLabel(role), isNotEmpty, reason: role.name);
        expect(roleLongLabel(role), isNotEmpty, reason: role.name);
      }
    });

    test('short labels are distinct per role', () {
      final labels = BondRole.values.map(roleShortLabel).toSet();
      expect(labels.length, BondRole.values.length);
    });
  });
}
