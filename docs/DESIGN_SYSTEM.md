# Design system

This is the permanent design contract for art.kubus (PRODUCT). It is the single
source of truth for PRODUCT visual semantics and hover motion. Historical audits
explain earlier decisions; they do not override this contract. Technical ownership
belongs in [Architecture](ARCHITECTURE.md); product priorities belong in the
[Roadmap](ROADMAP.md).

## Identity and hierarchy

Preserve the kubus family grammar while using platform-native interaction density.
The app is an instrument for discovering art, people and places. Real artwork,
geography and authored identity carry its character. Structural surfaces, hairlines,
contextual fields and cropped glyphs support that content. Avoid generic dashboard
cards, decorative gradients and repeated nested containers.

**One semantic idea, one primary expression.** Content, identity, status,
affordance, progress and atmosphere are different roles. A role label and verified
check may coexist; a heading, icon box and large glyph all naming the same section
are redundant. Remove a container that provides no grouping, identity, status,
action or atmosphere.

## Typography

Sofia Sans carries content, headings, names and prose. Space Mono carries the
selective structural register: controls, roles, ordinals, selected metadata and
exact machine values. Case follows the meaning of the text; neither blanket
uppercase nor a machine-only mono restriction is appropriate.

Use the typography roles in `lib/utils/design_tokens.dart`. Compatibility helper
names referring to Inter do not establish a different font contract. Use metric
value and label roles for statistics, rather than tiny navigation badges. Values
lead, labels follow, secondary context comes next, and decoration comes last.
Allow labels and long names to wrap. Increased system text scale must grow the
composition instead of clipping values or reducing all text to fit.

## Color and themes

Use `Theme.of(context).colorScheme`, the selected theme accent and shared semantic
tokens. `KubusProductPalette` defines light/dark ground, surface, raised surface,
foreground, muted foreground, rules and semantic accents. Do not store UI colors
in domain models. Keep destructive, warning, success and focus meanings consistent;
purple is reserved for explicitly supported AI/system indicators.

Contextual color identifies a destination or category, not an invented status.
Light and dark themes retain the same hierarchy and readable media overlays.
Color alone must never convey state, permission or selection.

## Layout, spacing and surfaces

Use existing spacing, radius, border and sizing tokens. Breakpoints respond to
the component's available width, safe areas and text scale. Desktop and mobile
share composition and state ownership; adapt density and wrapping rather than
creating unrelated visual languages. Test 320, 360, 393, 412 and 430 logical pixels,
tablet and desktop, portrait/landscape and English/Slovenian.

Use flat structural surfaces for ordinary content and forms. Contextual glass is
appropriate for map panels and overlays where the underlying spatial context
matters. Reuse `KubusMapGlassSurface` and its platform backdrop architecture:
consistent translucency, bounded backdrop region, contrast, borders, radius and
elevation. Nearby Art and its cards belong to the same contextual family. Do not
add an independent glass style or increase full-screen blur to mask a local defect.

Keep image viewports stable while loading or failing. Preserve source aspect ratio;
do not stretch or overwrite uploaded media. A cached unchanged image must not
replay a reveal. Preserve usable content during refresh and use the shared media
resolvers and `KubusCachedImage`.

## Components and iconography

| Purpose | Reference implementation |
| --- | --- |
| Destination shortcut | `KubusActionTile` (stacked, inline or compact) |
| Dense management destination | Compact `KubusActionTile` / `KubusActionSidebarTile` |
| Metric | `KubusStatCard` |
| Grouped content | `KubusCard` |
| Analytical or long-form content | `KubusReadingSurface` |
| Empty/error state | `EmptyStateCard` |
| Page identity | `KubusDashboardHeader` / `KubusAtmosphere` |
| Profile identity | `ProfileIdentityHero` |
| Map contextual surface | `KubusMapGlassSurface` |
| Utility | Existing compact button or icon control |

Icons must add information: Back, search, expand, upload, location, warning and
verification qualify. Icon-only controls require semantic labels and meaningful
tap targets (at least 44 logical pixels). A status chip owns its state icon.
`KubusGhostGlyph` is cropped, low-opacity atmosphere behind content, bounded away
from values, wrapped in `IgnorePointer` and `ExcludeSemantics`. Never pair it with
a foreground copy of the same identity symbol.

Buttons express one clear primary action and quieter secondary utilities using
existing components. Preserve permission and interaction behavior. Avoid duplicated
CTAs, arbitrary button heights, oversized secondary controls and detached rows.
Flat form controls and entity/search/picker rows keep their appropriate shapes.

## Data presentation

Metrics are data, not destination tiles. `KubusStatCard` expressive layouts use a
value, label and one ghost glyph; dense layouts use a compact identity device.
Values remain legible and labels wrap. Analytics overview cards use measured rows
that grow with text, with explicit metric selection and chart-series color keys.
Date filters, Share and Export retain a clear hierarchy and usable narrow layouts.
Calculations, queries and permissions are technical contracts, not visual choices.

## Profile composition

