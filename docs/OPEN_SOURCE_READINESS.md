# Open-Source Readiness Checklist

Polishing tasks to make this project fit for public release. Grouped by
priority: **P0** = do before publishing, **P1** = soon after, **P2** =
nice-to-have. Items reference concrete gaps in the current codebase.

## P0 — Before the repo goes public

### Legal & identity
- [ ] **Add a `LICENSE`** (MIT or Apache-2.0). There is none today.
- [ ] **Sonos trademark disclaimer.** Add a prominent note in the README and an
      in-app "About" that this is an **unofficial** tool, not affiliated with or
      endorsed by Sonos, Inc.; "Sonos" is their trademark. (The app name/icon
      lean on Sonos brand cues, so this matters.)
- [ ] **Scrub real device identifiers.** Test fixtures and the design docs embed
      the author's real RINCON UUIDs and firmware (`RINCON_1111111111101400`,
      `RINCON_2222222222201400`, etc.). Replace with obviously-fake IDs in
      `test/*` and `docs/superpowers/*`.
- [ ] **Finalize naming.** The Dart package is still `personal_sonos`, the app
      title is "Sonos Config", and the macOS bundle id is
      `com.personalsonos.personalSonos`. Pick one public name and make package
      name, display names (macOS/iOS/Android), and bundle/application IDs
      consistent.

### Correctness of the published surface
- [ ] **Decide the web target.** Discovery uses `dart:io` `RawDatagramSocket`
      (SSDP) and `network_info_plus`, neither of which works on Flutter web — the
      web build can't actually discover speakers. Either **drop web** (remove the
      `web/` target and the `flutter_launcher_icons` web entry) or clearly
      document it as non-functional. Do the same audit for Windows/Linux (never
      run against hardware).
- [ ] **Repo hygiene.** Add `.serena/` (and any other tool dirs) to
      `.gitignore`; confirm `build/`, `.dart_tool/` are ignored; remove stray
      artifacts.

### CI
- [ ] **Add GitHub Actions** running `flutter analyze` + `flutter test` on every
      PR (the repo has no CI; these two commands are the stated quality gate).

### Docs
- [ ] **README for newcomers:** screenshots/GIF of the system map + a config
      flow, per-platform install/run steps, supported-model caveats, the
      "not affiliated with Sonos" note, and a short troubleshooting section
      (nothing found → same-subnet requirement / multicast).

## P1 — Soon after launch

### Contributor experience
- [ ] `CONTRIBUTING.md` (build, test, `flutter analyze` gate, the SCPD-first rule
      for new SOAP actions, the "inject fakes" testing convention).
- [ ] `CODE_OF_CONDUCT.md`.
- [ ] `SECURITY.md` — how to report issues (relevant: the app sends unauthenticated
      control commands on the LAN).
- [ ] `.github/` issue + PR templates; a `CHANGELOG.md`.
- [ ] Dependabot/Renovate config (the current `flutter pub get` reports ~10
      out-of-date packages).

### Round out the config feature set (spec'd, not yet built)
- [ ] **Stereo-pair UI.** `CreateStereoPairAction`/`SeparateStereoPairAction`
      exist and are unit-tested, but there's no UI to trigger them and no *live*
      verification — capture a real stereo-pair `GetZoneGroupState` to confirm
      `isSettled` and the `stereoLeft/Right` parsing.
- [ ] **Surround add/remove.** Only Sub bond/unbond is wired. Add
      `AddSurround`/`RemoveSurround` actions + UI (uses the same `AddHTSatellite`
      with `:LR`/`:RR`).
- [ ] **Grouping (party mode) UI.** `SonosApi.joinGroup/leaveGroup` exist but
      there are no `ConfigAction`s or UI for grouping rooms.
- [ ] **Desktop master–detail layout.** The spec called for a split view on wide
      screens; the current UI is navigation-based (fine on phones, sparse on a
      Mac window).

### Robustness
- [ ] **Ethernet discovery.** `network_info_plus.getWifiIP()` returns null on a
      wired Mac, so the unicast fallback can't compute a subnet. Enumerate
      `NetworkInterface`s instead.
- [ ] Broaden test coverage: executor undo of a real action end-to-end, the
      `unconfirmed` (verify-timeout) UX, per-model capability edge cases.
- [ ] Accessibility pass (semantics labels on icon buttons/sliders, dynamic type,
      contrast in both themes).

### Release packaging
- [ ] macOS: code-sign + notarize; ship a DMG. (Current build is unsigned debug.)
- [ ] Android: release signing config + adaptive icon (foreground/background),
      set `minSdkVersion`, test on a device.
- [ ] iOS: document the multicast entitlement requirement for on-device SSDP.

## P2 — Nice to have
- [ ] Multi-model verification matrix (Play:1/3/5, Five, Era 100/300, Arc, Move,
      Roam, Amp, older gens) — the app is verified only on a Beam + One SL + Sub.
      Track community-confirmed models in the README.
- [ ] Internationalization (`flutter_localizations` / ARB) — strings are hardcoded.
- [ ] In-app theme toggle (currently follows system).
- [ ] Additional device settings: sub gain/polarity, surround level/EQ, TrueCinema
      / room calibration read-outs (`RenderingControl` `SetEQ` exposes more types).
- [ ] Release automation (tag → build macOS/Android artifacts via CI).
- [ ] A short architecture doc / diagram for contributors (or promote the design
      spec under `docs/superpowers/` to a top-level `ARCHITECTURE.md`).

## Quick wins (high value, low effort)
`LICENSE` · Sonos disclaimer · `.gitignore` `.serena/` · CI workflow · scrub real
UUIDs · drop/annotate the web target · README screenshots.
