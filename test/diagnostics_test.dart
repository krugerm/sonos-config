import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/models/group.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/models/room.dart';
import 'package:personal_sonos/src/services/diagnostics.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'support/fake_soap_client.dart';

// Clearly-fake identifiers (never real device data).
const _serial = 'RINCON_ABCDEF01234501400';
const _serial2 = 'RINCON_FEDCBA09876501400';
const _ip = '192.168.99.50';
const _token = 'SA_RINCON99999_X_#Svc99999-0-Token';
const _lc = 'lc_deadbeefdeadbeef99';
const _guid = '12345678-1234-1234-1234-123456789abc';

void main() {
  group('Anonymizer', () {
    test('strips serials, IPs, tokens, and GUIDs', () {
      final a = Anonymizer();
      const raw = 'Coordinator="$_serial" Location="http://$_ip:1400/x" '
          'token=$_token audio=$_lc zone=$_guid other="$_serial2"';
      final out = a.scrub(raw);

      for (final secret in [_serial, _serial2, _ip, _token, _lc, _guid]) {
        expect(out, isNot(contains(secret)), reason: secret);
      }
      expect(out, contains('RINCON_DEVICE1'));
      expect(out, contains('RINCON_DEVICE2'));
      expect(out, contains('10.0.0.1'));
      expect(out, contains('[REDACTED_ACCOUNT]'));
      expect(out, contains('[REDACTED]'));
      expect(out, contains('[REDACTED_GUID]'));
    });

    test('pseudonyms are stable per input', () {
      final a = Anonymizer();
      expect(a.scrub(_serial), a.scrub(_serial));
      expect(a.pseudoUuid(_serial), a.pseudoUuid(_serial));
    });
  });

  group('DiagnosticsService.collect', () {
    const household = Household(groups: [
      Group(id: 'g', coordinatorUuid: _serial, rooms: [
        Room(
          name: 'TV Room',
          coordinator: Device(
              uuid: _serial,
              roomName: 'TV Room',
              host: _ip,
              model: 'Sonos Beam',
              firmware: '95.1-78010',
              bondRole: BondRole.coordinator),
          satellites: [],
        ),
      ]),
    ]);

    test('produces an anonymized bundle with no raw identifiers', () async {
      final soap = FakeSoapClient((action) => switch (action) {
            'GetZoneGroupState' => soapResponse(
                '<ZoneGroupState>&lt;ZoneGroupMember UUID=&quot;$_serial&quot; '
                'Location=&quot;http://$_ip:1400/x&quot;/&gt;</ZoneGroupState>'),
            'GetEQ' => soapResponse('<CurrentValue>0</CurrentValue>'),
            _ => soapResponse(''),
          });
      final api = SonosApi(client: soap);
      final svc = DiagnosticsService(api,
          fetchDescription: (host) async =>
              '<root><modelName>Sonos Beam</modelName>'
              '<UDN>uuid:$_serial</UDN><ip>$_ip</ip></root>');

      final bundle = await svc.collect(household,
          appVersion: '1.0.0',
          platform: 'macos',
          problem: 'sub tuning missing');

      final blob = bundle.toPrettyJson() + bundle.summary;
      for (final secret in [_serial, _ip]) {
        expect(blob, isNot(contains(secret)), reason: secret);
      }
      expect(blob, contains('RINCON_DEVICE1'));
      expect(bundle.summary, contains('Sonos Beam'));
      expect(bundle.summary, contains('sub tuning missing'));
      expect((bundle.json['devices'] as List).first['model'], 'Sonos Beam');
      expect(bundle.json['eqSupport'], isNotEmpty);
    });
  });
}
