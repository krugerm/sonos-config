import '../models/household.dart';
import 'household_parser.dart';
import 'soap_client.dart';

/// Room attributes from `DeviceProperties.GetZoneAttributes`.
class ZoneAttributes {
  const ZoneAttributes({
    required this.name,
    required this.icon,
    required this.configuration,
    required this.targetRoomName,
  });

  final String name;
  final String icon;
  final String configuration;
  final String targetRoomName;
}

/// Typed wrapper over [SoapClient] exposing the Sonos configuration actions the
/// app uses. Instances are cheap; the host is passed per call so one API object
/// can address any player in the household.
class SonosApi {
  SonosApi({SoapClient? client}) : _soap = client ?? SoapClient();

  final SoapClient _soap;

  static const _instance = {'InstanceID': '0'};
  static const _masterChannel = {'Channel': 'Master'};

  // ---- Topology ----------------------------------------------------------

  /// Fetches the whole household as the config-tool [Household] model.
  Future<Household> getHousehold(String host) async {
    final resp = await _soap.invoke(
      host,
      SonosService.zoneGroupTopology,
      'GetZoneGroupState',
    );
    final xml = resp.arg('ZoneGroupState');
    if (xml == null || xml.isEmpty) return const Household(groups: []);
    return parseHousehold(xml);
  }

  // ---- Bonding / topology config ----------------------------------------

  /// Bonds a satellite (surround or Sub) into a home-theater [primaryHost].
  /// [htSatChanMapSet] e.g. `RINCON_BEAM:LF,RF;RINCON_SUB:SW`.
  Future<void> addHtSatellite(String primaryHost, String htSatChanMapSet) =>
      _soap
          .invoke(primaryHost, SonosService.deviceProperties, 'AddHTSatellite',
              arguments: {'HTSatChanMapSet': htSatChanMapSet})
          .then((_) {});

  /// Unbonds the satellite identified by [satRoomUuid] from [primaryHost].
  Future<void> removeHtSatellite(String primaryHost, String satRoomUuid) =>
      _soap
          .invoke(
              primaryHost, SonosService.deviceProperties, 'RemoveHTSatellite',
              arguments: {'SatRoomUUID': satRoomUuid})
          .then((_) {});

  /// Creates a stereo pair. [channelMapSet] e.g. `L_UUID:LF,LF;R_UUID:RF,RF`.
  Future<void> createStereoPair(String primaryHost, String channelMapSet) =>
      _soap
          .invoke(
              primaryHost, SonosService.deviceProperties, 'CreateStereoPair',
              arguments: {'ChannelMapSet': channelMapSet})
          .then((_) {});

  /// Splits a stereo pair back into two standalone players.
  Future<void> separateStereoPair(String primaryHost, String channelMapSet) =>
      _soap
          .invoke(primaryHost, SonosService.deviceProperties,
              'SeparateStereoPair',
              arguments: {'ChannelMapSet': channelMapSet})
          .then((_) {});

  // ---- Grouping (party mode) --------------------------------------------

  /// Makes the player at [memberHost] join the group led by [coordinatorUuid].
  Future<void> joinGroup(String memberHost, String coordinatorUuid) => _soap
      .invoke(memberHost, SonosService.avTransport, 'SetAVTransportURI',
          arguments: {
            ..._instance,
            'CurrentURI': 'x-rincon:$coordinatorUuid',
            'CurrentURIMetaData': '',
          })
      .then((_) {});

  /// Removes the player at [memberHost] from its group, making it standalone.
  Future<void> leaveGroup(String memberHost) => _soap
      .invoke(memberHost, SonosService.avTransport,
          'BecomeCoordinatorOfStandaloneGroup', arguments: _instance)
      .then((_) {});

  // ---- Identity / device settings ---------------------------------------

