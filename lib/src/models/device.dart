import 'bond_role.dart';
import 'capabilities.dart';

/// One physical Sonos player.
class Device {
  const Device({
    required this.uuid,
    required this.roomName,
    required this.host,
    required this.bondRole,
    this.model,
    this.firmware,
    this.invisible = false,
  });

  final String uuid;
  final String roomName;
  final String host;

  /// Model name from `device_description.xml` (e.g. `Sonos Beam`). Null until
  /// the device is enriched with its description (a later phase).
  final String? model;

  /// Firmware version (`SoftwareVersion` from topology), e.g. `95.1-78010`.
  final String? firmware;

  /// True for bonded satellites and invisible bridges — not shown on their own
  /// as a room, but still a real, possibly-actionable device.
  final bool invisible;

  final BondRole bondRole;

  /// Derived on read so it tracks [model]/[bondRole] through [copyWith].
  Capabilities get capabilities => Capabilities.forModel(model, bondRole);

  Device copyWith({
    String? roomName,
    String? host,
    String? model,
    String? firmware,
    bool? invisible,
    BondRole? bondRole,
  }) {
    return Device(
      uuid: uuid,
      roomName: roomName ?? this.roomName,
      host: host ?? this.host,
      model: model ?? this.model,
      firmware: firmware ?? this.firmware,
      invisible: invisible ?? this.invisible,
      bondRole: bondRole ?? this.bondRole,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Device && other.uuid == uuid && other.host == host;

  @override
  int get hashCode => Object.hash(uuid, host);

  @override
  String toString() => 'Device($roomName/${bondRole.name} @ $host)';
}
