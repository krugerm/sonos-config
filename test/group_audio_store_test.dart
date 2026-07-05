import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'package:personal_sonos/src/state/group_audio_store.dart';
import 'support/fake_soap_client.dart';

void main() {
  test('load reads group volume + mute from the coordinator', () async {
    final soap = FakeSoapClient((action) => switch (action) {
          'GetGroupVolume' => soapResponse('<CurrentVolume>40</CurrentVolume>'),
          'GetGroupMute' => soapResponse('<CurrentMute>1</CurrentMute>'),
          _ => soapResponse(''),
        });
    final store = GroupAudioStore(SonosApi(client: soap));
    await store.load('10.0.0.1');
    expect(store.volume, 40);
    expect(store.muted, isTrue);
  });

  test('setVolume/setMuted write to the loaded host and update state',
      () async {
    final soap = FakeSoapClient();
    final store = GroupAudioStore(SonosApi(client: soap));
    await store.load('10.0.0.1');

    await store.setVolume(30);
    expect(soap.lastCall.action, 'SetGroupVolume');
    expect(soap.lastCall.args['DesiredVolume'], '30');
    expect(store.volume, 30);

    await store.setMuted(true);
    expect(soap.lastCall.action, 'SetGroupMute');
    expect(soap.lastCall.args['DesiredMute'], '1');
    expect(store.muted, isTrue);
  });
}
