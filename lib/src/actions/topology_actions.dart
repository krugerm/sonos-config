import '../models/bond_role.dart';
import '../models/change_line.dart';
import '../models/household.dart';
import '../services/sonos_api.dart';
import 'config_action.dart';

/// Bonds a standalone Sub into a home-theater room as its subwoofer.
class BondSubAction extends ConfigAction {
  BondSubAction({
    required this.primaryHost,
    required this.primaryUuid,
    required this.subUuid,
    required this.roomName,
  });

  final String primaryHost;
  final String primaryUuid;
  final String subUuid;
  final String roomName;

  @override
  String get title => 'Bond Sub to $roomName';

  @override
  List<ChangeLine> preview(Household household) => [
        ChangeLine(
            label: 'Sub',
            before: 'Standalone (unbonded)',
            after: 'Bonded into $roomName as subwoofer'),
      ];

  @override
  bool get isReversible => true;

  @override
  Future<void> apply(SonosApi api) =>
      api.addHtSatellite(primaryHost, '$primaryUuid:LF,RF;$subUuid:SW');

  @override
  bool isSettled(Household after) =>
      after.deviceByUuid(subUuid)?.bondRole == BondRole.sub;

  @override
  ConfigAction inverse(Household household) => UnbondSubAction(
        primaryHost: primaryHost,
        primaryUuid: primaryUuid,
        subUuid: subUuid,
        roomName: roomName,
      );
}

/// Unbonds a Sub from a home-theater room, returning it to standalone.
class UnbondSubAction extends ConfigAction {
  UnbondSubAction({
    required this.primaryHost,
    required this.primaryUuid,
    required this.subUuid,
    required this.roomName,
  });

  final String primaryHost;
  final String primaryUuid;
  final String subUuid;
  final String roomName;

  @override
  String get title => 'Unbond Sub from $roomName';

  @override
  List<ChangeLine> preview(Household household) => [
        ChangeLine(
            label: 'Sub',
            before: 'Bonded into $roomName',
            after: 'Standalone (unbonded)'),
      ];

  @override
  bool get isReversible => true;

  @override
  Future<void> apply(SonosApi api) =>
      api.removeHtSatellite(primaryHost, subUuid);

  @override
  bool isSettled(Household after) =>
      after.deviceByUuid(subUuid)?.bondRole != BondRole.sub;

  @override
  ConfigAction inverse(Household household) => BondSubAction(
        primaryHost: primaryHost,
        primaryUuid: primaryUuid,
        subUuid: subUuid,
        roomName: roomName,
      );
}

/// Joins two standalone speakers into a stereo pair (left + right).
class CreateStereoPairAction extends ConfigAction {
  CreateStereoPairAction({
    required this.leftHost,
    required this.leftUuid,
    required this.rightUuid,
    required this.leftName,
    required this.rightName,
  });

  final String leftHost;
  final String leftUuid;
  final String rightUuid;
  final String leftName;
  final String rightName;

  @override
  String get title => 'Stereo-pair $leftName + $rightName';

  @override
  List<ChangeLine> preview(Household household) => [
        ChangeLine(
            label: 'Stereo pair',
            before: '$leftName, $rightName (separate rooms)',
            after: '$leftName (left + right pair)'),
      ];

  @override
  bool get isReversible => true;

  @override
  Future<void> apply(SonosApi api) =>
      api.createStereoPair(leftHost, '$leftUuid:LF,LF;$rightUuid:RF,RF');

  @override
  bool isSettled(Household after) =>
      // The right speaker is no longer its own visible room once paired.
      !after.visibleRooms.any((r) => r.coordinator.uuid == rightUuid);

  @override
  ConfigAction inverse(Household household) => SeparateStereoPairAction(
        leftHost: leftHost,
        leftUuid: leftUuid,
        rightUuid: rightUuid,
        leftName: leftName,
        rightName: rightName,
      );
}

