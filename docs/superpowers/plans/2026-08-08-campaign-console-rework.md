# Campaign Console Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the 1,224-line campaign builder into a links page and a performance page, make `app.kubus.site/` a first-class campaign landing end to end, and give the performance surface real charts.

**Architecture:** All logic lives in pure TypeScript modules (`src/utils/*.ts`) and framework-light composables (`src/composables/*.ts`) that are unit-testable in plain Node; `.vue` files stay thin and are verified by SFC template compilation plus source assertions. On the backend, one predicate widening, one new coverage producer, and two new time-series endpoints, all reusing the activation funnel's existing CTE and filter machinery.

**Tech Stack:** Vue 3 `<script setup>` + TypeScript + Tailwind + Pinia + vue-router + chart.js/vue-chartjs (admin.kubus, vitest); Node + Express + PostgreSQL (backend, jest).

## Global Constraints

- **No new dependencies in either repo.** `chart.js`, `vue-chartjs`, `BarChart.vue`, `LineChart.vue` and `chartTheme.ts` already exist in `admin.kubus`.
- **`admin.kubus` has no `@vue/test-utils` and no jsdom.** Component tests MUST NOT mount components. Follow the established patterns: pure logic in `.ts` modules tested directly, and `.vue` files verified with `@vue/compiler-sfc` `parse`/`compileTemplate` plus source-string assertions (see `src/views/cdpViews.regression.test.ts`).
- **Never import `components/charts/chartTheme.ts` from a `.ts` module under test.** It reads `document.documentElement` at module scope. Chart *data* builders return `ChartData` only; chart *options*/theme stay inside `.vue` components.
- Admin verify command: `npm run verify` (lint + typecheck + test + build). Lint runs with `--max-warnings=0`.
- Backend test command: `npx jest __tests__/<file>` from `g:\WorkingDATA\art.kubus\art.kubus\backend`.
- Backend SQL: **every** dynamic value is a bound parameter. Never interpolate a value into SQL. Stage names and bucket names are validated against allow-lists before interpolation, as the existing code does.
- Backend enum handling convention: an unrecognised `funnel` / `breakdown` / `bucket` falls back to a default rather than erroring, so a stale dashboard link still renders.
- Active property comes from `useSiteStore().currentSite` on both pages. Do not add a property picker.
- Repos: admin console at `g:\WorkingDATA\art.kubus\admin.kubus`, backend at `g:\WorkingDATA\art.kubus\art.kubus\backend`. They are separate git repos — commit in each independently.

## File Structure

**`admin.kubus`**

| File | Responsibility |
| --- | --- |
| `src/utils/campaignUrls.ts` (modify) | Pure URL truth: properties, presets, validation, build, debug. |
| `src/utils/campaignLinkForm.ts` (create) | Pure field-state rules for the builder: placement application, URL→fields. |
| `src/utils/campaignRange.ts` (create) | Pure date-range presets and bucket resolution. |
| `src/utils/campaignCharts.ts` (create) | Pure `ChartData` builders. No theme, no DOM. |
| `src/composables/useCampaignDateRange.ts` (create) | Reactive wrapper over `campaignRange.ts`. |
| `src/composables/useCampaignPerformance.ts` (create) | Loading, filters, request-race guard, API orchestration. |
| `src/components/campaigns/*.vue` (create) | Presentational units, one job each. |
| `src/views/analytics/CampaignLinksView.vue` (create) | Builder page shell. |
| `src/views/analytics/CampaignPerformanceView.vue` (create) | Performance page shell. |
| `src/views/analytics/CampaignUrlBuilderView.vue` (delete) | Replaced by the two views above. |
| `src/router/index.ts` (modify) | Two routes + redirect. |
| `src/config/adminNavigation.ts` (modify) | Two nav children. |
| `src/api/adminApi.ts` (modify) | Coverage type field + two series methods. |

**`backend`**

| File | Responsibility |
| --- | --- |
| `src/services/adminAnalyticsService.js` (modify) | Entry-route constants, shared filter-clause builder, coverage producer, two series producers. |
| `src/routes/adminAnalytics.js` (modify) | Two new GET routes. |
| `__tests__/adminActivationFunnelAttribution.test.js` (modify) | Existing assertion on the `/register` predicate must change. |
| `__tests__/adminCampaignCoverageAndSeries.test.js` (create) | Coverage buckets and both series producers. |

---

# Phase 1 — Root landing, end to end

Independent of every later phase. Ship it alone if you want.

### Task 1: `app.kubus.site/` is a valid campaign landing (frontend)

**Files:**
- Modify: `admin.kubus/src/utils/campaignUrls.ts` (landing presets ~line 72-83, `APP_CAMPAIGN_SAFE_PATHS` line 242)
- Test: `admin.kubus/src/utils/campaignUrls.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: `campaignLandingPresets('app.kubus.site')` gains a third entry labelled `App home (default entry)` with path `/`; `validateCampaignInput` and `debugCampaignUrl` stop warning on `https://app.kubus.site/`.

**Context you need:** two *existing* tests assert the old behaviour and MUST be changed, not worked around:
- `campaignUrls.test.ts:141` — `does not mistake a root compatibility route for a discovery preset` asserts root produces the `Choose Explore map or Register…` warning.
- `campaignUrls.test.ts:209` — asserts the app preset labels are exactly `['Explore map', 'Register and continue onboarding']`.

The new preset goes **last**, so `/register` stays the default and the deliberate funnels stay at the top of the dropdown.

- [ ] **Step 1: Rewrite the two existing tests to the new behaviour**

In `src/utils/campaignUrls.test.ts`, replace the test at line 141-153 with:

```ts
    it('accepts the app root as a campaign landing', () => {
      // `/` boots the app directly: onboarding for a first-time visitor, main
      // for one who finished or skipped it. That is account intent, so it is a
      // legitimate ad destination and must not sit in a warning state — a
      // warning here also disables the builder's test-event button.
      expect(validateCampaignInput({
        property: 'app.kubus.site',
        baseUrl: 'https://app.kubus.site/',
        source: 'instagram',
        medium: 'paid_social',
        campaign: 'beta_waitlist',
      })).toEqual([])
    })
```

and replace the label assertion at line 209-212 with:

```ts
      expect(campaignLandingPresets('app.kubus.site').map((preset) => preset.label)).toEqual([
        'Explore map',
        'Register and continue onboarding',
        'App home (default entry)',
      ])
```

- [ ] **Step 2: Add tests for the new preset and the debugger**

Append inside the `describe('app landing intent', …)` block:

```ts
    it('offers the app root as a landing preset without changing the default', () => {
      expect(campaignBaseUrls('app.kubus.site')).toContain('https://app.kubus.site/')
      // The deliberate funnels stay first and /register stays the default.
      expect(defaultCampaignBaseUrl('app.kubus.site')).toBe('https://app.kubus.site/register')
    })

    it('does not demand mode=guest on the app root', () => {
      // Only the browse surface is a guest landing. Root is account intent.
      expect(appLandingNeedsGuestMode('/')).toBe(false)
      const result = debugCampaignUrl({
        platform: 'meta',
        property: 'app.kubus.site',
        url: 'https://app.kubus.site/?utm_source=meta&utm_medium=paid_social&utm_campaign=open_call_en_aug_2026',
      })
      expect(result.warnings).toEqual([])
    })
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/utils/campaignUrls.test.ts
```

Expected: FAIL. `accepts the app root as a campaign landing` reports the received array as `['Choose Explore map or Register, or explicitly use Custom app route']`; the label assertion reports a 2-element array.

- [ ] **Step 4: Add the preset and widen the safe-path set**

In `src/utils/campaignUrls.ts`, append a third entry to the `app.kubus.site` `landingPresets` array (after the `/register` entry, before the closing `]`):

```ts
      {
        path: '/',
        label: 'App home (default entry)',
        description:
          'The app\'s own entry: onboarding for a first-time visitor, main for one who finished or skipped it.',
      },
```

Then replace the `APP_CAMPAIGN_SAFE_PATHS` line:

```ts
/**
 * App landing paths an ad may point at.
 *
 * `/` is here because it is the app's real cold-entry surface — it boots the
 * client directly and resolves to onboarding or main depending on the visitor.
 * Locale roots are the same surface; `normalizeAppPath` does not collapse them,
 * so they are listed individually.
 */
const APP_CAMPAIGN_SAFE_PATHS = new Set(['/', '/en', '/sl', '/map', '/register'])
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/utils/campaignUrls.test.ts
```

Expected: PASS, all tests in the file.

- [ ] **Step 6: Commit**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus
git add src/utils/campaignUrls.ts src/utils/campaignUrls.test.ts
git commit -m "fix(campaigns): accept app.kubus.site/ as a campaign landing"
```

---

### Task 2: Root landing counts as direct acquisition (backend)

**Files:**
- Modify: `backend/src/services/adminAnalyticsService.js` (near line 1051, and the `directCohortSql` block at 1259-1279)
- Test: `backend/__tests__/adminActivationFunnelAttribution.test.js` (line 113 asserts the old predicate)

**Interfaces:**
- Consumes: nothing.
- Produces: exported constants `APP_HOME_ENTRY_ROUTES` and `DIRECT_ACQUISITION_ENTRY_ROUTES` (Task 7 reuses both); the direct-acquisition cohort predicate becomes `= ANY($n::text[])` with the routes bound as a parameter.

**Context you need:** `params` is built once and shared verbatim by the totals, durations and breakdown queries (they all embed `baseCte`). Appending one parameter is therefore safe — but it must be appended *after* the filter parameters, because `filterClauses` already assigned `$6`…`$9`.

- [ ] **Step 1: Update the existing assertion and add the new one**

In `__tests__/adminActivationFunnelAttribution.test.js`, replace line 113:

```js
  expect(totalsSql).toContain("NULLIF(entry.metadata->>'entry_route', '') = '/register'")
```

with:

```js
  expect(totalsSql).toContain("NULLIF(entry.metadata->>'entry_route', '') = ANY($6::text[])")
  // The routes are bound, never interpolated, and root + locale roots are in
  // the cohort: `/` boots the app directly and is account intent, exactly as
  // `/register` is. `normalizeEntryRoute` does not collapse a locale prefix,
  // so `/en` is stored as `/en` and has to be listed.
  expect(params[5]).toEqual(['/register', '/', '/en', '/sl'])
```

- [ ] **Step 2: Add a test proving filters and routes coexist**

Append to the same file:

```js
test('the direct cohort routes are bound after any campaign filters', async () => {
  mockFunnelQueries(DIRECT_STAGES, { app_entry_sessions: 40 })

  await adminAnalyticsService.getActivationFunnel({
    ...RANGE,
    funnel: 'direct_acquisition',
    utmCampaign: 'open_call_en_aug_2026',
  })

  const [sql, params] = query.mock.calls[0]
  // Five fixed parameters, then the filter, then the cohort routes.
  expect(params[5]).toBe('open_call_en_aug_2026')
  expect(params[6]).toEqual(['/register', '/', '/en', '/sl'])
  expect(sql).toContain("NULLIF(metadata->>'utm_campaign', '')) = $6::text")
  expect(sql).toContain("NULLIF(entry.metadata->>'entry_route', '') = ANY($7::text[])")
})

test('the guest funnel binds no cohort routes at all', async () => {
  mockFunnelQueries(GUEST_STAGES, { guest_app_loaded_sessions: 10 })

  await adminAnalyticsService.getActivationFunnel(RANGE)

  const [sql, params] = query.mock.calls[0]
  expect(params).toHaveLength(5)
  expect(sql).not.toContain('entry_route')
})
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend && npx jest __tests__/adminActivationFunnelAttribution.test.js
```

Expected: FAIL — the SQL still contains the literal `= '/register'`, and `params` has length 5 where 6 is expected.

- [ ] **Step 4: Add the route constants**

In `src/services/adminAnalyticsService.js`, immediately above `const DIRECT_ACQUISITION_FUNNEL_STAGES` (line ~1058), insert:

```js
/// Entry routes that are the app's own home surface.
///
/// `/` boots the client directly and resolves to onboarding for a first-time
/// visitor and main for one who completed or skipped it. `/en` and `/sl` are
/// the same surface: `GuestSessionService.normalizeEntryRoute` collapses a
/// trailing slash but never a locale prefix, so `/en` is stored as `/en` and
/// would otherwise be invisible.
const APP_HOME_ENTRY_ROUTES = ['/', '/en', '/sl'];

/// Entry routes that mean account intent, and therefore direct acquisition.
///
/// `/register` is the explicit signup landing. App home is the same intent
/// arrived at implicitly — the visitor asked for the app, not the public map.
/// Discovery traffic lands on `/map` and stays exclusively in the guest funnel.
const DIRECT_ACQUISITION_ENTRY_ROUTES = ['/register', ...APP_HOME_ENTRY_ROUTES];
```

- [ ] **Step 5: Bind the routes into the cohort predicate**

Replace the `directCohortSql` block (lines 1259-1279) with:

```js
    // Direct acquisition is the cohort whose attributed entry event landed on
    // an account-intent route. Merely having UTMs is insufficient:
    // discovery-map campaigns also carry UTMs through signup and must remain
    // exclusively in the guest funnel. The entry event owns cohort membership;
    // its session join then retains later activation stages even when an older
    // client omitted UTM fields from an individual downstream event.
    let directCohortSql = '';
    if (funnelKey === 'direct_acquisition') {
      params.push(DIRECT_ACQUISITION_ENTRY_ROUTES);
      const routesIdx = `$${params.length}`;
      directCohortSql = `WHERE EXISTS (
          SELECT 1
          FROM candidate_events entry
          WHERE entry.session_id = candidate.session_id
            AND entry.event_type = 'app_entry'
            AND NULLIF(entry.metadata->>'entry_route', '') = ANY(${routesIdx}::text[])
            AND (
              COALESCE(NULLIF(entry.utm_campaign, ''), NULLIF(entry.metadata->>'utm_campaign', '')) IS NOT NULL
              OR COALESCE(NULLIF(entry.utm_source, ''), NULLIF(entry.metadata->>'utm_source', '')) IS NOT NULL
              OR COALESCE(NULLIF(entry.utm_medium, ''), NULLIF(entry.metadata->>'utm_medium', '')) IS NOT NULL
              OR COALESCE(NULLIF(entry.utm_content, ''), NULLIF(entry.metadata->>'utm_content', '')) IS NOT NULL
            )
        )`;
    }
```

- [ ] **Step 6: Export the constants**

Find the `module.exports = { … }` block at the end of `adminAnalyticsService.js` and add `APP_HOME_ENTRY_ROUTES,` and `DIRECT_ACQUISITION_ENTRY_ROUTES,` alongside the existing exports (`ACTIVATION_FUNNEL_STAGES` is already exported there — follow it).

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend && npx jest __tests__/adminActivationFunnelAttribution.test.js
```

Expected: PASS, all tests in the file.

- [ ] **Step 8: Commit**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend
git add src/services/adminAnalyticsService.js __tests__/adminActivationFunnelAttribution.test.js
git commit -m "fix(analytics): count app-home entries as direct acquisition"
```

**Note for the reviewer:** direct-acquisition figures will rise retroactively for any past range that had root-landing campaign traffic. That is the defect being fixed, not a regression.

---

# Phase 2 — The split

Moves existing behaviour onto two pages. The only intentional behaviour changes are the deletions agreed in the spec (bonus URLs, `Custom X` pairs, the "reporting filters are independent" disclaimer) and the new date-range control.

### Task 3: Pure field rules for the link builder

**Files:**
- Create: `admin.kubus/src/utils/campaignLinkForm.ts`
- Test: `admin.kubus/src/utils/campaignLinkForm.test.ts`

**Interfaces:**
- Consumes: `campaignUrls.ts` — `campaignBaseUrls`, `defaultCampaignBaseUrl`, `PLATFORM_PLACEMENT_PRESETS`, `type CampaignProperty`. (Exactly these four; lint runs with `--max-warnings=0`, so an unused import fails the build.)
- Produces, for Task 5:
  - `const CUSTOM_DESTINATION = 'custom'`
  - `type CampaignLinkFields = { destinationMode: string; customDestination: string; source: string; medium: string; campaign: string; content: string; term: string }`
  - `emptyCampaignLinkFields(property: CampaignProperty): CampaignLinkFields`
  - `destinationUrl(fields: CampaignLinkFields): string`
  - `applyPlacement(placement: string, currentContent: string): { source: string; medium: string; content: string; contentSuggestion: string } | null`
  - `campaignFieldsFromUrl(url: string, property: CampaignProperty): CampaignLinkFields`
  - `SOURCE_SUGGESTIONS`, `MEDIUM_SUGGESTIONS`, `CAMPAIGN_SUGGESTIONS`, `CONTENT_SUGGESTIONS`: `readonly string[]`

**Design note:** there are no `source`/`customSource` pairs any more. `source` and `medium` are plain strings; the option arrays become `<datalist>` suggestions. That is what removes four of the ten controls.

- [ ] **Step 1: Write the failing test**

Create `src/utils/campaignLinkForm.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import {
  applyPlacement,
  campaignFieldsFromUrl,
  CUSTOM_DESTINATION,
  destinationUrl,
  emptyCampaignLinkFields,
} from './campaignLinkForm'

