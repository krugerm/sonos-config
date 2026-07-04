# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Pivoted from a playback controller to a discovery & configuration tool.** The
  app now focuses on the setup/topology operations the official Sonos app hides or
  gets wrong; playback, queue, and favorites were removed.
- Rebuilt the state/domain layer around first-class `Device` / `Room` / `Group` /
  `Household` models with capability derivation.
- Introduced the `ConfigAction` guided-safe lifecycle
  (preview → apply → verify → undo) via `ActionExecutor`.

### Added

- Configuration for bonding a **Sub** into a home theater, and (in the API layer)
  stereo pairs and home-theater surrounds, room rename, LED and touch-button
  lock, and audio tuning (volume, balance, bass, treble, loudness, night mode,
  speech enhancement).
- New app icon, in-app About dialog, MIT license, and contributor/community docs.
- GitHub Actions CI (format, analyze, test).

### Fixed

- Topology parsing no longer surfaces a phantom room for an all-invisible group
  (a lone bonded Sub or bridge).

[Unreleased]: https://github.com/krugerm/personal-sonos/commits/main
