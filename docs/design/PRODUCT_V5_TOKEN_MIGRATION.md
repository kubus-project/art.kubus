# PRODUCT Family v5 token foundation

This document records the app-only token and shared-primitive foundation
stacked on the Wave 2 public-entry branch. It prepares the later Wave 2B
artwork detail pass; it does not recompose entity screens or claim that the
whole application has been migrated.

## Source and repeatable inventory

The implementation preserves the existing central token file, `ThemeProvider`,
Material `ThemeData`, spacing and responsive typography helpers, border and
focus utilities, and the shared component APIs. The current Wave 2 app base was
`251130ec6296c24ad317c5231d8dd365ed513874`.

Run the inventory from the repository root:

```powershell
py -3 scripts/audit_product_v5_tokens.py `
  --baseline 251130ec6296c24ad317c5231d8dd365ed513874 `
  --output docs/design/product_v5_token_inventory.json
```

The JSON contains baseline and working-tree occurrence counts and file paths
for Inter and Outfit helpers, direct Google Fonts APIs, Space Mono, Kubus colors
and typography, gradients, glass effects and profiles, glass panels/cards,
Material primary usage, raw color constructors, buttons, chips, borders,
radii, and explicit accent references. Counts are textual Dart source matches,
not runtime widget counts. They include test and lint-fixture source where
indicated by the paths. The script reads the baseline from Git and never reads
production data.

## Semantic colour roles

`KubusProductPalette` defines the family neutral palette. `KubusColorRoles` is
the app's context-aware `ThemeExtension` for both PRODUCT and existing semantic
data roles. New UI should use `KubusColorRoles.of(context)` for page ground,
surfaces, text hierarchy, rules, active/focus and semantic states. `ColorScheme`
continues to provide Material integration, with `primary` mapped to the stable
family active role.

| Role | Light | Dark |
| --- | --- | --- |
| ground | `#EAECE7` | `#090C0E` |
| surface | `#F4F5F2` | `#11181B` |
| surfaceRaised | `#FFFFFF` | `#1A2327` |
| surfaceOverlay | `#E6F4F5F2` | `#E611181B` |
| foreground | `#11181B` | `#EAECE7` |
| foregroundMuted | `#465357` | `#A3AFB3` |
| foregroundSubtle | `#667276` | `#849196` |
| rule | `#B9C2C1` | `#344147` |
| ruleStrong | `#899597` | `#536168` |
| active / focus | `#1F5FD0` | `#3F83FF` |
| onActive | `#FFFFFF` | `#11181B` |
| destructive / error | `#B3261E` | `#FF6B6B` |
| success | `#267344` | `#70C58B` |
| warning | `#805700` | `#FFC45B` |

`onDestructive` and `onError` are white in light mode and `#26090B` in dark
mode. Raised surfaces represent dialogs and sheets. Overlay surfaces are for
temporary controls over map, artwork media, and spatial views. Ordinary content
uses the flat surface role. Rules and typography carry hierarchy before
shadows or tinted panels.

The theme now maps `Scaffold`, `ColorScheme`, app bars, cards, dialogs, sheets,
Material buttons, inputs and bottom navigation through the same neutral and
active roles. Card elevation is zero in both themes. Existing spacing and
responsive type metrics remain unchanged. New radii are `control` (4),
`surface` (8), `sheet` (12), and `pill` (999); the legacy `xs` through `xl`
radius values remain for compatibility and have not been mass-migrated.

`KubusColors.primary` is a deprecated compatibility alias for the family active
blue. The old `primaryVariantLight` and `primaryVariantDark` cyan values remain
deprecated data-color aliases because the current map renderer still references
one of them. Moving those data consumers into dedicated map/category roles is
deferred to a map-scoped pass; this PR does not change marker/category colours.

### User accent

Previously, `ThemeProvider.accentColor` populated `ColorScheme.primary`,
`secondary`, and `tertiary`, Material button fills, focused input borders and
bottom navigation selection. An arbitrary saved accent could therefore change
structural UI throughout the app.

Now `ColorScheme` and global Material components use the family active role.
The persisted user colour and `ThemeProvider.setAccentColor` setting remain
available as `KubusColorRoles.userAccent` / `onUserAccent`, with contrast
computed from the actual chosen colour. The old `KubusButtonVariant.accent`
remains as a deprecated compatibility option and uses that explicit personal
role. Existing call sites that request `accentColor` directly remain in the
inventory; they are not evidence that `ColorScheme` is still personalized.
Map/data colors and semantic success, warning and error colors are kept
independent.

## Typography and delivery

| Register | Family | Intended roles |
| --- | --- | --- |
| content | Sofia Sans | display, titles, entity identity, body, lede, actions and ordinary labels |
| structural | Space Mono | deliberate system/family register, structural labels, ordinals and selected metadata |
| machine | Space Mono | coordinates, identifiers, versions, hashes and protocol values |
| map identity compatibility | Outfit | existing map attribution use only; do not extend into general PRODUCT UI |