describe('campaignLinkForm', () => {
  describe('applyPlacement', () => {
    it('fills an empty creative from the placement preset', () => {
      expect(applyPlacement('Instagram story', '')).toEqual({
        source: 'instagram',
        medium: 'story',
        content: 'story_1',
        contentSuggestion: '',
      })
    })

    it('never overwrites a creative the operator already typed', () => {
      // The old builder silently clobbered this field, which is why a
      // placement change used to lose work with no indication it had.
      expect(applyPlacement('Instagram story', 'my_own_creative')).toEqual({
        source: 'instagram',
        medium: 'story',
        content: 'my_own_creative',
        contentSuggestion: 'story_1',
      })
    })

    it('leaves the creative alone for a placement that suggests none', () => {
      expect(applyPlacement('Reddit post', 'keep_me')).toEqual({
        source: 'reddit',
        medium: 'organic_social',
        content: 'keep_me',
        contentSuggestion: '',
      })
    })

    it('returns null for an unknown placement', () => {
      expect(applyPlacement('Carrier pigeon', '')).toBeNull()
    })
  })

  describe('destinationUrl', () => {
    it('uses the preset when one is selected', () => {
      const fields = emptyCampaignLinkFields('app.kubus.site')
      fields.destinationMode = 'https://app.kubus.site/map?mode=guest&intent=discover'
      expect(destinationUrl(fields)).toBe('https://app.kubus.site/map?mode=guest&intent=discover')
    })

    it('uses the hand-written route when the custom option is selected', () => {
      const fields = emptyCampaignLinkFields('app.kubus.site')
      fields.destinationMode = CUSTOM_DESTINATION
      fields.customDestination = 'https://app.kubus.site/onboarding'
      expect(destinationUrl(fields)).toBe('https://app.kubus.site/onboarding')
    })
  })

  describe('campaignFieldsFromUrl', () => {
    it('splits an example into landing and tags, keeping non-UTM query', () => {
      const fields = campaignFieldsFromUrl(
        'https://app.kubus.site/map?mode=guest&intent=discover&utm_source=meta&utm_medium=paid_social&utm_campaign=open_call_en_aug_2026&utm_content=card_3',
        'app.kubus.site',
      )

      // mode/intent belong to the landing, not to the tags.
      expect(fields.destinationMode).toBe('https://app.kubus.site/map?mode=guest&intent=discover')
      expect(fields.customDestination).toBe('https://app.kubus.site/map?mode=guest&intent=discover')
      expect(fields.source).toBe('meta')
      expect(fields.medium).toBe('paid_social')
      expect(fields.campaign).toBe('open_call_en_aug_2026')
      expect(fields.content).toBe('card_3')
      expect(fields.term).toBe('')
    })

    it('routes a landing that matches no preset to the custom field', () => {
      const fields = campaignFieldsFromUrl(
        'https://app.kubus.site/onboarding?utm_source=meta&utm_medium=paid_social&utm_campaign=x',
        'app.kubus.site',
      )
      expect(fields.destinationMode).toBe(CUSTOM_DESTINATION)
      expect(fields.customDestination).toBe('https://app.kubus.site/onboarding')
    })

    it('defaults an untagged URL to empty tags rather than inventing them', () => {
      const fields = campaignFieldsFromUrl('https://app.kubus.site/register', 'app.kubus.site')
      expect(fields.source).toBe('')
      expect(fields.medium).toBe('')
      expect(fields.campaign).toBe('')
    })
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/utils/campaignLinkForm.test.ts
```

Expected: FAIL — `Failed to resolve import "./campaignLinkForm"`.

- [ ] **Step 3: Write the implementation**

Create `src/utils/campaignLinkForm.ts`:

```ts
/**
 * Field-state rules for the campaign link builder.
 *
 * Kept separate from `campaignUrls.ts`, which owns URL truth: this module owns
 * only what the *form* does to its own fields. Both are pure, so the builder
 * view can stay a thin shell over tested logic.
 */
import {
  campaignBaseUrls,
  defaultCampaignBaseUrl,
  PLATFORM_PLACEMENT_PRESETS,
  type CampaignProperty,
} from './campaignUrls'

/** Sentinel for "the destination is a hand-written route, not a preset". */
export const CUSTOM_DESTINATION = 'custom'

/**
 * Free-text suggestions, not an allow-list.
 *
 * The old builder paired every select with a disabled `Custom X` input, so
 * three values needed six controls. These are `<datalist>` hints on plain text
 * inputs instead — a partner source nobody predicted needs no second field.
 */
export const SOURCE_SUGGESTIONS = [
  'meta', 'instagram', 'facebook', 'tiktok', 'reddit', 'linkedin', 'medium', 'newsletter', 'direct',
] as const

export const MEDIUM_SUGGESTIONS = [
  'paid_social', 'organic_social', 'bio', 'story', 'reel', 'post', 'newsletter', 'referral', 'cpc',
] as const

export const CAMPAIGN_SUGGESTIONS = [
  'beta_waitlist', 'open_call_en_aug_2026', 'art_is_everywhere', 'this_is_art', 'profile_link', 'slovenia_post',
] as const

export const CONTENT_SUGGESTIONS = [
  'meta_ad_1', 'ig_story_1', 'reel_1', 'carousel_why_artists_need_infra',
] as const

export type CampaignLinkFields = {
  /** A preset landing URL, or `CUSTOM_DESTINATION`. */
  destinationMode: string
  /** The hand-written landing, used when `destinationMode` is the sentinel. */
  customDestination: string
  source: string
  medium: string
  campaign: string
  content: string
  term: string
}

export const emptyCampaignLinkFields = (property: CampaignProperty): CampaignLinkFields => {
  const preset = defaultCampaignBaseUrl(property)
  return {
    destinationMode: preset,
    customDestination: preset,
    source: '',
    medium: '',
    campaign: '',
    content: '',
    term: '',
  }
}

/** The landing URL the builder is currently pointing at. */
export const destinationUrl = (fields: CampaignLinkFields): string =>
  fields.destinationMode === CUSTOM_DESTINATION ? fields.customDestination : fields.destinationMode

export type PlacementApplication = {
  source: string
  medium: string
  content: string
  /** The preset's creative when it was NOT applied, for display as helper text. */
  contentSuggestion: string
}

/**
 * Apply a placement preset to the tag fields.
 *
 * Source and medium are what a placement *means*, so it owns them outright.
 * The creative is a step-3 field the operator may have typed: a preset writes
 * it only when it is empty, and otherwise returns its value as a suggestion.
 * The old builder overwrote it unconditionally and silently.
 */
export const applyPlacement = (
  placement: string,
  currentContent: string,
): PlacementApplication | null => {
  const preset = PLATFORM_PLACEMENT_PRESETS[placement]
  if (!preset) return null

  const typed = String(currentContent || '').trim()
  const suggested = preset.content || ''
  const applies = suggested.length > 0 && typed.length === 0

  return {
    source: preset.source,
    medium: preset.medium,
    content: applies ? suggested : currentContent,
    contentSuggestion: applies || !suggested ? '' : suggested,
  }
}

/**
 * Split a full campaign URL back into builder fields.
 *
 * Non-UTM query (`mode=guest`, `intent=discover`) is part of the landing and is
 * kept there; only a landing that exactly matches a preset can use the
 * dropdown, the rest go to the custom field. Tags are read verbatim rather than
 * defaulted, so an untagged URL loads as untagged instead of silently acquiring
 * an `instagram` source it never had.
 */
export const campaignFieldsFromUrl = (
  url: string,
  property: CampaignProperty,
): CampaignLinkFields => {
  const fields = emptyCampaignLinkFields(property)
  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return fields
  }

  fields.source = parsed.searchParams.get('utm_source') || ''
  fields.medium = parsed.searchParams.get('utm_medium') || ''
  fields.campaign = parsed.searchParams.get('utm_campaign') || ''
  fields.content = parsed.searchParams.get('utm_content') || ''
  fields.term = parsed.searchParams.get('utm_term') || ''

  for (const key of ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term']) {
    parsed.searchParams.delete(key)
  }

  const landing = parsed.toString()
  fields.destinationMode = campaignBaseUrls(property).includes(landing) ? landing : CUSTOM_DESTINATION
  fields.customDestination = landing
  return fields
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/utils/campaignLinkForm.test.ts
```

Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus
git add src/utils/campaignLinkForm.ts src/utils/campaignLinkForm.test.ts
git commit -m "feat(campaigns): pure field rules for the link builder"
```

---

### Task 4: Date range and bucket resolution

**Files:**
- Create: `admin.kubus/src/utils/campaignRange.ts`
- Create: `admin.kubus/src/composables/useCampaignDateRange.ts`
- Test: `admin.kubus/src/utils/campaignRange.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces, for Tasks 6 and 9-11:
  - `type CampaignRangePresetId = '24h' | '7d' | '30d' | '90d'`
  - `type CampaignRangeSelection = CampaignRangePresetId | 'custom'`
  - `type CampaignBucket = 'hour' | 'day' | 'week'`
  - `CAMPAIGN_RANGE_PRESETS: ReadonlyArray<{ id: CampaignRangePresetId; label: string; hours: number }>`
  - `rangeForPreset(id: CampaignRangePresetId, now: Date): { from: string; to: string }`
  - `resolveBucket(fromIso: string, toIso: string): CampaignBucket`
  - `useCampaignDateRange(): { selection, from, to, bucket, setPreset, setCustom }` (all `Ref`s except `bucket`, a `ComputedRef`)

- [ ] **Step 1: Write the failing test**

Create `src/utils/campaignRange.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { CAMPAIGN_RANGE_PRESETS, rangeForPreset, resolveBucket } from './campaignRange'

const NOW = new Date('2026-08-08T12:00:00.000Z')
const iso = (ms: number) => new Date(ms).toISOString()

describe('campaignRange', () => {
  it('offers four presets, shortest first', () => {
    expect(CAMPAIGN_RANGE_PRESETS.map((p) => p.id)).toEqual(['24h', '7d', '30d', '90d'])
  })

  it('ends every preset range at now and starts it a fixed span earlier', () => {
    expect(rangeForPreset('7d', NOW)).toEqual({
      from: '2026-08-01T12:00:00.000Z',
      to: '2026-08-08T12:00:00.000Z',
    })
    expect(rangeForPreset('24h', NOW).from).toBe('2026-08-07T12:00:00.000Z')
    expect(rangeForPreset('90d', NOW).from).toBe('2026-05-10T12:00:00.000Z')
  })

  describe('resolveBucket', () => {
    const to = NOW.getTime()

    it('buckets by hour up to and including 48 hours', () => {
      expect(resolveBucket(iso(to - 48 * 3600_000), iso(to))).toBe('hour')
    })

    it('crosses to day one millisecond past 48 hours', () => {
      expect(resolveBucket(iso(to - 48 * 3600_000 - 1), iso(to))).toBe('day')
    })

    it('buckets by day up to and including 31 days', () => {
      expect(resolveBucket(iso(to - 31 * 86_400_000), iso(to))).toBe('day')
    })

    it('crosses to week one millisecond past 31 days', () => {
      expect(resolveBucket(iso(to - 31 * 86_400_000 - 1), iso(to))).toBe('week')
    })

    it('falls back to day for an unparseable or inverted range', () => {
      // A stale or hand-edited range must still render, never throw.
      expect(resolveBucket('not-a-date', iso(to))).toBe('day')
      expect(resolveBucket('', '')).toBe('day')
      expect(resolveBucket(iso(to), iso(to - 86_400_000))).toBe('day')
    })
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/utils/campaignRange.test.ts
```

Expected: FAIL — `Failed to resolve import "./campaignRange"`.

- [ ] **Step 3: Write the pure module**

Create `src/utils/campaignRange.ts`:

```ts
/**
 * Reporting range presets and bucket selection.
 *
 * The campaign performance surface previously had no range control at all: it
 * computed a fixed last-7-days window on mount and never bound it to an input.
 */
export type CampaignRangePresetId = '24h' | '7d' | '30d' | '90d'
export type CampaignRangeSelection = CampaignRangePresetId | 'custom'
export type CampaignBucket = 'hour' | 'day' | 'week'

export const CAMPAIGN_RANGE_PRESETS = [
  { id: '24h', label: 'Last 24 hours', hours: 24 },
  { id: '7d', label: 'Last 7 days', hours: 24 * 7 },
  { id: '30d', label: 'Last 30 days', hours: 24 * 30 },
  { id: '90d', label: 'Last 90 days', hours: 24 * 90 },
] as const satisfies ReadonlyArray<{ id: CampaignRangePresetId; label: string; hours: number }>

const HOUR_MS = 3_600_000

export const rangeForPreset = (
  id: CampaignRangePresetId,
  now: Date,
): { from: string; to: string } => {
  const preset = CAMPAIGN_RANGE_PRESETS.find((entry) => entry.id === id) ?? CAMPAIGN_RANGE_PRESETS[1]
  const to = now.getTime()
  return {
    from: new Date(to - preset.hours * HOUR_MS).toISOString(),
    to: new Date(to).toISOString(),
  }
}

/** Widest bucket that still gives a readable number of points. */
const HOUR_BUCKET_MAX_MS = 48 * HOUR_MS
const DAY_BUCKET_MAX_MS = 31 * 24 * HOUR_MS

/**
 * Bucket for a range.
 *
 * An unparseable or inverted range resolves to `day` rather than throwing, for
 * the same reason the backend falls back on an unrecognised enum: a stale
 * dashboard link should still render.
 */
export const resolveBucket = (fromIso: string, toIso: string): CampaignBucket => {
  const from = Date.parse(fromIso)
  const to = Date.parse(toIso)
  if (!Number.isFinite(from) || !Number.isFinite(to)) return 'day'
  const span = to - from
  if (span <= 0) return 'day'
  if (span <= HOUR_BUCKET_MAX_MS) return 'hour'
  if (span <= DAY_BUCKET_MAX_MS) return 'day'
  return 'week'
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/utils/campaignRange.test.ts
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Write the composable**

Create `src/composables/useCampaignDateRange.ts`:

```ts
import { computed, ref } from 'vue'
import {
  rangeForPreset,
  resolveBucket,
  type CampaignRangePresetId,
  type CampaignRangeSelection,
} from '../utils/campaignRange'

/** Reactive reporting range, defaulting to the previous behaviour (7 days). */
export const useCampaignDateRange = (initial: CampaignRangePresetId = '7d') => {
  const selection = ref<CampaignRangeSelection>(initial)
  const initialRange = rangeForPreset(initial, new Date())
  const from = ref(initialRange.from)
  const to = ref(initialRange.to)

  const bucket = computed(() => resolveBucket(from.value, to.value))

  const setPreset = (id: CampaignRangePresetId) => {
    const range = rangeForPreset(id, new Date())
    selection.value = id
    from.value = range.from
    to.value = range.to
  }

  /** Custom bounds arrive from `<input type="datetime-local">`, so local time. */
  const setCustom = (nextFrom: string, nextTo: string) => {
    selection.value = 'custom'
    const parsedFrom = Date.parse(nextFrom)
    const parsedTo = Date.parse(nextTo)
    if (Number.isFinite(parsedFrom)) from.value = new Date(parsedFrom).toISOString()
    if (Number.isFinite(parsedTo)) to.value = new Date(parsedTo).toISOString()
  }

  return { selection, from, to, bucket, setPreset, setCustom }
}
```

- [ ] **Step 6: Run the whole admin suite and typecheck**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npm run test && npm run typecheck
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus
git add src/utils/campaignRange.ts src/utils/campaignRange.test.ts src/composables/useCampaignDateRange.ts
git commit -m "feat(campaigns): reporting range presets and bucket resolution"
```

---

### Task 5: The campaign links page

**Files:**
- Create: `admin.kubus/src/components/campaigns/CampaignLinkForm.vue`
- Create: `admin.kubus/src/components/campaigns/CampaignLinkOutput.vue`
- Create: `admin.kubus/src/components/campaigns/CampaignLinkDebugger.vue`
- Create: `admin.kubus/src/views/analytics/CampaignLinksView.vue`
- Modify: `admin.kubus/src/router/index.ts` (add one route after line 28)
- Modify: `admin.kubus/src/config/adminNavigation.ts` (analytics `children`, line 86-89)
- Test: `admin.kubus/src/views/analytics/campaignViews.regression.test.ts`

**Interfaces:**
- Consumes: everything Tasks 1 and 3 produced.
- Produces: route `/analytics/campaigns/links`; nav child `Campaign links`.

**Important:** the old route and `CampaignUrlBuilderView.vue` stay untouched in this task so the console keeps working. Task 6 removes them.

- [ ] **Step 1: Write the failing test**

Create `src/views/analytics/campaignViews.regression.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { compileTemplate, parse } from '@vue/compiler-sfc'
import { describe, expect, it } from 'vitest'

const here = (name: string) => fileURLToPath(new URL(`./${name}`, import.meta.url))
const componentPath = (name: string) =>
  resolve(process.cwd(), 'src/components/campaigns', name)
const repoFile = (path: string) => readFileSync(resolve(process.cwd(), path), 'utf8')

const expectSfcToCompile = (filename: string, id: string) => {
  const { descriptor, errors } = parse(readFileSync(filename, 'utf8'), { filename })
  expect(errors).toEqual([])
  expect(compileTemplate({
    source: descriptor.template?.content ?? '',
    filename,
    id,
    compilerOptions: { expressionPlugins: ['typescript'] },
  }).errors).toEqual([])
}

describe('campaign links page', () => {
  it('compiles the links view and its components', () => {
    expectSfcToCompile(here('CampaignLinksView.vue'), 'links-view')
    for (const name of ['CampaignLinkForm.vue', 'CampaignLinkOutput.vue', 'CampaignLinkDebugger.vue']) {
      expectSfcToCompile(componentPath(name), name)
    }
  })

  it('registers the links route and nav entry', () => {
    expect(repoFile('src/router/index.ts')).toContain(
      "path: 'analytics/campaigns/links', component: () => import('../views/analytics/CampaignLinksView.vue')",
    )
    expect(repoFile('src/config/adminNavigation.ts')).toContain("to: '/analytics/campaigns/links'")
  })

  it('drops the derived bonus URLs the operator never asked for', () => {
    const output = readFileSync(componentPath('CampaignLinkOutput.vue'), 'utf8')
    // One generated URL is the answer. Instagram/TikTok bio and Reddit variants
    // built from unrelated tags were the "which one do I copy" problem.
    expect(output).not.toContain('Instagram bio URL')
    expect(output).not.toContain('TikTok bio URL')
    expect(output).not.toContain('Reddit post link')
  })

  it('has no paired custom-value inputs', () => {
    const form = readFileSync(componentPath('CampaignLinkForm.vue'), 'utf8')
    // Source and medium are plain fields with datalist hints; a second,
    // usually-disabled twin is what made the old grid unreadable.
    expect(form).not.toContain('Custom source')
    expect(form).not.toContain('Custom medium')
    expect(form).not.toContain('customSource')
    expect(form).not.toContain('customMedium')
  })

  it('keeps the debugger collapsed by default', () => {
    const view = readFileSync(here('CampaignLinksView.vue'), 'utf8')
    expect(view).toContain('CampaignLinkDebugger')
    const debuggerSource = readFileSync(componentPath('CampaignLinkDebugger.vue'), 'utf8')
    expect(debuggerSource).toContain('<details')
    expect(debuggerSource).not.toContain('<details open')
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/views/analytics/campaignViews.regression.test.ts
```

Expected: FAIL — `ENOENT` on `CampaignLinksView.vue`.

- [ ] **Step 3: Create `CampaignLinkForm.vue`**

```vue
<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  campaignLandingPresets,
  campaignProperty,
  PLATFORM_PLACEMENT_PRESETS,
  type CampaignProperty,
} from '../../utils/campaignUrls'
import {
  applyPlacement,
  CAMPAIGN_SUGGESTIONS,
  CONTENT_SUGGESTIONS,
  CUSTOM_DESTINATION,
  MEDIUM_SUGGESTIONS,
  SOURCE_SUGGESTIONS,
  type CampaignLinkFields,
} from '../../utils/campaignLinkForm'

const props = defineProps<{
  modelValue: CampaignLinkFields
  property: CampaignProperty
  warnings: string[]
  carouselMode: boolean
  carouselContents: string
}>()

const emit = defineEmits<{
  'update:modelValue': [CampaignLinkFields]
  'update:carouselMode': [boolean]
  'update:carouselContents': [string]
}>()

const config = computed(() => campaignProperty(props.property))
const presets = computed(() => campaignLandingPresets(props.property))
const placementNames = Object.keys(PLATFORM_PLACEMENT_PRESETS)

const placement = ref('')
const contentSuggestion = ref('')
const showTagEditor = ref(false)
const showAdvanced = ref(false)

const patch = (changes: Partial<CampaignLinkFields>) => {
  emit('update:modelValue', { ...props.modelValue, ...changes })
}

const selectedPreset = computed(() =>
  presets.value.find((preset) => preset.url === props.modelValue.destinationMode) ?? null)

const isCustomDestination = computed(() => props.modelValue.destinationMode === CUSTOM_DESTINATION)

/**
 * A placement owns source and medium outright — that is what it means. The
 * creative is only filled when empty; `applyPlacement` returns the preset's
 * value as a suggestion otherwise, so a typed creative survives.
 */
const choosePlacement = (name: string) => {
  const result = applyPlacement(name, props.modelValue.content)
  if (!result) return
  placement.value = name
  contentSuggestion.value = result.contentSuggestion
  patch({ source: result.source, medium: result.medium, content: result.content })
}
</script>

<template>
  <div class="space-y-6">
    <!-- Step 1 -->
    <section class="space-y-2">
      <h3 class="text-sm font-semibold text-[var(--color-text-primary)]">1. Where does it land</h3>
      <label class="block space-y-1 text-sm">
        <span class="text-[var(--color-text-secondary)]">Destination on {{ config.label }}</span>
        <select
          class="input-field"
          :value="modelValue.destinationMode"
          @change="patch({ destinationMode: ($event.target as HTMLSelectElement).value })"
        >
          <option v-for="preset in presets" :key="preset.url" :value="preset.url">
            {{ preset.label }} — {{ preset.url }}
          </option>
          <option :value="CUSTOM_DESTINATION">Custom route…</option>
        </select>
      </label>
      <input
        v-if="isCustomDestination"
        class="input-field"
        :value="modelValue.customDestination"
        :placeholder="`${config.origin}${config.defaultPath}`"
        @input="patch({ customDestination: ($event.target as HTMLInputElement).value })"
      />
      <p class="text-xs text-[var(--color-text-tertiary)]">
        {{ selectedPreset ? selectedPreset.description : config.landingHint }}
      </p>
    </section>

    <!-- Step 2 -->
    <section class="space-y-2">
      <h3 class="text-sm font-semibold text-[var(--color-text-primary)]">2. Where is it running</h3>
      <div class="grid gap-2 sm:grid-cols-3 lg:grid-cols-5">
        <button
          v-for="name in placementNames"
          :key="name"
          type="button"
          class="rounded-xl border p-2 text-left text-xs transition"
          :class="placement === name
            ? 'border-[var(--color-accent)] bg-[var(--color-accent)]/10'
            : 'border-[var(--color-border)] hover:bg-[var(--color-bg-secondary)]'"
          :aria-pressed="placement === name"
          @click="choosePlacement(name)"
        >
          {{ name }}
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-2 pt-1">
        <span class="badge badge-neutral font-mono">utm_source: {{ modelValue.source || '—' }}</span>
        <span class="badge badge-neutral font-mono">utm_medium: {{ modelValue.medium || '—' }}</span>
        <button type="button" class="btn-ghost text-xs" @click="showTagEditor = !showTagEditor">
          {{ showTagEditor ? 'Hide tags' : 'Edit tags' }}
        </button>
      </div>

      <div v-if="showTagEditor" class="grid gap-3 md:grid-cols-2">
        <label class="space-y-1 text-sm">
          <span class="text-[var(--color-text-secondary)]">Source</span>
          <input
            class="input-field" list="campaign-source-suggestions" :value="modelValue.source"
            @input="patch({ source: ($event.target as HTMLInputElement).value })"
          />
          <datalist id="campaign-source-suggestions">
            <option v-for="item in SOURCE_SUGGESTIONS" :key="item" :value="item" />
          </datalist>
        </label>
        <label class="space-y-1 text-sm">
          <span class="text-[var(--color-text-secondary)]">Medium</span>
          <input
            class="input-field" list="campaign-medium-suggestions" :value="modelValue.medium"
            @input="patch({ medium: ($event.target as HTMLInputElement).value })"
          />
          <datalist id="campaign-medium-suggestions">
            <option v-for="item in MEDIUM_SUGGESTIONS" :key="item" :value="item" />
          </datalist>
        </label>
      </div>
    </section>

    <!-- Step 3 -->
    <section class="space-y-3">
      <h3 class="text-sm font-semibold text-[var(--color-text-primary)]">3. What campaign</h3>
      <div class="grid gap-3 md:grid-cols-2">
        <label class="space-y-1 text-sm">
          <span class="text-[var(--color-text-secondary)]">Campaign</span>
          <input
            class="input-field" list="campaign-name-suggestions" required placeholder="beta_waitlist"
            :value="modelValue.campaign"
            @input="patch({ campaign: ($event.target as HTMLInputElement).value })"
          />
          <datalist id="campaign-name-suggestions">
            <option v-for="item in CAMPAIGN_SUGGESTIONS" :key="item" :value="item" />
          </datalist>
        </label>
        <label v-if="!carouselMode" class="space-y-1 text-sm">
          <span class="text-[var(--color-text-secondary)]">Creative (utm_content)</span>
          <input
            class="input-field" list="campaign-content-suggestions" placeholder="optional"
            :value="modelValue.content"
            @input="patch({ content: ($event.target as HTMLInputElement).value })"
          />
          <datalist id="campaign-content-suggestions">
            <option v-for="item in CONTENT_SUGGESTIONS" :key="item" :value="item" />
          </datalist>
          <span v-if="contentSuggestion" class="block text-xs text-[var(--color-text-tertiary)]">
            This placement suggests <code>{{ contentSuggestion }}</code>; your value was kept.
          </span>
        </label>
      </div>

      <label class="flex items-center gap-2 text-sm text-[var(--color-text-secondary)]">
        <input
          type="checkbox" :checked="carouselMode"
          @change="emit('update:carouselMode', ($event.target as HTMLInputElement).checked)"
        />
        One link per creative (carousel)
      </label>

      <textarea
        v-if="carouselMode"
        class="input-field w-full font-mono text-xs"
        rows="4"
        placeholder="One utm_content per line, e.g.&#10;carousel_card_1_open_call&#10;carousel_card_2_collective_memory"
        :value="carouselContents"
        @input="emit('update:carouselContents', ($event.target as HTMLTextAreaElement).value)"
      />

      <details>
        <summary class="cursor-pointer text-xs text-[var(--color-text-tertiary)]">Advanced</summary>
        <label class="mt-2 block space-y-1 text-sm">
          <span class="text-[var(--color-text-secondary)]">Term (utm_term)</span>
          <input
            class="input-field" placeholder="optional" :value="modelValue.term"
            @input="patch({ term: ($event.target as HTMLInputElement).value })"
          />
        </label>
      </details>
    </section>

    <ul
      v-if="warnings.length"
      class="space-y-1 rounded-xl border border-[var(--color-warning)]/30 bg-[var(--color-warning)]/10 p-3 text-sm text-[var(--color-warning)]"
    >
      <li v-for="warning in warnings" :key="warning">{{ warning }}</li>
    </ul>
  </div>
</template>
```

- [ ] **Step 4: Create `CampaignLinkOutput.vue`**

```vue
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CarouselCampaignUrl } from '../../utils/campaignUrls'

const props = defineProps<{
  url: string
  carouselMode: boolean
  carouselUrls: CarouselCampaignUrl[]
  canSendTest: boolean
  sendTestDisabledReason: string
  status: string
}>()

const emit = defineEmits<{ sendTest: []; loadCarouselPreset: [] }>()

const copyStatus = ref('')

const copy = async (value: string, label = 'Copied') => {
  try {
    await navigator.clipboard.writeText(value)
    copyStatus.value = label
  } catch {
    copyStatus.value = 'Copy unavailable'
  }
}

const copyAll = () => {
  const text = props.carouselUrls.map((row) => row.url).join('\n')
  if (!text) return
  copy(text, `Copied ${props.carouselUrls.length} URLs`)
}

const openUrl = () => window.open(props.url, '_blank', 'noopener,noreferrer')

const footer = computed(() => [copyStatus.value, props.status].filter(Boolean).join(' · '))
</script>

<template>
  <div class="space-y-4">
    <div v-if="!carouselMode" class="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-secondary)] p-4">
      <div class="text-xs uppercase tracking-wide text-[var(--color-text-tertiary)]">Generated URL</div>
      <div class="mt-2 break-all font-mono text-sm text-[var(--color-text-primary)]">{{ url }}</div>
      <div class="mt-4 flex flex-wrap gap-2">
        <button class="btn-primary" type="button" @click="copy(url)">Copy</button>
        <button class="btn-secondary" type="button" @click="openUrl">Open test link</button>
        <button
          class="btn-secondary" type="button"
          :disabled="!canSendTest"
          :title="sendTestDisabledReason"
          @click="emit('sendTest')"
        >Send test event</button>
      </div>
    </div>

    <div v-else class="space-y-3">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <div class="text-xs text-[var(--color-text-tertiary)]">
          One URL per creative. Source, medium and campaign stay fixed; only utm_content changes.
        </div>
        <div class="flex gap-2">
          <button type="button" class="btn-ghost text-xs" @click="emit('loadCarouselPreset')">
            Load open-call preset
          </button>
          <button
            type="button" class="btn-secondary text-xs"
            :disabled="!carouselUrls.length" @click="copyAll"
          >Copy all</button>
        </div>
      </div>
      <div v-for="row in carouselUrls" :key="row.content" class="rounded-xl border border-[var(--color-border)] p-3">
        <div class="flex items-center justify-between gap-2">
          <div class="text-xs font-semibold text-[var(--color-text-primary)]">{{ row.content }}</div>
          <button type="button" class="btn-ghost text-xs" @click="copy(row.url)">Copy</button>
        </div>
        <div class="mt-1 break-all font-mono text-[11px] text-[var(--color-text-secondary)]">{{ row.url }}</div>
      </div>
      <p v-if="!carouselUrls.length" class="text-xs text-[var(--color-text-tertiary)]">
        Add one creative per line to generate links.
      </p>
    </div>

    <div v-if="footer" class="text-xs text-[var(--color-text-secondary)]">{{ footer }}</div>
  </div>
</template>
```

- [ ] **Step 5: Create `CampaignLinkDebugger.vue`**

Behaviour is carried over verbatim from `CampaignUrlBuilderView.vue` lines 710-755; only the wrapper changes.

```vue
<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  debugCampaignUrl,
  expectedPlatformValues,
  type AdPlatform,
  type CampaignProperty,
} from '../../utils/campaignUrls'

const props = defineProps<{
  property: CampaignProperty
  fallbackUrl: string
  canSendTest: boolean
  sendTestDisabledReason: string
}>()

const emit = defineEmits<{ sendTest: [string] }>()

const platform = ref<AdPlatform>('meta_instagram')
const url = ref('')
const expectedSource = ref('instagram')
const expectedMedium = ref('paid_social')
const expectedCampaign = ref('beta_waitlist')
const status = ref('')

const result = computed(() => debugCampaignUrl({
  platform: platform.value,
  property: props.property,
  url: url.value || props.fallbackUrl,
  expectedSource: expectedSource.value,
  expectedMedium: expectedMedium.value,
  expectedCampaign: expectedCampaign.value,
}))

const applyPlatform = () => {
  const expected = expectedPlatformValues(platform.value)
  expectedSource.value = expected.source
  expectedMedium.value = expected.medium
}

const copyFixed = async () => {
  try {
    await navigator.clipboard.writeText(result.value.fixedUrl)
    status.value = 'Fixed URL copied'
  } catch {
    status.value = 'Copy unavailable'
  }
}
</script>

<template>
  <details class="rounded-xl border border-[var(--color-border)] p-4">
    <summary class="cursor-pointer text-sm font-semibold text-[var(--color-text-primary)]">
      Ad click debugger
    </summary>
    <p class="mt-1 text-xs text-[var(--color-text-tertiary)]">
      Parse a pasted platform link, validate its expected UTMs, and send a safe backend test event.
    </p>

    <div class="mt-4 grid gap-4 lg:grid-cols-4">
      <label class="space-y-1 text-sm">
        <span class="text-[var(--color-text-secondary)]">Ad platform</span>
        <select v-model="platform" class="input-field" @change="applyPlatform">
          <option value="meta">Meta (Instagram + Facebook)</option>
          <option value="meta_instagram">Meta Instagram</option>
          <option value="meta_facebook">Meta Facebook</option>
          <option value="tiktok">TikTok</option>
          <option value="reddit">Reddit</option>
        </select>
      </label>
      <label class="space-y-1 text-sm lg:col-span-3">
        <span class="text-[var(--color-text-secondary)]">Generated or pasted URL</span>
        <input v-model="url" class="input-field" :placeholder="fallbackUrl" />
      </label>
      <input v-model="expectedSource" class="input-field" placeholder="expected source" />
      <input v-model="expectedMedium" class="input-field" placeholder="expected medium" />
      <input v-model="expectedCampaign" class="input-field" placeholder="expected campaign" />
      <div class="flex gap-2">
        <button class="btn-secondary flex-1" type="button" @click="copyFixed">Copy fixed</button>
        <button
          class="btn-primary flex-1" type="button"
          :disabled="!canSendTest" :title="sendTestDisabledReason"
          @click="emit('sendTest', result.fixedUrl)"
        >Send test</button>
      </div>
    </div>

    <div class="mt-4 grid gap-4 lg:grid-cols-2">
      <div class="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-secondary)] p-4">
        <div class="text-xs uppercase tracking-wide text-[var(--color-text-tertiary)]">Warnings</div>
        <ul class="mt-2 space-y-1 text-sm text-[var(--color-warning)]">
          <li v-for="warning in result.warnings" :key="warning">{{ warning }}</li>
          <li v-if="result.warnings.length === 0" class="text-[var(--color-success)]">No URL warnings.</li>
        </ul>
      </div>
      <div class="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-secondary)] p-4">
        <div class="text-xs uppercase tracking-wide text-[var(--color-text-tertiary)]">Fixed URL</div>
        <div class="mt-2 break-all font-mono text-sm text-[var(--color-text-primary)]">{{ result.fixedUrl }}</div>
        <div v-if="status" class="mt-3 text-xs text-[var(--color-text-secondary)]">{{ status }}</div>
      </div>
    </div>
  </details>
</template>
```

- [ ] **Step 6: Create `CampaignLinksView.vue`**

```vue
<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { adminApi } from '../../api/adminApi'
import PageTitle from '../../components/PageTitle.vue'
import PanelCard from '../../components/PanelCard.vue'
import CampaignLinkDebugger from '../../components/campaigns/CampaignLinkDebugger.vue'
import CampaignLinkForm from '../../components/campaigns/CampaignLinkForm.vue'
import CampaignLinkOutput from '../../components/campaigns/CampaignLinkOutput.vue'
import { useSiteStore } from '../../stores/site'
import {
  buildCampaignUrl,
  buildCarouselCampaignUrls,
  CAMPAIGN_PROPERTIES,
  campaignProperty,
  CAROUSEL_CONTENT_PRESET,
  DEFAULT_CAMPAIGN_PROPERTY,
  EXACT_CAMPAIGN_EXAMPLES,
  normalizeUtmValue,
  validateCampaignInput,
  type CampaignProperty,
} from '../../utils/campaignUrls'
import {
  campaignFieldsFromUrl,
  CUSTOM_DESTINATION,
  destinationUrl,
  emptyCampaignLinkFields,
  type CampaignLinkFields,
} from '../../utils/campaignLinkForm'

const siteStore = useSiteStore()

const activeProperty = computed<CampaignProperty | null>(() => {
  const current = siteStore.currentSite
  return CAMPAIGN_PROPERTIES.some((entry) => entry.id === current)
    ? (current as CampaignProperty)
    : null
})
const property = computed<CampaignProperty>(() => activeProperty.value ?? DEFAULT_CAMPAIGN_PROPERTY)
const config = computed(() => campaignProperty(property.value))
const usesAppFunnel = computed(() => config.value.analyticsSource === 'app')

const fields = ref<CampaignLinkFields>(emptyCampaignLinkFields(property.value))
const carouselMode = ref(false)
const carouselContents = ref('')
const status = ref('')

// Switching property in the Admin header must never leave a link pointing at
// the previous domain.
watch(property, (next) => {
  fields.value = emptyCampaignLinkFields(next)
  status.value = ''
})

const input = computed(() => ({
  property: property.value,
  baseUrl: destinationUrl(fields.value),
  source: fields.value.source,
  medium: fields.value.medium,
  campaign: fields.value.campaign,
  content: fields.value.content,
  term: fields.value.term,
  customAppRoute:
    property.value === 'app.kubus.site' && fields.value.destinationMode === CUSTOM_DESTINATION,
}))

const generatedUrl = computed(() => buildCampaignUrl(input.value))
const warnings = computed(() => validateCampaignInput(input.value))

const carouselUrls = computed(() => {
  const contents = carouselContents.value.split(/[\n,]/).map((line) => line.trim()).filter(Boolean)
  if (!contents.length) return []
  // Spelled out rather than rest-destructured off `input`: a discarded
  // `content` binding is an unused variable, and lint runs at zero warnings.
  return buildCarouselCampaignUrls({
    property: input.value.property,
    baseUrl: input.value.baseUrl,
    source: input.value.source,
    medium: input.value.medium,
    campaign: input.value.campaign,
    term: input.value.term,
    contents,
  })
})

const examples = computed(() =>
  Object.entries(EXACT_CAMPAIGN_EXAMPLES).filter(([, url]) => {
    try {
      return new URL(url).hostname === property.value
    } catch {
      return false
    }
  }))

// The app writes no anonymous pageviews, so a test event for it would insert a
// row nothing reads. Its campaign performance is the activation funnel.
const canSendTest = computed(() => warnings.value.length === 0 && !usesAppFunnel.value)
const sendTestDisabledReason = computed(() => {
  if (usesAppFunnel.value) {
    return 'The app does not write anonymous pageviews; use the activation funnel instead.'
  }
  return warnings.value.join(', ')
})

const referrerFor = (source: string) => {
  if (source === 'tiktok') return 'https://www.tiktok.com'
  if (source === 'reddit') return 'https://www.reddit.com'
  return 'https://www.facebook.com'
}

const sendTestEvent = async (target = generatedUrl.value) => {
  status.value = ''
  let url: URL
  try {
    url = new URL(target)
  } catch {
    status.value = 'Invalid URL'
    return
  }
  const clickIdSource = ['fbclid', 'ttclid', 'gclid'].find((key) => url.searchParams.has(key)) ?? null
  try {
    const res = await adminApi.sendAnonymousAcquisitionTestEvent({
      site: property.value,
      source: normalizeUtmValue(url.searchParams.get('utm_source')),
      medium: normalizeUtmValue(url.searchParams.get('utm_medium')),
      campaign: normalizeUtmValue(url.searchParams.get('utm_campaign')),
      content: normalizeUtmValue(url.searchParams.get('utm_content')) || null,
      targetPath: `${url.pathname}${url.search}`,
      referrerOrigin: referrerFor(normalizeUtmValue(url.searchParams.get('utm_source'))),
      clickIdSource,
    })
    status.value = `Inserted ${res.data.utm_source || '—'} / ${res.data.utm_campaign || '—'}`
  } catch (e: any) {
    status.value = e?.body?.error || e?.message || 'Test event failed'
  }
}

const loadExample = (url: string) => {
  fields.value = campaignFieldsFromUrl(url, property.value)
  carouselMode.value = false
}

const loadCarouselPreset = () => {
  carouselContents.value = CAROUSEL_CONTENT_PRESET.join('\n')
}
</script>

<template>
  <div class="space-y-6">
    <PageTitle
      title="Campaign links"
      subtitle="Build a readable, stable UTM link for the active platform."
    />

    <PanelCard
      v-if="!activeProperty"
      title="Choose a campaign platform"
      subtitle="Campaign links are available for kubus.site, art.kubus.site, and app.kubus.site."
    >
      <p class="text-sm text-[var(--color-text-secondary)]">
        Switch the active platform in the Admin header before creating a link.
      </p>
    </PanelCard>

    <div v-else class="space-y-6">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <PanelCard title="Build a campaign link" :subtitle="config.description">
          <CampaignLinkForm
            v-model="fields"
            v-model:carousel-mode="carouselMode"
            v-model:carousel-contents="carouselContents"
            :property="property"
            :warnings="warnings"
          />

          <div class="mt-6 border-t border-[var(--color-border)] pt-5">
            <CampaignLinkOutput
              :url="generatedUrl"
              :carousel-mode="carouselMode"
              :carousel-urls="carouselUrls"
              :can-send-test="canSendTest"
              :send-test-disabled-reason="sendTestDisabledReason"
              :status="status"
              @send-test="sendTestEvent()"
              @load-carousel-preset="loadCarouselPreset"
            />
          </div>
        </PanelCard>

        <PanelCard
          title="Examples for this platform"
          subtitle="Examples never switch the active platform or link to another domain."
        >
          <div class="space-y-3">
            <button
              v-for="[key, url] in examples"
              :key="key"
              class="w-full rounded-xl border border-[var(--color-border)] p-3 text-left hover:bg-[var(--color-bg-secondary)]"
              type="button"
              @click="loadExample(url)"
            >
              <div class="text-xs font-semibold text-[var(--color-text-primary)]">{{ key }}</div>
              <div class="mt-1 break-all font-mono text-[11px] text-[var(--color-text-secondary)]">{{ url }}</div>
            </button>
          </div>
        </PanelCard>
      </div>

      <CampaignLinkDebugger
        :property="property"
        :fallback-url="generatedUrl"
        :can-send-test="!usesAppFunnel"
        :send-test-disabled-reason="usesAppFunnel ? 'The app does not write anonymous pageviews; use the activation funnel instead.' : ''"
        @send-test="sendTestEvent"
      />
    </div>
  </div>
</template>
```

- [ ] **Step 7: Register the route and nav entry**

In `src/router/index.ts`, insert after the existing `analytics/campaign-builder` line:

```ts
        { path: 'analytics/campaigns/links', component: () => import('../views/analytics/CampaignLinksView.vue') },
```

In `src/config/adminNavigation.ts`, replace the analytics `children` array with:

```ts
    children: [
      { label: 'Dashboard', to: '/analytics', icon: 'chart-bar' },
      { label: 'Campaign links', to: '/analytics/campaigns/links', icon: 'sparkles' },
    ],
```

- [ ] **Step 8: Run the tests, typecheck and lint**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/views/analytics/campaignViews.regression.test.ts && npm run typecheck && npm run lint
```

Expected: PASS on all three.

- [ ] **Step 9: Commit**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus
git add src/components/campaigns src/views/analytics/CampaignLinksView.vue src/views/analytics/campaignViews.regression.test.ts src/router/index.ts src/config/adminNavigation.ts
git commit -m "feat(campaigns): dedicated campaign links page"
```

---

### Task 6: The campaign performance page

**Files:**
- Create: `admin.kubus/src/composables/useCampaignPerformance.ts`
- Create: `admin.kubus/src/composables/useCampaignPerformance.test.ts`
- Create: `admin.kubus/src/components/campaigns/CampaignFilterBar.vue`
- Create: `admin.kubus/src/views/analytics/CampaignPerformanceView.vue`
- Delete: `admin.kubus/src/views/analytics/CampaignUrlBuilderView.vue`
- Modify: `admin.kubus/src/router/index.ts`, `src/config/adminNavigation.ts`
- Test: `admin.kubus/src/views/analytics/campaignViews.regression.test.ts` (extend)

**Interfaces:**
- Consumes: `useCampaignDateRange` (Task 4); `adminApi.appActivationFunnel`, `anonymousAcquisition*` (existing).
- Produces, for Tasks 8 and 11: `useCampaignPerformance(property: Ref<CampaignProperty | null>)` returning
  `{ range, filters, funnelKind, breakdown, loading, error, funnel, acquisitionSummary, acquisitionCampaigns, acquisitionRecent, acquisitionDiagnostics, hasFilters, filterSummary, reload, setFunnelKind, clearFilters }`.

- [ ] **Step 1: Write the failing composable test**

Create `src/composables/useCampaignPerformance.test.ts`:

```ts
import { ref } from 'vue'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const appActivationFunnel = vi.fn()
const anonymousAcquisitionSummary = vi.fn()
const anonymousAcquisitionCampaigns = vi.fn()
const anonymousAcquisitionRecent = vi.fn()
const anonymousAcquisitionDiagnostics = vi.fn()

vi.mock('../api/adminApi', () => ({
  adminApi: {
    appActivationFunnel,
    anonymousAcquisitionSummary,
    anonymousAcquisitionCampaigns,
    anonymousAcquisitionRecent,
    anonymousAcquisitionDiagnostics,
  },
}))

const { useCampaignPerformance } = await import('./useCampaignPerformance')

const funnelPayload = (funnel: string, entrySessions: number) => ({
  data: {
    funnel,
    stages: [],
    breakdownRows: [],
    totals: { entrySessions },
    availableBreakdowns: ['campaign'],
  },
})

beforeEach(() => {
  for (const mock of [
    appActivationFunnel, anonymousAcquisitionSummary, anonymousAcquisitionCampaigns,
    anonymousAcquisitionRecent, anonymousAcquisitionDiagnostics,
  ]) mock.mockReset()
})

describe('useCampaignPerformance', () => {
  it('loads the activation funnel for an app property and never the pageview endpoints', async () => {
    appActivationFunnel.mockResolvedValue(funnelPayload('guest_discovery', 12))
    const property = ref('app.kubus.site' as const)
    const perf = useCampaignPerformance(property)

    await perf.reload()

    expect(appActivationFunnel).toHaveBeenCalledTimes(1)
    // The app writes no anonymous pageviews; calling those would report a
    // permanent zero and read as a failed campaign.
    expect(anonymousAcquisitionSummary).not.toHaveBeenCalled()
    expect(perf.funnel.value?.totals.entrySessions).toBe(12)
    expect(perf.loading.value).toBe(false)
  })

  it('loads the acquisition endpoints for a web property and never the funnel', async () => {
    anonymousAcquisitionSummary.mockResolvedValue({ data: { totalPageviews: 5 } })
    anonymousAcquisitionCampaigns.mockResolvedValue({ data: [] })
    anonymousAcquisitionRecent.mockResolvedValue({ data: [] })
    anonymousAcquisitionDiagnostics.mockResolvedValue({ data: { tableExists: true } })
    const perf = useCampaignPerformance(ref('art.kubus.site' as const))

    await perf.reload()

    expect(appActivationFunnel).not.toHaveBeenCalled()
    expect(perf.acquisitionSummary.value?.totalPageviews).toBe(5)
  })

  it('discards a superseded in-flight funnel response', async () => {
    // A slow first response must never repaint the page under a newer
    // selection — that is how a dashboard silently shows the wrong campaign.
    let resolveSlow: (value: unknown) => void = () => {}
    appActivationFunnel
      .mockImplementationOnce(() => new Promise((resolve) => { resolveSlow = resolve }))
      .mockResolvedValueOnce(funnelPayload('direct_acquisition', 99))

    const perf = useCampaignPerformance(ref('app.kubus.site' as const))
    const slow = perf.reload()
    const fast = perf.reload()
    await fast
    resolveSlow(funnelPayload('guest_discovery', 1))
    await slow

    expect(perf.funnel.value?.totals.entrySessions).toBe(99)
    expect(perf.loading.value).toBe(false)
  })

  it('summarises active filters and clears them', async () => {
    appActivationFunnel.mockResolvedValue(funnelPayload('guest_discovery', 0))
    const perf = useCampaignPerformance(ref('app.kubus.site' as const))

    expect(perf.hasFilters.value).toBe(false)
    expect(perf.filterSummary.value).toBe('All attributed campaigns')

    perf.filters.campaign = 'Open Call EN'
    expect(perf.hasFilters.value).toBe(true)
    expect(perf.filterSummary.value).toBe('campaign: open_call_en')

    await perf.clearFilters()
    expect(perf.hasFilters.value).toBe(false)
  })

  it('reports a failed load without blanking the previous error state', async () => {
    appActivationFunnel.mockRejectedValue({ status: 500, body: { error: 'boom' } })
    const perf = useCampaignPerformance(ref('app.kubus.site' as const))

    await perf.reload()

    expect(perf.error.value).toBe('HTTP 500: boom')
    expect(perf.loading.value).toBe(false)
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/composables/useCampaignPerformance.test.ts
```

Expected: FAIL — `Failed to resolve import "./useCampaignPerformance"`.

- [ ] **Step 3: Write the composable**

Create `src/composables/useCampaignPerformance.ts`:

```ts
import { computed, reactive, ref, type Ref } from 'vue'
import {
  adminApi,
  type AnonymousAcquisitionCampaignRow,
  type AnonymousAcquisitionDiagnostics,
  type AnonymousAcquisitionRecentRow,
  type AnonymousAcquisitionSummary,
  type AppActivationFunnel,
  type AppActivationFunnelKind,
} from '../api/adminApi'
import { campaignProperty, normalizeUtmValue, type CampaignProperty } from '../utils/campaignUrls'
import { useCampaignDateRange } from './useCampaignDateRange'

export type CampaignPerformanceFilters = {
  campaign: string
  content: string
  source: string
  medium: string
}

/**
 * Everything the campaign performance page loads.
 *
 * The two properties report from different places and must never be mixed: web
 * properties are covered by the anonymous-pageview pixel, while the app writes
 * no pageviews at all and reports through the activation funnel.
 */
export const useCampaignPerformance = (property: Ref<CampaignProperty | null>) => {
  const range = useCampaignDateRange('7d')
  const filters = reactive<CampaignPerformanceFilters>({
    campaign: '', content: '', source: '', medium: '',
  })

  const funnelKind = ref<AppActivationFunnelKind>('direct_acquisition')
  const breakdown = ref('campaign')
  const loading = ref(false)
  const error = ref('')

  const funnel = ref<AppActivationFunnel | null>(null)
  const acquisitionSummary = ref<AnonymousAcquisitionSummary | null>(null)
  const acquisitionCampaigns = ref<AnonymousAcquisitionCampaignRow[]>([])
  const acquisitionRecent = ref<AnonymousAcquisitionRecentRow[]>([])
  const acquisitionDiagnostics = ref<AnonymousAcquisitionDiagnostics | null>(null)

  const usesAppFunnel = computed(() =>
    property.value ? campaignProperty(property.value).analyticsSource === 'app' : false)

  const normalized = computed(() => ({
    campaign: normalizeUtmValue(filters.campaign),
    content: normalizeUtmValue(filters.content),
    source: normalizeUtmValue(filters.source),
    medium: normalizeUtmValue(filters.medium),
  }))

  const hasFilters = computed(() =>
    Object.values(normalized.value).some((value) => value.length > 0))

  const filterSummary = computed(() => {
    const active = Object.entries(normalized.value)
      .filter(([, value]) => value.length > 0)
      .map(([key, value]) => `${key}: ${value}`)
    return active.length ? active.join(' · ') : 'All attributed campaigns'
  })

  // Monotonic request id. Every load stamps one and only the newest may write,
  // so a slow response can never repaint the page under a newer selection.
  let requestId = 0

  const describeError = (e: any, fallback: string) => {
    const status = typeof e?.status === 'number' ? `HTTP ${e.status}: ` : ''
    return `${status}${e?.body?.error || e?.message || fallback}`
  }

  const reload = async () => {
    if (!property.value) return
    const id = ++requestId
    const target = property.value
    loading.value = true
    error.value = ''
    try {
      if (usesAppFunnel.value) {
        const res = await adminApi.appActivationFunnel(
          target, range.from.value, range.to.value, breakdown.value, null,
          {
            funnel: funnelKind.value,
            utmCampaign: normalized.value.campaign || null,
            utmContent: normalized.value.content || null,
            utmSource: normalized.value.source || null,
            utmMedium: normalized.value.medium || null,
          },
        )
        if (id !== requestId) return
        funnel.value = res.data
      } else {
        const [summary, campaigns, recent, diagnostics] = await Promise.all([
          adminApi.anonymousAcquisitionSummary(target, range.from.value, range.to.value),
          adminApi.anonymousAcquisitionCampaigns(target, range.from.value, range.to.value, 25),
          adminApi.anonymousAcquisitionRecent(target, range.from.value, range.to.value, 50),
          adminApi.anonymousAcquisitionDiagnostics(target),
        ])
        if (id !== requestId) return
        acquisitionSummary.value = summary.data
        acquisitionCampaigns.value = campaigns.data
        acquisitionRecent.value = recent.data
        acquisitionDiagnostics.value = diagnostics.data
      }
    } catch (e: any) {
      if (id !== requestId) return
      error.value = describeError(e, 'Failed to load campaign performance')
    } finally {
      if (id === requestId) loading.value = false
    }
  }

  const setFunnelKind = async (kind: AppActivationFunnelKind) => {
    funnelKind.value = kind
    // Never relabel the previous funnel as the newly selected one while its
    // replacement is still loading.
    funnel.value = null
    await reload()
  }

  const clearFilters = async () => {
    filters.campaign = ''
    filters.content = ''
    filters.source = ''
    filters.medium = ''
    await reload()
  }

  return {
    range, filters, funnelKind, breakdown, loading, error,
    funnel, acquisitionSummary, acquisitionCampaigns, acquisitionRecent, acquisitionDiagnostics,
    usesAppFunnel, hasFilters, filterSummary,
    reload, setFunnelKind, clearFilters,
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/composables/useCampaignPerformance.test.ts
```

Expected: PASS, 5 tests.

- [ ] **Step 5: Create `CampaignFilterBar.vue`**

```vue
<script setup lang="ts">
import { CAMPAIGN_RANGE_PRESETS, type CampaignRangePresetId, type CampaignRangeSelection } from '../../utils/campaignRange'
import type { CampaignPerformanceFilters } from '../../composables/useCampaignPerformance'

defineProps<{
  filters: CampaignPerformanceFilters
  selection: CampaignRangeSelection
  summary: string
  hasFilters: boolean
  loading: boolean
}>()

const emit = defineEmits<{
  apply: []
  clear: []
  preset: [CampaignRangePresetId]
}>()
</script>

<template>
  <form
    class="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-secondary)] p-4"
    @submit.prevent="emit('apply')"
  >
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <div class="text-xs uppercase tracking-wide text-[var(--color-text-tertiary)]">Reporting scope</div>
        <p class="mt-1 text-sm text-[var(--color-text-secondary)]">{{ summary }}</p>
      </div>
      <div class="flex flex-wrap gap-1">
        <button
          v-for="preset in CAMPAIGN_RANGE_PRESETS"
          :key="preset.id"
          type="button"
          class="rounded-lg border px-2.5 py-1 text-xs transition"
          :class="selection === preset.id
            ? 'border-[var(--color-accent)] bg-[var(--color-accent)]/10 text-[var(--color-text-primary)]'
            : 'border-[var(--color-border)] text-[var(--color-text-secondary)] hover:bg-[var(--color-bg-primary)]'"
          :aria-pressed="selection === preset.id"
          @click="emit('preset', preset.id)"
        >{{ preset.label }}</button>
      </div>
    </div>

    <div class="mt-3 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      <label class="space-y-1 text-sm">
        <span class="text-[var(--color-text-secondary)]">Campaign</span>
        <input v-model="filters.campaign" class="input-field" placeholder="All campaigns" />
      </label>
      <label class="space-y-1 text-sm">
        <span class="text-[var(--color-text-secondary)]">Creative (utm_content)</span>
        <input v-model="filters.content" class="input-field" placeholder="All creatives" />
      </label>
      <label class="space-y-1 text-sm">
        <span class="text-[var(--color-text-secondary)]">Source</span>
        <input v-model="filters.source" class="input-field" placeholder="All sources" />
      </label>
      <label class="space-y-1 text-sm">
        <span class="text-[var(--color-text-secondary)]">Medium</span>
        <input v-model="filters.medium" class="input-field" placeholder="All media" />
      </label>
    </div>

    <div class="mt-3 flex justify-end gap-2">
      <button class="btn-secondary" type="button" :disabled="!hasFilters" @click="emit('clear')">
        Show all campaigns
      </button>
      <button class="btn-primary" type="submit" :disabled="loading">
        {{ loading ? 'Loading…' : 'Apply' }}
      </button>
    </div>
  </form>
</template>
```

- [ ] **Step 6: Create `CampaignPerformanceView.vue`**

Port the panels from `CampaignUrlBuilderView.vue` lines 762-1211 verbatim except for the changes listed in the spec: the disclaimer subtitle is deleted, the dead `coverage` block is NOT ported (Task 8 adds a working one), the stage/breakdown tables move inside `<details>`, and Diagnostics moves inside `<details>`.

```vue
<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import PageTitle from '../../components/PageTitle.vue'
import PanelCard from '../../components/PanelCard.vue'
import CampaignFilterBar from '../../components/campaigns/CampaignFilterBar.vue'
import { useCampaignPerformance } from '../../composables/useCampaignPerformance'
import { useSiteStore } from '../../stores/site'
import {
  CAMPAIGN_PROPERTIES,
  campaignProperty,
  type CampaignProperty,
} from '../../utils/campaignUrls'
import type { CampaignRangePresetId } from '../../utils/campaignRange'

const siteStore = useSiteStore()

const activeProperty = computed<CampaignProperty | null>(() => {
  const current = siteStore.currentSite
  return CAMPAIGN_PROPERTIES.some((entry) => entry.id === current)
    ? (current as CampaignProperty)
    : null
})
const config = computed(() => campaignProperty(activeProperty.value))

const perf = useCampaignPerformance(activeProperty)

/** Human labels for the funnel stage identifiers. */
const STAGE_LABELS: Record<string, string> = {
  app_entry: 'Campaign-attributed app entry',
  signup_view: 'Registration viewed',
  signup_attempt: 'Registration attempted',
  guest_app_loaded: 'Ad-attributed guest session',
  map_opened: 'Map loaded',
  artwork_viewed: 'Content viewed',
  protected_action_clicked: 'Protected action attempted',
  auth_gate_viewed: 'Account prompt viewed',
  registration_submitted: 'Registration started',
  account_session_created: 'Account session created',
  onboarding_complete: 'Onboarding completed',
  contribution_started: 'Contribution started',
  contribution_submitted: 'Activated contributor',
  pending_action_restored: 'Original action restored',
  pending_action_completed: 'Original action completed',
}
const stageLabel = (stage: string) => STAGE_LABELS[stage] ?? stage

const formatRate = (value: number | null | undefined) =>
  value === null || value === undefined ? '—' : `${(value * 100).toFixed(1)}%`

// Breakdown columns are funnel-dependent. Render an em dash for a column this
// funnel does not report, rather than a misleading zero.
const countLabel = (value: number | null | undefined) =>
  value === null || value === undefined ? '—' : value.toLocaleString()

const formatDuration = (seconds: number | null | undefined) => {
  if (seconds === null || seconds === undefined) return 'no data'
  if (seconds < 60) return `${seconds}s`
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  return rest === 0 ? `${minutes}m` : `${minutes}m ${rest}s`
}

const isDirect = computed(() => perf.funnelKind.value === 'direct_acquisition')

const setPreset = async (id: CampaignRangePresetId) => {
  perf.range.setPreset(id)
  await perf.reload()
}

watch(activeProperty, () => { perf.reload() })
onMounted(() => { perf.reload() })
</script>

<template>
  <div class="space-y-6">
    <PageTitle
      title="Campaigns"
      :subtitle="activeProperty
        ? `Campaign performance for ${config.label}.`
        : 'Select a web or app platform to see campaign performance.'"
    />

    <PanelCard
      v-if="!activeProperty"
      title="Choose a campaign platform"
      subtitle="Campaign performance is available for kubus.site, art.kubus.site, and app.kubus.site."
    >
      <p class="text-sm text-[var(--color-text-secondary)]">
        Switch the active platform in the Admin header.
      </p>
    </PanelCard>

    <div v-else class="space-y-6">
      <CampaignFilterBar
        :filters="perf.filters"
        :selection="perf.range.selection.value"
        :summary="perf.filterSummary.value"
        :has-filters="perf.hasFilters.value"
        :loading="perf.loading.value"
        @apply="perf.reload()"
        @clear="perf.clearFilters()"
        @preset="setPreset"
      />

      <div
        v-if="perf.error.value"
        class="rounded-xl border border-[var(--color-error)]/30 bg-[var(--color-error)]/10 p-3 text-sm text-[var(--color-error)]"
      >
        {{ perf.error.value }}
      </div>

      <!-- App property: the activation funnel -->
      <PanelCard v-if="perf.usesAppFunnel.value" title="Activation funnel">
        <template #actions>
          <div class="flex items-center gap-2">
            <label class="text-sm text-[var(--color-text-secondary)]" for="activation-breakdown">Break down by</label>
            <select
              id="activation-breakdown" v-model="perf.breakdown.value" class="input-field"
              @change="perf.reload()"
            >
              <option
                v-for="dimension in perf.funnel.value?.availableBreakdowns || ['campaign']"
                :key="dimension" :value="dimension"
              >{{ dimension.replace(/_/g, ' ') }}</option>
            </select>
          </div>
        </template>

        <div class="mb-4 grid gap-3 md:grid-cols-2">
          <button
            class="rounded-xl border p-4 text-left transition"
            :class="isDirect
              ? 'border-[var(--color-accent)] bg-[var(--color-accent)]/10'
              : 'border-[var(--color-border)] hover:bg-[var(--color-bg-secondary)]'"
            type="button" :aria-pressed="isDirect"
            @click="perf.setFunnelKind('direct_acquisition')"
          >
            <div class="font-semibold text-[var(--color-text-primary)]">Direct registration</div>
            <p class="mt-1 text-sm text-[var(--color-text-secondary)]">
              Ad → app entry → registration → account → onboarding → contributor activation.
            </p>
          </button>
          <button
            class="rounded-xl border p-4 text-left transition"
            :class="!isDirect
              ? 'border-[var(--color-accent)] bg-[var(--color-accent)]/10'
              : 'border-[var(--color-border)] hover:bg-[var(--color-bg-secondary)]'"
            type="button" :aria-pressed="!isDirect"
            @click="perf.setFunnelKind('guest_discovery')"
          >
            <div class="font-semibold text-[var(--color-text-primary)]">Map discovery</div>
            <p class="mt-1 text-sm text-[var(--color-text-secondary)]">
              Ad → guest map → protected action → contextual registration → restored action.
            </p>
          </button>
        </div>

        <div v-if="isDirect" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <div class="panel-card p-4">
            <div class="stat-label">Attributed sessions</div>
            <div class="stat-value">{{ countLabel(perf.funnel.value?.totals.entrySessions) }}</div>
          </div>
          <div class="panel-card p-4">
            <div class="stat-label">Account sessions</div>
            <div class="stat-value">{{ countLabel(perf.funnel.value?.totals.registeredSessions) }}</div>
          </div>
          <div class="panel-card p-4">
            <div class="stat-label">Onboarding completed</div>
            <div class="stat-value">{{ countLabel(perf.funnel.value?.totals.onboardedSessions) }}</div>
          </div>
          <div class="panel-card p-4">
            <div class="stat-label">Activated contributors</div>
            <div class="stat-value">{{ countLabel(perf.funnel.value?.totals.meaningfullyActivatedSessions) }}</div>
          </div>
          <div class="panel-card p-4">
            <div class="stat-label">Activation rate</div>
            <div class="stat-value">{{ formatRate(perf.funnel.value?.totals.activatedFromEntryRate) }}</div>
          </div>
        </div>

        <div v-else class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div class="panel-card p-4">
            <div class="stat-label">Guest sessions</div>
            <div class="stat-value">{{ countLabel(perf.funnel.value?.totals.entrySessions) }}</div>
          </div>
          <div class="panel-card p-4">
            <div class="stat-label">Account sessions</div>
            <div class="stat-value">{{ countLabel(perf.funnel.value?.totals.registeredSessions) }}</div>
          </div>
          <div class="panel-card p-4">
            <div class="stat-label">Activation rate</div>
            <div class="stat-value">{{ formatRate(perf.funnel.value?.totals.activationRate) }}</div>
          </div>
          <div class="panel-card p-4">
            <div class="stat-label">Original action completed</div>
            <div class="stat-value">{{ countLabel(perf.funnel.value?.totals.completedSessions) }}</div>
          </div>
        </div>

        <div v-if="isDirect" class="mt-4 grid gap-3 sm:grid-cols-3">
          <div class="panel-card p-3 text-sm">
            <div class="stat-label">Entry to registration view</div>
            <div>{{ formatDuration(perf.funnel.value?.medianDurationsSeconds.entryToSignupView) }}</div>
          </div>
          <div class="panel-card p-3 text-sm">
            <div class="stat-label">Registration view to account</div>
            <div>{{ formatDuration(perf.funnel.value?.medianDurationsSeconds.signupViewToSession) }}</div>
          </div>
          <div class="panel-card p-3 text-sm">
            <div class="stat-label">Account to contribution</div>
            <div>{{ formatDuration(perf.funnel.value?.medianDurationsSeconds.sessionToContribution) }}</div>
          </div>
        </div>
        <div v-else class="mt-4 grid gap-3 sm:grid-cols-3">
          <div class="panel-card p-3 text-sm">
            <div class="stat-label">Map to first protected action</div>
            <div>{{ formatDuration(perf.funnel.value?.medianDurationsSeconds.mapToProtectedAction) }}</div>
          </div>
          <div class="panel-card p-3 text-sm">
            <div class="stat-label">Protected action to account</div>
            <div>{{ formatDuration(perf.funnel.value?.medianDurationsSeconds.protectedActionToSession) }}</div>
          </div>
          <div class="panel-card p-3 text-sm">
            <div class="stat-label">Account to completed action</div>
            <div>{{ formatDuration(perf.funnel.value?.medianDurationsSeconds.sessionToActionCompleted) }}</div>
          </div>
        </div>

        <details class="mt-4">
          <summary class="cursor-pointer text-sm text-[var(--color-text-secondary)]">Stage detail</summary>
          <div class="mt-2 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-left text-[var(--color-text-secondary)]">
                  <th class="py-2 pr-3">Stage</th>
                  <th class="py-2 pr-3 text-right">Sessions</th>
                  <th class="py-2 pr-3 text-right">Users</th>
                  <th class="py-2 pr-3 text-right">From previous</th>
                  <th class="py-2 text-right">Lost</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="stage in perf.funnel.value?.stages || []" :key="stage.stage"
                  class="border-t border-[var(--color-border)]"
                >
                  <td class="py-2 pr-3">{{ stageLabel(stage.stage) }}</td>
                  <td class="py-2 pr-3 text-right">{{ stage.sessions.toLocaleString() }}</td>
                  <td class="py-2 pr-3 text-right">{{ stage.uniqueUsers.toLocaleString() }}</td>
                  <td class="py-2 pr-3 text-right">{{ formatRate(stage.conversionFromPrevious) }}</td>
                  <td class="py-2 text-right">
                    {{ stage.abandonedFromPrevious === null ? '—' : stage.abandonedFromPrevious.toLocaleString() }}
                  </td>
                </tr>
                <tr v-if="!perf.funnel.value?.stages?.length">
                  <td class="py-3 text-[var(--color-text-secondary)]" colspan="5">
                    No activation events in this range yet.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </details>

        <details v-if="perf.funnel.value?.breakdownRows?.length" class="mt-4">
          <summary class="cursor-pointer text-sm text-[var(--color-text-secondary)]">
            By {{ (perf.funnel.value.breakdown || 'campaign').replace(/_/g, ' ') }}
          </summary>
          <div class="mt-2 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-left text-[var(--color-text-secondary)]">
                  <th class="py-2 pr-3">{{ (perf.funnel.value.breakdown || 'campaign').replace(/_/g, ' ') }}</th>
                  <th class="py-2 pr-3 text-right">{{ isDirect ? 'Entry' : 'Map' }}</th>
                  <th class="py-2 pr-3 text-right">{{ isDirect ? 'Registered' : 'Action attempted' }}</th>
                  <th class="py-2 pr-3 text-right">{{ isDirect ? 'Onboarded' : 'Account session' }}</th>
                  <th class="py-2 pr-3 text-right">{{ isDirect ? 'Activated' : 'Completed' }}</th>
                  <th class="py-2 text-right">Rate</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in perf.funnel.value.breakdownRows" :key="row.dimension"
                  class="border-t border-[var(--color-border)]"
                >
                  <td class="py-2 pr-3">{{ row.dimension }}</td>
                  <td class="py-2 pr-3 text-right">{{ countLabel(isDirect ? row.entrySessions : row.mapSessions) }}</td>
                  <td class="py-2 pr-3 text-right">{{ countLabel(isDirect ? row.registeredSessions : row.protectedActionSessions) }}</td>
                  <td class="py-2 pr-3 text-right">{{ countLabel(isDirect ? row.onboardedSessions : row.activatedSessions) }}</td>
                  <td class="py-2 pr-3 text-right">{{ countLabel(isDirect ? row.activatedSessions : row.completedSessions) }}</td>
                  <td class="py-2 text-right">{{ formatRate(row.activationRate) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </details>
      </PanelCard>

      <!-- Web property: anonymous acquisition -->
      <template v-else>
        <PanelCard
          title="Web acquisition"
          :subtitle="`Anonymous acquisition pageviews for ${config.label}, from public.anonymous_pageviews.`"
        >
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            <div class="panel-card p-4">
              <div class="stat-label">Anonymous pageviews</div>
              <div class="stat-value">{{ countLabel(perf.acquisitionSummary.value?.totalPageviews) }}</div>
            </div>
            <div class="panel-card p-4">
              <div class="stat-label">Click ID views</div>
              <div class="stat-value">{{ countLabel(perf.acquisitionSummary.value?.withClickIdCount) }}</div>
            </div>
            <div class="panel-card p-4">
              <div class="stat-label">Last 1h</div>
              <div class="stat-value">{{ countLabel(perf.acquisitionDiagnostics.value?.countLast1h) }}</div>
            </div>
            <div class="panel-card p-4">
              <div class="stat-label">Last 24h</div>
              <div class="stat-value">{{ countLabel(perf.acquisitionDiagnostics.value?.countLast24h) }}</div>
            </div>
            <div class="panel-card p-4">
              <div class="stat-label">Last 7d</div>
              <div class="stat-value">{{ countLabel(perf.acquisitionDiagnostics.value?.countLast7d) }}</div>
            </div>
          </div>

          <div class="mt-6 overflow-x-auto rounded-xl border border-[var(--color-border)]">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Campaign</th><th>Source / medium</th>
                  <th class="text-right">Views</th><th class="text-right">Click IDs</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in perf.acquisitionCampaigns.value"
                  :key="`${row.source}:${row.medium}:${row.campaign}:${row.content}`"
                >
                  <td>
                    <div class="font-mono text-xs text-[var(--color-text-primary)]">{{ row.campaign }}</div>
                    <div class="font-mono text-[11px] text-[var(--color-text-tertiary)]">{{ row.content }}</div>
                  </td>
                  <td class="font-mono text-xs text-[var(--color-text-secondary)]">{{ row.source }} / {{ row.medium }}</td>
                  <td class="text-right text-[var(--color-text-primary)]">{{ row.views.toLocaleString() }}</td>
                  <td class="text-right text-[var(--color-text-secondary)]">{{ row.clickIdViews.toLocaleString() }}</td>
                </tr>
                <tr v-if="perf.acquisitionCampaigns.value.length === 0">
                  <td colspan="4" class="text-[var(--color-text-tertiary)]">No campaign rows yet.</td>
                </tr>
              </tbody>
            </table>
          </div>

          <details class="mt-4">
            <summary class="cursor-pointer text-sm text-[var(--color-text-secondary)]">Recent events</summary>
            <div class="mt-2 overflow-x-auto rounded-xl border border-[var(--color-border)]">
              <table class="data-table">
                <thead>
                  <tr><th>Time</th><th>Landing path</th><th>Campaign</th><th>Click ID</th><th>Referrer</th></tr>
                </thead>
                <tbody>
                  <tr v-for="row in perf.acquisitionRecent.value" :key="`${row.created_at}:${row.landing_path}`">
                    <td class="text-xs text-[var(--color-text-secondary)]">{{ new Date(row.created_at).toLocaleString() }}</td>
                    <td class="max-w-[320px] break-all font-mono text-xs text-[var(--color-text-primary)]">{{ row.landing_path }}</td>
                    <td class="font-mono text-xs text-[var(--color-text-secondary)]">{{ row.utm_source }} / {{ row.utm_medium }} / {{ row.utm_campaign }}</td>
                    <td class="font-mono text-xs" :class="row.has_click_id ? 'text-[var(--color-success)]' : 'text-[var(--color-text-tertiary)]'">{{ row.click_id_source || 'none' }}</td>
                    <td class="break-all text-xs text-[var(--color-text-secondary)]">{{ row.referrer_origin || '—' }}</td>
                  </tr>
                  <tr v-if="perf.acquisitionRecent.value.length === 0">
                    <td colspan="5" class="text-[var(--color-text-tertiary)]">No recent anonymous pageviews.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </details>
        </PanelCard>

        <PanelCard title="Diagnostics" subtitle="Anonymous acquisition health and routing assumptions.">
          <details>
            <summary class="cursor-pointer text-sm text-[var(--color-text-secondary)]">Show diagnostics</summary>
            <div class="mt-3 grid gap-4 md:grid-cols-2">
              <div class="panel-card p-4">
                <div class="stat-label">Table exists</div>
                <div class="stat-value">{{ perf.acquisitionDiagnostics.value?.tableExists ? 'Yes' : 'No' }}</div>
              </div>
              <div class="panel-card p-4">
                <div class="stat-label">Latest event</div>
                <div class="text-sm text-[var(--color-text-primary)]">
                  {{ perf.acquisitionDiagnostics.value?.latestRowTimestamp
                    ? new Date(perf.acquisitionDiagnostics.value.latestRowTimestamp).toLocaleString()
                    : '—' }}
                </div>
              </div>
            </div>
          </details>
        </PanelCard>
      </template>
    </div>
  </div>
</template>
```

- [ ] **Step 7: Swap the routes and nav, delete the old view**

In `src/router/index.ts`, replace the `analytics/campaign-builder` line with:

```ts
        { path: 'analytics/campaigns', component: () => import('../views/analytics/CampaignPerformanceView.vue') },
        { path: 'analytics/campaigns/links', component: () => import('../views/analytics/CampaignLinksView.vue') },
        // The old builder route is where existing bookmarks point, and it was
        // the builder — so it lands on the builder, not the performance page.
        { path: 'analytics/campaign-builder', redirect: '/analytics/campaigns/links' },
```

(Delete the standalone `analytics/campaigns/links` line added in Task 5 so it is not registered twice.)

In `src/config/adminNavigation.ts`:

```ts
    children: [
      { label: 'Dashboard', to: '/analytics', icon: 'chart-bar' },
      { label: 'Campaigns', to: '/analytics/campaigns', icon: 'chart-bar' },
      { label: 'Campaign links', to: '/analytics/campaigns/links', icon: 'sparkles' },
    ],
```

Then:

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && git rm src/views/analytics/CampaignUrlBuilderView.vue
```

- [ ] **Step 8: Extend the regression test**

Append to `src/views/analytics/campaignViews.regression.test.ts`:

```ts
describe('campaign performance page', () => {
  it('compiles the performance view and the filter bar', () => {
    expectSfcToCompile(here('CampaignPerformanceView.vue'), 'performance-view')
    expectSfcToCompile(componentPath('CampaignFilterBar.vue'), 'CampaignFilterBar.vue')
  })

  it('registers both routes and redirects the old builder URL', () => {
    const router = repoFile('src/router/index.ts')
    expect(router).toContain(
      "path: 'analytics/campaigns', component: () => import('../views/analytics/CampaignPerformanceView.vue')",
    )
    expect(router).toContain("path: 'analytics/campaign-builder', redirect: '/analytics/campaigns/links'")
    const nav = repoFile('src/config/adminNavigation.ts')
    expect(nav).toContain("to: '/analytics/campaigns'")
    expect(nav).not.toContain('/analytics/campaign-builder')
  })

  it('replaces the single 1,224-line view', () => {
    expect(() => repoFile('src/views/analytics/CampaignUrlBuilderView.vue')).toThrow()
  })

  it('drops the disclaimer that patched over the two-field-set confusion', () => {
    const view = repoFile('src/views/analytics/CampaignPerformanceView.vue')
    // The builder now lives on another page, so there is nothing to disclaim.
    expect(view).not.toContain('independent from the URL being built')
  })

  it('offers a real reporting range instead of a fixed hidden window', () => {
    const bar = readFileSync(componentPath('CampaignFilterBar.vue'), 'utf8')
    expect(bar).toContain('CAMPAIGN_RANGE_PRESETS')
    expect(bar).toContain("emit('preset'")
  })
})
```

- [ ] **Step 9: Run the full verify**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npm run verify
```

Expected: PASS — lint, typecheck, all tests, and a successful production build.

- [ ] **Step 10: Commit**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus
git add -A src/views/analytics src/components/campaigns src/composables src/router/index.ts src/config/adminNavigation.ts
git commit -m "feat(campaigns): split builder and performance into two pages"
```

---

# Phase 3 — Coverage

Answers "my campaign has traffic but neither funnel shows it". Depends on Task 2 (the route constants) and Task 6 (the page to render it on).

### Task 7: Coverage producer (backend)

**Files:**
- Modify: `backend/src/services/adminAnalyticsService.js`
- Modify: `backend/__tests__/adminActivationFunnelAttribution.test.js` (`beforeEach` only)
- Test: `backend/__tests__/adminCampaignCoverage.test.js`

**Interfaces:**
- Consumes: `APP_HOME_ENTRY_ROUTES` (Task 2).
- Produces: `getActivationFunnel(...)` gains a `coverage` key:
  `{ attributedSessions, directRegisterSessions, appHomeSessions, discoverySessions, onboardingContinuationSessions, otherAttributedSessions }`, all numbers. Also two internal helpers reused by Task 9: `campaignValueExpr(column, schema)` and `campaignFilterClauses(filters, schema, params)`.

**Critical:** coverage adds a query *after* the optional breakdown query, so existing assertions on `query.mock.calls[0..2]` keep their meaning. The existing test file's `beforeEach` must gain a default mock resolution, or the un-queued trailing call returns `undefined` and throws.

- [ ] **Step 1: Make the existing suite tolerate a trailing query**

In `__tests__/adminActivationFunnelAttribution.test.js`, replace the `beforeEach` block:

```js
beforeEach(() => {
  query.mockReset()
  // Default for any call a test did not queue explicitly. The coverage summary
  // runs last and most tests here do not assert on it; an empty row makes every
  // bucket zero rather than throwing on `undefined.rows`.
  query.mockResolvedValue({ rows: [{}] })
  // mockClear, not mockReset: the passthrough implementation must survive.
  cache.wrap.mockClear()
})
```

- [ ] **Step 2: Write the failing coverage test**

Create `__tests__/adminCampaignCoverage.test.js`:

```js
/**
 * Coverage summary for campaign-attributed app entries.
 *
 * The admin console declared this shape but no producer ever existed, so the
 * "All attributed campaign activity" panel never rendered. These tests pin the
 * contract that makes it renderable: mutually exclusive buckets that sum to the
 * attributed total, filtered identically to the funnel beside them.
 */
process.env.NODE_ENV = 'development'

jest.mock('../src/services/cacheService', () => ({ wrap: jest.fn(async (_key, fn) => fn()) }))
jest.mock('../src/db', () => ({ query: jest.fn() }))

const { query } = require('../src/db')
const cache = require('../src/services/cacheService')
const adminAnalyticsService = require('../src/services/adminAnalyticsService')

const RANGE = {
  property: 'app.kubus.site',
  from: '2026-07-01T00:00:00.000Z',
  to: '2026-07-30T00:00:00.000Z',
}

const GUEST_STAGES = adminAnalyticsService.ACTIVATION_FUNNEL_STAGES

function totalsRow(stages) {
  const row = {}
  for (const stage of stages) {
    row[`${stage}_events`] = 0
    row[`${stage}_sessions`] = 0
    row[`${stage}_users`] = 0
  }
  return row
}

/** Queues totals, durations, then the coverage row. */
function mockQueries(coverage = {}) {
  query
    .mockResolvedValueOnce({ rows: [totalsRow(GUEST_STAGES)] })
    .mockResolvedValueOnce({ rows: [{}] })
    .mockResolvedValueOnce({ rows: [coverage] })
}

beforeEach(() => {
  query.mockReset()
  query.mockResolvedValue({ rows: [{}] })
  cache.wrap.mockClear()
})

test('splits attributed sessions into mutually exclusive landing buckets', async () => {
  mockQueries({
    attributed_sessions: 100,
    direct_register_sessions: 40,
    app_home_sessions: 25,
    discovery_sessions: 20,
    onboarding_continuation_sessions: 5,
  })

  const data = await adminAnalyticsService.getActivationFunnel(RANGE)

  expect(data.coverage).toEqual({
    attributedSessions: 100,
    directRegisterSessions: 40,
    appHomeSessions: 25,
    discoverySessions: 20,
    onboardingContinuationSessions: 5,
    otherAttributedSessions: 10,
  })

  // The buckets partition the total, so the panel can state that plainly
  // instead of the old "counts can overlap" hedge.
  const { attributedSessions, ...buckets } = data.coverage
  expect(Object.values(buckets).reduce((a, b) => a + b, 0)).toBe(attributedSessions)
})

test('never reports a negative remainder', async () => {
  // A partial scan must degrade to zero, not render a negative bucket.
  mockQueries({
    attributed_sessions: 10,
    direct_register_sessions: 8,
    app_home_sessions: 8,
  })

  const data = await adminAnalyticsService.getActivationFunnel(RANGE)
  expect(data.coverage.otherAttributedSessions).toBe(0)
})

test('an empty range reports zeroes rather than nulls', async () => {
  mockQueries({})
  const data = await adminAnalyticsService.getActivationFunnel(RANGE)
  for (const value of Object.values(data.coverage)) {
    expect(value).toBe(0)
  }
})

test('counts app home and locale roots as one bucket, bound not interpolated', async () => {
  mockQueries({ attributed_sessions: 3, app_home_sessions: 3 })

  await adminAnalyticsService.getActivationFunnel(RANGE)

  const [sql, params] = query.mock.calls[2]
  expect(sql).toContain("event_type = 'app_entry'")
  expect(sql).toContain("COUNT(*) FILTER (WHERE entry_route = '/register')")
  expect(sql).toMatch(/entry_route = ANY\(\$\d+::text\[\]\)/)
  expect(params[params.length - 1]).toEqual(['/', '/en', '/sl'])
})

test('coverage is filtered identically to the funnel beside it', async () => {
  mockQueries({ attributed_sessions: 2 })

  await adminAnalyticsService.getActivationFunnel({ ...RANGE, utmCampaign: 'open_call_en_aug_2026' })

  const [coverageSql, coverageParams] = query.mock.calls[2]
  // A coverage panel filtered differently from its funnel would be worse than
  // no panel: it would explain the wrong campaign's traffic.
  expect(coverageSql).toContain("NULLIF(metadata->>'utm_campaign', '')) = $5::text")
  expect(coverageParams[4]).toBe('open_call_en_aug_2026')
})

test('only sessions carrying attribution are counted', async () => {
  mockQueries({ attributed_sessions: 1 })
  await adminAnalyticsService.getActivationFunnel(RANGE)

  const [sql] = query.mock.calls[2]
  // Organic app entries are not campaign traffic and must not inflate the
  // denominator the panel reports.
  expect(sql).toMatch(/utm_campaign[\s\S]*IS NOT NULL[\s\S]*OR[\s\S]*utm_source[\s\S]*IS NOT NULL/)
})
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend && npx jest __tests__/adminCampaignCoverage.test.js
```

Expected: FAIL — `data.coverage` is `undefined`.

- [ ] **Step 4: Extract the shared filter helpers**

In `src/services/adminAnalyticsService.js`, immediately after `normalizeActivationFilter` (line ~1172), insert:

```js
/// How a campaign field is read: hoisted column first, metadata fallback for
/// rows written before the hoist. This is also the exact expression migration
/// 087 indexes, so it must stay byte-identical everywhere it is used.
function campaignValueExpr(column, schema) {
  return schema.columns.has(column)
    ? `COALESCE(NULLIF(${column}, ''), NULLIF(metadata->>'${column}', ''))`
    : `NULLIF(metadata->>'${column}', '')`;
}

/// Campaign filter predicates, bound onto `params` at whatever index it has
/// reached.
///
/// Shared so the funnel, its coverage summary and its time series can never be
/// filtered differently — a chart or panel filtered differently from the funnel
/// beside it would explain the wrong campaign's traffic.
function campaignFilterClauses(filters, schema, params) {
  const clauses = [];
  for (const key of ACTIVATION_FILTER_KEYS) {
    const value = filters[key];
    if (!value) continue;
    params.push(value);
    clauses.push(`AND ${campaignValueExpr(ACTIVATION_FILTERS[key].column, schema)} = $${params.length}::text`);
  }
  return clauses.join('\n          ');
}
```

Then replace the inline filter loop in `getActivationFunnel` (lines 1243-1257, from `const filterClauses = [];` through `const filterSql = filterClauses.join(...)`) with:

```js
    // Filter predicates live in the shared base CTE so totals, durations and
    // the breakdown are all filtered identically — a filter applied to only
    // some of them would report a campaign's stages against another's medians.
    const filterSql = campaignFilterClauses(filters, schema, params);
```

- [ ] **Step 5: Add the coverage query**

In `getActivationFunnel`, after the `breakdownRows` block (which ends at line ~1394) and before `const stages = [];`, insert:

```js
    // Where campaign-attributed traffic actually landed.
    //
    // Runs after the optional breakdown so existing call-order assertions keep
    // their meaning. Buckets are mutually exclusive and sum to
    // `attributedSessions`: `/register` and app home both feed the direct
    // funnel, `/map` is exclusively the guest one, and the remainder is
    // everything else that carried attribution.
    const coverageParams = [
      normalizedProperty,
      range.from.toISOString(),
      range.to.toISOString(),
      ingestPath,
    ];
    const coverageFilterSql = campaignFilterClauses(filters, schema, coverageParams);
    coverageParams.push(APP_HOME_ENTRY_ROUTES);
    const appHomeIdx = `$${coverageParams.length}`;
    const attributedPredicate = ['utm_campaign', 'utm_source', 'utm_medium', 'utm_content']
      .map((column) => `${campaignValueExpr(column, schema)} IS NOT NULL`)
      .join('\n            OR ');

    const coverageResult = await query(
      `WITH attributed AS (
        SELECT
          ${expr.sessionIdExpr} AS session_id,
          MIN(COALESCE(NULLIF(metadata->>'entry_route', ''), '(unknown)')) AS entry_route
        FROM public.analytics_events
        WHERE event_category = 'app'
          AND ${expr.propertyExpr} = $1
          AND event_type = 'app_entry'
          AND ${expr.tsExpr} >= $2::timestamptz
          AND ${expr.tsExpr} <= $3::timestamptz
          AND ($4::text IS NULL OR ${expr.ingestPathExpr} = $4)
          AND ${expr.sessionIdExpr} IS NOT NULL
          AND (
            ${attributedPredicate}
          )
          ${coverageFilterSql}
        GROUP BY 1
      )
      SELECT
        COUNT(*)::int AS attributed_sessions,
        COUNT(*) FILTER (WHERE entry_route = '/register')::int AS direct_register_sessions,
        COUNT(*) FILTER (WHERE entry_route = ANY(${appHomeIdx}::text[]))::int AS app_home_sessions,
        COUNT(*) FILTER (WHERE entry_route = '/map')::int AS discovery_sessions,
        COUNT(*) FILTER (WHERE entry_route = '/onboarding')::int AS onboarding_continuation_sessions
      FROM attributed`,
      coverageParams,
    );

    const coverageRow = coverageResult.rows[0] || {};
    const attributedSessions = Number(coverageRow.attributed_sessions || 0);
    const directRegisterSessions = Number(coverageRow.direct_register_sessions || 0);
    const appHomeSessions = Number(coverageRow.app_home_sessions || 0);
    const discoverySessions = Number(coverageRow.discovery_sessions || 0);
    const onboardingContinuationSessions = Number(coverageRow.onboarding_continuation_sessions || 0);
    const coverage = {
      attributedSessions,
      directRegisterSessions,
      appHomeSessions,
      discoverySessions,
      onboardingContinuationSessions,
      // The remainder, floored at zero so a partial scan can never render a
      // negative bucket.
      otherAttributedSessions: Math.max(
        0,
        attributedSessions - directRegisterSessions - appHomeSessions
          - discoverySessions - onboardingContinuationSessions,
      ),
    };
```

Then add `coverage,` to the returned object, immediately after `filters,`.

- [ ] **Step 6: Run both backend suites**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend && npx jest __tests__/adminCampaignCoverage.test.js __tests__/adminActivationFunnelAttribution.test.js __tests__/adminAnalyticsRoutesAuth.test.js
```

Expected: PASS on all three files.

- [ ] **Step 7: Commit**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend
git add src/services/adminAnalyticsService.js __tests__/adminCampaignCoverage.test.js __tests__/adminActivationFunnelAttribution.test.js
git commit -m "feat(analytics): campaign coverage summary by landing surface"
```

---

### Task 8: Coverage panel (frontend)

**Files:**
- Modify: `admin.kubus/src/api/adminApi.ts` (`AppActivationFunnelCoverage`, line 303-316)
- Create: `admin.kubus/src/components/campaigns/CampaignCoveragePanel.vue`
- Modify: `admin.kubus/src/views/analytics/CampaignPerformanceView.vue`
- Test: `admin.kubus/src/views/analytics/campaignViews.regression.test.ts` (extend)

**Interfaces:**
- Consumes: `perf.funnel.value?.coverage` (Task 7 shape).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing test**

Append to `src/views/analytics/campaignViews.regression.test.ts`:

```ts
describe('campaign coverage panel', () => {
  it('compiles and is rendered by the performance view', () => {
    expectSfcToCompile(componentPath('CampaignCoveragePanel.vue'), 'CampaignCoveragePanel.vue')
    expect(repoFile('src/views/analytics/CampaignPerformanceView.vue')).toContain('CampaignCoveragePanel')
  })

  it('names app home as its own bucket alongside /register', () => {
    const panel = readFileSync(componentPath('CampaignCoveragePanel.vue'), 'utf8')
    expect(panel).toContain('appHomeSessions')
    expect(panel).toContain('directRegisterSessions')
    // Both feed the direct funnel; saying so is the point of the panel.
    expect(panel).toContain('direct registration funnel')
  })

  it('states the buckets partition the total instead of the old overlap hedge', () => {
    const panel = readFileSync(componentPath('CampaignCoveragePanel.vue'), 'utf8')
    expect(panel).not.toContain('can overlap')
  })

  it('declares appHomeSessions on the coverage type', () => {
    expect(repoFile('src/api/adminApi.ts')).toContain('appHomeSessions: number')
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/views/analytics/campaignViews.regression.test.ts
```

Expected: FAIL — `ENOENT` on `CampaignCoveragePanel.vue`.

- [ ] **Step 3: Update the type**

In `src/api/adminApi.ts`, replace the `AppActivationFunnelCoverage` block (lines 303-316):

```ts
/**
 * All campaign-attributed activity in the selected range, split by where the
 * visitor landed.
 *
 * Buckets are mutually exclusive and sum to `attributedSessions`. `/register`
 * and app home both feed the direct-acquisition funnel; `/map` is exclusively
 * the guest one. This is what makes "my campaign has traffic but the funnel
 * shows nothing" answerable.
 */
export type AppActivationFunnelCoverage = {
  attributedSessions: number
  directRegisterSessions: number
  /** `/`, `/en` and `/sl` — the app's own entry surface. */
  appHomeSessions: number
  discoverySessions: number
  onboardingContinuationSessions: number
  otherAttributedSessions: number
}
```

- [ ] **Step 4: Create `CampaignCoveragePanel.vue`**

```vue
<script setup lang="ts">
import { computed } from 'vue'
import type { AppActivationFunnelCoverage } from '../../api/adminApi'

const props = defineProps<{ coverage: AppActivationFunnelCoverage }>()

const tiles = computed(() => [
  { label: 'All attributed sessions', value: props.coverage.attributedSessions, hint: 'Every session whose app entry carried a UTM.' },
  { label: 'Direct /register', value: props.coverage.directRegisterSessions, hint: 'Feeds the direct registration funnel.' },
  { label: 'App home', value: props.coverage.appHomeSessions, hint: 'Feeds the direct registration funnel.' },
  { label: 'Map discovery', value: props.coverage.discoverySessions, hint: 'Feeds the map discovery funnel.' },
  { label: 'Onboarding continuation', value: props.coverage.onboardingContinuationSessions, hint: 'An authenticated continuation, not an ad landing.' },
  { label: 'Other app activity', value: props.coverage.otherAttributedSessions, hint: 'Attributed, but landed somewhere neither funnel covers.' },
])
</script>

<template>
  <div class="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-secondary)] p-4">
    <div class="text-xs uppercase tracking-wide text-[var(--color-text-tertiary)]">
      Where attributed traffic landed
    </div>
    <p class="mt-1 text-sm text-[var(--color-text-secondary)]">
      Every bucket is exclusive and they sum to the attributed total. Direct /register and app home
      both feed the direct registration funnel.
    </p>
    <div class="mt-3 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      <div v-for="tile in tiles" :key="tile.label" class="panel-card p-3">
        <div class="stat-label">{{ tile.label }}</div>
        <div class="stat-value">{{ tile.value.toLocaleString() }}</div>
        <div class="mt-1 text-xs text-[var(--color-text-tertiary)]">{{ tile.hint }}</div>
      </div>
    </div>
  </div>
</template>
```

- [ ] **Step 5: Render it**

In `CampaignPerformanceView.vue`, add the import:

```ts
import CampaignCoveragePanel from '../../components/campaigns/CampaignCoveragePanel.vue'
```

and place it as the first child inside the app-funnel `<PanelCard title="Activation funnel">`, before the funnel-selector grid:

```html
        <CampaignCoveragePanel
          v-if="perf.funnel.value?.coverage"
          class="mb-4"
          :coverage="perf.funnel.value.coverage"
        />
```

- [ ] **Step 6: Run verify**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npm run verify
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus
git add src/api/adminApi.ts src/components/campaigns/CampaignCoveragePanel.vue src/views/analytics
git commit -m "feat(campaigns): render the campaign coverage summary"
```

---

# Phase 4 — Charts

Depends on Task 6. Independent of Phase 3.

### Task 9: Time-series endpoints (backend)

**Files:**
- Modify: `backend/src/services/adminAnalyticsService.js`
- Modify: `backend/src/routes/adminAnalytics.js`
- Test: `backend/__tests__/adminCampaignSeries.test.js`

**Interfaces:**
- Consumes: `campaignFilterClauses` (Task 7), `DIRECT_ACQUISITION_ENTRY_ROUTES` (Task 2).
- Produces:
  - `getActivationFunnelSeries({ property, from, to, ingest, funnel, bucket, utmCampaign, utmContent, utmSource, utmMedium })` → `{ property, from, to, funnel, bucket, points: Array<{ bucket, entrySessions, registeredSessions, activatedSessions }> }`
  - `getAnonymousAcquisitionSeries({ site, from, to, bucket })` → `{ site, from, to, bucket, points: Array<{ bucket, pageviews, clickIdViews }> }`
  - `GET /api/admin/analytics/app/activation-funnel/series`
  - `GET /api/admin/analytics/acquisition/series`

**Note on the fallback:** `getAppTimeSeries` throws 400 on an invalid bucket. These endpoints deliberately fall back instead, matching the funnel/breakdown convention in the same module, so a stale dashboard link still renders.

- [ ] **Step 1: Write the failing test**

Create `__tests__/adminCampaignSeries.test.js`:

```js
/**
 * Campaign time series for the activation funnel and web acquisition.
 *
 * The funnel series reads the same CTE and the same bound filters as the funnel
 * itself, so a chart and the funnel beside it can never disagree.
 */
process.env.NODE_ENV = 'development'

jest.mock('../src/services/cacheService', () => ({ wrap: jest.fn(async (_key, fn) => fn()) }))
jest.mock('../src/db', () => ({ query: jest.fn() }))

const { query } = require('../src/db')
const cache = require('../src/services/cacheService')
const adminAnalyticsService = require('../src/services/adminAnalyticsService')

const RANGE = {
  property: 'app.kubus.site',
  from: '2026-07-01T00:00:00.000Z',
  to: '2026-07-08T00:00:00.000Z',
}

beforeEach(() => {
  query.mockReset()
  query.mockResolvedValue({ rows: [] })
  cache.wrap.mockClear()
})

test('maps rows to points named after the funnel milestones', async () => {
  query.mockResolvedValueOnce({
    rows: [
      { bucket: '2026-07-01T00:00:00.000Z', entry_sessions: 10, registered_sessions: 4, activated_sessions: 1 },
      { bucket: '2026-07-02T00:00:00.000Z', entry_sessions: 8, registered_sessions: 3, activated_sessions: 0 },
    ],
  })

  const data = await adminAnalyticsService.getActivationFunnelSeries({
    ...RANGE,
    funnel: 'direct_acquisition',
  })

  expect(data.funnel).toBe('direct_acquisition')
  expect(data.points).toEqual([
    { bucket: '2026-07-01T00:00:00.000Z', entrySessions: 10, registeredSessions: 4, activatedSessions: 1 },
    { bucket: '2026-07-02T00:00:00.000Z', entrySessions: 8, registeredSessions: 3, activatedSessions: 0 },
  ])
})

test('scans only the three milestone stages, not the whole funnel', async () => {
  await adminAnalyticsService.getActivationFunnelSeries({ ...RANGE, funnel: 'direct_acquisition' })

  const [sql, params] = query.mock.calls[0]
  expect(params[4]).toEqual(['app_entry', 'account_session_created', 'contribution_submitted'])
  expect(sql).toContain("COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'app_entry')")
  // Same cohort rule as the funnel: an ad landing on the map is not direct.
  expect(sql).toMatch(/entry_route', ''\) = ANY\(\$\d+::text\[\]\)/)
})

test('resolves the bucket from the range when none is valid', async () => {
  // 48h and under reads by hour; a week reads by day; a quarter by week.
  const at = async (from, to, bucket) => {
    query.mockClear()
    const data = await adminAnalyticsService.getActivationFunnelSeries({
      property: 'app.kubus.site', from, to, bucket,
    })
    return data.bucket
  }

  expect(await at('2026-07-01T00:00:00.000Z', '2026-07-03T00:00:00.000Z', null)).toBe('hour')
  expect(await at('2026-07-01T00:00:00.000Z', '2026-07-20T00:00:00.000Z', null)).toBe('day')
  expect(await at('2026-04-01T00:00:00.000Z', '2026-07-20T00:00:00.000Z', null)).toBe('week')
  // A stale link with a nonsense bucket still renders.
  expect(await at('2026-07-01T00:00:00.000Z', '2026-07-03T00:00:00.000Z', 'fortnight')).toBe('hour')
  // An explicit valid bucket wins over the range.
  expect(await at('2026-07-01T00:00:00.000Z', '2026-07-20T00:00:00.000Z', 'week')).toBe('week')
})

test('binds campaign filters exactly as the funnel does', async () => {
  await adminAnalyticsService.getActivationFunnelSeries({
    ...RANGE,
    utmCampaign: 'open_call_en_aug_2026',
  })

  const [sql, params] = query.mock.calls[0]
  expect(params[5]).toBe('open_call_en_aug_2026')
  expect(sql).toContain("NULLIF(metadata->>'utm_campaign', '')) = $6::text")
})

test('the bucket and the funnel are part of the cache key', async () => {
  await adminAnalyticsService.getActivationFunnelSeries({ ...RANGE, bucket: 'day' })
  await adminAnalyticsService.getActivationFunnelSeries({ ...RANGE, bucket: 'week' })

  const keys = cache.wrap.mock.calls.map(([key]) => key)
  expect(keys[0]).not.toBe(keys[1])
  expect(keys[0]).toContain('day')
  expect(keys[1]).toContain('week')
})

test('acquisition series reports pageviews and click-id views per bucket', async () => {
  query.mockResolvedValueOnce({
    rows: [{ bucket: '2026-07-01T00:00:00.000Z', pageviews: 30, click_id_views: 12 }],
  })

  const data = await adminAnalyticsService.getAnonymousAcquisitionSeries({
    site: 'art.kubus.site',
    from: RANGE.from,
    to: RANGE.to,
  })

  expect(data.site).toBe('art.kubus.site')
  expect(data.bucket).toBe('day')
  expect(data.points).toEqual([
    { bucket: '2026-07-01T00:00:00.000Z', pageviews: 30, clickIdViews: 12 },
  ])
  const [sql, params] = query.mock.calls[0]
  expect(sql).toContain('FROM public.anonymous_pageviews')
  expect(sql).toContain("date_trunc('day'")
  expect(params[0]).toBe('art.kubus.site')
})
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend && npx jest __tests__/adminCampaignSeries.test.js
```

Expected: FAIL — `adminAnalyticsService.getActivationFunnelSeries is not a function`.

- [ ] **Step 3: Extract the shared base CTE**

In `src/services/adminAnalyticsService.js`, add after `campaignFilterClauses`:

```js
/// The candidate/base CTE the funnel, its coverage and its series all read.
///
/// Extracted so the series cannot drift from the funnel: same stage filter,
/// same bound campaign filters, same direct-acquisition cohort rule. `params`
/// must already hold the five fixed values (property, from, to, ingest,
/// stages); this appends filter and cohort parameters after them.
function buildActivationBaseCte({ schema, expr, funnelKey, filters, params }) {
  const filterSql = campaignFilterClauses(filters, schema, params);

  // Direct acquisition is the cohort whose attributed entry event landed on an
  // account-intent route. Merely having UTMs is insufficient: discovery-map
  // campaigns also carry UTMs through signup and must remain exclusively in the
  // guest funnel. The entry event owns cohort membership; its session join then
  // retains later activation stages even when an older client omitted UTM
  // fields from an individual downstream event.
  let directCohortSql = '';
  if (funnelKey === 'direct_acquisition') {
    params.push(DIRECT_ACQUISITION_ENTRY_ROUTES);
    directCohortSql = `WHERE EXISTS (
          SELECT 1
          FROM candidate_events entry
          WHERE entry.session_id = candidate.session_id
            AND entry.event_type = 'app_entry'
            AND NULLIF(entry.metadata->>'entry_route', '') = ANY($${params.length}::text[])
            AND (
              COALESCE(NULLIF(entry.utm_campaign, ''), NULLIF(entry.metadata->>'utm_campaign', '')) IS NOT NULL
              OR COALESCE(NULLIF(entry.utm_source, ''), NULLIF(entry.metadata->>'utm_source', '')) IS NOT NULL
              OR COALESCE(NULLIF(entry.utm_medium, ''), NULLIF(entry.metadata->>'utm_medium', '')) IS NOT NULL
              OR COALESCE(NULLIF(entry.utm_content, ''), NULLIF(entry.metadata->>'utm_content', '')) IS NOT NULL
            )
        )`;
  }

  return `
      candidate_events AS (
        SELECT
          event_type,
          ${expr.sessionIdExpr} AS session_id,
          COALESCE(actor_user_id, user_id::text) AS actor_id,
          ${expr.tsExpr} AS event_ts,
          metadata,
          ${schema.columns.has('utm_campaign') ? 'utm_campaign' : "NULL::text AS utm_campaign"},
          ${schema.columns.has('utm_content') ? 'utm_content' : "NULL::text AS utm_content"},
          ${schema.columns.has('utm_source') ? 'utm_source' : "NULL::text AS utm_source"},
          ${schema.columns.has('utm_medium') ? 'utm_medium' : "NULL::text AS utm_medium"}
        FROM public.analytics_events
        WHERE event_category = 'app'
          AND ${expr.propertyExpr} = $1
          AND event_type = ANY($5::text[])
          AND ${expr.tsExpr} >= $2::timestamptz
          AND ${expr.tsExpr} <= $3::timestamptz
          AND ($4::text IS NULL OR ${expr.ingestPathExpr} = $4)
          AND ${expr.eventIdExpr} IS NOT NULL
          AND ${expr.sessionIdExpr} IS NOT NULL
          ${filterSql}
      ),
      base AS (
        SELECT candidate.*
        FROM candidate_events candidate
        ${directCohortSql}
      )`;
}
```

Then in `getActivationFunnel`, delete the now-duplicated `filterSql`, `directCohortSql` and `baseCte` blocks and replace with:

```js
    const baseCte = buildActivationBaseCte({ schema, expr, funnelKey, filters, params });
```

Keep the coverage block from Task 7 unchanged — it builds its own params and does not use this CTE.

- [ ] **Step 4: Add the bucket resolver and both series producers**

Add after `buildActivationBaseCte`:

```js
const SERIES_BUCKETS = new Set(['hour', 'day', 'week']);
const HOUR_MS = 3_600_000;

/// Bucket for a range.
///
/// An unrecognised value falls back to a range-derived bucket rather than
/// erroring, matching how `funnel` and `breakdown` behave in this module, so a
/// stale dashboard link still renders. (`getAppTimeSeries` predates that
/// convention and still throws; it is left as-is.)
function resolveSeriesBucket(bucket, range) {
  const requested = (bucket || '').toString().trim().toLowerCase();
  if (SERIES_BUCKETS.has(requested)) return requested;
  const span = range.to.getTime() - range.from.getTime();
  if (span <= 48 * HOUR_MS) return 'hour';
  if (span <= 31 * 24 * HOUR_MS) return 'day';
  return 'week';
}

/// Entry / account / activation sessions per bucket, for the trend chart.
async function getActivationFunnelSeries({
  property, from, to, ingest = null, funnel = null, bucket = null,
  utmCampaign = null, utmContent = null, utmSource = null, utmMedium = null,
}) {
  const normalizedProperty = normalizeProperty(property);
  const range = parseRange({ from, to });
  const ingestPath = normalizeIngest(ingest);
  const funnelKey = normalizeActivationFunnel(funnel);
  const definition = ACTIVATION_FUNNELS[funnelKey];
  const safeBucket = resolveSeriesBucket(bucket, range);

  const filters = {
    utmCampaign: normalizeActivationFilter(utmCampaign, ACTIVATION_FILTERS.utmCampaign.maxLength),
    utmContent: normalizeActivationFilter(utmContent, ACTIVATION_FILTERS.utmContent.maxLength),
    utmSource: normalizeActivationFilter(utmSource, ACTIVATION_FILTERS.utmSource.maxLength),
    utmMedium: normalizeActivationFilter(utmMedium, ACTIVATION_FILTERS.utmMedium.maxLength),
  };

  const filterKey = ACTIVATION_FILTER_KEYS.map((k) => filters[k] || 'all').join('::');
  const cacheKey = `admin:analytics:app:activation-series::${normalizedProperty}::${ingestPath || 'all'}::${funnelKey}::${safeBucket}::${filterKey}::${range.from.toISOString()}::${range.to.toISOString()}`;

  return cache.wrap(cacheKey, async () => {
    const schema = await getAnalyticsEventsSchema();
    if (!schema.exists) throwAnalyticsSchemaError();
    const expr = buildAnalyticsEventsExpr(schema.columns);

    // Only the three milestones the chart plots. Scanning the full stage list
    // would read events no series line ever uses.
    const entryStage = definition.entryStage;
    const registeredStage = definition.registeredStage;
    const activatedStage = definition.activatedStage;
    const stageList = Array.from(new Set([entryStage, registeredStage, activatedStage].filter(Boolean)));

    const params = [
      normalizedProperty,
      range.from.toISOString(),
      range.to.toISOString(),
      ingestPath,
      stageList,
    ];
    const baseCte = buildActivationBaseCte({ schema, expr, funnelKey, filters, params });

    const result = await query(
      `WITH ${baseCte}
       SELECT
         (date_trunc('${safeBucket}', (event_ts AT TIME ZONE 'UTC')) AT TIME ZONE 'UTC') AS bucket,
         COUNT(DISTINCT session_id) FILTER (WHERE event_type = '${entryStage}')::int AS entry_sessions,
         COUNT(DISTINCT session_id) FILTER (WHERE event_type = '${registeredStage}')::int AS registered_sessions,
         COUNT(DISTINCT session_id) FILTER (WHERE event_type = '${activatedStage}')::int AS activated_sessions
       FROM base
       GROUP BY 1
       ORDER BY 1`,
      params,
    );

    return {
      property: normalizedProperty,
      from: range.from.toISOString(),
      to: range.to.toISOString(),
      funnel: funnelKey,
      bucket: safeBucket,
      points: result.rows.map((r) => ({
        bucket: r.bucket,
        entrySessions: Number(r.entry_sessions || 0),
        registeredSessions: Number(r.registered_sessions || 0),
        activatedSessions: Number(r.activated_sessions || 0),
      })),
    };
  }, { ttlSeconds: 60 });
}

/// Anonymous acquisition pageviews per bucket, for the web trend chart.
async function getAnonymousAcquisitionSeries({ site, from, to, bucket = null }) {
  const normalizedSite = normalizeSite(site);
  const range = parseRange({ from, to });
  const safeBucket = resolveSeriesBucket(bucket, range);
  const schema = await getAnonymousPageviewsSchema();
  if (!schema.exists) throwAnonymousAcquisitionSchemaError();

  const cacheKey = `admin:analytics:acquisition:series::${normalizedSite}::${safeBucket}::${range.from.toISOString()}::${range.to.toISOString()}`;

  return cache.wrap(cacheKey, async () => {
    const result = await query(
      `SELECT
        (date_trunc('${safeBucket}', (created_at AT TIME ZONE 'UTC')) AT TIME ZONE 'UTC') AS bucket,
        COUNT(*)::int AS pageviews,
        COUNT(*) FILTER (WHERE has_click_id = true)::int AS click_id_views
       FROM public.anonymous_pageviews
       WHERE site = $1
         AND created_at >= $2::timestamptz
         AND created_at <= $3::timestamptz
       GROUP BY 1
       ORDER BY 1`,
      [normalizedSite, range.from.toISOString(), range.to.toISOString()],
    );

    return {
      site: normalizedSite,
      from: range.from.toISOString(),
      to: range.to.toISOString(),
      bucket: safeBucket,
      points: result.rows.map((r) => ({
        bucket: r.bucket,
        pageviews: Number(r.pageviews || 0),
        clickIdViews: Number(r.click_id_views || 0),
      })),
    };
  }, { ttlSeconds: 30 });
}
```

Add `getActivationFunnelSeries,` and `getAnonymousAcquisitionSeries,` to `module.exports`.

- [ ] **Step 5: Add the routes**

In `src/routes/adminAnalytics.js`, after the `/acquisition/diagnostics` handler:

```js
router.get('/acquisition/series', asyncHandler(async (req, res) => {
  const { site, from, to, bucket } = req.query;
  const data = await adminAnalyticsService.getAnonymousAcquisitionSeries({ site, from, to, bucket });
  res.json({ success: true, data });
}));
```

and after the `/app/activation-funnel` handler:

```js
// Entry / account / activation sessions over time, for the campaign trend
// chart. Reads the same CTE and the same filters as the funnel itself, so the
// chart and the funnel beside it can never disagree.
router.get('/app/activation-funnel/series', asyncHandler(async (req, res) => {
  const {
    property, from, to, ingest, funnel, bucket,
    utmCampaign, utmContent, utmSource, utmMedium,
  } = req.query;
  const data = await adminAnalyticsService.getActivationFunnelSeries({
    property,
    from,
    to,
    ingest,
    funnel,
    bucket,
    utmCampaign: utmCampaign ?? req.query.campaign ?? req.query.utm_campaign,
    utmContent: utmContent ?? req.query.utm_content,
    utmSource: utmSource ?? req.query.utm_source,
    utmMedium: utmMedium ?? req.query.utm_medium,
  });
  res.json({ success: true, data });
}));
```

- [ ] **Step 6: Run the backend analytics suites**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend && npx jest __tests__/adminCampaignSeries.test.js __tests__/adminCampaignCoverage.test.js __tests__/adminActivationFunnelAttribution.test.js __tests__/adminAnalyticsRoutesAuth.test.js
```

Expected: PASS on all four.

- [ ] **Step 7: Commit**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend
git add src/services/adminAnalyticsService.js src/routes/adminAnalytics.js __tests__/adminCampaignSeries.test.js
git commit -m "feat(analytics): campaign time-series endpoints"
```

---

### Task 10: API client and pure chart data builders

**Files:**
- Modify: `admin.kubus/src/api/adminApi.ts`
- Create: `admin.kubus/src/utils/campaignCharts.ts`
- Test: `admin.kubus/src/utils/campaignCharts.test.ts`, `admin.kubus/src/api/adminApi.test.ts` (extend)

**Interfaces:**
- Consumes: Task 9's endpoints.
- Produces:
  - Types `AppActivationFunnelSeriesPoint`, `AppActivationFunnelSeries`, `AnonymousAcquisitionSeriesPoint`, `AnonymousAcquisitionSeries`
  - `adminApi.appActivationFunnelSeries(property, from, to, options)` and `adminApi.anonymousAcquisitionSeries(site, from, to, bucket)`
  - `funnelStageChartData(stages, labelFor)`, `campaignTrendChartData(points, isDirect)`, `acquisitionTrendChartData(points)`, `campaignComparisonChartData(rows, isDirect)`, `breakdownChartData(rows, label)` — all returning `ChartData<'bar'|'line'>`

**Constraint restated:** `campaignCharts.ts` must not import `chartTheme.ts`. It returns data only.

- [ ] **Step 1: Write the failing chart-builder test**

Create `src/utils/campaignCharts.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import {
  acquisitionTrendChartData,
  breakdownChartData,
  campaignComparisonChartData,
  campaignTrendChartData,
  funnelStageChartData,
} from './campaignCharts'

describe('campaignCharts', () => {
  it('plots funnel stages in order with human labels', () => {
    const data = funnelStageChartData(
      [
        { stage: 'app_entry', sessions: 100 },
        { stage: 'account_session_created', sessions: 30 },
      ],
      (stage) => (stage === 'app_entry' ? 'Entry' : 'Account'),
    )

    expect(data.labels).toEqual(['Entry', 'Account'])
    expect(data.datasets[0].data).toEqual([100, 30])
  })

  it('renders an empty funnel as empty arrays, never a phantom series', () => {
    const data = funnelStageChartData([], (s) => s)
    expect(data.labels).toEqual([])
    expect(data.datasets[0].data).toEqual([])
  })

  it('labels the trend series for the funnel being viewed', () => {
    const points = [
      { bucket: '2026-07-01T00:00:00.000Z', entrySessions: 10, registeredSessions: 4, activatedSessions: 1 },
    ]

    expect(campaignTrendChartData(points, true).datasets.map((d) => d.label)).toEqual([
      'Attributed entries', 'Account sessions', 'Activated contributors',
    ])
    // The guest funnel's milestones are different events, so they get different
    // names rather than one set relabelled by accident.
    expect(campaignTrendChartData(points, false).datasets.map((d) => d.label)).toEqual([
      'Guest sessions', 'Account sessions', 'Completed action',
    ])
    expect(campaignTrendChartData(points, true).datasets[0].data).toEqual([10])
  })

  it('plots acquisition pageviews against click-id views', () => {
    const data = acquisitionTrendChartData([
      { bucket: '2026-07-01T00:00:00.000Z', pageviews: 30, clickIdViews: 12 },
    ])
    expect(data.datasets.map((d) => d.label)).toEqual(['Pageviews', 'Click ID views'])
    expect(data.datasets[1].data).toEqual([12])
  })

  it('compares campaigns on entry and activation', () => {
    const data = campaignComparisonChartData(
      [
        { dimension: 'open_call', entrySessions: 80, activatedSessions: 8, mapSessions: 0, completedSessions: 0 },
        { dimension: 'beta_waitlist', entrySessions: 40, activatedSessions: 6, mapSessions: 0, completedSessions: 0 },
      ] as any,
      true,
    )
    expect(data.labels).toEqual(['open_call', 'beta_waitlist'])
    expect(data.datasets[0].data).toEqual([80, 40])
    expect(data.datasets[1].data).toEqual([8, 6])
  })

  it('turns a key-value breakdown into a single labelled series', () => {
    const data = breakdownChartData([{ value: 'instagram', views: 12 }], 'Sources')
    expect(data.labels).toEqual(['instagram'])
    expect(data.datasets[0].label).toBe('Sources')
    expect(data.datasets[0].data).toEqual([12])
  })
})
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/utils/campaignCharts.test.ts
```

Expected: FAIL — `Failed to resolve import "./campaignCharts"`.

- [ ] **Step 3: Write the builders**

Create `src/utils/campaignCharts.ts`:

```ts
/**
 * Chart *data* for the campaign performance page.
 *
 * Data only — never options and never theme. `components/charts/chartTheme.ts`
 * reads `document.documentElement` at module scope, so importing it here would
 * make this module unusable in a plain Node test run.
 */
import type { ChartData } from 'chart.js'
import type {
  AnonymousAcquisitionSeriesPoint,
  AppActivationFunnelBreakdownRow,
  AppActivationFunnelSeriesPoint,
} from '../api/adminApi'

/** One bar per stage, in funnel order. */
export const funnelStageChartData = (
  stages: Array<{ stage: string; sessions: number }>,
  labelFor: (stage: string) => string,
): ChartData<'bar'> => ({
  labels: stages.map((entry) => labelFor(entry.stage)),
  datasets: [{ label: 'Sessions', data: stages.map((entry) => entry.sessions) }],
})

const bucketLabel = (iso: string) => {
  const parsed = Date.parse(iso)
  return Number.isFinite(parsed) ? new Date(parsed).toLocaleString() : iso
}

export const campaignTrendChartData = (
  points: AppActivationFunnelSeriesPoint[],
  isDirect: boolean,
): ChartData<'line'> => ({
  labels: points.map((point) => bucketLabel(point.bucket)),
  datasets: [
    {
      label: isDirect ? 'Attributed entries' : 'Guest sessions',
      data: points.map((point) => point.entrySessions),
    },
    {
      label: 'Account sessions',
      data: points.map((point) => point.registeredSessions),
    },
    {
      label: isDirect ? 'Activated contributors' : 'Completed action',
      data: points.map((point) => point.activatedSessions),
    },
  ],
})

export const acquisitionTrendChartData = (
  points: AnonymousAcquisitionSeriesPoint[],
): ChartData<'line'> => ({
  labels: points.map((point) => bucketLabel(point.bucket)),
  datasets: [
    { label: 'Pageviews', data: points.map((point) => point.pageviews) },
    { label: 'Click ID views', data: points.map((point) => point.clickIdViews) },
  ],
})

export const campaignComparisonChartData = (
  rows: AppActivationFunnelBreakdownRow[],
  isDirect: boolean,
): ChartData<'bar'> => ({
  labels: rows.map((row) => row.dimension),
  datasets: [
    {
      label: isDirect ? 'Entries' : 'Map sessions',
      data: rows.map((row) => (isDirect ? row.entrySessions : row.mapSessions) ?? 0),
    },
    {
      label: isDirect ? 'Activated' : 'Completed',
      data: rows.map((row) => (isDirect ? row.activatedSessions : row.completedSessions) ?? 0),
    },
  ],
})

export const breakdownChartData = (
  rows: Array<{ value: string; views: number }>,
  label: string,
): ChartData<'bar'> => ({
  labels: rows.map((row) => row.value),
  datasets: [{ label, data: rows.map((row) => row.views) }],
})
```

- [ ] **Step 4: Add the API types and methods**

In `src/api/adminApi.ts`, after `AppActivationFunnelQuery` (line ~361), add:

```ts
export type AppActivationFunnelSeriesPoint = {
  bucket: string
  entrySessions: number
  registeredSessions: number
  activatedSessions: number
}

export type AppActivationFunnelSeries = {
  property: string
  from: string
  to: string
  funnel: AppActivationFunnelKind
  bucket: 'hour' | 'day' | 'week'
  points: AppActivationFunnelSeriesPoint[]
}

export type AnonymousAcquisitionSeriesPoint = {
  bucket: string
  pageviews: number
  clickIdViews: number
}

export type AnonymousAcquisitionSeries = {
  site: string
  from: string
  to: string
  bucket: 'hour' | 'day' | 'week'
  points: AnonymousAcquisitionSeriesPoint[]
}
```

After `appActivationFunnel` (line ~3235), add:

```ts
  /** Entry / account / activation sessions over time, for the trend chart. */
  appActivationFunnelSeries: async (
    property: string,
    from?: string,
    to?: string,
    options?: {
      funnel?: AppActivationFunnelKind | null
      bucket?: string | null
      utmCampaign?: string | null
      utmContent?: string | null
      utmSource?: string | null
      utmMedium?: string | null
    },
  ) => {
    const params = new URLSearchParams({ property })
    if (from) params.set('from', from)
    if (to) params.set('to', to)
    if (options?.funnel) params.set('funnel', options.funnel)
    if (options?.bucket) params.set('bucket', options.bucket)
    if (options?.utmCampaign) params.set('utmCampaign', options.utmCampaign)
    if (options?.utmContent) params.set('utmContent', options.utmContent)
    if (options?.utmSource) params.set('utmSource', options.utmSource)
    if (options?.utmMedium) params.set('utmMedium', options.utmMedium)
    return request<{ success: true; data: AppActivationFunnelSeries }>(
      `/api/admin/analytics/app/activation-funnel/series?${params.toString()}`,
    )
  },
```

After `anonymousAcquisitionRecent`, add:

```ts
  anonymousAcquisitionSeries: async (site: string, from?: string, to?: string, bucket?: string | null) => {
    const params = new URLSearchParams({ site })
    if (from) params.set('from', from)
    if (to) params.set('to', to)
    if (bucket) params.set('bucket', bucket)
    return request<{ success: true; data: AnonymousAcquisitionSeries }>(
      `/api/admin/analytics/acquisition/series?${params.toString()}`,
    )
  },
```

- [ ] **Step 5: Add API path tests**

Append inside the existing `describe('adminApi anonymous acquisition analytics', …)` block in `src/api/adminApi.test.ts` (that block already has the `afterEach` teardown). Each test there creates its own local `fetchMock` and stubs it — follow that exactly:

```ts
  it('builds the campaign series paths', async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ success: true, data: { points: [] } }))
    vi.stubGlobal('fetch', fetchMock)

    await adminApi.appActivationFunnelSeries(
      'app.kubus.site', '2026-08-01T00:00:00.000Z', '2026-08-02T00:00:00.000Z',
      { funnel: 'direct_acquisition', bucket: 'hour', utmCampaign: 'open_call', utmSource: '' },
    )
    await adminApi.anonymousAcquisitionSeries(
      'art.kubus.site', '2026-08-01T00:00:00.000Z', '2026-08-02T00:00:00.000Z', 'day',
    )

    expect(requestPath(fetchMock.mock.calls[0][0])).toBe(
      '/api/admin/analytics/app/activation-funnel/series?property=app.kubus.site&from=2026-08-01T00%3A00%3A00.000Z&to=2026-08-02T00%3A00%3A00.000Z&funnel=direct_acquisition&bucket=hour&utmCampaign=open_call',
    )
    expect(requestPath(fetchMock.mock.calls[1][0])).toBe(
      '/api/admin/analytics/acquisition/series?site=art.kubus.site&from=2026-08-01T00%3A00%3A00.000Z&to=2026-08-02T00%3A00%3A00.000Z&bucket=day',
    )
  })
```

`jsonResponse` and `requestPath` are module-level helpers already defined at the top of that file (lines 5 and 25); `vi` is already imported. Nothing new to add.

Note the first assertion deliberately has no `utmSource`: the method omits blank filters so an empty string never narrows a query to the empty value, matching `appActivationFunnel`.

- [ ] **Step 6: Run tests, typecheck**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/utils/campaignCharts.test.ts src/api/adminApi.test.ts && npm run typecheck
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus
git add src/api/adminApi.ts src/api/adminApi.test.ts src/utils/campaignCharts.ts src/utils/campaignCharts.test.ts
git commit -m "feat(campaigns): series client and chart data builders"
```

---

### Task 11: Render the charts

**Files:**
- Create: `admin.kubus/src/components/campaigns/CampaignChartCard.vue`
- Modify: `admin.kubus/src/composables/useCampaignPerformance.ts`
- Modify: `admin.kubus/src/views/analytics/CampaignPerformanceView.vue`
- Test: `admin.kubus/src/composables/useCampaignPerformance.test.ts`, `campaignViews.regression.test.ts` (extend both)

**Interfaces:**
- Consumes: Task 10's client methods and builders.
- Produces: `perf.funnelSeries`, `perf.acquisitionSeries`, `perf.seriesError` on the composable.

- [ ] **Step 1: Write the failing composable test**

Append to `src/composables/useCampaignPerformance.test.ts` (and add the two new mocks to the `vi.mock` factory and the `beforeEach` reset list):

```ts
  it('loads the series alongside the funnel and survives a series failure', async () => {
    appActivationFunnel.mockResolvedValue(funnelPayload('direct_acquisition', 7))
    appActivationFunnelSeries.mockRejectedValue({ message: 'series down' })
    const perf = useCampaignPerformance(ref('app.kubus.site' as const))

    await perf.reload()

    // A failed chart must not blank the funnel beside it: they are independent
    // requests and the numbers are the more important half.
    expect(perf.funnel.value?.totals.entrySessions).toBe(7)
    expect(perf.funnelSeries.value).toEqual([])
    expect(perf.seriesError.value).toBe('series down')
    expect(perf.error.value).toBe('')
  })

  it('passes the resolved bucket and the active filters to the series', async () => {
    appActivationFunnel.mockResolvedValue(funnelPayload('direct_acquisition', 1))
    appActivationFunnelSeries.mockResolvedValue({ data: { points: [], bucket: 'day' } })
    const perf = useCampaignPerformance(ref('app.kubus.site' as const))
    perf.filters.campaign = 'open_call'

    await perf.reload()

    expect(appActivationFunnelSeries).toHaveBeenCalledWith(
      'app.kubus.site',
      perf.range.from.value,
      perf.range.to.value,
      expect.objectContaining({ bucket: 'day', utmCampaign: 'open_call' }),
    )
  })
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npx vitest run src/composables/useCampaignPerformance.test.ts
```

Expected: FAIL — `perf.funnelSeries` is `undefined`.

- [ ] **Step 3: Load the series in the composable**

Add to `useCampaignPerformance.ts`: the imports for the two series types, these refs

```ts
  const funnelSeries = ref<AppActivationFunnelSeriesPoint[]>([])
  const acquisitionSeries = ref<AnonymousAcquisitionSeriesPoint[]>([])
  const seriesError = ref('')
```

and inside `reload`, after the funnel/acquisition assignment in each branch:

```ts
        // The chart is a separate request on purpose: if it fails, the numbers
        // beside it still render.
        try {
          const series = await adminApi.appActivationFunnelSeries(
            target, range.from.value, range.to.value,
            {
              funnel: funnelKind.value,
              bucket: range.bucket.value,
              utmCampaign: normalized.value.campaign || null,
              utmContent: normalized.value.content || null,
              utmSource: normalized.value.source || null,
              utmMedium: normalized.value.medium || null,
            },
          )
          if (id !== requestId) return
          funnelSeries.value = series.data.points
        } catch (e: any) {
          if (id !== requestId) return
          funnelSeries.value = []
          seriesError.value = describeError(e, 'Failed to load the trend chart')
        }
```

and the web equivalent:

```ts
        try {
          const series = await adminApi.anonymousAcquisitionSeries(
            target, range.from.value, range.to.value, range.bucket.value,
          )
          if (id !== requestId) return
          acquisitionSeries.value = series.data.points
        } catch (e: any) {
          if (id !== requestId) return
          acquisitionSeries.value = []
          seriesError.value = describeError(e, 'Failed to load the trend chart')
        }
```

Reset `seriesError.value = ''` next to `error.value = ''` at the top of `reload`, and add `funnelSeries, acquisitionSeries, seriesError` to the returned object.

- [ ] **Step 4: Create `CampaignChartCard.vue`**

A single wrapper so every chart gets the same empty and error states.

```vue
<script setup lang="ts">
import type { ChartData } from 'chart.js'
import BarChart from '../charts/BarChart.vue'
import LineChart from '../charts/LineChart.vue'

const props = defineProps<{
  title: string
  kind: 'bar' | 'line'
  data: ChartData<'bar'> | ChartData<'line'>
  empty: boolean
  error?: string
  height?: number
  horizontal?: boolean
}>()
</script>

<template>
  <div class="rounded-xl border border-[var(--color-border)] p-4">
    <div class="text-xs uppercase tracking-wide text-[var(--color-text-tertiary)]">{{ title }}</div>
    <p v-if="error" class="mt-3 text-sm text-[var(--color-error)]">{{ error }}</p>
    <!-- An axis with no series reads as "zero", which is not the same as "no
         data in this range". Say which one it is. -->
    <p v-else-if="empty" class="mt-3 text-sm text-[var(--color-text-tertiary)]">
      No data in this range yet.
    </p>
    <div v-else class="mt-3">
      <BarChart
        v-if="kind === 'bar'"
        :data="(props.data as ChartData<'bar'>)"
        :height="height ?? 240"
        :options="horizontal ? { indexAxis: 'y' } : undefined"
      />
      <LineChart v-else :data="(props.data as ChartData<'line'>)" :height="height ?? 240" />
    </div>
  </div>
</template>
```

- [ ] **Step 5: Render the charts in the performance view**

Add imports:

```ts
import CampaignChartCard from '../../components/campaigns/CampaignChartCard.vue'
import {
  acquisitionTrendChartData,
  breakdownChartData,
  campaignComparisonChartData,
  campaignTrendChartData,
  funnelStageChartData,
} from '../../utils/campaignCharts'
```

Add computeds:

```ts
const trendData = computed(() => campaignTrendChartData(perf.funnelSeries.value, isDirect.value))
const stageData = computed(() =>
  funnelStageChartData(perf.funnel.value?.stages ?? [], stageLabel))
const comparisonData = computed(() =>
  campaignComparisonChartData(perf.funnel.value?.breakdownRows ?? [], isDirect.value))
const acquisitionTrendData = computed(() => acquisitionTrendChartData(perf.acquisitionSeries.value))
const sourceData = computed(() =>
  breakdownChartData(perf.acquisitionSummary.value?.bySource ?? [], 'Sources'))
const mediumData = computed(() =>
  breakdownChartData(perf.acquisitionSummary.value?.byMedium ?? [], 'Mediums'))
const contentData = computed(() =>
  breakdownChartData(perf.acquisitionSummary.value?.byContent ?? [], 'Creatives'))
```

In the app-funnel `PanelCard`, after the stat tiles and before the duration tiles:

```html
        <div class="mt-4 grid gap-4 xl:grid-cols-2">
          <CampaignChartCard
            title="Over time" kind="line" :data="trendData"
            :empty="perf.funnelSeries.value.length === 0" :error="perf.seriesError.value"
          />
          <CampaignChartCard
            title="Funnel stages" kind="bar" :data="stageData" horizontal
            :empty="(perf.funnel.value?.stages?.length ?? 0) === 0"
          />
        </div>
        <CampaignChartCard
          v-if="perf.funnel.value?.breakdownRows?.length"
          class="mt-4"
          :title="`By ${(perf.funnel.value.breakdown || 'campaign').replace(/_/g, ' ')}`"
          kind="bar" :data="comparisonData" :empty="false"
        />
```

In the web `PanelCard`, after the stat tiles:

```html
          <CampaignChartCard
            class="mt-4" title="Pageviews over time" kind="line" :data="acquisitionTrendData"
            :empty="perf.acquisitionSeries.value.length === 0" :error="perf.seriesError.value"
          />
          <div class="mt-4 grid gap-4 xl:grid-cols-3">
            <CampaignChartCard title="Sources" kind="bar" :data="sourceData"
              :empty="(perf.acquisitionSummary.value?.bySource?.length ?? 0) === 0" />
            <CampaignChartCard title="Mediums" kind="bar" :data="mediumData"
              :empty="(perf.acquisitionSummary.value?.byMedium?.length ?? 0) === 0" />
            <CampaignChartCard title="Creatives" kind="bar" :data="contentData"
              :empty="(perf.acquisitionSummary.value?.byContent?.length ?? 0) === 0" />
          </div>
```

Delete the three replaced key-value lists (Sources, Mediums, Content) if they were ported in Task 6. Referrer origins, landing paths and click-ID presence stay as lists — they are long-tail strings that read better that way.

- [ ] **Step 6: Extend the view regression test**

Append to `campaignViews.regression.test.ts`:

```ts
describe('campaign charts', () => {
  it('compiles the chart card and renders it on the performance page', () => {
    expectSfcToCompile(componentPath('CampaignChartCard.vue'), 'CampaignChartCard.vue')
    expect(repoFile('src/views/analytics/CampaignPerformanceView.vue')).toContain('CampaignChartCard')
  })

  it('keeps chart data building out of the theme-dependent chart module', () => {
    const charts = repoFile('src/utils/campaignCharts.ts')
    // chartTheme.ts touches document at module scope; importing it here would
    // make this module unusable in a plain Node test run.
    expect(charts).not.toContain('chartTheme')
  })
})
```

- [ ] **Step 7: Run the full verify**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npm run verify
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus
git add src/components/campaigns src/composables src/views/analytics
git commit -m "feat(campaigns): charts on the campaign performance page"
```

---

## Final verification

- [ ] **Backend full suite**

```bash
cd /g/WorkingDATA/art.kubus/art.kubus/backend && npx jest __tests__/adminAnalytics __tests__/adminActivationFunnel __tests__/adminCampaign
```

- [ ] **Admin full verify**

```bash
cd /g/WorkingDATA/art.kubus/admin.kubus && npm run verify
```

- [ ] **Manual QA** (requires the admin console running against a live API)

1. Build a link for each of `art.kubus.site`, `kubus.site` and `app.kubus.site`, including an `app.kubus.site/` root link — no spurious warning, and `Send test event` enabled for the two web properties.
2. Visit `/analytics/campaign-builder` and confirm it redirects to `/analytics/campaigns/links`.
3. On `/analytics/campaigns`, change the range preset and confirm both the numbers and the trend chart reload.
4. Toggle the OS colour scheme and confirm charts stay legible in both themes (`chartTheme.ts` reads the `dark` class on `documentElement`).
