# Profile identity hierarchy + semantic Home rails

Restore a coherent profile identity hierarchy across mobile and desktop, fix
truncated handles, replace bespoke relationship actions with canonical square
Kubus buttons, align public/owner/overlay profile composition, and implement
semantic color coding for all Home discovery rails.

## Root cause (grounded in code + PR history)

- **PR #37** (`ux/art-platform-visual-refresh`) refreshed profiles and Home. It
  added the bespoke cover-mounted profile header in
  `lib/screens/community/user_profile_screen.dart` (`_buildProfileHeader`) with
  `ElevatedButton` Follow/Message, and gave Home rails a single accent
  (`AppColorUtils.tealAccent` for artwork only) in `home_screen.dart`.
- **PR #38** ("cover profile actions") placed Follow/Message **on the cover in a
  horizontal row** competing with name + handle + badges. This is why long
  handles truncate and the actions feel undersized/misplaced.
- **PR #45** completed the refresh (account-health, desktop profile) but never
  revisited the header hierarchy or rail accents.

Observed in current `origin/master`:

- `lib/widgets/detail/profile_header_shell.dart` — a shared header primitive
  exists but is **referenced by no screen** (`rg ProfileHeaderShell` → only its
  own file). Handle normalization is duplicated inline in its two build methods
  and again across the four profile screens.
- `user_profile_screen.dart:988` Follow = `ElevatedButton` (bespoke, pill-ish,
  animated scale); `:1418` Message = `ElevatedButton`. Not `KubusButton`.
  Name uses `TextOverflow.ellipsis`; handle shares the cover row → truncation.
- `home_screen.dart:2303` rail icon color = `artwork ? tealAccent : scheme.primary`.
  `home_promotion_rail.dart` hover border / placeholder use `scheme.primary` with
  no entity awareness. `desktop_home_screen.dart` duplicates the switch.
- Handle rule already exists but is scattered: trim, strip one `@`, reject
  wallet-like via `WalletUtils.looksLikeWallet`.

## Canonical primitives to reuse (do not re-invent)

- `KubusButton` (`variant: accent|secondary`), square radius `KubusRadius.sm`,
  built-in loading/hover/press/disabled + contrast-computed on-accent foreground.
- `KubusColorRoles` stat palette: `statTeal / statBlue / statGreen / statCoral /
  achievementGold` — theme-aware, already used by `AppColorUtils.markerSubjectColor`.
- `WalletUtils.looksLikeWallet` for wallet-like fallback detection.
- `ProfileHeaderShell` + `ProfileIdentitySummary` for identity composition.

## Deliverables

### Phase 1 — canonical handle (`lib/utils/profile_handle.dart`)
`ProfileHandle.normalize(String?) -> String?` (null = no handle): trim, collapse
one leading `@`, reject empty / wallet-like / provisional generated ids; preserve
Unicode usernames; no invented max length. Unit tests in
`test/utils/profile_handle_test.dart`. Replace every inline normalization.

### Phase 5 — semantic rail resolver (`lib/utils/home_rail_semantics.dart`)
`HomeRailSemantics.accentFor(PromotionEntityType, KubusColorRoles) -> Color`
mapping artwork→statTeal, profile→statBlue, institution→statGreen, event→statCoral,
exhibition→achievementGold. Shared by mobile `home_screen.dart` +
`desktop_home_screen.dart` + `home_promotion_rail.dart` (section header icon,
icon tint, hover border, focus border, placeholder gradient, card edge). Text +
icon remain the non-color signal. Unit tests: five distinct roles, single resolver.

### Phases 2–4 — profile header unification
Evolve `ProfileHeaderShell` into the single identity primitive: handle on its own
line (no ellipsis), name may wrap 2 lines, badges stay with name, relationship
actions **below** identity via `KubusButton` (Follow accent/secondary, Message
secondary+icon), min 44×44 targets, wrap/stack on narrow widths. Desktop hierarchy
= identity → actions → stats → sections; owner keeps private sections after
cultural identity. Wire mobile + desktop public + owner + overlay to the shared
primitive & handle helper.

### Phase 6 — remove duplication
Delete bespoke `_buildProfileHeader` follow/message `ElevatedButton`s + unused
animation controllers/imports; remove per-screen normalization; single rail
resolver; `ProfileHeaderShell` actively used or removed.

## Tests / QA
- Unit: handle normalization, rail resolver.
- Widget: authenticated profile header across variants/widths/locales/themes/scales,
  asserting no overflow, full handle, 44×44 targets, traversal order, stats after actions.
- Home rail tests: distinct roles, shared resolver, header/card/placeholder accent.
- Authenticated visual QA via existing `scripts/qa` Playwright harness with build-hash gate.

## Rollback boundaries
Each phase is an independent commit. `profile_handle.dart` and
`home_rail_semantics.dart` are additive; screen wiring reverts per-commit.
Unrelated backend gitlink changes are never staged as part of this UI plan.
