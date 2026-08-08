# Campaign console rework — design

Date: 2026-08-08
Status: approved for planning
Repos touched: `admin.kubus` (Vue console), `art.kubus/backend` (analytics service + routes)

## Problem

`admin.kubus/src/views/analytics/CampaignUrlBuilderView.vue` is a single 1,224-line
view doing five unrelated jobs in one scroll: compose a UTM link, batch-generate
carousel links, debug a pasted link, read the app activation funnel, and read web
acquisition plus ingest diagnostics. Its git history is a run of
`fix(campaigns): clarify …` commits — the confusion has been patched with copy
several times rather than restructured.

Four confirmed usability faults and three confirmed defects:

### Usability

1. **Two near-identical field sets that mean opposite things.** The builder's
   Campaign / Source / Medium / Content compose a URL; the performance panel's
   Campaign / Creative / Source / Medium filter a report. The panel subtitle has
   to state they are unrelated — a label compensating for a layout problem.
2. **Paired `Custom X` fields, disabled most of the time.** Six controls carry
   three values: Base URL + Custom route, Source + Custom source, Medium +
   Custom medium.
3. **"Platform placement" is an invisible macro.** `applyPlacement()` overwrites
   source, medium *and* content with no indication that selecting a placement
   discards typed values.
4. **Ambiguous output.** The generated URL competes with four unrequested derived
   URLs (Instagram bio, TikTok bio, Reddit), the carousel list, and the
   debugger's "fixed URL".

### Defects

- **D1 — `app.kubus.site/` cannot be used as a campaign landing, in two places.**
  `APP_CAMPAIGN_SAFE_PATHS = new Set(['/map', '/register'])`
  (`admin.kubus/src/utils/campaignUrls.ts:242`) puts every root link into a
  permanent warning state, which also disables the builder's "Send test event".
  Independently, the backend's direct-acquisition cohort is hard-gated to
  `entry_route = '/register'`
  (`backend/src/services/adminAnalyticsService.js:1271`), so root traffic is
  attributed, emits `app_entry`, and is then excluded from *both* funnels.
  Root is the app's real cold-entry surface: onboarding for first-time
  visitors, main for visitors who completed or skipped onboarding.
- **D2 — the "All attributed campaign activity" panel has never rendered.** The
  backend has no `coverage` producer. The field is optional on
  `AppActivationFunnel` (`admin.kubus/src/api/adminApi.ts:327`) and the template
  guards `v-if="activationFunnel?.coverage"`, so five stat tiles are dead code.
- **D3 — the date range is locked to the last 7 days with no UI.** `from` / `to`
  are set once by `setDefaultRange()` on mount and are never bound to an input.

## Goals

- Separate "make a link" from "read performance" so the two field sets can never
  be confused again.
- Make the app's root landing a first-class campaign destination, end to end.
- Give the performance surface real charts, using the charting stack already in
  the repo.
- Decompose the view so each unit has one purpose and can be tested alone.

## Non-goals

- No change to `Promotions → Campaigns` (paid placement / billing). It shares the
  word "campaign" and nothing else.
- No change to how the active property is chosen. The Admin header picker stays
  the single owner of destination.
- No new charting or UI dependency. `chart.js`, `vue-chartjs`,
  `components/charts/BarChart.vue`, `LineChart.vue` and `chartTheme.ts` already
  exist and are used by `AnalyticsView`.
- No redesign of the funnel stage definitions themselves.

## Architecture

### Routes and navigation

| Route | View | Nav label |
| --- | --- | --- |
| `/analytics/campaigns` | `CampaignPerformanceView.vue` | Campaigns |
| `/analytics/campaigns/links` | `CampaignLinksView.vue` | Campaign links |

`/analytics/campaign-builder` redirects to `/analytics/campaigns/links`. The old
route was the builder, so a bookmark should still land on the builder.

`adminNavigation.ts` replaces the single `Campaign URLs` child of the Analytics
group with these two entries, in this order.

Both pages read the active property from `useSiteStore` exactly as today, and
both show the same empty state when the active property is not a campaign
property.

### File layout

