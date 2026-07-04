import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/models/group.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/models/room.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'package:personal_sonos/src/services/ssdp_discovery.dart';
import 'package:personal_sonos/src/state/household_store.dart';

class _FakeApi extends SonosApi {
  _FakeApi(this._hh);
  final Household _hh;
  @override
  Future<Household> getHousehold(String host) async => _hh;
}

class _FakeDiscovery extends SsdpDiscovery {
  _FakeDiscovery(this._hosts);
  final Set<String> _hosts;
  @override
  Future<Set<String>> discover({Duration timeout = const Duration(seconds: 3)}) async =>
      _hosts;
}

const _household = Household(groups: [
  Group(id: 'g', coordinatorUuid: 'BEAM', rooms: [
    Room(
      name: 'TV Room',
      coordinator: Device(
          uuid: 'BEAM',
          roomName: 'TV Room',
          host: '10.0.0.1',
          bondRole: BondRole.coordinator),
      satellites: [
        Device(
            uuid: 'SUB',
            roomName: 'TV Room',
            host: '10.0.0.2',
            invisible: true,
            bondRole: BondRole.sub),
      ],
    ),
  ]),
]);

void main() {
  test('initialize discovers, loads, and enriches devices with models', () async {
    final store = HouseholdStore(
      api: _FakeApi(_household),
      discovery: _FakeDiscovery({'10.0.0.1'}),
      fetchModel: (host) async =>
          host == '10.0.0.1' ? 'Sonos Beam' : 'Sonos Sub',
      pollInterval: const Duration(minutes: 5),
    );
    await store.initialize();

    expect(store.status, HouseholdStatus.ready);
    expect(store.household!.deviceByUuid('BEAM')!.model, 'Sonos Beam');
    expect(store.household!.deviceByUuid('SUB')!.model, 'Sonos Sub');
    // Enrichment feeds capability derivation.
    expect(store.household!.deviceByUuid('BEAM')!.capabilities.canBondSub, isTrue);
    store.dispose();
  });

  test('empty discovery yields the empty status', () async {
    final store = HouseholdStore(
      api: _FakeApi(_household),
      discovery: _FakeDiscovery({}),
      fetchModel: (_) async => null,
    );
    await store.initialize();
    expect(store.status, HouseholdStatus.empty);
    store.dispose();
  });
}
