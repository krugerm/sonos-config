import 'package:xml/xml.dart';

import '../models/sonos_speaker.dart';
import '../models/zone_group.dart';

/// Parses the escaped XML returned by `ZoneGroupTopology.GetZoneGroupState`
/// into a list of [ZoneGroup]s.
///
/// One player can describe the entire household, so a single successful call
/// gives us every room, every group and every coordinator.
List<ZoneGroup> parseZoneGroupState(String zoneGroupStateXml) {
  final doc = XmlDocument.parse(zoneGroupStateXml);
  final groups = <ZoneGroup>[];

  for (final groupEl in doc.findAllElements('ZoneGroup')) {
    final coordinatorUuid = groupEl.getAttribute('Coordinator') ?? '';
    final groupId = groupEl.getAttribute('ID') ?? coordinatorUuid;

    final members = <SonosSpeaker>[];
    for (final memberEl in groupEl.findAllElements('ZoneGroupMember')) {
      final speaker = _speakerFromMember(memberEl, coordinatorUuid);
      if (speaker != null) members.add(speaker);
    }
    if (members.isEmpty) continue;

    // Keep only visible members. A group with no visible member is not a
    // user-facing room — it's a lone bonded Sub, an invisible bridge/Boost, or
    // a satellite-only remnant. Surfacing it would give the UI a phantom room
    // ("Sub") the user can't meaningfully select or control, so drop it.
    final visible = members.where((m) => !m.invisible).toList();
    if (visible.isEmpty) continue;

    final coordinator = visible.firstWhere(
      (m) => m.uuid == coordinatorUuid,
      orElse: () => visible.first,
    );

    // Coordinator first, then the rest by name for a stable UI order.
    final others = visible.where((m) => m.uuid != coordinator.uuid).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final ordered = <SonosSpeaker>[coordinator, ...others];

    groups.add(ZoneGroup(
      id: groupId,
      coordinator: coordinator,
      members: ordered,
    ));
  }

  groups.sort((a, b) => a.displayName.compareTo(b.displayName));
  return groups;
}

SonosSpeaker? _speakerFromMember(XmlElement member, String coordinatorUuid) {
  final uuid = member.getAttribute('UUID');
  final location = member.getAttribute('Location');
  final name = member.getAttribute('ZoneName');
  if (uuid == null || location == null || name == null) return null;

  final host = Uri.tryParse(location)?.host;
  if (host == null || host.isEmpty) return null;

  final invisible = member.getAttribute('Invisible') == '1' ||
      member.getAttribute('IsZoneBridge') == '1';

  return SonosSpeaker(
    uuid: uuid,
    name: name,
    host: host,
    isCoordinator: uuid == coordinatorUuid,
    invisible: invisible,
    icon: _iconName(member.getAttribute('Icon')),
  );
}

/// Sonos icon attribute looks like `x-rincon-roomicon:living`. We only keep
/// the trailing hint, if any.
String? _iconName(String? icon) {
  if (icon == null || !icon.contains(':')) return null;
  final hint = icon.split(':').last.trim();
  return hint.isEmpty ? null : hint;
}
