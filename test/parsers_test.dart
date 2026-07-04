import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/play_mode.dart';
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

    // Real capture from a Sonos Beam home-theater household (2026): a lone
    // bonded Sub sits in its own invisible group, and the two Sonos One SL
    // surrounds are <Satellite> children of the Beam, not ZoneGroupMembers.
    // Expected: exactly one room ("TV Room"); the phantom "Sub" group is
    // dropped and the invisible satellites don't inflate the member count.
    test('drops a lone invisible Sub group and hides bonded satellites', () {
      const xml = '''
<ZoneGroupState><ZoneGroups>
  <ZoneGroup Coordinator="RINCON_SUB" ID="RINCON_SUB:2083832462">
    <ZoneGroupMember UUID="RINCON_SUB" ZoneName="Sub" Invisible="1"
      Location="http://192.168.4.18:1400/xml/device_description.xml"/>
  </ZoneGroup>
  <ZoneGroup Coordinator="RINCON_BEAM" ID="RINCON_BEAM:2878326650">
    <ZoneGroupMember UUID="RINCON_BEAM" ZoneName="TV Room" Configuration="1"
      Location="http://192.168.4.185:1400/xml/device_description.xml"
      HTSatChanMapSet="RINCON_BEAM:LF,RF;RINCON_LR:LR;RINCON_RR:RR">
      <Satellite UUID="RINCON_RR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.4.34:1400/xml/device_description.xml"/>
      <Satellite UUID="RINCON_LR" ZoneName="TV Room" Invisible="1"
        Location="http://192.168.4.52:1400/xml/device_description.xml"/>
    </ZoneGroupMember>
  </ZoneGroup>
</ZoneGroups></ZoneGroupState>''';

      final groups = parseZoneGroupState(xml);
      expect(groups, hasLength(1));
      final room = groups.single;
      expect(room.displayName, 'TV Room');
      expect(room.isSingle, isTrue);
      expect(room.coordinator.host, '192.168.4.185');
      expect(room.members.every((m) => !m.invisible), isTrue);
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

  group('PlayMode', () {
    test('round-trips every Sonos play-mode string', () {
      for (final s in [
        'NORMAL',
        'SHUFFLE',
        'SHUFFLE_NOREPEAT',
        'SHUFFLE_REPEAT_ONE',
        'REPEAT_ALL',
        'REPEAT_ONE',
      ]) {
        expect(PlayMode.parse(s).toSonos(), s, reason: s);
      }
    });

    test('shuffle + repeat map onto the two axes', () {
      final m = PlayMode.parse('SHUFFLE');
      expect(m.shuffle, isTrue);
      expect(m.repeat, SonosRepeatMode.all);
    });

    test('cycleRepeat goes off -> all -> one -> off', () {
      var m = const PlayMode();
      m = m.cycleRepeat();
      expect(m.repeat, SonosRepeatMode.all);
      m = m.cycleRepeat();
      expect(m.repeat, SonosRepeatMode.one);
      m = m.cycleRepeat();
      expect(m.repeat, SonosRepeatMode.off);
    });
  });

  group('parseMediaItems (favorites)', () {
    test('extracts uri and resMD metadata for a favorite', () {
      const result = '''
<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
  xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/"
  xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <item id="FV:2/12" parentID="FV:2" restricted="true">
    <dc:title>Morning Jazz</dc:title>
    <r:description>Radio</r:description>
    <res>x-sonosapi-stream:station%3a123?sid=254</res>
    <upnp:albumArtURI>/getaa?s=1&amp;u=x</upnp:albumArtURI>
    <r:resMD>&lt;DIDL-Lite&gt;&lt;item&gt;meta&lt;/item&gt;&lt;/DIDL-Lite&gt;</r:resMD>
  </item>
</DIDL-Lite>''';
      final items = parseMediaItems(result, '192.168.1.10');
      expect(items, hasLength(1));
      final fav = items.single;
      expect(fav.title, 'Morning Jazz');
      expect(fav.uri, 'x-sonosapi-stream:station%3a123?sid=254');
      expect(fav.isPlayable, isTrue);
      expect(fav.metadata, contains('meta'));
      expect(fav.albumArtUri, 'http://192.168.1.10:1400/getaa?s=1&u=x');
    });

    test('returns empty list for blank input', () {
      expect(parseMediaItems(null, '10.0.0.1'), isEmpty);
      expect(parseMediaItems('', '10.0.0.1'), isEmpty);
    });
  });
}
