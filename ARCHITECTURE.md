# Architecture

A short map for contributors. See [`CLAUDE.md`](CLAUDE.md) for conventions and
`docs/superpowers/specs/` for the original design.

## One-way layering

The UI never touches the network directly — everything flows through stores and
actions over a small hand-rolled Sonos protocol layer.

```
models/     immutable domain — Device, Room, Group, Household, Capabilities,
            BondRole, ChangeLine
services/   the Sonos wire protocol
  soap_client.dart       SOAP envelope + response helpers
  ssdp_discovery.dart    SSDP M-SEARCH + unicast /24 fallback
  household_parser.dart  GetZoneGroupState XML -> Household
  device_info.dart       fetch modelName from device_description.xml
  sonos_api.dart         typed config/EQ methods (SCPD-verified)
actions/    ConfigAction (preview / apply / isSettled / inverse) + concrete ops
state/      provider ChangeNotifiers
  household_store.dart       discovery + topology poll + model enrichment
  action_executor.dart       guided-safe apply -> verify -> undo
  device_settings_store.dart per-device audio + LED/button settings
ui/         screens read the stores, dispatch actions
```

## Three concepts, kept distinct

- **Device** — one physical player.
- **Room** — a coordinator + its bonded satellites (sub/surrounds), shown as one
  configurable unit.
- **Group** — a party-mode set of rooms playing in sync (distinct from bonding).

## The mutation path

Every change is a `ConfigAction` run by `ActionExecutor`:

```
preview → confirm → apply (SOAP) → verify (poll HouseholdStore.refresh() until
isSettled, ~30s timeout) → done / unconfirmed / failed  (+ undo if reversible)
```

`verify` handles the speaker reboot a topology change causes: it re-polls the
household snapshot until the expected end-state appears. The UI never reports a
success it hasn't observed.

## Adding a capability

1. Add the typed method to `SonosApi` — verify the action's signature against the
   device's own SCPD (`/xml/DeviceProperties1.xml`, `/xml/RenderingControl1.xml`).
2. Add a `ConfigAction` subclass (or, for instant non-rebooting settings, a
   `DeviceSettingsStore` method).
3. Wire it into the UI via `runConfigAction`.
4. Unit-test the API method and the action with injected fakes
   (`test/support/fake_soap_client.dart`).
