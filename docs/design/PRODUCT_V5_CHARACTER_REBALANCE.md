# PRODUCT v5 character rebalance (Wave 5A)

Wave 4 made PRODUCT flat and truthful but also took most of its character
away: the active colour had drifted to electric blue, metric tiles lost
their icons, and several screens stacked tinted glass cards. Wave 5A
restores a teal-first family identity and local, semantic colour without
going back to glass, gradients or rainbow chrome.

This page is the contract. The tests named under each rule enforce it.

## Colour roles

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| Primary / active / focus | `#00766A` | `#4ECDC4` | Identity, selection, focus, primary action (Save, Publish), structural switch ON |
| Secondary | `#1F5FD0` | `#3F83FF` | Information, analytics, community, institution and secondary discovery context |
| Contextual | `KubusColorRoles` stat/web3 accents | | A metric's or section's own meaning (followers coral, created green, marketplace orange, …) |
| User accent | `ThemeProvider.accentColor` | | Personal highlights only. Never structure, never a screen accent |

- `KubusProductPalette.activeLight/Dark` and `secondaryLight/Dark` are the
  values; `KubusColorRoles.active` / `.secondary` expose them; the theme
  wires `ColorScheme.primary`/`tertiary` = teal and `secondary` = blue.
- `screenAccentForKey` returns teal for structural screens (home, settings,
  profile, wallet, map) and the blue secondary for community/analytics.
- Because `ColorScheme.secondary` used to equal the active colour, every
  `scheme.secondary` use was audited in 5A. Structural ones (settings
  identity header, dialog primary actions, role switches, message
  selection) moved to teal. Community, comment, analytics, governance
  reward, testnet and the user-location dot stay blue on purpose.

Tests: `test/design/product_v5_character_foundation_test.dart`,
`test/utils/theme_scheme_contrast_test.dart`.

## Surfaces

Flat and neutral: surface fill plus a hairline rule. No glass, gradient
banner or full-card tint on product surfaces (settings, profile,
management, wallet). Glass stays available for map and media overlays.

## Contextual icons

`KubusContextIcon` is the only contextual icon tile: a flat rounded square
with a 12 % accent wash, a 38 % accent hairline and a full-strength glyph.
No glass, glow or shadow.

| Size | Box | Glyph | Use |
| --- | --- | --- | --- |
| `compact` | 30 | 16 | Metric tiles, management rail sections, dense rows |
| `regular` | 38 | 20 | Section headers, settings sections |
| `hero` | 52 | 26 | Page identity, empty states |

Use it for section identity, metric category, asset identity and status.
Not for chevrons, back arrows, overflow menus or every list-row icon.

## Stats

`KubusStatCard` has two layouts. The centred layout is a fixed stack:
context icon tile, number, label. The accent paints only the icon tile and
the hover wash; the card stays neutral. There is no watermark and no hover
motion. The Wave-4 parameters (`tintBase`, `borderColor`, `iconBoxSize`,
`iconSize`, `centeredWatermark*`) are removed.

Grids of stat tiles use a **measured** height, never an aspect ratio:

- `KubusStatCard.centeredExtent(context, …)` measures icon + number +
  label lines with the tile's own styles at the ambient text scale.
- `DesktopStatCard.extentOf(context)` does the same for desktop tiles
  (134 px at 1.0×).
- `DesktopGrid(mainAxisExtent: …)` applies it.
- From 1.5× text the label gets one more line, and the measurement
  reserves it. A number wider than its tile scales down rather than being
  ellipsised.

Before 5A the profile stat tiles overflowed by 17–25 px at ordinary
desktop widths and by up to 71 px at 200 % text. They now render with no
overflow at 320–1920 px and at 200 % text.

Tests: `test/design/product_v5_character_foundation_test.dart`,
`test/widgets/common/kubus_stat_card_test.dart`,
`test/qa/product_v5_responsive_sweep_test.dart`. The profile harness no
longer allow-lists stat-card overflows.

