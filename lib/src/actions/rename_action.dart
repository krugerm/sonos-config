import '../models/change_line.dart';
import '../models/household.dart';
import '../services/sonos_api.dart';
import 'config_action.dart';

/// Renames a room (its coordinator's zone name).
class RenameRoomAction extends ConfigAction {
  RenameRoomAction({
    required this.host,
    required this.uuid,
    required this.currentName,
    required this.newName,
  });

  final String host;
  final String uuid;
  final String currentName;
  final String newName;

  @override
  String get title => 'Rename "$currentName" to "$newName"';

  @override
  List<ChangeLine> preview(Household household) =>
      [ChangeLine(label: 'Room name', before: currentName, after: newName)];

  @override
  bool get isReversible => true;

  @override
  Future<void> apply(SonosApi api) => api.renameRoom(host, newName);

  @override
  bool isSettled(Household after) =>
      after.deviceByUuid(uuid)?.roomName == newName;

  @override
  ConfigAction inverse(Household household) => RenameRoomAction(
        host: host,
        uuid: uuid,
        currentName: newName,
        newName: currentName,
      );
}