```text
admin.kubus/src/
  views/analytics/
    CampaignPerformanceView.vue     # thin: filter bar + funnel/acquisition sections
    CampaignLinksView.vue           # thin: 3-step form + output + collapsed debugger
  components/campaigns/
    CampaignLinkForm.vue            # steps 1-3, emits a CampaignUrlInput
    CampaignLinkOutput.vue          # single generated URL, or carousel list
    CampaignLinkDebugger.vue        # collapsed by default
    CampaignFilterBar.vue           # campaign/creative/source/medium + date range
    ActivationFunnelChart.vue       # horizontal stage bars
    CampaignTrendChart.vue          # entries vs accounts vs activations over time
    CampaignComparisonChart.vue     # top campaigns by entry, from breakdownRows
    CampaignCoveragePanel.vue       # where attributed traffic landed
  composables/
    useCampaignPerformance.ts       # range, filters, loading, request-race guard
    useCampaignDateRange.ts         # preset + custom range state
  utils/
    campaignUrls.ts                 # unchanged role: the pure core
```

`utils/campaignUrls.ts` stays the single source of URL truth and keeps its
existing test file. No URL logic moves into components.

## Campaign links page

The 10-control grid becomes three labelled steps. Each step answers one question.

### Step 1 — Where does it land

One destination control listing the property's landing presets plus
`Custom route…`. Selecting `Custom route…` makes **that same control** editable
rather than enabling a second, previously-greyed field. The selected preset's
`description` renders beneath it.

This removes the Base URL / Custom route pair.

### Step 2 — Where is it running

A placement picker rendered as selectable cards over `PLATFORM_PLACEMENT_PRESETS`,
plus a `Custom…` card. Selecting a placement sets source and medium and renders
the resulting `utm_source` / `utm_medium` as read-only derived chips with an
`Edit tags` disclosure that reveals free-text inputs.

This removes the Source / Custom source / Medium / Custom medium quartet, and
makes the macro's effect visible instead of silently clobbering typed values.

Behaviour change: a placement no longer overwrites a Content value the operator
already typed. Content is a step-3 field, and having a step-2 control silently
reach into step 3 is precisely the invisible-macro problem. The rule is exact:
a placement preset's `content` is written into the Content field **only when that
field is empty**; when it holds any value, the preset's suggestion is shown as
helper text beneath the field and nothing is written.

### Step 3 — What campaign

- **Campaign** — required, `datalist` of `campaignExamples`.
- **Creative (`utm_content`)** — optional, `datalist` of `contentExamples`.
- **One link per creative** — a toggle. When on, the Creative field is replaced
  by the multi-line carousel list and the output switches to the per-card list.
  The carousel generator is preserved but stops occupying the page permanently.
- **Advanced** — a disclosure holding `utm_term`.

### Output

One `CampaignLinkOutput` card: the generated URL, `Copy`, `Open test link`,
`Send test event`. The four derived bonus URLs (`urlOutputs`) are deleted — an
operator building an Instagram feed link did not ask for a Reddit link, and
their presence is the "which one do I copy" problem.

Validation warnings from `validateCampaignInput` render as a list, each item
anchored to the step it belongs to, replacing the comma-joined blob.

### Debugger

`CampaignLinkDebugger` keeps today's behaviour verbatim (parse, expected-value
check, fixed URL, send test event) inside a `<details>` collapsed by default. It
belongs with links, not with performance.

## Campaign performance page

### Filter bar

`CampaignFilterBar` at the top owns the page's scope:

- Campaign, Creative, Source, Medium — the existing `performance*` refs.
- **Date range** — presets `24h` / `7d` / `30d` / `90d` plus a custom
  from/to pair. This fixes D3; the range is currently unchangeable.

Since the builder now lives on another page, the "reporting filters are
independent from the URL being built" disclaimer is deleted rather than reworded.

### App property (`analyticsSource === 'app'`)

1. **Coverage panel** — `CampaignCoveragePanel`, newly backed by a real backend
   producer (see below). Answers "my campaign has traffic but the funnel shows
   nothing".
2. **Funnel selector** — the two existing cards (Direct registration / Map
   discovery), kept as-is.
3. **Trend chart** — `CampaignTrendChart` over the new time-series endpoint:
   entry sessions, account sessions, activated sessions per bucket.
