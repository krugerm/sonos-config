# Personal Sonos → Discovery & Configuration Tool — Design

**Date:** 2026-07-04
**Status:** Approved (Sections 1–2 reviewed live; 3–5 delegated for autonomous completion)

## 1. Purpose & pivot

Repurpose Personal Sonos from a **playback controller** into a **Sonos discovery &
configuration tool**. Playback and queueing move out of scope — the user manages
those in Spotify and similar apps. The new app does two things equally well:

1. **Read-only system map** — a trustworthy inventory of every speaker (model, IP,
   firmware, UUID, health) and how rooms, bonds, and groups are wired.
2. **Broad configuration editor** — change device/room settings, including the
   bonding/topology operations the official Sonos app hides or gets wrong (the
   motivating example: bonding a Sub into a Beam home theater via `AddHTSatellite`,
   which the official app failed to do).

**Safety posture: guided & safe.** Every mutating action shows a plain-English
preview of what will change, confirms, applies, **verifies the result after the
speaker reboot settles**, and offers one-tap **undo** where a clean inverse exists.
The app must never claim a success it hasn't verified.

**Primary target:** macOS / desktop (master–detail). Flutter's responsive layout is
retained so it still works on a phone, but desktop is the design center.

**Approach:** rebuild the state/domain layer from scratch (chosen over strip-and-
extend) on top of the reused low-level services. The hard-won, dangerous-to-rewrite
code (SSDP quirks, topology parsing, SOAP envelope) is kept; the state layer and UI
are redesigned around the config domain.

## 2. Domain model

Three first-class concepts replace today's conflated `SonosSpeaker` + `ZoneGroup`:

- **Device** — one physical unit.
  `uuid, roomName, model, host, firmware, invisible`, plus:
  - **bondRole**: `standalone | coordinator | sub | surroundLeft | surroundRight |
    stereoLeft | stereoRight`
  - **capabilities**: a derived `Capabilities` set (see below)
- **Room (Zone)** — a coordinator **plus its bonded satellites**, presented as one
  unit. This is what you *configure*. Example: TV Room = Beam + 2 surround One SLs +
  Sub = one Room, four Devices.
- **Group** — a *party-mode* set of Rooms playing in sync (`x-rincon:` joins).
  Distinct from bonding.

Keeping **Room (bonded) vs Group (synced) vs Device (physical)** separate is what
lets the UI and actions target the right level.

**Capabilities** are derived per-device from model + topology, e.g.
`canBondSub, canAddSurrounds, canStereoPair, hasBassTreble, hasLoudness,
hasNightMode, hasLed, hasButtonLock`. UI shows/enables actions off capabilities
rather than hard-coding model names.

The whole household is parsed once per poll from `GetZoneGroupState` + each device's
`device_description.xml` into an **immutable `Household` snapshot**
(`Household { devices, rooms, groups }`).

## 3. State layer & the action lifecycle

Replace the monolithic `SonosController` with **focused stores**, each with one job:

- **`DiscoveryService`** — SSDP multicast + unicast `/24` fallback → set of reachable
  hosts. Reused from today almost unchanged.
- **`HouseholdStore`** (`ChangeNotifier`) — the read-only system map. Polls
  `GetZoneGroupState` + device descriptions, parses into the immutable `Household`.
  Single source of truth for *what is*. Everything visual reads from here.
- **`ActionExecutor`** (`ChangeNotifier`) — runs every mutating change through one
  uniform lifecycle; reconciles by re-reading `HouseholdStore` until reality matches
  intent.
- **`DeviceSettingsStore`** — lazily reads/writes per-device settings not present in
  the topology snapshot (bass/treble/loudness/balance/night-mode, LED, button-lock).

State management stays on **provider / `ChangeNotifier`** (already a dependency; no
new state library — YAGNI).

### The `ConfigAction` abstraction (core)

Every bond/pair/rename/EQ change is a `ConfigAction`:

```dart
abstract class ConfigAction {
  String get title;                        // "Bond Sub to TV Room"
  List<ChangeLine> preview(Household h);   // structured before → after
  bool get isReversible;
  Future<void> apply(SonosApi api);        // the SOAP call(s)
  bool isSettled(Household after);         // expected end-state observed?
  ConfigAction? inverse(Household h);      // for undo, or null
}
```

`ChangeLine` is a small struct: `{ label, before, after }` for rendering the preview.

### Guided-safe lifecycle (run by `ActionExecutor` for all actions)

```
preview → confirm → apply → verify (poll HouseholdStore until isSettled, ~30s timeout)
        → done (+ undo if reversible)  │  failed (SOAP fault)  │  unconfirmed (timeout)
```

