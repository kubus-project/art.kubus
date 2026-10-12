# PRODUCT v5 motion contract

**Status:** canonical. This is the single source of truth for hover and
pointer motion on the PRODUCT tile family. Every other document that mentions
hover, lift, float or reduced motion defers to this one. If a document
disagrees, this one wins and the other is wrong.

Why it exists: in 0.8.1 the approved hover was described in four documents
that did not agree (one said tiles lift, one said tiles never move, one said
compact rows answer without a lift, one said only the glyph moves). The code
followed whichever document was read last, the one-shot 2 px lift replaced the
continuous kubus float that owners had approved, and nothing measured what was
actually painted. Both halves are fixed here: one contract, and a gate that
measures pixels in a real browser.

## The contract

Machine-checked by `test/design/product_v5_motion_contract_doc_test.dart`: the
values in this block must equal the constants in `KubusHoverResponse`.

```text
liftDistance: 3
floatAmplitude: 1.5
floatPeriodMs: 2200
entryMs: 180
```

Hover (pointer only; touch never hovers) on a tile **floats**:

1. **Rise.** Over `entryMs` (180 ms, ease-out cubic) the whole surface rises
   `liftDistance` px as one painted unit.
2. **Float.** While the pointer stays, the surface keeps drifting up and down
   by `floatAmplitude` px around the lifted position, one cycle per
   `floatPeriodMs`. The band is 1.5 to 4.5 px above the resting line, so it
   never drops below where it started.
3. **Answer.** A soft contextual accent shadow
   (`KubusHoverResponse.accentShadow`), a stronger field and edge (expressive
   tiles) or accent hairline (dense tiles).
4. **Glyph.** A ghost glyph drifts inward and grows (`hoverShift`,
   `hoverScale`) and counter-floats against the surface
   (`KubusGhostGlyph.floatFraction` of its size), so the two read as depth.
5. **Exit.** The surface settles back over `entryMs`; the float fades with the
   lift and stops only once the surface is at rest. Nothing snaps.

Everything is a paint-only translation inside a `MouseRegion` that sits
outside the transform, so layout never moves and the hover region does not
flicker as the surface moves. Text and arrows move with the surface, never
relative to it, except the inline arrow's 2 px travel.

### Reduced motion

`MediaQuery.disableAnimations` (`prefers-reduced-motion` on the web) removes
the **animation**, not the **answer**: the tile takes its lifted position,
shadow, field, edge and indicator **at once**, stays perfectly still (no float,
no glyph drift or scale, no arrow travel) and returns at once on exit.

This is not a corner case. **The owner's Windows PC has "Animation effects"
off, so every browser on it reports `prefers-reduced-motion: reduce`.**
Anything that is gated on motion looks dead there, which is exactly how the
0.8.1 tiles looked: all v5 hover motion was disabled and the only visible
answer was a shadow tint. Always test the reduced mode first; to see the float
on that machine, turn Windows Settings, Accessibility, Visual effects,
Animation effects on.

### Which surfaces float

| Surface | Hover | Notes |
| --- | --- | --- |
| `KubusActionTile` stacked, inline, compact | rise + float + shadow + field/edge; glyph drift and counter-float (stacked, compact); arrow travel 2 px (inline) | compact also strengthens its leading indicator |
| `KubusActionTile` disabled or loading | none | no lift, no shadow, default cursor |
| `KubusStatCard` expressive (centred by default, or `expressive: true`) | rise + float + shadow + field/edge; glyph drift and counter-float | |
| `KubusStatCard` dense (standard layout by default) | rise + float + shadow + accent hairline | **layout density chooses the identity device, never whether the tile answers the pointer** |
| `KubusStatCard` informational (no `onTap`) | same visual answer; default cursor, no button semantics | visual feedback and button semantics are separate concerns |
| `DesktopStatCard`, `KubusSidebarStatCard`, `AchievementStatCard` | via `KubusStatCard` | they must not re-implement hover |

Deliberately **not** floating (do not "fix" these without an owner decision):

| Surface | Why |
| --- | --- |
| `KubusActionSidebarTile` (studio and hub side actions) | flat list rows by design since 0.8.0; hover tint only |
| `KubusEntityCard` | content card: one-shot lift (no float), media scale, no motion under reduced motion; pinned by `kubus_entity_card_test.dart` |
| `DesktopActionButton` | a button, not a tile: own 2 px lift and shadow |
| `DesktopCard`, rails, forms, list rows | flat; hover strengthens the rule |
| `KubusAtmosphere` and heroes | identity fields, not controls |

