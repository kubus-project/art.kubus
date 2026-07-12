# Slice 2 — Token Debt Burn-down (glass sweep recalibrated)

Date: 2026-07-11
Status: Executing under the standing UI-overhaul mandate (see 2026-07-10 slice-1 spec; roadmap item 2).

## Recalibration

Slice-1 verification showed the original "glass sweep" is mostly done: raw
`BackdropFilter` count is already **0** outside the canonical glass stack.
What actually remains for "professional, no weird design choices":

1. **Burn the grandfathered ratchet to zero.** 22 files still carry
   `// ignore_for_file: kubus_*` headers (12 raw-color / 7 raw-border /
   3 inline-google-fonts). Migrate every one onto tokens/roles/`KubusBorders`/
   `KubusTextStyles`; delete headers; ratchet ends at 0/0/0/0 and the rules
   become fully binding repo-wide.
2. **Register/auth accent alignment.** `/register` (`AuthMethodsPanel`
   standalone) renders a loud amber backdrop amid an otherwise teal/emerald
   auth flow (verified visually). Align its accent with the auth-flow family
   via the centralized role — a role-level change, not a per-widget color.

## Rules of migration

- Colors that are semantic → `KubusColorRoles` / scheme. Contextual sets
  (brand marks, AR/marker art) → new central files added to the lint
  allowlists: `lib/utils/kubus_brand_colors.dart` (Google brand colors etc.)
  and, if needed, marker/AR palette additions to already-allowlisted files.
- Borders → `KubusBorders.{hairline,glass,focus,active,accentTint,onDark}`.
  Alphas collapse onto the role ladder; ±0.1 alpha visual drift is accepted
  consolidation, anything larger keeps its exact value via a named token.
- Inline `GoogleFonts.*` → `KubusTextStyles`/textTheme equivalents.
- No layout/behavior changes. `const` may be dropped where a token getter
  replaces a literal.

## Batches (each: migrate → analyze → custom_lint → ratchet --write → targeted tests → commit)

- **A. Auth/onboarding widgets:** email_registration_form,
  google_sign_in_button (brand colors → kubus_brand_colors.dart),
  kubus_auth_method_button, onboarding_wallet_connect_step,
  wallet_mnemonic_backup_prompt, download_app_screen.
- **B. Community/profile:** community/profile_screen,
  desktop/community/desktop_profile_screen, desktop_home_screen.
- **C. Web3:** governance_hub (largest border cluster), desktop_wallet_screen,
  desktop_marketplace_screen.
- **D. Art/map:** art_detail_screen, exhibition_list_screen, map_screen,
  art_map_view, ar_view, art_marker_cube, marker_attribution_section.
- **E. Register accent alignment + full verification** (analyze, custom_lint,
  ratchet 0/0/0/0, full test suite vs the known pre-existing failure,
  visual pass via the project verify skill).

## Verification bar

Same as slice 1: zero new test failures (full suite baseline: +1235 ~1 -1
under puro 3.38.5), analyze/custom_lint clean, visual smoke of touched
surfaces light+dark.

## Outcome (2026-07-11)

- Batches A–E executed. **Ratchet: 0/0/0/0** — every grandfather header
  removed; the four kubus lint rules are now fully binding repo-wide.
- New central homes: `KubusBrandColors` (Google/Play/Twitter/Instagram),
  `KubusTypography.mono` + `.outfit`, `KubusColors.surfaceDarkElevated`,
  `MarkerCubePalette` (canvas marker art, in map_marker_style_config).
- Register backdrop accent aligned with sign-in (primary→positiveAction);
  previously lockedFeature→likeAction (orange/coral).
- Full suite: +1235 ~1 -1 — identical to baseline (the single failure is
  the pre-existing TabBar/Material assert under pinned Flutter 3.38.5).
