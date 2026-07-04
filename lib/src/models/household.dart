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

  /// Returns a copy with each device's [Device.model] filled in from
  /// [modelByUuid] (used after fetching device descriptions). Uuids absent from
  /// the map keep their existing model.
  Household withModels(Map<String, String?> modelByUuid) {
    Device apply(Device d) {
      final m = modelByUuid[d.uuid];
      return m == null ? d : d.copyWith(model: m);
    }

    return Household(groups: [
      for (final g in groups)
        Group(id: g.id, coordinatorUuid: g.coordinatorUuid, rooms: [
          for (final r in g.rooms)
            Room(
              name: r.name,
              coordinator: apply(r.coordinator),
              satellites: [for (final s in r.satellites) apply(s)],
            ),
        ]),
    ]);
  }
}
