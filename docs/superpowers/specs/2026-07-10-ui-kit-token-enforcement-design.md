# UI Kit + Token Enforcement — Slice 1 Design

Date: 2026-07-10
Status: Approved (user), with amendment: contextual colors are legitimate but must be centralized.

## Context

The kubus design system already exists and is strong:

- `lib/utils/design_tokens.dart` — `KubusColors`, `KubusSpacing`, `KubusRadius`, `KubusTypography`/`KubusTextStyles`, `KubusGlassEffects`, per-surface glass profiles.
- `lib/widgets/glass/glass_surface.dart` + `lib/widgets/glass_components.dart` — canonical `GlassSurface` with `LiquidGlassPanel/Card`, `FrostedContainer`, `BackdropGlassSheet`, `FrostedModal`, `KubusAlertDialog`, low-power fallback.
- `lib/utils/kubus_color_roles.dart` — semantic `ThemeExtension` roles incl. web3 section accents.
- Partial kit: `KubusButton`, `KubusCard`, `KubusGlassIconButton`, `KubusGlassChip`, `KubusSearchBar`, `KubusScreenHeader`, `KubusStatCard`, `KubusSnackbar`, CreatorKit.

The problem is **adoption drift**, not missing infrastructure:

- 193 raw `Color(0x…)` literals across 20 files (auth, onboarding, wallet, map config).
- 546 `Border.all`/`BorderSide` call sites across 155 files, each inventing color/alpha.
- Ad-hoc glass reimplementations (`_glassIconButton`, `_buildGlassChip`, raw `BackdropFilter`s) in the map god-files instead of the canonical widgets.
- Nothing prevents new violations, so prior unification passes rot.

## Goal

One canonical component vocabulary; tokens enforced by lint so drift cannot recur; proven by migrating the most visible surfaces. The app should look professional: clean liquid glass, consistent borders, no one-off design choices.

## Non-goals (later slices)

Map engine unification, god-file decomposition, loading/skeleton language, prefetch/network overhaul. See Roadmap.

## Color policy (amendment)

Contextual colors are **allowed and encouraged** — section accents (web3 hubs), category accents, rarity colors, status colors may differ per context. The rule is *where they live*, not *whether they exist*:

- Every color is defined centrally: `KubusColors` (palette), `KubusColorRoles` (semantic/contextual roles), `category_accent_color.dart`, `rarity_ui.dart`, or `ThemeProvider.accentColor`/scheme.
- Widgets never define inline `Color(0x…)` literals. If a context needs a new color, it gets a named role/token first.

## Design

### 1. Kit consolidation — declare canon, fill gaps

No file moves (155+ importers). Instead:

- **Barrel** `lib/widgets/kubus_kit.dart` exporting the canonical set, with dartdoc acting as the "which component do I use" decision table. `lib/AGENTS.md` gains a short pointer.
- **New primitives** (in `lib/widgets/common/` unless noted):
  - `KubusBadge` — status/count/label pill; consolidates `CreatorStatusBadge` + ad-hoc badges. Colors only from roles/scheme.
  - `KubusBorders` (in `design_tokens.dart`) — the four semantic border roles:
    - `hairline(context)` — default container border (scheme.outline @ tokenized alpha)
    - `glass(context)` — glass surface border (existing glass border tokens)
    - `focus(context, {accent})` — focused input/interactive border
    - `active(context, {accent})` — selected/active state border
  - `KubusTextField` — general-purpose text field lifted from `CreatorTextField` patterns (above-label, token fill/border/focus) for non-creator screens.

### 2. Enforcement — in-repo `custom_lint` package + ratchet

- New package `packages/kubus_lints/` (custom_lint_builder), wired via dev_dependencies + `analysis_options.yaml`.
- **Rules v1** (tight on purpose):

| Rule | Flags | Fix direction |
|---|---|---|
| `kubus_no_raw_color` | `Color(0x…)` literals outside token/role files + small allowlist (brand art, marker style config) | tokens or roles |
| `kubus_no_raw_border` | `Border.all(`/`BorderSide(` whose color is a literal or `Colors.*` | `KubusBorders.*` |
| `kubus_no_raw_backdropfilter` | `BackdropFilter(` outside the glass stack files | `GlassSurface` family |
| `kubus_no_inline_google_fonts` | `GoogleFonts.*` outside `design_tokens.dart` | `KubusTextStyles`/textTheme |

- **Grandfathering:** one-time script adds `// ignore_for_file:` headers to currently-violating files → analyzer green day one; new code can't add violations anywhere.
- **Ratchet:** CI counts ignore headers per rule against a checked-in baseline (`tool/kubus_lint_ratchet.json`); count may only decrease. Migration slices delete headers as files are cleaned.
- CI: `dart run custom_lint` + ratchet check in `ci.yml`.
- **Risk/fallback:** if `custom_lint` is incompatible with the pinned Flutter/analyzer, ship the same rules as a CI grep-gate with the same ratchet file (no IDE squiggles, same guarantee).

### 3. Beachhead migration

1. **Map controls/chips (mobile + desktop map screens):** replace ad-hoc `_glassIconButton`/`_glassChip`/`_buildGlassIconButton`/`_buildGlassChip` with canonical `KubusGlassIconButton`/`KubusGlassChip`. Marker engine untouched (Slice 3).
2. **Onboarding + auth:** `onboarding_flow_screen.dart` (38 raw colors), `onboarding_data.dart` (29), `sign_in_screen.dart` → tokens/roles/`KubusBorders`.
3. **Connect-wallet:** `connectwallet_screen.dart` (24 raw colors + 23 border sites) — worst single offender.

Each migrated file loses its ignore header → ratchet ticks down, proving the mechanism.

### 4. Verification

- `flutter analyze` + `dart run custom_lint` green; ratchet baseline committed.
- Widget tests: `KubusBadge`, `KubusTextField`, `KubusBorders` (light/dark role resolution).
- Full existing suite (respecting known pre-existing flaky tests).
- Manual visual pass of beachhead surfaces: light + dark, blur-on + blur-off, mobile + desktop widths.

## Roadmap (each gets its own spec → plan cycle)

1. **This slice** — kit + enforcement + beachhead.
2. Glass sweep — remaining raw `BackdropFilter`s and glass one-offs.
3. Map engine unification — executes `docs/refactor/unification_audit.md`.
4. Loading/skeleton language — unified loading, empty, error states; perceived smoothness.
5. Prefetch & network — request dedupe, cache policy, prefetch on intent.
6. God-file decomposition — interleaved where it unblocks 2–5.
