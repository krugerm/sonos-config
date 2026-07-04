import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/playback_state.dart';
import 'package:personal_sonos/src/services/didl_parser.dart';
import 'package:personal_sonos/src/services/topology_parser.dart';

void main() {
  group('parseZoneGroupState', () {
    test('parses groups, members and coordinators', () {
      const xml = '''
<ZoneGroupState>
  <ZoneGroups>
    <ZoneGroup Coordinator="RINCON_A" ID="RINCON_A:1">
      <ZoneGroupMember UUID="RINCON_A" ZoneName="Living Room"
        Location="http://192.168.1.10:1400/xml/device_description.xml"
        Icon="x-rincon-roomicon:living" Invisible="0"/>
      <ZoneGroupMember UUID="RINCON_C" ZoneName="Kitchen"
        Location="http://192.168.1.12:1400/xml/device_description.xml"
        Invisible="0"/>
    </ZoneGroup>
    <ZoneGroup Coordinator="RINCON_B" ID="RINCON_B:2">
      <ZoneGroupMember UUID="RINCON_B" ZoneName="Bedroom"
        Location="http://192.168.1.11:1400/xml/device_description.xml"
        Invisible="0"/>
      <ZoneGroupMember UUID="RINCON_SUB" ZoneName="Bedroom (Sub)"
        Location="http://192.168.1.13:1400/xml/device_description.xml"
        Invisible="1"/>
    </ZoneGroup>
  </ZoneGroups>
</ZoneGroupState>''';

      final groups = parseZoneGroupState(xml);
      expect(groups.length, 2);

      final bedroom = groups.firstWhere((g) => g.coordinator.name == 'Bedroom');
      // Invisible sub is filtered out of the visible members.
      expect(bedroom.members.length, 1);
      expect(bedroom.isSingle, isTrue);

      final living =
          groups.firstWhere((g) => g.coordinator.name == 'Living Room');
      expect(living.members.length, 2);
      expect(living.coordinator.host, '192.168.1.10');
      expect(living.coordinator.isCoordinator, isTrue);
      expect(living.displayName, 'Living Room + 1');
      expect(living.coordinator.icon, 'living');
    });

    test('sorts members with coordinator first', () {
      const xml = '''
<ZoneGroupState><ZoneGroups>
  <ZoneGroup Coordinator="RINCON_Z" ID="RINCON_Z:9">
    <ZoneGroupMember UUID="RINCON_Y" ZoneName="Attic"
      Location="http://10.0.0.5:1400/x" Invisible="0"/>
    <ZoneGroupMember UUID="RINCON_Z" ZoneName="Office"
      Location="http://10.0.0.6:1400/x" Invisible="0"/>
  </ZoneGroup>
</ZoneGroups></ZoneGroupState>''';
      final groups = parseZoneGroupState(xml);
      expect(groups.single.members.first.name, 'Office'); // coordinator first
      expect(groups.single.members.last.name, 'Attic');
    });
  });

  group('parseDidl', () {
    test('extracts title, artist, album and art', () {
      const didl = '''
<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
  xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <item id="-1" parentID="-1" restricted="true">
    <dc:title>Come Together</dc:title>
    <dc:creator>The Beatles</dc:creator>
    <upnp:album>Abbey Road</upnp:album>
    <upnp:albumArtURI>/getaa?u=song%3a1&amp;v=42</upnp:albumArtURI>
  </item>
</DIDL-Lite>''';
      final meta = parseDidl(didl);
      expect(meta.title, 'Come Together');
      expect(meta.artist, 'The Beatles');
      expect(meta.album, 'Abbey Road');
      expect(meta.albumArtUri, '/getaa?u=song%3a1&v=42');
    });

    test('returns empty for placeholder / blank input', () {
      expect(parseDidl(null).title, isNull);
      expect(parseDidl('').title, isNull);
      expect(parseDidl('NOT_IMPLEMENTED').title, isNull);
    });
  });

  group('resolveAlbumArt', () {
    test('resolves relative paths against the speaker host', () {
      expect(resolveAlbumArt('/getaa?x=1', '192.168.1.10'),
          'http://192.168.1.10:1400/getaa?x=1');
    });
    test('leaves absolute URLs untouched', () {
      expect(resolveAlbumArt('https://art/x.jpg', '192.168.1.10'),
          'https://art/x.jpg');
    });
    test('returns null for empty input', () {
      expect(resolveAlbumArt(null, '192.168.1.10'), isNull);
    });
  });

  group('TransportState', () {
    test('maps Sonos transport strings', () {
      expect(TransportState.parse('PLAYING'), TransportState.playing);
      expect(TransportState.parse('PAUSED_PLAYBACK'), TransportState.paused);
      expect(TransportState.parse('STOPPED'), TransportState.stopped);
      expect(TransportState.parse('WAT'), TransportState.unknown);
    });
  });
}