  Future<ZoneAttributes> getZoneAttributes(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.deviceProperties, 'GetZoneAttributes');
    return ZoneAttributes(
      name: resp.arg('CurrentZoneName') ?? '',
      icon: resp.arg('CurrentIcon') ?? '',
      configuration: resp.arg('CurrentConfiguration') ?? '',
      targetRoomName: resp.arg('CurrentTargetRoomName') ?? '',
    );
  }

  /// Renames the room at [host]. `SetZoneAttributes` requires all fields, so we
  /// read the current icon/configuration/target and preserve them.
  Future<void> renameRoom(String host, String newName) async {
    final current = await getZoneAttributes(host);
    await _soap.invoke(
        host, SonosService.deviceProperties, 'SetZoneAttributes', arguments: {
      'DesiredZoneName': newName,
      'DesiredIcon': current.icon,
      'DesiredConfiguration': current.configuration,
      'DesiredTargetRoomName': current.targetRoomName,
    });
  }

  Future<bool> getLedOn(String host) async {
    final resp =
        await _soap.invoke(host, SonosService.deviceProperties, 'GetLEDState');
    return resp.arg('CurrentLEDState') == 'On';
  }

  Future<void> setLedOn(String host, bool on) => _soap
      .invoke(host, SonosService.deviceProperties, 'SetLEDState',
          arguments: {'DesiredLEDState': on ? 'On' : 'Off'})
      .then((_) {});

  Future<bool> getButtonLock(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.deviceProperties, 'GetButtonLockState');
    return resp.arg('CurrentButtonLockState') == 'On';
  }

  Future<void> setButtonLock(String host, bool locked) => _soap
      .invoke(host, SonosService.deviceProperties, 'SetButtonLockState',
          arguments: {'DesiredButtonLockState': locked ? 'On' : 'Off'})
      .then((_) {});

  // ---- Audio tuning ------------------------------------------------------

  Future<int> getVolume(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetVolume',
        arguments: {..._instance, ..._masterChannel});
    return resp.argInt('CurrentVolume') ?? 0;
  }

  Future<void> setVolume(String host, int volume) => _soap
      .invoke(host, SonosService.renderingControl, 'SetVolume', arguments: {
        ..._instance,
        ..._masterChannel,
        'DesiredVolume': volume.clamp(0, 100).toString(),
      })
      .then((_) {});

  Future<int> getBass(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetBass', arguments: _instance);
    return resp.argInt('CurrentBass') ?? 0;
  }

  Future<void> setBass(String host, int level) => _soap
      .invoke(host, SonosService.renderingControl, 'SetBass', arguments: {
        ..._instance,
        'DesiredBass': level.clamp(-10, 10).toString(),
      })
      .then((_) {});

  Future<int> getTreble(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetTreble', arguments: _instance);
    return resp.argInt('CurrentTreble') ?? 0;
  }

  Future<void> setTreble(String host, int level) => _soap
      .invoke(host, SonosService.renderingControl, 'SetTreble', arguments: {
        ..._instance,
        'DesiredTreble': level.clamp(-10, 10).toString(),
      })
      .then((_) {});

  Future<bool> getLoudness(String host) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetLoudness',
        arguments: {..._instance, ..._masterChannel});
    return resp.arg('CurrentLoudness') == '1';
  }

  Future<void> setLoudness(String host, bool on) => _soap
      .invoke(host, SonosService.renderingControl, 'SetLoudness', arguments: {
        ..._instance,
        ..._masterChannel,
        'DesiredLoudness': on ? '1' : '0',
      })
      .then((_) {});

  Future<int> getEq(String host, String eqType) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetEQ',
        arguments: {..._instance, 'EQType': eqType});
    return resp.argInt('CurrentValue') ?? 0;
  }

  Future<void> setEq(String host, String eqType, int value) => _soap
      .invoke(host, SonosService.renderingControl, 'SetEQ', arguments: {
        ..._instance,
        'EQType': eqType,
        'DesiredValue': value.toString(),
      })
      .then((_) {});

  Future<bool> getNightMode(String host) async =>
      await getEq(host, 'NightMode') == 1;

  Future<void> setNightMode(String host, bool on) =>
      setEq(host, 'NightMode', on ? 1 : 0);

  Future<bool> getSpeechEnhancement(String host) async =>
      await getEq(host, 'DialogLevel') == 1;

  Future<void> setSpeechEnhancement(String host, bool on) =>
      setEq(host, 'DialogLevel', on ? 1 : 0);

  Future<int> _channelVolume(String host, String channel) async {
    final resp = await _soap.invoke(
        host, SonosService.renderingControl, 'GetVolume',
        arguments: {..._instance, 'Channel': channel});
    return resp.argInt('CurrentVolume') ?? 0;
  }

  Future<void> _setChannelVolume(String host, String channel, int vol) => _soap
      .invoke(host, SonosService.renderingControl, 'SetVolume', arguments: {
        ..._instance,
        'Channel': channel,
        'DesiredVolume': vol.clamp(0, 100).toString(),
      })
      .then((_) {});

  /// Balance as -100 (full left) .. 0 (centre) .. 100 (full right), realised by
  /// trimming the quieter of the LF/RF channels.
  Future<int> getBalance(String host) async {
    final left = await _channelVolume(host, 'LF');
    final right = await _channelVolume(host, 'RF');
    return right - left;
  }

  Future<void> setBalance(String host, int balance) async {
    final b = balance.clamp(-100, 100);
    final left = b > 0 ? 100 - b : 100;
    final right = b < 0 ? 100 + b : 100;
    await _setChannelVolume(host, 'LF', left);
    await _setChannelVolume(host, 'RF', right);
  }

  void close() => _soap.close();
}
