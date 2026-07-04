import 'sonos_speaker.dart';

/// A group of one or more [SonosSpeaker]s that play in sync.
///
/// Playback and group-volume commands are addressed to the group's
/// [coordinator]; per-speaker volume is addressed to each member.
class ZoneGroup {
  const ZoneGroup({
    required this.id,
    required this.coordinator,
    required this.members,
  });

  /// Group id from ZoneGroupTopology, e.g. `RINCON_...:1234567890`.
  final String id;

  /// The speaker that owns transport/playback for the whole group.
  final SonosSpeaker coordinator;

  /// All visible members, coordinator first.
  final List<SonosSpeaker> members;

  bool get isSingle => members.length == 1;

  /// Label shown in the speaker list, e.g. `Kitchen` or `Kitchen + 2`.
  String get displayName {
    if (isSingle) return coordinator.name;
    final others = members.length - 1;
    return '${coordinator.name} + $others';
  }

  /// Every room in the group, for a subtitle line.
  String get roomsSummary => members.map((m) => m.name).join(', ');

  @override
  bool operator ==(Object other) => other is ZoneGroup && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
