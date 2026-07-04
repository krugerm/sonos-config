import 'room.dart';

/// A party-mode set of rooms playing in sync (`x-rincon:` joins). Distinct from
/// bonding: bonded devices live inside a single [Room].
class Group {
  const Group({
    required this.id,
    required this.coordinatorUuid,
    required this.rooms,
  });

  final String id;
  final String coordinatorUuid;
  final List<Room> rooms;

  /// True when more than one room plays in sync in this group.
  bool get isBonded => rooms.length > 1;
}
