# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-05

First release as a Sonos discovery & configuration tool.

### Changed

- **Pivoted from a playback controller to a discovery & configuration tool.** The
  app focuses on the setup/topology operations the official Sonos app hides or
  gets wrong; playback, queue, and favorites were removed.
- Rebuilt the state/domain layer around first-class `Device` / `Room` / `Group` /
  `Household` models with capability derivation.
- Introduced the `ConfigAction` guided-safe lifecycle
  (preview → apply → verify → undo) via `ActionExecutor`.

### Added

- **System map** — every speaker with model, IP, firmware, and how rooms, bonds,
  and groups are wired; product-form glyphs and role-tinted device thumbnails.
- **Bonding & topology** — bond/unbond a Sub, add/remove home-theater surrounds,
  create/split stereo pairs, and group/ungroup rooms (party mode), each with a
  preview → verify → undo flow.
- **Per-device audio** — volume, mute, bass, treble, balance, loudness; and on
  home-theater bars: night mode, speech enhancement, sub level/phase, surround
  enable/level (TV & music), height, audio delay; plus Trueplay and fixed
  line-out where supported.
- **Group audio** — room-level group volume + mute.
- **Room & device** — rename rooms, status LED, touch-button lock.
- Distinctive app icon, in-app About dialog, MIT license, contributor/community
  docs, and GitHub Actions CI (format, analyze, test).

### Fixed

- Topology parsing no longer surfaces a phantom room for an all-invisible group
  (a lone bonded Sub or bridge).

[1.0.0]: https://github.com/krugerm/sonos-config/releases/tag/v1.0.0
