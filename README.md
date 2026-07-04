# Personal Sonos

A small, self-contained Flutter app to **discover and control every Sonos
speaker on your local network** — no Sonos account, no cloud, no login. It talks
directly to your speakers over their local UPnP/SOAP interface, the same
protocol the official app and projects like [`node-sonos`](https://github.com/bencevans/node-sonos)
and [SoCo](https://github.com/SoCo/SoCo) use.

## Features

- **Automatic discovery** of all Sonos players via SSDP (UDP multicast), with a
  unicast subnet-scan fallback for Wi-Fi that blocks multicast.
- **Whole-house topology** — rooms, stereo pairs and grouped zones are read from
  a single `ZoneGroupTopology` query, so one reachable speaker maps the lot.
- **Playback control** per group: play / pause / next / previous and seek.
- **Shuffle & repeat** — toggle shuffle and cycle repeat off / all / one.
- **Favorites** — browse your Sonos Favorites and start one on any room.
- **Grouping** — add or remove rooms from a group for synchronised playback.
- **Now Playing** with album art, title, artist, album and a live progress bar.
- **Volume** — group volume + mute, plus a per-speaker volume slider for every
  member of a grouped zone.
- **Live updates** — the selected group is polled so state stays in sync when
  you (or someone else) change things from another controller.
- **Responsive UI** — master–detail on tablet/desktop, a stacked
  list → Now Playing flow on phones. Light & dark themes.

## How it works

Sonos players expose a local UPnP stack on **port 1400**. This app speaks it
directly:

| Concern            | Mechanism                                                             |
| ------------------ | -------------------------------------------------------------------- |
| Discovery          | SSDP `M-SEARCH` for `urn:schemas-upnp-org:device:ZonePlayer:1`        |
| Topology           | `ZoneGroupTopology#GetZoneGroupState`                                 |
| Transport          | `AVTransport` — `Play`, `Pause`, `Next`, `Previous`, `Seek`, position |
| Shuffle / repeat   | `AVTransport` — `GetTransportSettings` / `SetPlayMode`               |
| Favorites / queue  | `ContentDirectory#Browse` (`FV:2`, `Q:0`) + `SetAVTransportURI`       |
| Grouping           | `SetAVTransportURI` `x-rincon:` / `BecomeCoordinatorOfStandaloneGroup`|
| Group volume       | `GroupRenderingControl` — `GetGroupVolume` / `SetGroupVolume` / mute  |
| Per-speaker volume | `RenderingControl` — `GetVolume` / `SetVolume`                        |
| Track metadata     | DIDL-Lite parsed from `GetPositionInfo`                               |

Rather than pull in a heavyweight generic UPnP dependency, the SOAP envelope is
hand-rolled in a compact client ([`soap_client.dart`](lib/src/services/soap_client.dart)) —
Sonos only needs a handful of actions, and this keeps behaviour predictable.

### Open-source libraries leveraged

- [`http`](https://pub.dev/packages/http) — SOAP POSTs and album-art fetches.
- [`xml`](https://pub.dev/packages/xml) — parsing SOAP / DIDL / topology XML.
- [`provider`](https://pub.dev/packages/provider) — state management.
- [`network_info_plus`](https://pub.dev/packages/network_info_plus) — local IP for
  the unicast discovery fallback.

## Project layout

```
lib/
  main.dart                       app entry, theme, provider wiring
  src/
    models/                       SonosSpeaker, ZoneGroup, PlaybackState
    services/
      soap_client.dart            minimal Sonos SOAP client
      ssdp_discovery.dart         SSDP multicast + unicast fallback
      sonos_api.dart              typed wrapper over the SOAP actions
      topology_parser.dart        GetZoneGroupState -> ZoneGroup list
      didl_parser.dart            DIDL-Lite -> track metadata
    state/
      sonos_controller.dart       ChangeNotifier: discovery, polling, commands
    ui/
      home_page.dart              responsive master–detail / stacked layout
      speaker_list_panel.dart     the rooms list
      now_playing_panel.dart      art, seek bar, transport, play modes, volumes
      favorites_sheet.dart        browse & play Sonos Favorites
      group_sheet.dart            add/remove rooms from a group
      widgets/                    reusable UI pieces
test/
  parsers_test.dart               topology / DIDL / metadata parsing
  controller_test.dart            end-to-end controller flow with fakes
```

## Running it

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.22+). The **device running the app must be on the same Wi-Fi/LAN as your
Sonos speakers.**

```bash
flutter pub get

# Pick a target:
flutter run              # attached device / emulator
flutter run -d macos     # or -d linux, -d windows
flutter build apk        # Android release
```

On first launch the app scans the network; grant the **local network** prompt
on iOS/macOS so discovery can work. If nothing is found, tap the refresh icon
to rescan.

## Platform permissions (already configured)

- **Android** — `INTERNET`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`,
  and `usesCleartextTraffic` (Sonos control is plain HTTP).
- **iOS** — `NSLocalNetworkUsageDescription`, `NSBonjourServices`, and
  `NSAllowsLocalNetworking`. Note: sending SSDP multicast on a **physical**
  iPhone additionally requires Apple's
  [multicast networking entitlement](https://developer.apple.com/contact/request/networking-multicast),
  which needs approval on your developer account. The unicast fallback works
  without it.
- **macOS** — sandbox `network.client` + `network.server` entitlements.

## Testing

```bash
flutter test      # parsers + full controller flow (no hardware needed)
flutter analyze   # clean
```

The controller tests inject fake discovery/API implementations, so the whole
discover → topology → playback → command flow is exercised without a real
speaker.

## Notes & limitations

- Favorites cover the common "start something playing" path. Deep browsing of a
  music service's full catalogue (search, drilling into playlists/albums) isn't
  implemented — the `ContentDirectory#Browse` plumbing in `SonosApi` is the hook
  to extend it.
- Discovery relies on the controller device sharing the speakers' subnet;
  VLAN-segmented IoT networks may need the multicast fallback or an mDNS reflector.

## Verified against real hardware?

The networking, SOAP wire format and control flow are covered by unit and
integration tests (17 tests, parsers + full controller flow with injected
fakes), and the app builds for Linux/Android/iOS/macOS/Windows/web. It has
**not** yet been exercised against physical speakers from CI — that requires
running on the same LAN as your Sonos system. Do a `flutter run` at home with
your soundbar, Sub and Sonos Ones powered on to confirm discovery and control
end-to-end.
