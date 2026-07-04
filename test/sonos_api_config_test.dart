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
}