/// Splits a stereo pair back into two standalone speakers.
class SeparateStereoPairAction extends ConfigAction {
  SeparateStereoPairAction({
    required this.leftHost,
    required this.leftUuid,
    required this.rightUuid,
    required this.leftName,
    required this.rightName,
  });

  final String leftHost;
  final String leftUuid;
  final String rightUuid;
  final String leftName;
  final String rightName;

  @override
  String get title => 'Split $leftName stereo pair';

  @override
  List<ChangeLine> preview(Household household) => [
        ChangeLine(
            label: 'Stereo pair',
            before: '$leftName (left + right pair)',
            after: '$leftName, $rightName (separate rooms)'),
      ];

  @override
  bool get isReversible => true;

  @override
  Future<void> apply(SonosApi api) =>
      api.separateStereoPair(leftHost, '$leftUuid:LF,LF;$rightUuid:RF,RF');

  @override
  bool isSettled(Household after) =>
      // The right speaker is a standalone visible room again once split.
      after.visibleRooms.any((r) => r.coordinator.uuid == rightUuid);

  @override
  ConfigAction inverse(Household household) => CreateStereoPairAction(
        leftHost: leftHost,
        leftUuid: leftUuid,
        rightUuid: rightUuid,
        leftName: leftName,
        rightName: rightName,
      );
}

/// Bonds a standalone speaker into a home theater as a rear surround.
/// [channel] is `LR` (left) or `RR` (right).
class AddSurroundAction extends ConfigAction {
  AddSurroundAction({
    required this.primaryHost,
    required this.primaryUuid,
    required this.satUuid,
    required this.channel,
    required this.roomName,
    required this.satName,
  });

  final String primaryHost;
  final String primaryUuid;
  final String satUuid;
  final String channel; // LR | RR
  final String roomName;
  final String satName;

  bool get _isLeft => channel.toUpperCase() == 'LR';

  @override
  String get title => 'Add $satName as ${_isLeft ? 'left' : 'right'} surround';

  @override
  List<ChangeLine> preview(Household household) => [
        ChangeLine(
            label: satName,
            before: 'Standalone',
            after: '${_isLeft ? 'Left' : 'Right'} surround of $roomName'),
      ];

  @override
  bool get isReversible => true;

  @override
  Future<void> apply(SonosApi api) =>
      api.addHtSatellite(primaryHost, '$primaryUuid:LF,RF;$satUuid:$channel');

  @override
  bool isSettled(Household after) {
    final role = after.deviceByUuid(satUuid)?.bondRole;
    return role == BondRole.surroundLeft || role == BondRole.surroundRight;
  }

  @override
  ConfigAction inverse(Household household) => RemoveSurroundAction(
        primaryHost: primaryHost,
        primaryUuid: primaryUuid,
        satUuid: satUuid,
        channel: channel,
        roomName: roomName,
        satName: satName,
      );
}

/// Unbonds a surround speaker from a home theater, returning it to standalone.
class RemoveSurroundAction extends ConfigAction {
  RemoveSurroundAction({
    required this.primaryHost,
    required this.primaryUuid,
    required this.satUuid,
    required this.channel,
    required this.roomName,
    required this.satName,
  });

  final String primaryHost;
  final String primaryUuid;
  final String satUuid;
  final String channel;
  final String roomName;
  final String satName;

  @override
  String get title => 'Remove $satName surround';

  @override
  List<ChangeLine> preview(Household household) => [
        ChangeLine(
            label: satName,
            before: 'Surround of $roomName',
            after: 'Standalone'),
      ];

  @override
  bool get isReversible => true;

  @override
  Future<void> apply(SonosApi api) =>
      api.removeHtSatellite(primaryHost, satUuid);

  @override
  bool isSettled(Household after) {
    final role = after.deviceByUuid(satUuid)?.bondRole;
    return role != BondRole.surroundLeft && role != BondRole.surroundRight;
  }

  @override
  ConfigAction inverse(Household household) => AddSurroundAction(
        primaryHost: primaryHost,
        primaryUuid: primaryUuid,
        satUuid: satUuid,
        channel: channel,
        roomName: roomName,
        satName: satName,
      );
}
