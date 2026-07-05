# Roadmap

Shipped in **v1.0.0**: discovery, topology (bond Sub, surrounds, stereo pairs,
grouping), room + device identity, audio + home-theater EQ, guided-safe actions
with undo, and an in-app anonymized diagnostics/report flow. See `CHANGELOG.md`.

## Backlog / ideas

Not committed to a version — a running list of things worth doing, roughly in
priority order.

- **Prebuilt binaries & store distribution** — notarized macOS DMG, Android APK,
  TestFlight / Play internal track. The biggest lever for adoption: most Sonos
  owners can't `flutter run`.
- **Tag-triggered CI build artifacts** — auto-build a signed APK + macOS build on
  each release tag and attach them to the GitHub release.
- **Desktop master–detail layout** — responsive two-pane (list + detail) on wide
  windows; collapses to today's push navigation on phones. UI-only refactor, no
  protocol changes. macOS is the primary target, so this matters.
- **Remote device-capability profiles** — externalize capability gating into a
  fetchable JSON so many per-model fixes ship without a rebuild or store review.
- **Broaden device coverage** — confirm Arc/Ray, Play:1/3/5, Era, Move/Roam,
  Amp/Port, multi-room, and existing stereo pairs; grow the "Devices known to
  work" table from incoming device reports.

## Parked (maintainer decision)

- **Phase D — home-theater TV / `HTControl`** and **Phase E — alarms /
  `AlarmClock`**. See `docs/DEVICE_CAPABILITIES.md`.
