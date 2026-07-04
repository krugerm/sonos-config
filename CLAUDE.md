# CLAUDE.md

Guidance for Claude Code (and humans) working in this repository.

## What this is

**Personal Sonos** — a Flutter app that discovers and controls every Sonos
speaker on the local network by speaking the speakers' local **UPnP/SOAP**
interface directly (port 1400). No Sonos account, no cloud API, no login.

## Commands

```bash
flutter pub get            # install dependencies
flutter run                # run on attached device (or -d macos/linux/android/…)
flutter analyze            # static analysis — keep this clean
flutter test               # unit + controller integration tests
flutter build apk          # Android release (or build linux/macos/ios/web)
```

There is no CI configured; `flutter analyze` + `flutter test` are the gate.
Always run both before committing non-trivial changes.

## Architecture

Strict one-way layering — UI never talks to the network directly, only through
the controller:

```
models/     plain data: SonosSpeaker, ZoneGroup, PlaybackState, PlayMode, MediaItem
services/   the Sonos wire protocol
  soap_client.dart      minimal hand-rolled SOAP envelope + response helpers
  ssdp_discovery.dart   SSDP multicast M-SEARCH + unicast /24 fallback scan
  sonos_api.dart        typed methods per SOAP action (transport, volume, browse, grouping)
  topology_parser.dart  GetZoneGroupState XML -> List<ZoneGroup>
  didl_parser.dart      DIDL-Lite -> track metadata / MediaItem list
state/
  sonos_controller.dart ChangeNotifier: discovery, polling loop, all commands
ui/         screen-level widgets (home_page, *_panel, *_sheet); read state via
            provider, call controller methods
  widgets/  small reusable pieces (album_art, status_view, transport_controls,
            volume_control) — put shared, stateless UI here, not in screens
```

- **State management:** `provider` (`ChangeNotifier` = `SonosController`). It is
  the single source of truth; the widget tree is declarative over it.
- **Data flow:** `SonosController` owns a `SonosApi` and `SsdpDiscovery`. It
  discovers hosts, loads topology from any reachable player, polls the selected
  group every 2s, and exposes optimistic command methods.
- **Addressing:** transport/group-volume commands go to the group
  **coordinator**; per-speaker volume goes to the member's own host.

## Conventions

- `InstanceID` is always `0`; volume channel is always `Master`.
- New Sonos actions: add the service to the `SonosService` enum in
  `soap_client.dart` (control path + service type), then a typed method on
  `SonosApi`, then a command on `SonosController`. Keep XML parsing in the
  `*_parser.dart` files, not in widgets.
- Commands should update local `PlaybackState` optimistically where it helps the
  UI feel responsive (volume, play/pause), then reconcile on the next poll.
- Network calls in the controller are wrapped in `try/catch` that swallow
  transient errors — the polling loop retries. Don't let one failed sub-call
  blank the whole tile.
- Name clash to remember: our repeat enum is `SonosRepeatMode` (Flutter Material
  already exports a `RepeatMode`).

## Testing approach

- `test/parsers_test.dart` — pure functions: topology, DIDL/favorites, play-mode
  round-trip. No I/O.
- `test/controller_test.dart` — drives the full discover → topology → playback →
  command flow with **injected fakes** (`extends SonosApi` / `SsdpDiscovery`
  with overridden methods). This is how to test behaviour without hardware.

Prefer extending the real service classes and overriding methods over mocking
frameworks — the constructors are cheap and take injectable dependencies.

## Environment gotchas

- **No speakers in cloud/CI:** an isolated sandbox has no route to a home LAN
  (its IP is in the RFC 5737 test range) and SSDP returns nothing. You cannot
  test against real speakers except on the same Wi-Fi. Do not claim hardware
  verification that didn't happen.
- **Cleartext HTTP:** Sonos control is plain HTTP on port 1400. Android needs
  `usesCleartextTraffic`; iOS needs `NSAllowsLocalNetworking`; both are already
  set. Don't switch these calls to HTTPS.
- **Permissions already wired:** Android multicast + INTERNET, iOS
  local-network/Bonjour, macOS `network.client`/`network.server` entitlements.
  Adding network features usually needs no permission changes.
- **iOS multicast on device:** sending SSDP from a physical iPhone additionally
  requires Apple's multicast entitlement (needs account approval); the unicast
  fallback works without it.
- **Running `flutter` as root** prints a warning and needs
  `git config --global --add safe.directory <flutter-sdk>`; it still works.

## Known extension points

- Deep music-service browsing (search, drill into albums/playlists) — the
  `ContentDirectory#Browse` plumbing in `SonosApi` is the hook.
- Queue management UI — `browseQueue` (`Q:0`) already exists in `SonosApi`.
