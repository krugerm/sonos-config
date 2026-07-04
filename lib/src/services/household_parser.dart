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