`KubusTypography.textTheme` and `KubusTextStyles` now use local Sofia Sans for
PRODUCT content. Named helpers include display, entity title, lede, body,
caption, action label, structural label, metadata register, ordinal, machine
value, coordinate, and version. Responsive-width helpers and text scaling are
preserved. `KubusTypography.structural()` and `machine()` use Space Mono.

There were 726 `KubusTypography.inter()` matches in 54 Dart files on the base
branch. The call sites were intentionally not edited one by one. The helper is
deprecated and now resolves to the local Sofia Sans content family, so these
existing screens receive the new family without a screen rewrite. Direct
`GoogleFonts.inter` calls were removed from app typography; remaining direct
text matches are in the lint package's example fixture and its rule comment,
not production app code. `KubusTypography.mono()` is deprecated and now maps
legacy machine values to Space Mono.

Outfit has one app consumer, `marker_attribution_section.dart`, and remains
scoped to the existing map attribution treatment. Its helper still delegates
to the existing `google_fonts` package. WORLD/map work should review whether to
bundle it locally or move that one role to a dedicated map typeface. This pass
does not spread Outfit into app screens.

The app previously had no Space Mono calls. The new structural/machine API and
the compatibility `mono()` helper provide that register centrally.

Sofia Sans is bundled as a variable TrueType font (weight axis 100–900 declared
to Flutter; source axis range 1–1000). Space Mono Regular and Bold are bundled
as static TrueType faces. Flutter web, Android and iOS all use the same
`pubspec.yaml` font assets; normal PRODUCT text no longer needs a runtime
Google Fonts fetch. The font files include their SIL Open Font Licenses:

