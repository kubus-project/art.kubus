# Art Platform Visual Refresh — Implementation Plan

Date: 2026-07-16
Spec: `docs/superpowers/specs/2026-07-16-art-platform-visual-refresh-design.md`
Branch: `ux/art-platform-visual-refresh` (worktree `../art.kubus-ux-art-platform-visual-refresh`)
Toolchain: puro env `canonical_qa` (Flutter 3.44.2 stable — matches CI).

Each increment is independently revertable and ends with focused tests +
`flutter analyze`.

## Increment 1 — Theme foundation (systemic contrast fix)

Files:

- `lib/utils/app_color_utils.dart` — add `AppColorUtils.onColor(Color)`
  (brightness-estimated black/white foreground) if absent.
- `lib/providers/themeprovider.dart` — complete both `ColorScheme`s:
  `onPrimary` (computed from accent), `onPrimaryContainer`, `onSecondary`,
  `onSecondaryContainer`, `tertiary`/`onTertiary`/`tertiaryContainer`/
  `onTertiaryContainer`, `onError`. `elevatedButtonTheme.foregroundColor`
  switches from hardcoded white to the computed on-accent.
- `lib/widgets/kubus_button.dart` — new `KubusButtonVariant.accent` and
  `.destructive` consuming scheme.primary/error + computed foregrounds.
- `lib/widgets/detail/detail_shell_sections.dart` — `DetailBadge` default
  foreground: auto-contrast instead of `Colors.white`.
- New `lib/widgets/common/kubus_reading_surface.dart` — quiet tonal container
  for long-form text (no blur; `surfaceContainerHighest`-style tint, hairline
  border optional, tokenized padding). Export from `kubus_kit.dart`.

Tests (new):

- `test/utils/theme_scheme_contrast_test.dart` — for every
  `ThemeProvider.availableAccentColors` × {dark, light}: contrast(onPrimary,
  primary) ≥ 4.5, contrast(onSecondaryContainer, secondaryContainer) ≥ 4.5,
  contrast(onPrimaryContainer, primaryContainer) ≥ 4.5, contrast(onSurface,
  surface) ≥ 4.5. Include a plain contrast-ratio helper in the test.
- Extend `test/widgets/kubus_button_states_test.dart` for accent/destructive
  variants (enabled/disabled/loading, light+dark, blur on/off).

Risk: scheme-wide foreground changes are intentional (fixes the bug class);
verify no goldens depend on black-on-accent (repo has no goldens).

## Increment 2 — Artwork detail

Files: `lib/screens/art/art_detail_screen.dart`,
`lib/screens/desktop/art/desktop_artwork_detail_screen.dart`,
`lib/widgets/detail/detail_shell_primitives.dart` (only if a param is
missing).

Mobile:

- Title block → `DetailIdentityBlock`; ad-hoc chips/tags → `DetailContextCluster`.
- Description → `ExpandableDetailText` on `KubusReadingSurface` (currently bare text).
- Action rows: Navigate becomes the accent CTA (`DetailPrimaryCtaButton` or
  scheme-fixed `DetailActionButton`); Show on map secondary; owner actions
  remain in the owner sheet. All colors from the (now complete) scheme.
- Keep hero sliver; scrim stays but via tokens where the lint requires.

Desktop:

- Media column becomes dominant: media no longer height-capped at 320 —
  aspect-driven within the left pane; identity + actions right under it.
- Description card → reading surface.

Preserve: takeover-ready scheduling, contextual auth, attendance/POAP flows,
claims, gallery cover-dedup order, `ArtworkLocationActions` routing.

Tests: existing detail tests must pass; add/adjust a widget test asserting
the Navigate action uses onPrimary-contrast colors in dark mode.

## Increment 3 — Event + exhibition detail

Files: `lib/screens/events/event_detail_screen.dart`,
`lib/screens/events/exhibition_detail_screen.dart`.

- Cover image moves out of the overview glass card to an edge-to-edge media
  block above it (16:9, rounded, tappable state preserved).
- Exhibition top actions: raw `IconButton` row → `DetailSecondaryActionCluster`
  (same pattern as event).
- Description/about (`ExpandableDetailText`) rendered on `KubusReadingSurface`
  instead of inside `LiquidGlassPanel`.
- What/when/where/who stays via `DetailIdentityBlock` + `DetailMetadataBlock`
  (already present) — hierarchy sharpened, status badge not dominant.