## Rules for changing hover

1. Hover lives in `KubusHoverResponse` and `KubusGhostGlyph`. A tile or card
   must not hand-roll a `MouseRegion` plus `Transform` or `transform:` for the
   same job; build on the primitive.
2. Use the contract constants. No new durations, distances or shadows.
3. A layout default must never remove interactivity. Add an identity device
   per layout; do not remove the response.
4. One PR that changes hover updates, together: the code, the constants block
   above, this document, the widget tests and the browser gate.
5. Reduced motion is verified first, in a real browser, not inferred.

## Acceptance

**Widget tests** (`flutter test`) pin exact paint transforms with the clock
under control: `kubus_action_tile_hover_test.dart` (every layout; rise,
intermediate entry frames, float band over a full period, glyph counter-float,
shadow fade, exit and `pumpAndSettle` proving the float stops, reduced motion,
disabled, disposal while hovered) and `kubus_stat_card_test.dart` (every
layout, tappable and informational, both motion modes).

**Browser gate** (`scripts/qa/product_motion_acceptance.mjs`, run by
`pr-validation.yml`, job `flutter_quality`): a real Chromium and Firefox
pointer over the gallery `tool/qa/product_motion_gallery_main.dart`, which
renders every layout at known coordinates. It screenshots at 2x, estimates the
tile's vertical offset against its rest frame to a fraction of a pixel and
measures the accent shadow below it, then fails unless:

| Check | Motion allowed | Reduced motion |
| --- | --- | --- |
| mean rise while hovered | at least 1.5 px | at least 1.5 px |
| peak-to-peak while the pointer stays | at least 1 px (it floats) | at most 0.6 px (it is still) |
| accent shadow below the tile | present | present |
| disabled tile | does not move or shadow | does not move or shadow |
| after the pointer leaves | back on the rest line, no shadow | back on the rest line, no shadow |

```text
flutter build web --release -t tool/qa/product_motion_gallery_main.dart --output build/motion-gallery
QA_WEB_ROOT=build/motion-gallery QA_BROWSER=chromium QA_REDUCED=0 node scripts/qa/product_motion_acceptance.mjs
QA_WEB_ROOT=build/motion-gallery QA_BROWSER=firefox  QA_REDUCED=1 node scripts/qa/product_motion_acceptance.mjs
```

Adding a tile layout means adding it to the gallery and to `CASES` in the
script, in the same PR. `scripts/qa/tile_hover_browser_qa.mjs` remains the
whole-page screenshot tool for real screens (set `QA_REDUCED=1` for the
owner's mode).

## Discrepancy inventory (0.8.2 motion restoration)

| Component | Approved behaviour | Rendered behaviour before | Root cause | Correction |
| --- | --- | --- | --- | --- |
| Every tile and stat card, on the owner's PC | hover answers | nothing moved; only a shadow tint | Windows "Animation effects" off, so `prefers-reduced-motion`; v5 gated lift, glyph drift and arrow travel on motion | reduced motion keeps a still lifted state and the shadow; the contract documents the owner machine |
| `KubusActionTile`, `KubusStatCard` expressive | continuous float while hovered (pre-0.8.0 look) | a one-shot 2 px lift, then still | the pre-v5 looping float (2200 ms) was removed when metrics were flattened in 56dd3e1f and never restored by the v5 hover response | float restored in `KubusHoverResponse` and `KubusGhostGlyph` |
| `KubusStatCard` standard (dense) | tiles answer the pointer | no response at all (Platform statistics, Spatial library, dense rows) | the hover path was wired only for expressive tiles | every layout floats; the dense identity device is unchanged |
| PRODUCT documents | one contract | four documents disagreeing | hover text duplicated and edited per wave | this document; the others point here |
| Tests | would catch a dead hover | asserted state and a single 2 px offset; passed while the browser looked inert | widget tests never ran in reduced mode against real pixels, nothing measured the float | widget tests extended; browser gate added |

## Evidence

`docs/evidence/product-motion/` holds the before and after frames and the
`report.json` of each browser run for the restoration pass.
