import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/device.dart';
import 'package:personal_sonos/src/models/group.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/models/room.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'package:personal_sonos/src/services/ssdp_discovery.dart';
import 'package:personal_sonos/src/state/household_store.dart';
import 'package:personal_sonos/src/ui/system_map_page.dart';
import 'package:provider/provider.dart';

class _FakeApi extends SonosApi {
  _FakeApi(this._hh);
  final Household _hh;
  @override
  Future<Household> getHousehold(String host) async => _hh;
}

class _FakeDiscovery extends SsdpDiscovery {
  @override
  Future<Set<String>> discover(
          {Duration timeout = const Duration(seconds: 3)}) async =>
      {'10.0.0.1'};
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
            bondRole: BondRole.standalone),
      ],
    ),
  ]),
]);

void main() {
  testWidgets('system map renders rooms once the store is ready',
      (tester) async {
    final store = HouseholdStore(
      api: _FakeApi(_household),
      discovery: _FakeDiscovery(),
      fetchModel: (_) async => 'Sonos Beam',
      pollInterval: const Duration(minutes: 5),
    );
    await store.initialize();
    expect(store.status, HouseholdStatus.ready);

    await tester.pumpWidget(
      ChangeNotifierProvider<HouseholdStore>.value(
        value: store,
        child: const MaterialApp(home: SystemMapPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Sonos Config'), findsOneWidget);
    expect(find.text('TV Room'), findsOneWidget);
    expect(find.text('Rooms'.toUpperCase()), findsOneWidget);

    // Dispose in-body to cancel the poll timer before the framework's
    // pending-timer invariant check at test end.
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
