# Device Config Capabilities & Surfacing Plan

A catalog of the configuration settings and actions the Sonos devices actually
expose over their local UPnP interface (read from each device's SCPD), and a plan
to surface all of them in the app.

Legend: ✅ surfaced today · 🟡 API/action exists, no UI · ⬜ not implemented ·
⛔ intentionally out of scope.

## Services by device role

The config surface differs by role — a bonded satellite proxies transport through
its coordinator, so it exposes fewer services.

| Service | Coordinator (e.g. Beam) | Satellite / standalone (Sub, One SL) |
| --- | --- | --- |
| DeviceProperties | ✔ | ✔ |
| RenderingControl | ✔ | ✔ |
| AlarmClock | ✔ | ✔ |
| GroupManagement | ✔ | ✔ |
| SystemProperties | ✔ | ✔ |
| ZoneGroupTopology | ✔ | ✔ |
| GroupRenderingControl | ✔ | — |
| HTControl | ✔ (home-theater bars) | — |
| AVTransport / ContentDirectory / Queue / MusicServices / VirtualLineIn / QPlay | ✔ | — |

(The last row is playback/streaming — ⛔ out of scope for this app.)

## The config catalog

Numeric ranges and enums below are read from the SCPDs. `InstanceID` is always
`0`; `Channel` is `Master` unless noted.

### Identity & device — `DeviceProperties`
| Action | What it configures | Status |
| --- | --- | --- |
| `SetZoneAttributes(name, icon, config, targetRoom)` | Rename room; room icon | ✅ rename · ⬜ icon picker |
| `SetLEDState(On/Off)` | Status light | ✅ |
| `SetButtonLockState(On/Off)` | Lock touch controls | ✅ |
| `EnterConfigMode` / `ExitConfigMode` | Setup/diagnostic modes | ⛔ advanced |
| `RoomDetectionStartChirping` / `StopChirping` | Trueplay tuning chirps | ⛔ needs mic flow |

### Bonding & topology — `DeviceProperties` / `GroupManagement`
| Action | What it configures | Status |
| --- | --- | --- |
| `AddHTSatellite(HTSatChanMapSet)` | Bond a Sub (`:SW`) or surround (`:LR`/`:RR`) | ✅ Sub · 🟡 surrounds (action only) |
| `RemoveHTSatellite(SatRoomUUID)` | Unbond a satellite | ✅ Sub · 🟡 surrounds |
| `CreateStereoPair(ChannelMapSet)` | Pair two speakers L/R | 🟡 action + tests, no UI |
| `SeparateStereoPair(ChannelMapSet)` | Split a pair | 🟡 |
| `AddBondedZones` / `RemoveBondedZones(…, KeepGrouped)` | Alternate bonding path | ⬜ |
| `AddMember` / `RemoveMember` (+ `x-rincon:` join/leave) | Group/ungroup rooms (party mode) | 🟡 join/leave API, no UI |

### Audio tuning — `RenderingControl`
| Action | Range / values | Status |
| --- | --- | --- |
| `SetVolume(Channel, 0..100)` | Per-speaker volume | ✅ |
| `SetMute(Channel, bool)` | Per-speaker mute | ⬜ |
| `SetBass(-10..10)` / `SetTreble(-10..10)` | Tone | ✅ |
| `SetLoudness(bool)` | Loudness | ✅ |
| `SetEQ(NightMode, 0/1)` | Night mode | ✅ |
| `SetEQ(DialogLevel, 0/1)` | Speech enhancement | ✅ |
| `SetEQ(SubGain −15..15, SubEnabled, SubPolarity, SubCrossover)` | Sub level/tuning | ⬜ |
| `SetEQ(SurroundEnable, SurroundLevel, MusicSurroundLevel, SurroundMode, HeightChannelLevel)` | Home-theater surrounds | ⬜ |
| `SetEQ(AudioDelay)` | Lip-sync delay | ⬜ |
| Balance via `SetVolume(LF/RF)` | −100..100 | ✅ |
| `SetOutputFixed(bool)` | Fixed line-out (Amp/Port/Connect) | ⬜ capability-gated |
| `SetRoomCalibrationStatus(bool)` | Trueplay on/off | ⬜ |
| `RampToVolume`, `SetChannelMap`, `SetVolumeDB` | playback/advanced | ⛔ |

> EQ types are firmware-defined and **not** listed in the SCPD; the valid set
> varies by model. The app must probe with `GetEQ`/handle faults and
> capability-gate them (Sub-only, home-theater-only).

### Group audio — `GroupRenderingControl` (coordinator only)
| Action | Status |
| --- | --- |
| `SetGroupVolume` / `SetGroupMute` / `SetRelativeGroupVolume` | ⬜ (dropped with playback; useful as room-level config) |

### Home theater / TV — `HTControl` (home-theater bars only)
| Action | What it configures | Status |
| --- | --- | --- |
| `SetIRRepeaterState(On/Off)` | IR repeater | ⬜ |
| `SetLEDFeedbackState(On/Off)` | TV-control LED feedback | ⬜ |
| `LearnIRCode` / `CommitLearnedIRCodes` / `IdentifyIRRemote` | Program a TV remote | ⛔ advanced |

### Alarms & time — `AlarmClock`
| Action | Status |
| --- | --- |
| `CreateAlarm` / `UpdateAlarm(ID,…)` / `DestroyAlarm(ID)` | ⬜ |
| `SetTimeZone(Index, AutoAdjustDst)` · `SetTimeServer` · `SetFormat` · `SetDailyIndexRefreshTime` | ⬜ |

### System — `SystemProperties`
| Action | Status |
| --- | --- |
| `SetString` / `Remove` (household key/values) | ⛔ internal |
| `AddAccountX` / `AddOAuthAccountX` / `RemoveAccount` / `SetAccountNicknameX` | ⛔ music-service accounts (SMAPI) |

## Surfacing plan

**Status: Phases A, B, C implemented ✅ · Phases D, E parked 🛑 (maintainer
decision).** Topology mutations (B) are unit-tested with fakes, not live-fired on
a working home theater.

Each item maps cleanly to the existing architecture: **instant, non-rebooting
settings** become `DeviceSettingsStore` methods + `SonosApi` calls; **topology
changes** become `ConfigAction`s (preview → apply → verify → undo). New actions
are SCPD-verified before wiring.

First, extend the capability model (`Capabilities.forModel`) with the flags these
phases gate on: `hasSubTuning`, `hasSurroundTuning`, `isHomeTheater`,
`hasIrControl`, `hasFixedOutput`, `hasTrueplay`, plus a role/service-derived
`isCoordinator` for group-level controls.

**Phase A ✅ — Finish per-device audio (`DeviceSettingsStore`, instant, low-risk).**
Per-speaker mute; Sub tuning (`SubGain`/`SubEnabled`/`SubPolarity`/`SubCrossover`);
home-theater surround tuning (`SurroundEnable`/`SurroundLevel`/`MusicSurroundLevel`
/`HeightChannelLevel`/`AudioDelay`); `SetOutputFixed`; Trueplay toggle. All
capability-gated; probe `GetEQ` and hide unsupported types. *(Verify whether Sub/
surround EQ targets the coordinator or the satellite host.)*

**Phase B ✅ — Topology actions UI (`ConfigAction`, guided-safe).** Wire the existing
stereo-pair and surround actions into the UI; add a grouping (party-mode) join/
leave flow; add a room-icon picker. Capture real `GetZoneGroupState` fixtures for
stereo-pair/surround to validate `isSettled`.

**Phase C ✅ — Group audio (coordinator).** Room-level group volume + mute via
`GroupRenderingControl`, shown on the room detail.

**Phase D — Home theater / TV (`HTControl`). 🛑 DO NOT PROCEED** (maintainer
decision). IR-repeater / TV LED-feedback toggles are parked.

**Phase E — Alarms & time (`AlarmClock`). 🛑 DO NOT PROCEED** (maintainer
decision). Alarms and time settings are parked.

**Out of scope (⛔).** Playback/queue/streaming services, music-service account
management, `EnterConfigMode`, Trueplay chirp tuning, raw `SetString`.

### Effort & sequencing
Phase A and C are the cheapest, highest-value (pure per-device/coordinator
settings). Phase B is the flagship "config the official app won't" work but needs
real multi-device fixtures to verify. D and E are additive, capability-gated
surfaces. Each phase is independently shippable and testable with injected fakes.