Preserve: POAP eligibility/claim chains, attendance, scan-proof handoff,
`PublicEntityTakeoverReady`, linked sections.

## Increment 4 — Home

Files: `lib/screens/home_screen.dart`,
`lib/screens/desktop/desktop_home_screen.dart`,
`lib/widgets/home/home_promotion_rail.dart`.

Mobile order becomes: header → welcome (slimmed; CTA text via computed
on-accent) → **home rails (content, image-led, larger media)** → quick
actions → stats (compact) → web3 strip → recent activity → support.
Desktop: rails move above the stats grid; right-sidebar "Trending Art" rows
render artwork imagery via `MediaUrlResolver` instead of gradient icon boxes.

Fixes: `Colors.orange` DEVNET pill on desktop → mobile's
`web3Provider.currentNetwork` + scheme pattern; `Colors.amber` →
`roles.achievementGold`; desktop hardcoded strings → existing l10n keys
(mobile already has them).

Preserve: quick-action registry/executor contracts, search + deep-link
routing, rail navigation per entity type, wallet-gating, data lifecycles.

## Increment 5 — Analytics

Files: `lib/features/analytics/widgets/analytics_overview_grid.dart`,
`analytics_insights_panel.dart`, `analytics_trend_panel.dart`,
`analytics_metric_colors.dart`,
`lib/widgets/charts/stats_interactive_line_chart.dart` (axis label
formatting only).

- Overview: first overview metric renders as a full-width lead card (large
  value + trend); remaining metrics as smaller supporting tiles; hover glow
  gradients calmed (tint, not neon shadow).
- Metric category colors remapped off `statCoral`/`statGreen` (collision with
  negative/positive judgment) onto statBlue/statTeal/statAmber/statPurple.
- Trend delta color unified on `roles.positiveAction/negativeAction`.
- Insights: drop index-modulo accent decoration; quiet reading-surface list.
- Axis labels use compact formatting (`AnalyticsMetricRegistry.formatCompact`
  -style) instead of raw `round().toString()`.

NOT touched: capability resolver, presets, registry availability logic,
filters provider, ensureSnapshot/ensureSeries keys, export/share.

## Increment 6 — Profiles

Files: `lib/screens/community/profile_screen.dart`,
`lib/screens/community/user_profile_screen.dart`,
`lib/screens/desktop/community/desktop_profile_screen.dart`,
`lib/screens/desktop/community/desktop_user_profile_screen.dart`,
`lib/widgets/artist_badge.dart`, `lib/widgets/institution_badge.dart`,
l10n arb + generated files (hand-patched per repo convention).

- Public profiles (mobile+desktop): follow/message actions move directly
  under the identity header, above stats.
- Own profile (mobile+desktop): cultural content (saved/highlights/posts)
  moves above the stats grid; performance stat stack merges with the stats
  grid into one compact strip (dedupe followers/following).
- Wallet pill made compact/secondary inside the identity card.
- `ARTIST`/`INSTITUTION` badges localized.
- Verified badge rendered consistently (all four screens) when `isVerified`.
- Empty showcase sections hidden for visitors (own profile keeps
  actionable empty states).

Preserve: identity keying (wallet), `UserProfileNavigation.open`, contextual
auth returnRoutes, follow/message/block/report flows, privacy gates,
takeover wrappers, hero tags, prefetch caches.

## Increment 7 — Sweep + docs

- Repo-wide grep for the audited raw-color/off-system patterns introduced by
  the touched areas; fix only coherent related issues.
- Update `docs/SCREENS.md` if section orders are documented there.
- Spec/plan docs finalized; markdownlint tidy.

## Validation (every increment + final)

- `puro flutter analyze --fatal-infos --fatal-warnings`
- `puro dart run custom_lint` + `node tool/` ratchet check (must stay 0s)
- Focused `puro flutter test <area>` per increment; full
  `puro flutter test` at the end (document pre-existing 3.44.2 failures:
  ink_sparkle shader tests, map-glass region toggle tests).
- `puro flutter build web --release`
- `npm run qa:web:test`, `npm run docs:doctor`, `npm run verify:architecture`
  where runnable locally.
- `git diff --check`
- Screenshots before/after under
  `output/visual-qa/art-platform-visual-refresh/` via the repo Playwright QA
  harness (`npm run qa:web`) at 390×844 and 1440×1000, light+dark.

## Rollback

Each increment is a separate commit; reverting any commit restores the prior
visual state. No data, schema, or route changes anywhere in the branch.
