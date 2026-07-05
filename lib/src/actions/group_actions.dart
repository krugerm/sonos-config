import '../models/change_line.dart';
import '../models/household.dart';
import '../services/sonos_api.dart';
import 'config_action.dart';

/// Joins one room into another room's group for synchronised playback
/// (party mode) — distinct from bonding.
class JoinGroupAction extends ConfigAction {
  JoinGroupAction({
    required this.memberHost,
    required this.memberUuid,
    required this.memberRoomName,
    required this.coordinatorUuid,
    required this.targetRoomName,
  });

  final String memberHost;
  final String memberUuid;
  final String memberRoomName;
  final String coordinatorUuid;
  final String targetRoomName;

  @override
  String get title => 'Group $memberRoomName with $targetRoomName';

  @override
  List<ChangeLine> preview(Household household) => [
        ChangeLine(
            label: memberRoomName,
            before: 'Its own group',
            after: 'Grouped with $targetRoomName'),
      ];

  @override
  bool get isReversible => true;

  @override
  Future<void> apply(SonosApi api) =>
      api.joinGroup(memberHost, coordinatorUuid);

  @override
  bool isSettled(Household after) => after.groups.any((g) =>
      g.rooms.any((r) => r.coordinator.uuid == memberUuid) &&
      g.rooms.any((r) => r.coordinator.uuid == coordinatorUuid));

  @override
  ConfigAction inverse(Household household) => LeaveGroupAction(
        memberHost: memberHost,
        memberUuid: memberUuid,
        memberRoomName: memberRoomName,
        priorCoordinatorUuid: coordinatorUuid,
        priorTargetName: targetRoomName,
      );
}

/// Removes a room from its group, returning it to standalone.
class LeaveGroupAction extends ConfigAction {
  LeaveGroupAction({
    required this.memberHost,
    required this.memberUuid,
    required this.memberRoomName,
    this.priorCoordinatorUuid,
    this.priorTargetName,
  });

  final String memberHost;
  final String memberUuid;
  final String memberRoomName;
  final String? priorCoordinatorUuid;
  final String? priorTargetName;

  @override
  String get title => 'Ungroup $memberRoomName';

  @override
  List<ChangeLine> preview(Household household) => [
        ChangeLine(
            label: memberRoomName, before: 'Grouped', after: 'Its own group'),
      ];

  @override
  bool get isReversible => priorCoordinatorUuid != null;

  @override
  Future<void> apply(SonosApi api) => api.leaveGroup(memberHost);

  @override
  bool isSettled(Household after) => after.groups.any((g) =>
      g.rooms.length == 1 && g.rooms.single.coordinator.uuid == memberUuid);

  @override
  ConfigAction? inverse(Household household) => priorCoordinatorUuid == null
      ? null
      : JoinGroupAction(
          memberHost: memberHost,
          memberUuid: memberUuid,
          memberRoomName: memberRoomName,
          coordinatorUuid: priorCoordinatorUuid!,
          targetRoomName: priorTargetName ?? 'group',
        );
}
