# Open-Source Readiness Checklist

Polishing tasks to make this project fit for public release. Grouped by
priority: **P0** = do before publishing, **P1** = soon after, **P2** =
nice-to-have. Checked items are done.

**Build status:** macOS, Android (APK), and iOS (`--no-codesign`) all build
successfully; `flutter analyze` clean; 48 tests pass.

## P0 — Before the repo goes public

### Legal & identity
- [x] **`LICENSE`** — MIT.
- [x] **Sonos trademark disclaimer** — in the README and the in-app About dialog.
- [x] **No real device identifiers** — fixtures use anonymized IDs
      (`RINCON_BEAM`, …). Keep it that way.
- [x] **Display name unified** to "Sonos Config" across iOS/macOS/Android
      (internal package `personal_sonos` and bundle IDs left stable). Picking a
      distinct public/store brand name is an optional maintainer decision.

### Correctness of the published surface
- [ ] **Decide the web target.** Discovery uses `dart:io` `RawDatagramSocket`
      (SSDP) + `network_info_plus`, which don't work on Flutter web — a web build
      can't discover speakers. Drop the web target or document it as
      non-functional. Same audit for Windows/Linux (never run against hardware).
- [x] **Repo hygiene** — `.serena/` gitignored; `build/`, `.dart_tool/` already
      ignored.

### CI
- [x] **GitHub Actions** — dart-format + `flutter analyze` + `flutter test` on
      push/PR.

### Docs
- [ ] **README for newcomers** — screenshots/GIF of the system map + a config
      flow, and a short troubleshooting section (nothing found → same-subnet /
      multicast). (Per-platform install steps, model caveats, and the disclaimer
      are already in.)

## P1 — Soon after launch

### Contributor experience
- [x] `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1),
      `SECURITY.md`, issue + PR templates, `CHANGELOG.md`.
- [ ] Dependabot/Renovate config (`flutter pub get` reports ~10 out-of-date
      packages; `network_info_plus` also triggers a Flutter "Built-in Kotlin"
      deprecation warning on Android — worth tracking an upgrade).

### Round out the config feature set (spec'd, API done, UI pending)
- [ ] **Stereo-pair UI.** `CreateStereoPairAction`/`SeparateStereoPairAction`
      exist + are unit-tested, but there's no UI and no *live* verification —
      capture a real stereo-pair `GetZoneGroupState` to validate `isSettled` and
      `stereoLeft/Right` parsing.
- [ ] **Surround add/remove** actions + UI (same `AddHTSatellite`, `:LR`/`:RR`).
- [ ] **Grouping (party mode) UI.** `SonosApi.joinGroup/leaveGroup` exist; no
      `ConfigAction`s or UI yet.
- [ ] **Desktop master–detail layout** for wide screens (current UI is
      navigation-based).

### Robustness
- [ ] **Ethernet discovery.** `network_info_plus.getWifiIP()` is null on a wired
      Mac, so the unicast fallback can't compute a subnet. Enumerate
      `NetworkInterface`s instead.
- [ ] Broaden tests: end-to-end undo, the verify-timeout (`unconfirmed`) UX,
      per-model capability edge cases.
- [ ] Accessibility pass (semantics labels on icon buttons/sliders, dynamic type,
      contrast in both themes).

### Release packaging (needs maintainer secrets/accounts)
- [ ] macOS: code-sign + notarize; ship a DMG. (Current build is unsigned.)
- [ ] Android: release signing config + adaptive icon; set `minSdkVersion`.
- [ ] iOS: document the multicast entitlement requirement for on-device SSDP.

## P2 — Nice to have
- [ ] Multi-model verification matrix (Play:1/3/5, Five, Era 100/300, Arc, Move,
      Roam, Amp, older gens) — verified only on Beam + One SL + Sub. Track
      community-confirmed models in the README.
- [ ] Internationalization (`flutter_localizations` / ARB).
- [ ] In-app theme toggle (currently follows system).
- [ ] Additional device settings: sub gain/polarity, surround level, room
      calibration read-outs (`RenderingControl#SetEQ` exposes more types).
- [ ] Release automation (tag → build macOS/Android artifacts via CI).
- [ ] Promote the design spec to a top-level `ARCHITECTURE.md`.
