import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'package:personal_sonos/src/state/device_settings_store.dart';
import 'support/fake_soap_client.dart';

const _beam = Device(
    uuid: 'BEAM',
    roomName: 'TV Room',
    host: '10.0.0.1',
    model: 'Sonos Beam',
    bondRole: BondRole.coordinator);

void main() {
  test('load reads all settings a Beam supports', () async {
    final soap = FakeSoapClient((action) {
      switch (action) {
        case 'GetBass':
          return soapResponse('<CurrentBass>3</CurrentBass>');
        case 'GetTreble':
          return soapResponse('<CurrentTreble>-2</CurrentTreble>');
        case 'GetLoudness':
          return soapResponse('<CurrentLoudness>1</CurrentLoudness>');
        case 'GetEQ':
          return soapResponse('<CurrentValue>1</CurrentValue>');
        case 'GetLEDState':
          return soapResponse('<CurrentLEDState>On</CurrentLEDState>');
        case 'GetButtonLockState':
          return soapResponse(
              '<CurrentButtonLockState>Off</CurrentButtonLockState>');
        default:
          return soapResponse('');
      }
    });
    final store = DeviceSettingsStore(SonosApi(client: soap));
    await store.load(_beam);

    expect(store.settings.bass, 3);
    expect(store.settings.treble, -2);
    expect(store.settings.loudness, isTrue);
    expect(store.settings.nightMode, isTrue);
    expect(store.settings.speechEnhancement, isTrue);
    expect(store.settings.ledOn, isTrue);
    expect(store.settings.buttonLocked, isFalse);
  });

  test('setBass writes to the device then updates local state', () async {
    final soap = FakeSoapClient();
    final store = DeviceSettingsStore(SonosApi(client: soap));
    await store.setBass(_beam, 5);
    expect(soap.lastCall.action, 'SetBass');
    expect(soap.lastCall.args['DesiredBass'], '5');
    expect(store.settings.bass, 5);
  });
}
