import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/services/soap_client.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'support/fake_soap_client.dart';

void main() {
  late FakeSoapClient soap;
  late SonosApi api;
  setUp(() {
    soap = FakeSoapClient();
    api = SonosApi(client: soap);
  });

  group('bonding / topology', () {
    test('addHtSatellite posts HTSatChanMapSet to DeviceProperties', () async {
      await api.addHtSatellite('10.0.0.1', 'PRIMARY:LF,RF;SUB:SW');
      expect(soap.lastCall.host, '10.0.0.1');
      expect(soap.lastCall.service, SonosService.deviceProperties);
      expect(soap.lastCall.action, 'AddHTSatellite');
      expect(soap.lastCall.args, {'HTSatChanMapSet': 'PRIMARY:LF,RF;SUB:SW'});
    });

    test('removeHtSatellite posts the satellite room UUID', () async {
      await api.removeHtSatellite('10.0.0.1', 'RINCON_SUB');
      expect(soap.lastCall.action, 'RemoveHTSatellite');
      expect(soap.lastCall.args, {'SatRoomUUID': 'RINCON_SUB'});
    });

    test('createStereoPair posts the channel map set', () async {
      await api.createStereoPair('10.0.0.1', 'L:LF,LF;R:RF,RF');
      expect(soap.lastCall.action, 'CreateStereoPair');
      expect(soap.lastCall.args, {'ChannelMapSet': 'L:LF,LF;R:RF,RF'});
    });

    test('separateStereoPair posts the channel map set', () async {
      await api.separateStereoPair('10.0.0.1', 'L:LF,LF;R:RF,RF');
      expect(soap.lastCall.action, 'SeparateStereoPair');
      expect(soap.lastCall.args, {'ChannelMapSet': 'L:LF,LF;R:RF,RF'});
    });
  });

  group('identity / device', () {
    test('getZoneAttributes parses all four fields', () async {
      soap = FakeSoapClient((action) => soapResponse(
          '<CurrentZoneName>TV Room</CurrentZoneName>'
          '<CurrentIcon>x-rincon-roomicon:tv</CurrentIcon>'
          '<CurrentConfiguration>1</CurrentConfiguration>'
          '<CurrentTargetRoomName></CurrentTargetRoomName>'));
      api = SonosApi(client: soap);
      final attrs = await api.getZoneAttributes('10.0.0.1');
      expect(attrs.name, 'TV Room');
      expect(attrs.icon, 'x-rincon-roomicon:tv');
      expect(attrs.configuration, '1');
    });

    test('renameRoom preserves icon/config while changing the name', () async {
      soap = FakeSoapClient((action) => action == 'GetZoneAttributes'
          ? soapResponse('<CurrentZoneName>Old</CurrentZoneName>'
              '<CurrentIcon>x-rincon-roomicon:tv</CurrentIcon>'
              '<CurrentConfiguration>1</CurrentConfiguration>'
              '<CurrentTargetRoomName></CurrentTargetRoomName>')
          : soapResponse(''));
      api = SonosApi(client: soap);
      await api.renameRoom('10.0.0.1', 'Living Room');
      final set = soap.calls.firstWhere((c) => c.action == 'SetZoneAttributes');
      expect(set.args['DesiredZoneName'], 'Living Room');
      expect(set.args['DesiredIcon'], 'x-rincon-roomicon:tv');
      expect(set.args['DesiredConfiguration'], '1');
    });

    test('getLedOn maps "On" to true', () async {
      soap = FakeSoapClient(
          (action) => soapResponse('<CurrentLEDState>On</CurrentLEDState>'));
      api = SonosApi(client: soap);
      expect(await api.getLedOn('10.0.0.1'), isTrue);
    });

    test('setLedOn sends On/Off', () async {
      await api.setLedOn('10.0.0.1', false);
      expect(soap.lastCall.action, 'SetLEDState');
      expect(soap.lastCall.args, {'DesiredLEDState': 'Off'});
    });

    test('setButtonLock sends On/Off', () async {
      await api.setButtonLock('10.0.0.1', true);
      expect(soap.lastCall.action, 'SetButtonLockState');
      expect(soap.lastCall.args, {'DesiredButtonLockState': 'On'});
    });
  });

  group('audio tuning', () {
    test('setBass clamps to -10..10 and posts DesiredBass', () async {
      await api.setBass('10.0.0.1', 42);
      expect(soap.lastCall.action, 'SetBass');
      expect(soap.lastCall.args['DesiredBass'], '10');
    });

    test('getBass parses CurrentBass', () async {
      soap = FakeSoapClient(
          (action) => soapResponse('<CurrentBass>-4</CurrentBass>'));
      api = SonosApi(client: soap);
      expect(await api.getBass('10.0.0.1'), -4);
    });

    test('setLoudness sends 1/0 on the Master channel', () async {
      await api.setLoudness('10.0.0.1', true);
      expect(soap.lastCall.action, 'SetLoudness');
      expect(soap.lastCall.args['Channel'], 'Master');
      expect(soap.lastCall.args['DesiredLoudness'], '1');
    });

    test('setNightMode uses SetEQ with EQType NightMode', () async {
      await api.setNightMode('10.0.0.1', true);
      expect(soap.lastCall.action, 'SetEQ');
      expect(soap.lastCall.args['EQType'], 'NightMode');
      expect(soap.lastCall.args['DesiredValue'], '1');
    });

    test('getSpeechEnhancement reads DialogLevel EQ', () async {
      soap = FakeSoapClient(
          (action) => soapResponse('<CurrentValue>1</CurrentValue>'));
      api = SonosApi(client: soap);
      expect(await api.getSpeechEnhancement('10.0.0.1'), isTrue);
      expect(soap.lastCall.args['EQType'], 'DialogLevel');
    });

    test('setBalance maps -100 (full left) to LF=100, RF=0', () async {
      await api.setBalance('10.0.0.1', -100);
      final lf = soap.calls.firstWhere((c) => c.args['Channel'] == 'LF');
      final rf = soap.calls.firstWhere((c) => c.args['Channel'] == 'RF');
      expect(lf.args['DesiredVolume'], '100');
      expect(rf.args['DesiredVolume'], '0');
    });

    test('getBalance is right minus left', () async {
      soap = FakeSoapClient((action) => soapResponse(
          '<CurrentVolume>40</CurrentVolume>')); // both channels read 40
      api = SonosApi(client: soap);
      expect(await api.getBalance('10.0.0.1'), 0);
    });
  });
}
