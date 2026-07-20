# Art Platform Visual Refresh — Completion Implementation Plan

Date: 2026-07-19
Spec: `docs/superpowers/specs/2026-07-19-art-platform-visual-refresh-completion-design.md`
Branch: `ux/complete-art-platform-visual-refresh`
(worktree `../art.kubus-complete-art-platform-visual-refresh`, based on
`origin/master` @ c6ba8cea, which already contains PR #42)
Toolchain: puro env `canonical_qa` (Flutter 3.44.2 stable — matches CI).

Each increment is an independent commit ending with focused tests +
`flutter analyze`.

## Increment 1 — Analytics localization

Files:

- `lib/l10n/app_en.arb`, `lib/l10n/app_sl.arb` — new `analytics*` keys
  (metric labels/descriptions, preset titles/scope labels, blocked-state
  copy, insights, comparisons, chart series, filter sheet, export/share).
- `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`,
  `app_localizations_sl.dart` — hand-patched per repo convention
  (`_safeCanonicalizedLocale` untouched; locale-guard test must stay green).
- `lib/features/analytics/analytics_metric_registry.dart` — full
  `localizedLabel`/`localizedDescription` coverage; raw label/description
  strings removed from definitions.
- `lib/features/analytics/analytics_presets.dart` — `localizedTitle`,
  `localizedScopeLabel`, complete `localizedSubtitle`.
- `lib/features/analytics/analytics_entity_registry.dart` — localized scope
  label accessor.
- `lib/features/analytics/analytics_capability_resolver.dart` — replace
  string title/description with `AnalyticsBlockedReason` enum; new
  `lib/features/analytics/analytics_blocked_copy.dart` maps reason → l10n.
- `lib/features/analytics/unified_analytics_screen.dart`,
  `widgets/analytics_header.dart`, `widgets/analytics_state_widgets.dart`,
  `widgets/analytics_trend_panel.dart`,
  `widgets/analytics_compare_panel.dart`,
  `widgets/analytics_insights_panel.dart` — all copy via l10n.
- `lib/screens/desktop/community/desktop_profile_screen.dart` — analytics
  dialog copy via l10n.

Tests: extend `test/features/analytics/analytics_metric_registry_test.dart`
(all metrics resolve localized copy in EN and SL); update
`analytics_capability_resolver_test.dart` for the reason enum; new
`test/l10n/analytics_l10n_parity_test.dart` (EN/SL key parity for the
analytics namespace); keep `app_localizations_locale_guard_test.dart` green.

## Increment 2 — Responsive filter architecture

Files:

- `lib/features/analytics/widgets/analytics_shell_scaffold.dart` — delete
  `_AnalyticsFilterHeaderDelegate` (86/148); mobile pinned summary with
  deterministic text-scale-aware extent; desktop `SliverToBoxAdapter`.
- `lib/features/analytics/widgets/analytics_filter_bar.dart` — desktop-only
  compact toolbar (chips + dropdown, wrap-capable, focus-visible).
- New `lib/features/analytics/widgets/analytics_filter_summary_bar.dart` —
  mobile chip row (metric + timeframe, opens sheet).
- New `lib/features/analytics/widgets/analytics_filter_sheet.dart` —
  `BackdropGlassSheet` with metric rows + timeframe chips.
- `lib/features/analytics/unified_analytics_screen.dart` — wiring.

Tests: rewrite `test/features/analytics/analytics_shell_scaffold_test.dart`
(mobile pinned summary at 1.0× and 1.6× text scale without overflow, desktop
unpinned toolbar, long-SL-label wrap, embedded variant); new widget test for
sheet selection persistence through `AnalyticsFiltersProvider`.

## Increment 3 — Analytics section surfaces + states

Files:

- New `lib/features/analytics/widgets/analytics_section_panel.dart`
  (wraps `KubusReadingSurface`).
- `analytics_trend_panel.dart`, `analytics_insights_panel.dart`,
  `analytics_compare_panel.dart` — adopt the panel; keep content stable
  during filter refresh (loading overlay only on the affected region).
- `analytics_state_widgets.dart` — distinct empty/error/permission
  presentation, localized defaults.

Tests: trend-panel state test (loading with prior data keeps chart; error
shows error copy; unsupported shows snapshot-only copy).

## Increment 4 — Desktop owner profile composition

Files:

- `lib/widgets/secure_account_banner_card.dart`,
  `lib/widgets/wallet_backup_banner_card.dart` — optional
  `onVisibilityResolved` callback + localized remaining strings
  (`Dismiss`/`Not now`/`Secure`).
- New `lib/widgets/profile/profile_account_health_section.dart`.
- `lib/screens/desktop/community/desktop_profile_screen.dart` — two-column
  from 1200 px directly under the identity card; cultural content main
  column; side column = compact stats → account health → badges →
  performance → achievements; single-column order per spec.

Tests: new
`test/widgets/profile/profile_account_health_section_test.dart`
(critical-only / advisory-only / both / none); desktop profile smoke builds
at 1280 and 1440 px without overflow.

## Increment 5 — Visual QA harness + matrix

Files:

- `scripts/qa/web_runtime_smoke.mjs` / support — port-hygiene fail-fast,
  build fingerprint in the JSON report, EN/SL + viewport matrix routes for
  analytics and profile surfaces where the stubbed harness supports them.
- Artifacts under
  `output/visual-qa/art-platform-visual-refresh-completion/{before,after}/`.

Order: capture `before` from a clean `origin/master` build **first** (before
increments land), `after` from the branch build at the end.

## Increment 6 — Docs

- This plan + spec finalized; `docs/SCREENS.md` updated if section orders are
  documented there.

## Validation (final)

- `puro flutter analyze --fatal-infos --fatal-warnings`
- `puro dart run custom_lint` (ratchet stays 0/0/0/0/0)
- `puro dart format --output=none --set-exit-if-changed <touched files>`
- Focused suites per increment; full `puro flutter test` at the end
- `puro flutter build web --release`
- `npm run qa:web:test`, `npm run qa:web`, `npm run verify:architecture`,
  `npm run docs:doctor` (known local failure: missing backend submodule)
- `git diff --check`

## Conflict risks

- PR #42 is already merged into the base — no rebase risk remains, but
  artwork-detail files are not touched at all by this plan.
- Another session's uncommitted work exists in the main checkout on
  `fix/walking-navigation-flow-and-ui` (touches `analytics_presets.dart`,
  `analytics_filter_bar.dart`, `analytics_trend_panel.dart`). This worktree
  never reads or writes that checkout; if that branch merges first, rebase
  semantically before opening the PR.

## Rollback

Each increment is one commit; reverting restores the prior state. No schema,
route, or backend changes.