## Header ownership

A screen has one header owner. Inside the desktop shell the owner profile
wraps its body in the shared `DesktopSubScreen` and passes its utilities
(Share, Invites, Analytics when the flag is on, Settings) as that bar's
`actions`; `DesktopShell` pushes it bare. The result is one row:
`[Back] Profile … [Share] [Invites] [Analytics] [Settings]`.

Utility actions are flat, neutral 44 px controls with a hairline. Hover
and keyboard focus answer in teal. They are never individually coloured.

Tests: `test/screens/desktop/profile_header_ownership_test.dart`.

## Settings

Email preferences read as three Space Mono groups separated by space, with
subtle rules inside each group:

- **Marketing:** product updates, newsletter, community digest
- **Activity:** artwork, community, governance, Artist Hub, Institution
  Hub, promotion
- **Essential:** critical account security, critical wallet security,
  account (transactional) mail. Always ON, locked, and explained by the
  group note.

App notifications (push, login, in-app categories) are a separate section
with a blue context tile. `SharedSettingsToggleRow` uses `Switch.adaptive`
with teal ON; its `mandatory` mode shows ON and cannot be changed. Mobile
previously rendered these rows as OFF.

The desktop settings sidebar is a flat surface with a right hairline. The
selected item has one teal indicator, wash and weight change; only Danger
Zone is red. Backend preference keys are unchanged.

Tests: `test/settings/settings_hierarchy_test.dart`.

## Management workspace

`DesktopCreatorShell` is used by every creator and by the artwork editor.
It has one flat header row, one edit column and one rail, separated by
hairlines. Rail sections are a compact context tile, a title and content,
closed by a hairline. They are not tinted cards.

- **Readiness:** one glyph per row. A green check means complete; an amber
  open ring means missing.
- **Actions:** primary teal. Save is the filled primary action.
- **Collaboration:** blue secondary. `CollaborationPanel(embedded: true)`
  drops its own card and title.

Artist Studio and Institution Hub rails no longer repeat the page's
notion, hub title and selected tab. Their numbers carry context tiles.

Tests: `test/widgets/creator/management_rail_test.dart`.

## KUB8 identity

- **Identity is the mint.** `KubusTokenIdentity.isCanonicalKub8(mint)`
  decides it. A token that calls itself KUB8 with another mint stays
  generic and never loads the house image.
- **Metadata first.** For canonical KUB8, `KubusTokenAvatar(imageUrl:)`
  shows the token's usable http(s) metadata image.
- **Bundled fallback.** If there is no metadata image, or it fails to
  load, the avatar shows `assets/images/logo.png`. That is the kubus
  lattice, which `SolanaWalletService` already records as KUB8's known
  logo; it is drawn as an alpha mask in the avatar colour. The generated
  cube is gone.
- The configured mint's metadata names the token `kubit` / `KUB8`. Its
  IPFS metadata image is currently unreachable from the providers tried,
  so users see the bundled logo today.
- **Where the mark appears:** wallet heroes (leading KUB8 balance), wallet
  asset rows and transaction cards. Marketplace, promotion, achievements
  and DAO show KUB8 as text and gain no new mark.

Tests: `test/widgets/kubus_token_identity_test.dart` covers the
metadata-first path, the fallback in light and dark at small and large
sizes, the wrong-mint impostor, SOL and generic tokens.

**Follow-up (separate PR, deliberately not in 5A):** IPFS gateway repair,
covering the default gateway order, retry behaviour and the pinning of the
KUB8 metadata and image.

## Evidence

`docs/evidence/product-v5-character-rebalance/` holds before/after pairs:
BEFORE from `dev@4dc26a17`, AFTER from the 5A branch. They come from the
opt-in matrix `test/qa/product_v5_character_rebalance_visual_matrix_test.dart`
(`KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after`). The 200 % captures use Flutter
text scaling, not browser zoom; a human browser-zoom pass is still
required.