Owner and visitor profiles use the shared identity composition. At ordinary mobile
widths, keep the avatar left of the display name, handle, role and verification
group. Wrap unusually long names and enlarged text before abandoning that
relationship. Actions follow the identity group; ownership changes the action set,
not the composition. Retain Edit, Share, Analytics, Follow and Message where their
real permissions allow them.

Profile covers are user-authored compositions. Preserve approved desktop framing.
Mobile identity uses the cover-led dark contextual glass panel beside the floating
avatar, overlapping the cover edge. Use dark semantic surface/foreground tokens
even in light theme; name, full handle, role and verification stay readable within
that identity composition. Keep content in normal flow as names and text scale grow.
On mobile the avatar's lower-right badge uses the role's contextual color and
corresponding artist, institution or account icon. Verification qualifies its
accessible label only when verified; a role icon never grants verification.
Artist/institution role labels remain integrated into the identity panel.
Preserve the canonical rounded-square avatar and the separate upper-right active
presence indicator. Presence appears only for fresh, visible provider data; do not
invent an online status or cover it with the identity badge.
Desktop retains the existing name-adjacent verification composition.
Mobile uses a stable viewport with source aspect ratio preserved and excess width
cropped at the sides, centered by default; honor saved focal metadata when the
media contract supports it. `BoxFit.cover` must have appropriate parent constraints.
Keep avatar overlap and viewport geometry stable through asynchronous load and
failure. Missing-cover fallback and failed authored-cover framing are distinct.

Single-video Community stages on mobile reserve the usable content viewport before
scrolling, excluding safe areas and persistent navigation/composer chrome. Posters,
loading and playback share that stable height; metadata must not move the scroll
anchor. Fit every video aspect whole without distortion or blanket cover cropping.
Desktop retains its viewport cap; quoted previews and mixed carousels retain their
compact and shared stage geometry.

## PRODUCT hover motion

Machine-checked constants must equal `KubusHoverResponse`:

```text
liftDistance: 3
floatAmplitude: 1.5
floatPeriodMs: 2200
entryMs: 180
```

Pointer hover rises over 180 ms ease-out cubic, then floats around the lifted
position by ±1.5 logical pixels over a 2200 ms cycle. The surface remains 1.5–4.5
pixels above rest. Contextual accent shadow, field and edge answer the pointer;
expressive glyphs drift inward, scale and counter-float. Inline arrows may travel
2 pixels. Exit settles over the entry duration and stops at rest.

Motion is paint-only. The `MouseRegion` sits outside the transform so layout and
hit regions stay stable. Reuse `KubusHoverResponse` and `KubusGhostGlyph`; never
hand-roll competing tile hover behavior. Every action-tile layout and both dense
and expressive stat-card layouts answer the pointer. Informational stat cards keep
the default cursor and no button semantics. Disabled or loading tiles do not lift,
float or acquire the hover shadow. Touch-only interfaces never receive continuous
hover motion.

### Reduced motion

Honor `MediaQuery.disableAnimations` and operating-system `prefers-reduced-motion`.
Reduced motion gives the lifted position, shadow, field, edge and indicator
immediately, then remains stationary: no float, glyph drift/scale or arrow travel.
Exit is immediate. Never override the user's preference or gate visible feedback
on animation. Verify reduced motion first in a real browser.

### Exclusions and navigation

`KubusActionSidebarTile` stays a flat tinting row. `KubusEntityCard` uses its own
one-shot lift/media response and no motion under reduced motion. `DesktopActionButton`
keeps its button response. `DesktopCard`, rails, forms and list rows stay flat;
`KubusAtmosphere` and heroes are identity fields. Do not extend continuous floating
to these surfaces without a deliberate design decision.

Screen transitions use current routing ownership and platform-appropriate behavior.
Preserve map camera, selected marker and appropriate scroll/panel state on return.
Avoid empty intermediate frames, repeated entrances on equivalent data, competing
scale/fade/slide effects and continuous animation on hidden screens. Canonical
markers remain visible while artwork loads; cover replacement preserves geometry.

## Accessibility and acceptance

Preserve keyboard focus, meaningful semantics, contrast, text scaling and touch
targets. Decorative glyphs are excluded from semantics. Loading/error states retain
stable dimensions; map information is an icon control with explanation in a
separate accessible tooltip/dialog/sheet.

Visual changes need inspected screenshots or frame sequences from real screens,
with environment, source revision, viewport, theme, locale and motion preference.
Widget tests and compilation do not establish visual or device acceptance.

`test/design/product_v5_motion_contract_doc_test.dart` pins the constants and
canonical authority. Existing action-tile/stat-card widget tests pin entry, full
float period, counter-float, rest return, disposal and reduced motion. The tile
system and semantic guards remain active despite their historical filenames.

`scripts/qa/product_motion_acceptance.mjs` measures painted pixels at DPR 2 in
Chromium and Firefox. Preserve 14 settled samples over at least one full 2200 ms
cycle, rise ≥1.5 px, normal peak-to-peak ≥1 px, reduced peak-to-peak ≤0.6 px, accent
shadow, disabled stillness and return to rest. Adaptive capture deadlines account
for slow screenshots; insufficient samples remain inconclusive failures. A hover
change updates code, this contract, widget tests and browser acceptance together.
