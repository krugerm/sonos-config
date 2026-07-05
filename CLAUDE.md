# CLAUDE.md

Guidance for Claude Code (and humans) working in this repository.

## What this is

**Sonos Config** — a Flutter app that discovers and **configures** every Sonos
speaker on the local network by speaking the speakers' local **UPnP/SOAP**
interface directly (port 1400). No Sonos account, no cloud, no login.

It is a **discovery & configuration tool**, not a playback controller. It does
the topology/setup operations the official app hides or gets wrong — bonding a
Sub, home-theater surrounds, stereo pairs, room renaming, LED/button lock, and
audio EQ. **Playback, queue, and favorites are intentionally out of scope**
(manage those in Spotify etc.). History: this began as a playback controller;
see `docs/superpowers/specs/` for the pivot design.

## Commands

```bash
flutter pub get            # install dependencies
flutter run -d macos       # run (macOS is the primary target; also linux/ios/…)
flutter analyze            # static analysis — keep this clean
flutter test               # unit + widget tests
flutter build macos        # release build (or build apk/linux/…)
```

There is no CI configured; `flutter analyze` + `flutter test` are the gate.
Always run both before committing non-trivial changes.

## Architecture

Strict one-way layering — UI never talks to the network directly, only through
the stores/actions:

```
models/     immutable domain: Device, Room, Group, Household, Capabilities,
            BondRole, ChangeLine
  Device  = one physical player (uuid, model, host, firmware, bondRole)
  Room    = a coordinator + its bonded satellites (sub/surrounds), one unit
  Group   = a party-mode set of Rooms playing in sync (distinct from bonding)
  Capabilities.forModel(model, role) — derived flags that gate the UI
services/   the Sonos wire protocol
  soap_client.dart       minimal hand-rolled SOAP envelope + response helpers
  ssdp_discovery.dart    SSDP M-SEARCH + unicast /24 fallback scan
  household_parser.dart  GetZoneGroupState XML -> Household (Devices/Rooms/Groups)
  device_info.dart       fetch modelName from /xml/device_description.xml
  sonos_api.dart         typed config methods (bonding, identity, audio/EQ)
actions/    the mutating operations, each a ConfigAction
  config_action.dart     abstract: preview / apply / isSettled / inverse
  topology_actions.dart  BondSub/UnbondSub, Add/RemoveSurround, Create/SeparateStereoPair
  group_actions.dart     JoinGroup / LeaveGroup (party mode)
  rename_action.dart     RenameRoom
state/
  household_store.dart      discovery + topology poll + model enrichment (source of truth)
  action_executor.dart      guided-safe lifecycle: apply -> verify -> undo
  device_settings_store.dart per-device audio + HT tuning + LED/button settings
  group_audio_store.dart    coordinator-scoped group volume + mute
ui/         system_map_page (home), room_detail_page, device_detail_page,
            action_runner (confirm -> progress -> result + undo), theme,
            widgets (Eyebrow/RoleChip/SpecRow), product_glyph, ui_util
```

- **State management:** `provider`. Four `ChangeNotifier` stores
  (`HouseholdStore`, `ActionExecutor`, `DeviceSettingsStore`, `GroupAudioStore`)
  built in `main.dart` over one shared `SonosApi`.
- **Read path:** `HouseholdStore` discovers hosts, loads the `Household` from any
  reachable player, enriches devices with model names, and polls. The UI is
  declarative over its immutable snapshot.
- **Write path:** every change is a `ConfigAction` run through `ActionExecutor`:
  preview → apply (SOAP) → **verify** (poll `HouseholdStore.refresh()` until
  `isSettled` or ~30s timeout) → done/unconfirmed/failed, with one-tap undo when
  a clean inverse exists. Never report success that wasn't observed.
- **Addressing:** bonding/home-theater actions go to the **primary
  (coordinator)** host; per-device settings go to the member's own host.

## Conventions

- **SCPD-first:** before wiring a new SOAP action, verify its exact name +
  argument signature against the device's own service description
  (`/xml/DeviceProperties1.xml`, `/xml/RenderingControl1.xml`, …). Don't guess.
- `InstanceID` is always `0`; single-channel ops use `Channel: Master`.
- Channel-map formats (reproduce from real captures):
  - stereo pair `ChannelMapSet`: `{leftUuid}:LF,LF;{rightUuid}:RF,RF`
  - HT satellite `HTSatChanMapSet`: `{primaryUuid}:LF,RF;{satUuid}:{LR|RR|SW}`
  - unbond: `RemoveHTSatellite(SatRoomUUID={satUuid})`
- **Home-theater EQ targets the coordinator.** Sub/surround tuning
  (`SetEQ` types `SubGain`, `SubPolarity`, `SurroundEnable`, `SurroundLevel`,
  `MusicSurroundLevel`, `HeightChannelLevel`, `AudioDelay`) is set on the HT
  primary (e.g. the Beam), **not** the satellites — they reject it (`803`).
  EQ types are firmware-defined (not in the SCPD) and vary by model, so probe
  with `GetEQ` and capability-gate. See `docs/DEVICE_CAPABILITIES.md` for the
  full per-device catalog.
- Keep XML parsing in `*_parser.dart`, not in widgets. Capability-gate UI
  controls off `Device.capabilities`, never off model-name checks in widgets.
- A group whose members are all invisible (a lone bonded Sub / bridge) is not a
  room; but an *unbonded* invisible device is surfaced via
  `Household.unbondedInvisibleDevices` so it can be bonded.

## Testing approach

Prefer extending the real service classes / injecting fakes over mock
frameworks — constructors are cheap and take injectable dependencies.

- `test/support/fake_soap_client.dart` — records SOAP calls + returns canned
  responses; the basis for `SonosApi`/action tests.
- Pure model/parser tests: `capabilities_test`, `device_test`,
  `household_model_test`, `household_parser_test` (real topology captures).
- `config_actions_test` / `action_executor_test` — action preview/isSettled/
  inverse, and the executor lifecycle (settle / timeout / fault / undo) with a
  scriptable fake household.
- `household_store_test` / `device_settings_store_test` — stores with a fake API
  + fake discovery + fake `fetchModel`.
- `system_map_widget_test` — the home screen renders from a ready store.

## Environment gotchas

- **No speakers in cloud/CI:** an isolated sandbox has no route to a home LAN and
  SSDP returns nothing. You cannot test against real speakers except on the same
  Wi-Fi. Do not claim hardware verification that didn't happen.
- **Cleartext HTTP:** Sonos control is plain HTTP on port 1400. Android needs
  `usesCleartextTraffic`; iOS needs `NSAllowsLocalNetworking`; both are set.
  Don't switch these calls to HTTPS.
- **Permissions already wired:** Android multicast + INTERNET, iOS
  local-network/Bonjour, macOS `network.client`/`network.server` entitlements.
- **iOS multicast on device** additionally needs Apple's multicast entitlement;
  the unicast fallback works without it.
- **Bonding reboots the satellite** (~10-15s) before it re-joins — this is why
  actions verify by polling until the topology settles.

## Design docs

`docs/superpowers/specs/` (design) and `docs/superpowers/plans/` (phased
implementation plans) capture the pivot and the build.
