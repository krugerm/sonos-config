import '../models/household.dart';
import '../models/media_item.dart';
import '../models/play_mode.dart';
import '../models/playback_state.dart';
import '../models/zone_group.dart';
import 'didl_parser.dart';
import 'household_parser.dart';
import 'soap_client.dart';
import 'topology_parser.dart';

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

/// Typed wrapper over [SoapClient] exposing the Sonos actions the app uses.
///
/// Instances are cheap; the [host] is passed per-call so a single API object
/// can address any player in the household.
class SonosApi {
  SonosApi({SoapClient? client}) : _soap = client ?? SoapClient();

  final SoapClient _soap;

  static const _instance = {'InstanceID': '0'};
  static const _masterChannel = {'Channel': 'Master'};

  // ---- Topology -----------------------------------------------------------

  /// Fetches the whole household topology by asking one player at [host].
  Future<List<ZoneGroup>> getZoneGroups(String host) async {
    final resp = await _soap.invoke(
      host,
      SonosService.zoneGroupTopology,
      'GetZoneGroupState',
    );
    final xml = resp.arg('ZoneGroupState');
    if (xml == null || xml.isEmpty) return const [];
    return parseZoneGroupState(xml);
  }

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

  // ---- Transport (address the group coordinator) --------------------------

  Future<void> play(String host) => _soap
      .invoke(host, SonosService.avTransport, 'Play',
          arguments: {..._instance, 'Speed': '1'})
      .then((_) {});

  Future<void> pause(String host) => _soap
      .invoke(host, SonosService.avTransport, 'Pause', arguments: _instance)
      .then((_) {});

  Future<void> next(String host) => _soap
      .invoke(host, SonosService.avTransport, 'Next', arguments: _instance)
      .then((_) {});

  Future<void> previous(String host) => _soap
      .invoke(host, SonosService.avTransport, 'Previous', arguments: _instance)
      .then((_) {});

  /// Seeks to an absolute [position] within the current track.
  Future<void> seek(String host, Duration position) => _soap
      .invoke(host, SonosService.avTransport, 'Seek', arguments: {
        ..._instance,
        'Unit': 'REL_TIME',
        'Target': _formatDuration(position),
      })
      .then((_) {});

  Future<TransportState> getTransportState(String host) async {
    final resp = await _soap.invoke(
      host,
      SonosService.avTransport,
      'GetTransportInfo',
      arguments: _instance,
    );
    return TransportState.parse(resp.arg('CurrentTransportState'));
  }

  /// Returns current track metadata plus position/duration.
  Future<PlaybackState> getPositionInfo(String host, PlaybackState base) async {
    final resp = await _soap.invoke(
      host,
      SonosService.avTransport,
      'GetPositionInfo',
      arguments: _instance,
    );
    final meta = parseDidl(resp.arg('TrackMetaData'));
    return base.copyWith(
      title: meta.title ?? '',
      artist: meta.artist ?? '',
      album: meta.album ?? '',
      albumArtUri: resolveAlbumArt(meta.albumArtUri, host) ?? '',
      position: _parseDuration(resp.arg('RelTime')),
      duration: _parseDuration(resp.arg('TrackDuration')),
    );
  }

  Future<PlayMode> getPlayMode(String host) async {
    final resp = await _soap.invoke(
      host,
      SonosService.avTransport,
      'GetTransportSettings',
      arguments: _instance,
    );
    return PlayMode.parse(resp.arg('PlayMode'));
  }

  Future<void> setPlayMode(String host, PlayMode mode) => _soap
      .invoke(host, SonosService.avTransport, 'SetPlayMode', arguments: {
        ..._instance,
        'NewPlayMode': mode.toSonos(),
      })
      .then((_) {});

  /// Points the coordinator at [uri] (with its DIDL [metadata]) and starts it.
  /// Used to play a favorite.
  Future<void> playUri(String host, String uri, {String metadata = ''}) async {
    await _soap.invoke(host, SonosService.avTransport, 'SetAVTransportURI',
        arguments: {
          ..._instance,
          'CurrentURI': uri,
          'CurrentURIMetaData': metadata,
        });
    await play(host);
  }

  // ---- Content browsing (favorites / queue) -------------------------------

  /// Browses the "Sonos Favorites" container (`FV:2`) on [host].
  Future<List<MediaItem>> browseFavorites(String host) =>
      _browse(host, 'FV:2');

  /// Browses the current play queue (`Q:0`) of the group at [host].
  Future<List<MediaItem>> browseQueue(String host) => _browse(host, 'Q:0');

  Future<List<MediaItem>> _browse(String host, String objectId) async {
    final resp = await _soap.invoke(
      host,
      SonosService.contentDirectory,
      'Browse',
      arguments: {
        'ObjectID': objectId,
        'BrowseFlag': 'BrowseDirectChildren',
        'Filter': '*',
        'StartingIndex': '0',
        'RequestedCount': '200',
        'SortCriteria': '',
      },
    );
    return parseMediaItems(resp.arg('Result'), host);
  }

  // ---- Grouping -----------------------------------------------------------

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

  // ---- Group volume (coordinator) -----------------------------------------

  Future<int> getGroupVolume(String host) async {
    final resp = await _soap.invoke(
      host,
      SonosService.groupRenderingControl,
      'GetGroupVolume',
      arguments: _instance,
    );
    return resp.argInt('CurrentVolume') ?? 0;
  }

  Future<void> setGroupVolume(String host, int volume) => _soap
      .invoke(host, SonosService.groupRenderingControl, 'SetGroupVolume',
          arguments: {
            ..._instance,
            'DesiredVolume': volume.clamp(0, 100).toString(),
          })
      .then((_) {});

  Future<bool> getGroupMute(String host) async {
    final resp = await _soap.invoke(
      host,
      SonosService.groupRenderingControl,
      'GetGroupMute',
      arguments: _instance,
    );
    return resp.arg('CurrentMute') == '1';
  }

  Future<void> setGroupMute(String host, bool mute) => _soap
      .invoke(host, SonosService.groupRenderingControl, 'SetGroupMute',
          arguments: {..._instance, 'DesiredMute': mute ? '1' : '0'})
      .then((_) {});

  // ---- Per-speaker volume (any member) ------------------------------------

  Future<int> getVolume(String host) async {
    final resp = await _soap.invoke(
      host,
      SonosService.renderingControl,
      'GetVolume',
      arguments: {..._instance, ..._masterChannel},
    );
    return resp.argInt('CurrentVolume') ?? 0;
  }

  Future<void> setVolume(String host, int volume) => _soap
      .invoke(host, SonosService.renderingControl, 'SetVolume', arguments: {
        ..._instance,
        ..._masterChannel,
        'DesiredVolume': volume.clamp(0, 100).toString(),
      })
      .then((_) {});

  // ---- Duration helpers ----------------------------------------------------

  static Duration _parseDuration(String? hms) {
    if (hms == null || hms.isEmpty || hms == 'NOT_IMPLEMENTED') {
      return Duration.zero;
    }
    final parts = hms.split(':');
    if (parts.length != 3) return Duration.zero;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2].split('.').first) ?? 0;
    return Duration(hours: h, minutes: m, seconds: s);
  }

  static String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  void close() => _soap.close();
}
