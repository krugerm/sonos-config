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
      Location="http://192.168.4.185:1400/xml/device_description.xml"
      HTSatChanMapSet="RINCON_BEAM:LF,RF;RINCON_LR:LR;RINCON_RR:RR;RINCON_SUB:SW">
      <Satellite UUID="RINCON_LR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.4.52:1400/xml/device_description.xml"/>
      <Satellite UUID="RINCON_RR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.4.34:1400/xml/device_description.xml"/>
      <Satellite UUID="RINCON_SUB" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.4.18:1400/xml/device_description.xml"/>
    </ZoneGroupMember>
  </ZoneGroup>
</ZoneGroups></ZoneGroupState>''';

  // Real capture: same household BEFORE bonding — Sub floats in its own
  // invisible group; Beam has only the two surrounds.
  const unbondedSub = '''
<ZoneGroupState><ZoneGroups>
  <ZoneGroup Coordinator="RINCON_SUB" ID="RINCON_SUB:208">
    <ZoneGroupMember UUID="RINCON_SUB" ZoneName="Sub" Invisible="1" SoftwareVersion="86.7-77050"
      Location="http://192.168.4.18:1400/xml/device_description.xml"/>
  </ZoneGroup>
  <ZoneGroup Coordinator="RINCON_BEAM" ID="RINCON_BEAM:287">
    <ZoneGroupMember UUID="RINCON_BEAM" ZoneName="TV Room" SoftwareVersion="95.1-78010"
      Location="http://192.168.4.185:1400/xml/device_description.xml"
      HTSatChanMapSet="RINCON_BEAM:LF,RF;RINCON_LR:LR;RINCON_RR:RR">
      <Satellite UUID="RINCON_LR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.4.52:1400/xml/device_description.xml"/>
      <Satellite UUID="RINCON_RR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.4.34:1400/xml/device_description.xml"/>
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
    expect(tv.coordinator.host, '192.168.4.185');
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
