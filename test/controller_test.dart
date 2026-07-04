import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/playback_state.dart';
import 'package:personal_sonos/src/models/sonos_speaker.dart';
import 'package:personal_sonos/src/models/zone_group.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'package:personal_sonos/src/services/ssdp_discovery.dart';
import 'package:personal_sonos/src/state/sonos_controller.dart';

/// Discovery that returns a fixed host without touching the network.
class _FakeDiscovery extends SsdpDiscovery {
  @override
  Future<Set<String>> discover({Duration timeout = const Duration(seconds: 3)}) async {
    return {'192.168.1.10'};
  }

  @override
  void close() {}
}

/// A scriptable [SonosApi] that records commands instead of hitting a speaker.
class _FakeApi extends SonosApi {
  TransportState transport = TransportState.paused;
  int groupVolume = 30;
  bool groupMuted = false;
  final List<String> calls = [];

  ZoneGroup get theGroup => const ZoneGroup(
        id: 'RINCON_A:1',
        coordinator: SonosSpeaker(
            uuid: 'RINCON_A', name: 'Living Room', host: '192.168.1.10'),
        members: [
          SonosSpeaker(uuid: 'RINCON_A', name: 'Living Room', host: '192.168.1.10'),
          SonosSpeaker(uuid: 'RINCON_B', name: 'Kitchen', host: '192.168.1.11'),
        ],
      );

  @override
  Future<List<ZoneGroup>> getZoneGroups(String host) async => [theGroup];

  @override
  Future<TransportState> getTransportState(String host) async => transport;

  @override
  Future<int> getGroupVolume(String host) async => groupVolume;

  @override
  Future<bool> getGroupMute(String host) async => groupMuted;

  @override
  Future<PlaybackState> getPositionInfo(String host, PlaybackState base) async {
    return base.copyWith(title: 'Test Track', artist: 'Tester');
  }

  @override
  Future<void> play(String host) async {
    calls.add('play');
    transport = TransportState.playing;
  }

  @override
  Future<void> pause(String host) async {
    calls.add('pause');
    transport = TransportState.paused;
  }

  @override
  Future<void> next(String host) async => calls.add('next');

  @override
  Future<void> setGroupVolume(String host, int volume) async {
    calls.add('vol:$volume');
    groupVolume = volume;
  }

  @override
  void close() {}
}

void main() {
  test('initialize discovers, builds topology and selects a group', () async {
    final api = _FakeApi();
    final controller =
        SonosController(api: api, discovery: _FakeDiscovery());
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.status, DiscoveryStatus.ready);
    expect(controller.groups, hasLength(1));
    expect(controller.selectedGroup?.coordinator.name, 'Living Room');

    final state = controller.playbackFor(controller.selectedGroup!);
    expect(state.title, 'Test Track');
    expect(state.volume, 30);
  });

  test('togglePlayPause drives the coordinator and flips transport', () async {
    final api = _FakeApi();
    final controller =
        SonosController(api: api, discovery: _FakeDiscovery());
    addTearDown(controller.dispose);
    await controller.initialize();

    final group = controller.selectedGroup!;
    expect(controller.playbackFor(group).transport, TransportState.paused);

    await controller.togglePlayPause(group);
    expect(api.calls, contains('play'));
    expect(controller.playbackFor(group).transport, TransportState.playing);

    await controller.togglePlayPause(group);
    expect(api.calls, contains('pause'));
  });

  test('setGroupVolume updates optimistically and sends the command', () async {
    final api = _FakeApi();
    final controller =
        SonosController(api: api, discovery: _FakeDiscovery());
    addTearDown(controller.dispose);
    await controller.initialize();
    final group = controller.selectedGroup!;

    await controller.setGroupVolume(group, 55);

    expect(controller.playbackFor(group).volume, 55);
    expect(api.calls, contains('vol:55'));
  });

  test('empty discovery yields the empty status', () async {
    final controller = SonosController(
      api: _FakeApi(),
      discovery: _EmptyDiscovery(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.status, DiscoveryStatus.empty);
  });
}

class _EmptyDiscovery extends SsdpDiscovery {
  @override
  Future<Set<String>> discover({Duration timeout = const Duration(seconds: 3)}) async => {};
  @override
  void close() {}
}