- Sofia Sans upstream metadata and license: [Google Fonts Sofia Sans](https://github.com/google/fonts/tree/main/ofl/sofiasans)
- Space Mono upstream metadata and license: [Google Fonts Space Mono](https://github.com/google/fonts/tree/main/ofl/spacemono)

Asset SHA-256 values:

| Asset | SHA-256 |
| --- | --- |
| `SofiaSans-Variable.ttf` | `A3E1019B8867E21B75D26A7B59D4EB2C81D1ACF6B69B9AE6CEDCA269FB68E291` |
| `SpaceMono-Regular.ttf` | `95837E182BAEEADA83368F7748DB28357F0A1B75C6B84FF7065B5EDF933C8E18` |
| `SpaceMono-Bold.ttf` | `405E73D41AFB7E5906EFCE206A326AF5C956F38E255F35421C260E861E599C59` |

## Shared component semantics

| Component | Previous default | Current default |
| --- | --- | --- |
| `KubusButton.primary` | user-accent fill, glass whenever blur was allowed, hover glow | flat family-active fill; no glass or glow |
| `KubusButton.secondary` | translucent surface/glass | raised neutral surface and hairline |
| `KubusButton.quiet` | no dedicated role | low-chrome support action |
| `KubusButton.contextual` | no dedicated role | neutral unless a semantic fill is explicitly passed |
| `KubusButton.destructive` | error fill | semantic error fill with paired foreground |
| legacy `KubusButton.accent` | user-selected accent | deprecated, explicitly uses bounded user accent |
| `KubusOutlineButton` | glass surface | flat surface and hairline |
| `KubusCard()` | `isGlass: true` | flat theme surface, hairline, zero elevation |
| `KubusCard(isGlass: true)` | implicit default | explicit glass option for a justified overlay |
| `KubusChip()` | primary background and on-primary text | neutral surface, rule, foreground |
| `KubusChip(backgroundColor: …)` | caller tint | explicit contextual fill with contrast-resolved text |

Loading, success, disabled, full-width and tap behavior remain in place.
Reduced-motion still collapses the press scale to zero duration. Keyboard
focus gets a stronger state overlay than hover; hover no longer adds a blurred
shadow. Generic glass remains an opt-in button choice through
`useGlassOverlay: true` and the existing device glass capability gate.

`KubusProductBackground` is now the default flat app-shell ground. The mobile
and desktop shells no longer paint their base pages with route-tinted animated
gradients. `AnimatedGradientBackground` remains available and is deprecated
for ordinary PRODUCT pages, so current explicit spatial/media, auth and
transitional consumers can migrate in their own scoped work.

## Gradient and glass inventory

The generated inventory records every source file and member count. The table
below compares the Wave 2 base to this working tree. The current side includes
the test-only token preview and widget tests; file paths in the JSON show those
additions separately.

| Inventory item | Wave 2 base | Current tree |
| --- | ---: | ---: |
| `KubusTypography.inter()` references | 726 / 54 files | 726 / 54 files |
| direct `GoogleFonts.inter` text matches | 19 / 4 files | 2 / 2 files (lint example and rule comment only) |
| Outfit helper callers | 1 / 1 file | 1 / 1 file |
| `Space Mono` family text | 0 | 8 / 3 files (token/demo/test) |
| `KubusGradients` references | 14 / 7 files | 12 / 6 files |
| `AnimatedGradientBackground` constructions | 30 / 27 files | 26 / 24 files |
| direct `KubusGlassEffects` references | 87 / 31 files | 87 / 31 files |
| `KubusGlassSurfaceTokens` references | 7 / 3 files | 7 / 3 files |
| `LiquidGlassPanel` constructors | 92 / 60 files | 91 / 60 files |
| `KubusCard` constructions | 17 / 14 files | 22 / 16 files (includes preview/tests) |
| explicit `KubusCard(isGlass: true)` | 0 | 1 (test-only preview) |
| `KubusButton` constructions | 75 / 30 files | 87 / 32 files (includes preview/tests) |
| raw `Color(...)` constructors | 132 / 16 files | 140 / 17 files |
| hex `Color(0x...)` literals | 129 / 14 files | 137 / 15 files |
| direct `scheme.primary` references | 221 / 100 files | 221 / 98 files |
| explicit `.accentColor` references | 266 / 41 files | 266 / 41 files |

Only the shared default paths and application-shell background were changed
here. Remaining glass call sites are classified by the path lists in the JSON:
map panels and AR/media controls are retained as valid spatial overlays;
ordinary community/profile/settings/content panels remain migration debt;
auth/wallet/tutorial/snackbar and similar flow components are deferred to their
own pass; `GlassSurface`, `glass_components.dart`, and `design_tokens.dart` are
shared implementation infrastructure. `KubusButton` and `KubusCard` retain
glass only as explicit options.

| Use | Classification |
| --- | --- |
| Map controls, map panels, AR scanner and spatial/media controls | VALID SPATIAL OVERLAY; retain explicit glass where visibility through to the scene matters |
| Ordinary profile/community/settings/event/content panels | ORDINARY PRODUCT SURFACE TO MIGRATE; use surface, rule and composition in their scoped UI pass |
| Auth, wallet, tutorial, snackbar and generic transient controls | OUT OF SCOPE / REVIEW IN THEIR FLOW PASS; no whole-flow redesign here |
| `GlassSurface`, `LiquidGlassPanel`, profile/effect token definitions | SHARED OVERLAY INFRASTRUCTURE; retained for the explicit cases above |
| `KubusButton`, `KubusOutlineButton`, `KubusCard` defaults | FIXED IN THIS PASS; opt-in glass remains available |
| map color indexed from an animated palette | KEEP SEMANTICALLY for now; it is a map/data color consumer |
| support section hero/from-colors gradients and desktop auth gradient | LEGACY DECORATIVE GRADIENT debt; later local surface migration |
| `glassShimmer` | RETAIN for explicit glass overlays; not a normal content surface |

Classification is path- and caller-based, not a claim that every occurrence in
a file has the same runtime purpose. The JSON retains the complete file/member
lists for review; no broad screen migration was performed.

## Visual QA and regression sample

The test-only token fixture has Chromium and Firefox captures at 390 × 844 and
1440 × 900 in light and dark themes. The evidence folder also contains 200%
zoom and keyboard-focus captures. The Chromium reduced-motion capture uses the
browser's `prefers-reduced-motion: reduce` setting; the browser reported that
preference as active and `documentElement.scrollWidth` equaled the 1440 px
viewport. The preview demonstrates the semantic roles and shared card, chip,
button and type registers, not a production screen.

The repository browser smoke captured the changed app's desktop home and
compact home/map surface in Chromium with zero console, HTTP, page or request
failures. Those images are included in the evidence folder. The desktop home
still has a legacy blue hero and colored status blocks; these are visible
migration debt. Marker/category colors on the compact map remain contextual.
Artwork, artist, institution and event captures already on the Wave 2B branch
were reviewed as prior-state references, not relabeled as screenshots of this
token branch. The Wave 2B branch should recapture those after stacking here.

Shared button/card/chip behavior and existing wallet transaction rendering
are covered by widget tests. This foundation did not separately recapture the
auth flow, settings, community, institution workspace, artist studio, wallet,
dialog or bottom-sheet screens. Their screen-specific visual migration stays
deferred; no broad polish is claimed.

## Remaining migration debt

The inventory includes current exact counts. Key interpretation:

- The 726 deprecated Inter helper call sites remain source-level migration
  debt, but render through Sofia Sans after this change.
- Outfit remains in one map attribution caller.
- Raw `Color(...)` constructors remain across app code. The new central palette
  adds a small number of intentional definitions; screen literal cleanup is
  not part of this pass.
- Existing `ColorScheme.primary` and `scheme.primary` consumers now resolve to
  the family active color. Their uses still need semantic review when screens
  are migrated, especially where a category/data color was intended.
- Glass consumers and legacy gradient call sites remain listed by path in the
  inventory and have not been treated as ordinary surfaces automatically.
- `KubusColors.primaryVariant*` stay in map/stat compatibility use until those
  roles are separated in a future map-specific pass.

The artist/artwork detail layouts, map architecture, auth flow, community,
institution workspace, DAO and wallet architecture, SEO/indexing/canonical
behavior, database content, Android App Links and production delivery were not
changed. Wave 2B should use the semantic roles and typography helpers from this
foundation when it starts the SSR-to-Flutter detail composition work.
