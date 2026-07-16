# Walking navigation flow implementation note

Verified against `origin/master` at merge commit `d1f8bf39` (PRs #29, #30, and #31).

## Verified root causes

- `MapNavigation.openWalking` passes both `walkingNavigationIntent` and `initialArtworkId`. Both map screens therefore submit a normal `MapTargetIntent` while starting the walking session, which can select the destination marker and center/open its preview over route-follow UI.
- The mobile stack deliberately renders the marker preview after the walking panel, so an automatically selected destination card can cover navigation. Desktop also permits the normal target coordinator to run during walking startup.
- PR #31 correctly moved provider startup into the destination map and added generation leases, but `openWalking` still pushes a complete map screen. Reusing an already-mounted Explore screen would require a broader shell-to-map command channel; the safe incremental choice is to retain the pushed screen while enforcing a single leased foreground session and controller-local route ownership.
- Mobile location acquisition uses the `location` package, while retry/settings decisions use `geolocator`. Persisted `map_location_permission_requested` and `map_location_service_requested` flags can suppress a later explicit navigation request, and acquisition catches errors without returning a typed outcome.
- Desktop uses `geolocator`, but permission denied, denied forever, disabled services, timeout, and live-fix failure all become the same `locationUnavailable` provider failure. Mobile has the same collapse plus cached fallback positioning in the acquisition method.
- `WalkingNavigationProvider.retry` returns without action when `currentPosition` is null, so the UI cannot recover from an initial location failure through the provider/session contract.
- Routing service failures are partly typed internally, but route-too-long and no-route share `routeUnavailable`; the provider discards `WalkingDirectionsErrorType` and exposes raw exception text. The panel then ignores that text and shows one generic route error.
- The in-app choice is a multi-line `ListTile` with a construction-icon badge, while external choices are compact single-line tiles. There is no shared row layout contract or long-label coverage.
- Route/style replay and stale-lease protection already exist and should be retained. Camera following is split between screen auto-follow and the walking map coordinator; explicit marker selection is not arbitrated against navigation state.
- Existing tests cover provider races, route failover, map-layer replay, and normal show-on-map targeting, but not the bottom-sheet-to-map journey, permission/settings outcomes, compact row parity, state-specific UI actions, or mobile/desktop session equivalence.

## Architecture decision

Keep the incremental map-screen entry established by PR #31 for this fix. Make walking intent exclusive, centralize live location access behind one injectable `geolocator`-backed gateway, expand the provider into typed access/routing states, and make both map screens consume the same session/action contract. A later shell command channel can activate walking mode in an already-mounted Explore map without changing the provider, lease, routing API, or MapLibre coordinator contracts introduced here.
