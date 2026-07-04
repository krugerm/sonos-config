/// A single physical Sonos player (one "zone member").
///
/// Several speakers can be bonded into a stereo pair or grouped for
/// synchronised playback; those relationships live on [ZoneGroup]. This class
/// only describes one box.
class SonosSpeaker {
  const SonosSpeaker({
    required this.uuid,
    required this.name,
    required this.host,
    this.isCoordinator = false,
    this.invisible = false,
    this.icon,
  });

  /// Stable Sonos identifier, e.g. `RINCON_949F3E0C1A2B01400`.
  final String uuid;

  /// User-visible room name, e.g. `Living Room`.
  final String name;

  /// IP address on the LAN.
  final String host;

  /// True when this speaker drives its group's playback.
  final bool isCoordinator;

  /// True for members that should not be shown on their own — bonded
  /// surround/sub satellites and invisible bridges.
  final bool invisible;

  /// A short model hint (e.g. `Play:1`) when the topology provides one.
  final String? icon;

  SonosSpeaker copyWith({
    String? name,
    String? host,
    bool? isCoordinator,
    bool? invisible,
    String? icon,
  }) {
    return SonosSpeaker(
      uuid: uuid,
      name: name ?? this.name,
      host: host ?? this.host,
      isCoordinator: isCoordinator ?? this.isCoordinator,
      invisible: invisible ?? this.invisible,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SonosSpeaker && other.uuid == uuid && other.host == host;

  @override
  int get hashCode => Object.hash(uuid, host);

  @override
  String toString() => 'SonosSpeaker($name @ $host)';
}