4. **Funnel chart** — `ActivationFunnelChart`, horizontal `BarChart` of stage
   sessions with stage-over-stage retention in the tooltip. The existing stage
   table moves below it inside a collapsed `<details>`; it stays because exact
   numbers matter and a chart is a poor table.
5. **Campaign comparison** — `CampaignComparisonChart` from `breakdownRows`,
   which the endpoint already returns. Existing breakdown table retained below.
6. **Median durations** — unchanged tiles.

### Web properties (`analyticsSource === 'web'`)

1. **Trend chart** — acquisition pageviews per bucket, from the new acquisition
   series endpoint.
2. **Summary tiles** — unchanged.
3. **Source / medium / content bar charts** — replacing three of the six stacked
   key-value lists. Referrer origins, landing paths and click-ID presence stay as
   lists: they are long-tail string data that reads better as a list.
4. **Campaign table and recent-events table** — unchanged.
5. **Diagnostics** — moved into a collapsed `<details>` at the page foot.

## Backend changes

### 1. Root landing counts as direct acquisition

`adminAnalyticsService.js:1271` currently requires
`NULLIF(entry.metadata->>'entry_route', '') = '/register'`.

It becomes a membership test over a named constant:

```js
const DIRECT_ACQUISITION_ENTRY_ROUTES = ['/register', '/', '/en', '/sl'];
```

Locale roots are listed explicitly because
`GuestSessionService.normalizeEntryRoute` (`lib/services/guest_session_service.dart:80`)
collapses a trailing slash but does **not** collapse a locale prefix — `/en` is
stored as `/en`, not `/`. Per the direct-app-entry work, `/`, `/en` and `/sl` all
boot the app directly, and all three resolve to onboarding for a first-time
visitor and main for a returning one. That is account intent, so it is the direct
funnel.

No client change is required: `app_entry` already fires on every entry route and
already carries `entry_route`.

### 2. Coverage producer

New service function returning the shape `adminApi.ts` already declares, plus one
field:

| Key | Definition (distinct sessions with an attributed `app_entry` in range) |
| --- | --- |
| `attributedSessions` | any `app_entry` carrying at least one UTM value |
| `directRegisterSessions` | `entry_route = '/register'` |
| `appHomeSessions` | `entry_route IN ('/', '/en', '/sl')` |
| `discoverySessions` | `entry_route = '/map'` |
| `onboardingContinuationSessions` | `entry_route = '/onboarding'` |
| `otherAttributedSessions` | everything else |

`appHomeSessions` is new and is added to `AppActivationFunnelCoverage` in
`adminApi.ts`. It is what makes the root-landing fix legible: the panel shows
`/register` and app-home as separate rows while stating that both feed the direct
funnel.

Buckets are mutually exclusive and sum to `attributedSessions`. The panel states
this, replacing the current "counts can overlap" note, which described a panel
that never shipped.

Coverage is attached to the existing activation-funnel response, honouring the
same range and campaign filters as the funnel itself — a coverage panel filtered
differently from the funnel beside it would be worse than none.

### 3. Time-series endpoints

Two endpoints, following existing naming (`/api/admin/analytics/acquisition/*`,
`bucket` param as used by `/api/admin/analytics/timeseries`):

- `GET /api/admin/analytics/app/activation-funnel/series` — params `property`,
  `from`, `to`, `funnel`, `bucket`, and the four `utm*` filters. Returns
  `[{ bucket, entrySessions, registeredSessions, activatedSessions }]`.
- `GET /api/admin/analytics/acquisition/series` — params `site`, `from`, `to`,
  `bucket`. Returns `[{ bucket, pageviews, clickIdViews }]`.

`bucket` accepts `hour` / `day` / `week`. An absent or unrecognised value is
resolved from the range: ≤48h → `hour`, ≤31d → `day`, otherwise `week` — matching
the existing convention that an unrecognised enum falls back rather than errors,
so a stale dashboard link still renders.

Both reuse the funnel's existing candidate-events CTE and filter clauses so a
filtered chart and its filtered funnel always agree.

## Data flow