- **verify** handles reboots: re-poll until `isSettled` (e.g. "Sub is now a satellite
  of TV Room") or time out.
- **undo** re-dispatches `inverse()` (e.g. `RemoveHTSatellite`) through the same
  lifecycle.
- SOAP faults (e.g. UPnP `714`/`701`) surface verbatim as a failed action.
- Timeout is reported as **"applied, but not confirmed within 30s"** — never a false
  success.

### v1 concrete actions

Topology/bonding: `BondSub`, `UnbondSub`, `CreateStereoPair`, `SeparateStereoPair`,
`AddSurround`, `RemoveSurround`, `JoinGroup`, `LeaveGroup`.
Identity/device: `RenameRoom`, `SetLed`, `SetButtonLock`.
Audio: `SetVolume`, `SetBalance`, `SetBass`, `SetTreble`, `SetLoudness`,
`SetNightMode`, `SetSpeechEnhancement`.

Adding a new operation later = one `ConfigAction` subclass; preview/confirm/verify/
undo/error-handling come for free.

## 4. UI / information architecture

macOS-primary master–detail; responsive fallback to stacked navigation on narrow
widths.

- **System Map (home)** — master–detail.
  - Left: **Rooms** (each showing bonded devices as chips, coordinator marked),
    **Groups** (party-mode links, with join/leave), any **standalone/unassigned**
    devices, and discovery status + rescan.
  - Right: detail for the selected Room or Device.
- **Room detail** — identity (rename, icon); topology actions (bond/unbond Sub,
  add/remove surrounds, create/separate stereo pair, join/leave group); member list
  (each bonded Device with its role, tap → Device detail).
- **Device detail** — read-only diagnostics (model, IP, firmware, UUID, connection
  type/signal, bond role); capability-gated audio tuning (volume + balance, bass,
  treble, loudness, night mode / speech enhancement); device settings (LED,
  button lock).
- **Action flow** — confirm sheet renders the `ChangeLine` preview (before → after);
  Apply shows a progress/verify indicator ("applying… waiting for TV Room to
  settle…"); result shows success + **Undo** (if reversible), or the verbatim UPnP
  error, or the timeout message.

Controls are shown/enabled strictly off `Capabilities`, so a device never offers a
control it can't honor.

## 5. Error handling

- **SOAP faults** → surfaced as failed actions with the parsed UPnP `errorCode` +
  `errorDescription` (reuse `SoapClient._extractFault`).
- **Verify timeout (~30s)** → "applied, but couldn't confirm — check the system map."
  Not a hard failure.
- **Discovery empty** → empty state + rescan; unicast fallback retained.
- **Transient poll errors** → swallowed; polling continues (as today).
- **Invariant:** the UI never reports success it hasn't observed in a fresh
  `Household` snapshot (the lesson from the favorites false-"Playing" bug).

## 6. Testing

Reuse the inject-fakes approach (extend real service classes, override methods):

- **Household parser / domain** (pure, no I/O): topology XML → `Household`
  (Devices/Rooms/Groups); capability derivation per model. Fixtures from real 2026
  captures: Beam HT with Sub bonded, Beam HT with Sub as a standalone invisible group
  (the phantom-Sub regression), stereo pair, ungrouped.
- **`ConfigAction`** (pure): `preview` lines, `isSettled` predicate, and `inverse()`
  correctness for each action.
- **`ActionExecutor`**: fake `SonosApi` + a scriptable fake `Household` that
  transitions after `apply`. Assert lifecycle paths: apply → settle → done; verify
  timeout; SOAP fault → failed; undo re-dispatches inverse.
- **Stores**: `HouseholdStore` builds a snapshot from fake discovery + api;
  `DeviceSettingsStore` read/write round-trips.

Gate: `flutter analyze` clean + `flutter test`.

## 7. Migration / file plan

**Reused (kept, lightly evolved):**
`services/soap_client.dart` (extend `SonosService` enum as needed — `DeviceProperties`
and `RenderingControl` already present), `services/ssdp_discovery.dart`,
`services/topology_parser.dart` (evolves into the richer household parser).

**Removed (playback stack):**
`services/didl_parser.dart`, `models/media_item.dart`, `models/playback_state.dart`,
`models/play_mode.dart`, `state/sonos_controller.dart`, `ui/now_playing_panel.dart`,
`ui/favorites_sheet.dart`, playback-only widgets (`transport_controls.dart`; reassess
`album_art.dart`). Remove browse/favorites/queue/transport/play-mode methods from
`services/sonos_api.dart`. Remove playback tests.

**Added:**
- `models/`: `device.dart`, `room.dart`, `group.dart`, `household.dart`,
  `capabilities.dart`, `bond_role.dart`, `change_line.dart`
- `services/`: `household_parser.dart`; extend `sonos_api.dart` with
  `DeviceProperties` (`addHTSatellite`, `removeHTSatellite`, `createStereoPair`,
  `separateStereoPair`, `setZoneAttributes` for rename/icon, `setLEDState`,
  `setButtonLockState`) and `RenderingControl` EQ (`getBass`/`setBass`,
  `getTreble`/`setTreble`, `getLoudness`/`setLoudness`, balance via LF/RF channel
  volumes, night mode / speech enhancement via `SetEQ`)
- `actions/`: `config_action.dart` + the v1 concrete actions
- `state/`: `household_store.dart`, `action_executor.dart`, `device_settings_store.dart`
  (and keep/rename `discovery_service.dart`)
- `ui/`: `system_map_page.dart`, `room_detail.dart`, `device_detail.dart`,
  `action_confirm_sheet.dart`, plus small widgets (reuse `volume_control.dart`,
  `status_view.dart` where they fit)

**SCPD-first rule:** every new SOAP action's exact name + argument signature is
verified against the device's own service description (e.g. `/xml/DeviceProperties1.xml`,
`/xml/RenderingControl1.xml`) before wiring it — as was done for `AddHTSatellite`.
Channel-map formats to reproduce from real data:
- Stereo pair `ChannelMapSet`: `{leftUUID}:LF,LF;{rightUUID}:RF,RF`
- HT satellite `HTSatChanMapSet`: `{primaryUUID}:LF,RF;{satUUID}:{LR|RR|SW}`
- Unbond: `RemoveHTSatellite(SatRoomUUID={satUUID})`

## 8. Out of scope (v1)

Playback, queue, favorites, now-playing, transport, play modes; alarms/clock; music
service (SMAPI) integration; multi-household / remote access; writing to cloud
settings. These may be revisited later but are explicitly excluded here.
