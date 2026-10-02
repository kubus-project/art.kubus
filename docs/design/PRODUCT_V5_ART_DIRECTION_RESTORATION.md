# PRODUCT v5 art-direction restoration (Wave 5A-R)

> **Amended by Wave 5A-S** (`PRODUCT_V5_SEMANTIC_VISUAL_SYSTEM.md`): the
> ghost glyph is the only identity layer where it appears (no foreground
> icon tile beside it), and section headings are typographic.

Wave 4 removed nested glass, fake gradients and generic dashboard cards.
Wave 5A restored a teal-first colour system. Both were right, but together
they flattened PRODUCT into one repeated pattern (small icon box, number,
label, hairline). This pass brings back the visual devices that made the
master-era app recognisably art.kubus, rebuilt on the current architecture.
It changes appearance only: navigation, data, semantics, copy, measured
layouts and accessibility behaviour are unchanged.

This page is the contract. It amends the "Surfaces", "Contextual icons"
and "Stats" sections of `PRODUCT_V5_CHARACTER_REBALANCE.md`.

## Sources

| Reference | Used for |
| --- | --- |
| `dev@1be4de61` | Behaviour, IA, semantics, accessibility (kept) |
| `master@ee5554f0` | Visual archaeology only: rendered with the same fixtures |
| `20cda54f` | Contained in master; nothing it shows was missing from master |

## What master did better, and what came back

| Master device | Decision | Where it lives now |
| --- | --- | --- |
| Large cropped watermark glyph in stat tiles | ADAPT | `KubusGhostGlyph` in `KubusStatCard` (cropped harder, quieter, measured layout kept) |
| Contextually tinted quick-action tiles | ADAPT | `KubusActionTile` (tint is a corner field + edge, fill stays the surface) |
| Hub header bands (studio coral, institution blue) | ADAPT | `KubusDashboardHeader(accent:, glyph:)` |
| Amber wallet balance hero | ADAPT | `KubusWalletSectionCard(accent:)` / desktop balance |
| Teal cover gradient on profiles | ADAPT | `ProfileCoverField` in the role colour, not the user accent |
| Ljubljana map background (`GeneralBackground`) | ADAPT | `KubusAtmosphere(texture: cartographic)` on the Home opening only |
| Hover float on stat watermarks | ADAPT | Glyph drifts inside the clipped tile; tiles never move |
| Wallet-first / Web3-first Home hero | DISCARD | Home stays discovery-first |
| Liquid glass on every card, tinted management cards | DISCARD | Rails and forms stay flat and hairline-separated |
| Full-bleed gradient feature intros, per-page rainbow gradients | DISCARD | One feature colour per intro, on a hero context tile |
| Watermark that clipped numbers (28-53 px overflow at desktop/200 %) | DISCARD | Measured extents from 5A kept |
| Duplicate profile header / follower cards | DISCARD | One header owner kept |

## Vocabulary

- **Neutral structural surface** (unchanged): surface fill and hairline.
  Settings, lists, forms, rails, messages, search.
- **`KubusAtmosphere`**: identity field. A diffuse field of the contextual
  colour from one corner (20 % dark / 13 % light), a quieter secondary
  field opposite (9 % / 6 %), a 1 px edge light, optional cropped glyph and
  optional cartographic texture. Content sits on the plain surface tone.
  Use for page identity and hero context only.
- **`KubusGhostGlyph`**: oversized, cropped, low-opacity contextual symbol
  (11 % dark / 8.5 % light). Decorative: no semantics, no hit testing.
  Never behind running text.
- **Expressive metric** (`KubusStatCard`, default for the centred layout,
  opt-in for rows): compact context tile, number, label, plus a ghost glyph
  bleeding 36 % off the trailing corner, a corner field and an edge light.
- **`KubusActionTile`**: destination shortcut in the destination's colour.
- **`KubusHoverResponse`**: pointer-only hover; optional 2 px paint-only
  lift.

### Cartographic texture

The bundled dark Ljubljana tile is used as a line mask in both themes:
street luminance becomes alpha and lines are drawn in the theme foreground.
It is drawn at 1.6x anchored to the trailing edge so the tile's city label
never sits behind text. The light tile is not used (white roads on grey
paper cannot serve as a mask).

## Colour

No colour-role changes. Teal stays structural, blue secondary, contextual
colours semantic, the user accent personal. Contextual colours now also
drive fields, ghost glyphs and edge lights:

- Profiles: artist coral, institution blue, other accounts teal (role
  colour, the same as the role badges).
- Hubs: studio coral, institution blue, governance green, marketplace
  orange (`web3AccentForKey`).
- Wallet balance: amber (the wallet screen accent). Achievements: gold.
- Feature intros: the feature colour, never the per-page gradient list
  (which contains violet).

## Motion

- Stat tiles: hover brightens the field and edge and drifts/scales the
  glyph 4 px / 6 % inside the clipped tile. The tile and its text never
  move.
- Action tiles: 2 px paint-only lift, accent edge and soft accent shadow.
- Reduced motion (`MediaQuery.disableAnimations`, `prefers-reduced-motion`
  on web): no lift and no glyph drift; the brightening stays as a state
  change. Touch never hovers.

## Where it is not used

Settings, search, messages, forms, management rail sections, list rows and
public entity detail. Public entity detail is deliberately unchanged so the
server first frame and the Flutter takeover keep one hierarchy.

## Tests

`test/widgets/common/kubus_stat_card_test.dart` (ghost glyph is decorative,
cropped, larger than the tile glyph, the number never moves on hover, no
glyph drift under reduced motion), `test/design/product_v5_character_foundation_test.dart`,
`test/widgets/desktop/desktop_widgets_test.dart`, the measured-extent tests
at 1.0/1.3/2.0x and `test/qa/product_v5_responsive_sweep_test.dart`.

## Evidence

`docs/evidence/product-v5-art-direction/`. Flutter captures come from
`test/qa/product_v5_art_direction_visual_matrix_test.dart` (real Sofia Sans
and Space Mono) on dev, master and this branch. Browser captures come from
`scripts/qa/product_v5_art_direction_browser_qa.mjs` (offline Chromium:
200 % page zoom, pointer hover, reduced motion).