```text
Admin header property picker (useSiteStore)
        |
        +-- CampaignLinksView -------> campaignUrls.ts (pure) --> generated URL
        |
        +-- CampaignPerformanceView
                  |
                  +-- useCampaignDateRange  --> { from, to, bucket }
                  +-- CampaignFilterBar     --> { campaign, content, source, medium }
                              |
                  +-- useCampaignPerformance
                              |
                              +-- app  : activation-funnel (+coverage) + funnel series
                              +-- web  : acquisition summary/campaigns/recent/diag + series
```

`useCampaignPerformance` owns the monotonic request-id guard that
`loadActivationFunnel` implements today, and extends it to the series requests,
so a slow response can never repaint a chart under a newer filter selection.

## Error handling

- Per-section error banners, as today. A failed series request shows an inline
  chart-area error and leaves the funnel rendered; the two are independent
  requests and one failing must not blank the other.
- Empty ranges render the existing "No activation events in this range yet."
  copy. Charts render an explicit empty state, never an axis with no series.
- The stale-response guard drops superseded responses rather than rendering them.
- `Send test event` stays disabled for app properties with its existing
  explanatory `title`, on both the builder and the debugger.

## Testing

### Unit (`admin.kubus`, vitest)

- `campaignUrls.test.ts` extended: `/` is campaign-safe for the app property;
  root links produce no warning; locale roots on `art.kubus.site` still warn on
  bare `/` (that property genuinely requires `/en` or `/sl`).
- `useCampaignDateRange` — preset-to-range conversion and bucket resolution at
  the 48h and 31d boundaries.
- `useCampaignPerformance` — a superseded in-flight response is discarded.
- `CampaignLinkForm` — selecting a placement updates the derived source/medium
  chips and does **not** overwrite a non-empty Content.

### Backend (`art.kubus/backend`, jest)

- `adminActivationFunnelAttribution.test.js` extended: a session entering on `/`,
  `/en` or `/sl` with UTMs is in the direct-acquisition cohort; a `/map` guest
  entry still is not.
- New coverage test: buckets are mutually exclusive and sum to
  `attributedSessions`; campaign filters apply to coverage identically to the
  funnel.
- New series tests: bucket resolution from range; filters produce series totals
  consistent with the funnel totals for the same filters.

### Manual QA

- Build a link for each of `art.kubus.site`, `kubus.site`, `app.kubus.site`,
  including an `app.kubus.site/` root link, and confirm no spurious warning and
  an enabled test-event button where applicable.
- Confirm `/analytics/campaign-builder` redirects to the links page.
- Confirm charts render in both light and dark themes via `chartTheme.ts`.

## Phasing

The work splits into four independently shippable phases. Each leaves the console
in a working state, so the plan has real checkpoints rather than one long branch.

1. **Root landing, end to end.** Frontend: `/` added to the app's landing presets
   and `APP_CAMPAIGN_SAFE_PATHS`. Backend: `DIRECT_ACQUISITION_ENTRY_ROUTES`
   widening plus its tests. Smallest change, fixes the defect that blocks real
   campaign work, and is independent of the restructure.
2. **The split.** Two routes, two views, the redirect, nav entries, and the
   component/composable extraction — moving existing behaviour without changing
   it, except the deletions already agreed (bonus URLs, `Custom X` pairs,
   disclaimer copy) and the new date-range control.
3. **Coverage.** Backend producer, `appHomeSessions` on the type,
   `CampaignCoveragePanel`.
4. **Charts.** Series endpoints, then `CampaignTrendChart`,
   `ActivationFunnelChart`, `CampaignComparisonChart`, and the web
   source/medium/content bars.

Phase 1 is independent of the rest. Phases 3 and 4 both depend on phase 2 having
landed the page split, and are independent of each other.

## Migration and risk

- No database migration. The root-landing fix is a predicate widening over data
  already recorded, so historical root-landing campaigns become visible
  retroactively.
- **Behaviour change to flag:** direct-acquisition funnel numbers will *increase*
  for any past range that had root-landing campaign traffic. This is the fix
  working, not a regression, but anyone comparing against a previously exported
  figure needs to know. The coverage panel makes the composition visible.
- Route redirect preserves existing bookmarks.
- The rework is additive on the backend (one predicate widened, two endpoints and
  one response field added); no existing response shape changes.
