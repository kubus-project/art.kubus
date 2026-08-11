# Campaign activation contract

The cross-repository agreement behind first-party acquisition reporting: which
landing surfaces count as campaign entries, and what counts as activation once
someone arrives. Three codebases must agree on both, and nothing at runtime
forces them to — the mirrored constants and the tests listed here are what does.

Strictly first-party. No Meta Pixel, CAPI, Google Analytics, Mixpanel, Segment,
Amplitude, Hotjar or fingerprinting is used anywhere in this pipeline.

## Entry-route taxonomy

| Class | Routes |
| --- | --- |
| App home (direct acquisition, implicit intent) | `/`, `/en`, `/sl`, `/main` |
| Direct acquisition (explicit intent) | `/register` |
| Discovery | `/map` |

Everything else — `/onboarding`, auth callbacks, dynamic entity paths, arbitrary
app routes — is **not** a campaign entry. `/onboarding` in particular is an
authenticated continuation; sessions that reach it are identified by their
`onboarding_enter` event, never by a landing route. Making every interactive
route an analytics dimension is what the allowlist exists to prevent: entity
ids and attacker-controlled paths would otherwise become unbounded breakdown
rows.

`normalizeEntryRoute` on both sides strips query and fragment and collapses a
trailing slash, so `/register/` and `/register` are one row. Neither side
collapses a locale prefix, which is why `/en` and `/sl` must be listed
explicitly rather than folded into `/`.

Held in three places, deliberately mirrored rather than fetched at runtime:

| Repo | Definition |
| --- | --- |
| `art.kubus` | `GuestSessionService.campaignEntryRoutes` and friends |
| `art.kubus-backend` | `src/config/campaignEntryRoutes.js` |
| `admin.kubus` | `APP_CAMPAIGN_SAFE_PATHS` in `src/utils/campaignUrls.ts` |

Runtime coupling would mean an analytics constant could take the app down, so
each repo owns a bounded literal and a checked-in test asserts the literals
agree. The drift this catches is silent and total: while the Flutter client's
list was missing `/en` and `/sl`, a campaign landing on
`https://app.kubus.site/en?utm_*` kept every UTM but dropped its `entry_route`,
and the backend's direct-acquisition cohort requires that route — so those
clicks were attributable and permanently unactivatable.

## Contribution taxonomy

`contribution_type` is the canonical metadata key on `contribution_started` and
`contribution_submitted`.

| Type | Production creation boundary |
| --- | --- |
| `artwork` | `ArtworkDraftsProvider.submitDraft` → `createArtworkRecord` returns an `Artwork` |
| `marker` | `MarkerManagementProvider.createMarker` and `MapMarkerService.createMarker` |
| `event` | `EventsProvider.createEvent` → `_api.createEvent` returns a `KubusEvent` |
| `exhibition` | `ExhibitionsProvider.createExhibition` → `_api.createExhibition` returns an `Exhibition` |

Mirrored in `lib/services/telemetry/contribution_type.dart` and
`backend/src/config/contributionTypes.js`, tested the same way as the routes.

`submitted` fires only after the backend has confirmed a durable record. Media
upload alone is not activation, validation failure is not activation, a failed
API call is not activation, and updating something that already exists is not a
new contribution — so `updateEvent`, `updateExhibition`, `updateMarker`, cover
uploads, artwork/event/marker linking and POAP synchronisation all emit nothing.

An artist who publishes one artwork and never touches the map reaches
`contribution_submitted` with `contribution_type=artwork`. Marker creation is
not required for activation.

### Marker path ownership

Two independent production entry points create markers:

- `marker_editor_view` → `MarkerManagementProvider.createMarker`
- map screens → `KubusMapMarkerCreationCoordinator` → `MapMarkerService.createMarker`

Neither wraps the other; each calls `BackendApiService.createArtMarkerRecord`
directly. Both therefore instrument themselves, and a single submission can only
traverse one of them. If one is ever changed to delegate to the other, only the
true success boundary may keep emitting.

Both paths recover a submission the backend committed but that appeared to fail,
by re-reading the marker list and matching a client nonce. Those recovery
branches are mutually exclusive returns with the direct-success branch, so a
recovered creation emits exactly one `contribution_submitted` — not zero, and
not two after a retry.

### Types deliberately absent

