# Art Platform Visual Refresh — Completion Design Specification

Date: 2026-07-19
Status: In progress (implementation branch `ux/complete-art-platform-visual-refresh`)
Predecessors: PR #37 (`feat(ux): refresh the art discovery, detail, analytics
and profile experience`), PR #38 (`fix(ux): persona-aware home, glass stat
tiles, cover profile actions, role-picker gate`), and the merged takeover work
through PR #42.

## 1. What is already solved (do not redo)

PR #37 delivered the systemic theme fix (complete `ColorScheme` `on*` pairs via
`AppColorUtils.onColor`), the `accent`/`destructive` `KubusButton` variants,
`KubusReadingSurface`, artwork/event/exhibition detail hierarchy, editorial
Home rails, the analytics lead-card + supporting-tile hierarchy, semantic
color decollision (`statCoral`/`statGreen` no longer double as category
colors), public-profile action placement, and localized artist/institution
badges.

PR #38 corrected the follow-ups per the designer's direction: persona-aware
Home ordering, surface-based glass tint on `KubusStatCard`, compact cover
follow/message actions, quiet wallet pill, deduplicated performance counters,
hidden empty visitor achievement sections, and the role-picker gate for
established accounts.

All of that is baseline. **Rok designed the profile and home section orders —
they must not be reordered on taste** (PR #38 lesson). Changes below are
scoped to the defects that PRs #37/#38 explicitly deferred.

## 2. Remaining defects (verified against current master c6ba8cea)

1. **Analytics copy is largely hardcoded English.** The metric registry
   (39 metrics × label + description, all but 2 pairs), preset
   titles/scope labels/2 subtitles, capability blocked-state copy (~12 pairs
   in `analytics_capability_resolver.dart`), the unified screen's insight/
   comparison/share/export strings, `analytics_state_widgets.dart` defaults,
   the header's Share/Export buttons, the trend panel's title/subtitle/series
   labels/empty states, the compare panel's headings and rows, the scope
   badge, and the desktop profile analytics dialog are all raw English.
2. **`AnalyticsShellScaffold` pins the filter bar at fixed 86/148 px.** Any
   text scale, long Slovenian label, narrow width, or wrap change clips or
   leaves dead space.
3. **Analytics panels hand-roll their surfaces.** Trend/insights/compare each
   rebuild `surfaceContainerHighest` + border + radius + title typography
   ad hoc; states (loading/refresh/empty/error/unsupported) are visually
   near-identical.
4. **Desktop owner profile leads with administration.** Order today:
   profile card → security banner → wallet-backup banner → stat cards →
   cultural content; the two-column split only starts at ≥1400 px and puts
   badges/performance/achievements at the top of the left column.
5. **The promised screenshot matrix was never completed**, and the July-15
   stale-proxy incident showed the smoke can silently pass against a zombie
   server on port 8090.

## 3. Analytics localization design

- Every user-facing analytics string moves to `AppLocalizations`
  (`app_en.arb` + `app_sl.arb` + the three generated files, hand-patched per
  repo convention — `_safeCanonicalizedLocale` guard stays intact).
- `AnalyticsMetricDefinition.localizedLabel/localizedDescription` switch over
  every metric id; the raw `label`/`description` fields are removed from the
  registry entries (no dead English fallbacks inside widgets).
- `AnalyticsPreset` gains `localizedTitle(l10n)`/`localizedScopeLabel(l10n)`
  and the existing `localizedSubtitle` covers all six presets.
- `AnalyticsCapabilityResolver` stops returning display strings. It returns a
  typed `AnalyticsBlockedReason` enum; a UI-side mapper
  (`analytics_blocked_copy.dart`) resolves title/description through l10n.
  Capability *rules* (who may see what) are unchanged.
- `AnalyticsScope.label` gets a localized accessor for the header badge.
- Orphaned keys from the pre-refresh stats screens
  (`analyticsInsightsEmptyTitle`, `analyticsComparisonTotal`,
  `analyticsPeakBucket`, `analyticsAveragePerBucket`, `commonNotAvailableShort`,
  `commonShare`, …) are reused where the meaning matches; new keys follow the
  `analytics*` prefix convention.
- Localization tests: an EN/SL parity test for the analytics key namespace and
  widget tests asserting SL copy renders in the states/filter sheet.

## 4. Responsive filter architecture

The fixed-extent `SliverPersistentHeader` is deleted. Replacement:

- **Mobile (<720 px): pinned compact summary + canonical sheet.** A new
  `AnalyticsFilterSummaryBar` renders one row: a metric chip and a timeframe
  chip (each shows the current value; both open the filter sheet). It is
  pinned with a *deterministic, text-scale-aware* extent
  (`chrome + lineHeight × textScaler`, min-height ≥ 44 px targets), and
  min == max so scrolling never animates a shrink (no jumps). Advanced
  controls open `showModalBottomSheet` + `BackdropGlassSheet`
  (`AnalyticsFilterSheet`): full metric list as tappable rows (selected state,
  descriptions), timeframe chip group, closes on selection persistence via the
  existing `AnalyticsFiltersProvider` (unchanged). No horizontal chip
  scrolling anywhere.
- **Desktop (≥720 px): unpinned intrinsic toolbar.** The filter bar becomes a
  plain `SliverToBoxAdapter` — intrinsic height, wraps freely for long SL
  labels and text scaling, keyboard-focusable controls (chips + dropdown),
  no reserved dead space. Pinning is dropped deliberately: the desktop
  viewport keeps the toolbar visible near the top and analytics content depth
  does not justify sticky chrome.
- Embedded analytics keep working: the scaffold API is unchanged
  (`embedded` flag, same slots), only the sliver composition changes.

## 5. Analytics surfaces and states

- New `AnalyticsSectionPanel` (features/analytics/widgets): thin wrapper over
  `KubusReadingSurface` with the standard section title row (title + optional
  trailing). Trend, insights, and compare panels adopt it — no more ad-hoc
  `surfaceContainerHighest` containers. Glass remains only on the floating
  filter sheet and summary bar (canonical stack).
- States become visibly distinct and localized:
  - initial load → `InlineLoading` + label;
  - filter refresh → the affected panel keeps its last content with a subtle
    refresh indicator (screen is never cleared);
  - no data / unsupported series / error / permission → distinct icon + copy
    via `AnalyticsInlineEmptyState`/`AnalyticsPermissionState`.
- Charts keep compact axis formatting; series labels ("Current"/"Previous")
  and tooltips are localized; delta colors stay on
  `positiveAction`/`negativeAction` with arrows (never color-only).
- No changes to calculations, request keys, capability rules, presets,
  registry availability, or filter persistence semantics.

## 6. Desktop owner profile composition

Target order (desktop `ProfileScreen`):

1. Header (title + actions) — unchanged.
2. Identity/profile card (cover, avatar, name, bio, socials) — unchanged
   internally.
3. **Two-column split begins immediately after the identity card** (threshold
   lowered from 1400 to 1200; single column below that):
   - **Main column (dominant): cultural content** — artist portfolio /
     institution programme / recently-viewed, then saved items, then posts —
     exactly the existing sections in their existing relative order.
   - **Side column (~360 px): owner context** — compact stat cards (2×2),
     then a new **Account health** group, then badges/verification,
     performance, achievements (existing relative order preserved).
4. Single-column (<1200): identity card → cultural content → stats →
   account health → performance → badges → achievements → posts.

**Account health** (`ProfileAccountHealthSection`, lib/widgets/profile/):

- Wraps the existing `WalletBackupBannerCard` (critical: unbacked mnemonic)
  and `SecureAccountBannerCard` (advisory: add email/password, dismissible).
- Both banner widgets gain an optional `onVisibilityResolved(bool)` callback
  (drop-in compatible) so the group knows what is actually showing.
- Critical notices always render inline and expanded. Advisory notices render
  inside a compact collapsed disclosure ("Account suggestions") when a
  critical notice is present; inline when they are the only notice. The
  section renders nothing (no header) when neither banner is visible.
- No warning is removed, no action is dropped, dismissal semantics are
  untouched. Mobile profile keeps its current banner placement (its first
  viewport is already identity-led; parity of the grouping widget is applied
  there only if the visual audit shows the same dominance problem).
- Widget tests cover: critical-only, advisory-only, both, none.

Public profiles, mobile profiles, and Home keep their PR #38-approved
composition; only defects proven by the visual audit are touched.

## 7. Visual QA architecture

- Artifacts live under
  `output/visual-qa/art-platform-visual-refresh-completion/{before,after}/`
  (gitignored).
- The maintained Playwright smoke (`scripts/qa`) is extended with a
  **build-identity + port-hygiene contract**:
  - the harness fails fast if the QA port is already owned by a foreign
    process (the July-15 zombie-proxy failure mode);
  - the served bundle is fingerprinted (git commit + `flutter_bootstrap`/
    main.dart.js hash) and recorded in a machine-readable report next to the
    screenshots;
  - console errors and non-2xx/3xx responses fail the run.
- The matrix is captured per screen × viewport (390×844, 412×915, 1024×768,
  1440×1000) × theme (light/dark) × locale (EN/SL) where deterministic data
  exists; states that need authenticated fixtures are captured through the
  stubbed-API harness where supported and listed as limitations otherwise.
- Screenshots are reviewed by eye; generation alone is not QA.

## 8. Accessibility

- All new controls: ≥44×44 targets, visible focus, semantic labels,
  keyboard traversal (sheet + toolbar), no color-only meaning.
- Text scale 1.3×+ must not clip the filter summary, sheet, or profile side
  column; long Slovenian strings verified in both filter compositions.
- Reduced motion: no new persistent motion; sheet uses standard modal route
  animations governed by the app theme.
- Blur-off fallback inherits from the canonical `GlassSurface` stack.

## 9. Protected behavior (unchanged)

Public takeover (`PublicEntityTakeoverReady`, readiness scheduling, canonical
routes, browser history — PR #42), contextual auth, identity keying
(wallet/profile), follow/message/block/report, walking navigation, marker
flows, analytics capability rules and request keys, filter persistence,
quick-action contracts, feature flags, lint ratchet 0/0/0/0/0.

## 10. Acceptance criteria

- `minExtent => 86` / `maxExtent => 148` no longer exist anywhere.
- `grep -rn "'" lib/features/analytics` shows no user-facing English literals.
- EN/SL analytics namespaces are key-for-key equal (tested).
- Desktop owner profile first viewport shows identity + cultural content;
  no full-width admin banner appears before cultural content at ≥1200 px.
- Critical wallet-backup warning remains visible whenever it fired before.
- All validation gates from `docs/LOCAL_VERIFICATION.md` pass on 3.44.2.
- Screenshot report proves branch build hash; matrix reviewed.
