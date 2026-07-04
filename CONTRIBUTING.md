# Contributing

Thanks for your interest in improving Sonos Config! This is a small, focused
project — contributions of all sizes are welcome.

## Getting set up

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+)
and a machine on the **same Wi-Fi/LAN as your Sonos speakers** to test anything
that touches real hardware.

```bash
flutter pub get
flutter run -d macos     # or -d ios / android
```

## The quality gate

Every change must keep these green — CI enforces them on each PR:

```bash
dart format .            # keep the tree formatted
flutter analyze          # no issues
flutter test             # all tests pass
```

## How the code is organized

See [`CLAUDE.md`](CLAUDE.md) for the architecture (it's written for both humans
and AI assistants). The short version:

- **`models/`** — immutable domain (`Device`, `Room`, `Group`, `Household`,
  `Capabilities`).
- **`services/`** — the Sonos wire protocol (SOAP, SSDP, parsers).
- **`actions/`** — each mutating operation is a `ConfigAction`
  (`preview → apply → verify → undo`).
- **`state/`** — `provider` stores (`HouseholdStore`, `ActionExecutor`,
  `DeviceSettingsStore`).
- **`ui/`** — screens read the stores and dispatch actions.

## Two conventions that matter

1. **SCPD-first.** Before wiring a new SOAP action, confirm its exact name and
   argument signature against the device's own service description
   (`http://<speaker-ip>:1400/xml/DeviceProperties1.xml`, `RenderingControl1.xml`,
   …). Don't guess the wire format.
2. **Test with injected fakes**, not a mocking framework. Extend the real service
   classes / use `test/support/fake_soap_client.dart`. **Never commit real device
   serial numbers (RINCON UUIDs) in fixtures** — use anonymized IDs like
   `RINCON_BEAM`.

## Adding a configuration action

1. Add the typed method to `SonosApi` (SCPD-verified).
2. Add a `ConfigAction` subclass with `preview`/`apply`/`isSettled`/`inverse`.
3. Wire it into the UI via `runConfigAction`.
4. Unit-test the API method and the action; if it changes topology, capture a
   real `GetZoneGroupState` fixture to validate `isSettled`.

## Pull requests

- Branch from `main`, keep PRs focused.
- Describe what you changed and how you tested it (which speakers/models, if any).
- Make sure the quality gate passes.

By contributing you agree your contributions are licensed under the project's
[MIT License](LICENSE).