**`artist_profile`.** `TelemetryService.trackArtistProfileCreated` exists and has
no production call site. It is left that way. Artist standing in this product is
derived, not created: `is_artist` comes from profile data and DAO review
approval, and `artistInfo` is computed from `fieldOfWork`/`yearsActive`, which
are ordinary editable profile fields. There is no moment a user performs "create
my public artist identity" as a distinct durable transaction, so there is
nothing to fire once. Wiring the event to account creation, persona selection,
onboarding completion or a display-name change would each measure something
other than what the name claims. **An artist's activation is measured by their
first actual artwork or marker.**

**`institution_profile`.** `InstitutionProvider.createInstitution` writes to
local storage, has no backend call, and has no call site in the app. Institution
identity is derived from profile/DAO role state (`_derivedInstitution`).
Instrumenting a derived-state rebuild would produce an activation count that
rises when a role is recomputed. **A gallery's or independent space's activation
is measured by their first exhibition, event or artwork** — all of which are
instrumented, so the institutional half of this campaign remains measurable
without inventing an event.

Do not add a contribution type without a real durable creation boundary; the
resulting dimension can never be non-zero.

## Attribution window

An acquisition touch attributes later activity for **7 days**
(`GuestSessionService.attributionWindow`), stamped at capture in
`kubus_entry_attribution_at_v1`.

Seven days covers the slowest real path — ad click → email registration →
verification (the mail can sit unread overnight) → onboarding → first artwork,
which the creator flow makes a multi-session task because it needs finished
images — without becoming lifetime attribution. Before the window existed,
attribution persisted until another campaign replaced it, and for a low-volume
campaign set most installs never see a second touch.

Semantics:

- **Replacement is atomic.** A new campaign touch clears every optional field it
  does not itself carry, so campaign B without a `utm_term` cannot inherit
  campaign A's. No mixed attribution.
- **Ordinary navigation never refreshes the clock.** Capture reads the frozen
  launch URL, not the live one, and only a launch carrying UTMs re-stamps.
- **The entry route ages with its campaign.** It is stored, replaced and expired
  as part of the same touch.
- **`clearGuestMode()` clears guest mode only.** It never erases valid
  acquisition attribution.
- **Unstamped touches are adopted, not dropped.** A legacy install upgrading, or
  a route-only first touch, gets stamped on the next prune so it is bounded from
  that point instead of being wiped on sight or living forever.

## First-contribution milestone scope

`first_contribution_completed` fires once per **account**, keyed by the canonical
`user_id` UUID the telemetry service already normalises — never email, display
name or wallet address.

The v1 key was installation-wide, so the second account to use a device could
never record its first contribution; on a shared browser that is every account
after the first. The v1 flag is now read once and claimed by the first account
seen after the upgrade — the account that almost certainly set it — so it can
suppress at most one account rather than all future ones.

An unauthenticated contribution has no account to scope to. No such flow exists
today; if one appears the key falls back to the session id, which is honest
about being session-scoped rather than pretending install state is account state.

## Reporting

`GET /api/admin/analytics/app/activation-funnel` returns `firstActivationByType`
for funnels whose activation event carries a type (`direct_acquisition` only —
`guest_discovery` activates on a pending action, which is as often a save or a
follow as a contribution).

Each session is filed under its **first** `contribution_submitted` only, so the
rows are mutually exclusive and sum to `meaningfullyActivatedSessions`. This is
deliberately not a `breakdown` dimension: contribution type does not exist until
the funnel's final event, so labelling whole sessions by it would report rows
with entry 0, registered 0, activated 3.

Three counts are kept distinct and must not be substituted for one another:

| Concept | Field |
| --- | --- |
| Successful contributions | `firstActivationByType[].contributionEvents` |
| Attributed sessions reaching a contribution | `totals.meaningfullyActivatedSessions` |
| Authenticated accounts reaching a contribution | `totals.meaningfullyActivatedUsers` |

One artist publishing five more artworks raises `contributionEvents` and moves
no session between rows.

Historical rows are read `metadata->>'contribution_type'`, then
`metadata->>'kind'` filtered through the same allowlist, then `(none)`. No
database migration is required or performed.

## Rollout

Deploy **backend → app → admin**.

- Old app + new backend: the app sends `kind` only; the read path's `kind`
  fallback reports it unchanged.
- New app + old backend: `contribution_type` is an unknown key and the sanitiser
  drops unknown keys silently, and the app sends the same value under `kind`
  as well, so the event still stores and still reports. One new dimension can
  never fail a whole telemetry batch.
- No user contribution can fail because analytics versions are mixed: every
  emission is `unawaited(...).catchError(...)` after the product transaction has
  already succeeded.
