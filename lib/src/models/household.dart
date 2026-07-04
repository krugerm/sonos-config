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
