# Art Platform Visual Refresh — Design Specification

Date: 2026-07-16
Status: In progress (implementation branch `ux/art-platform-visual-refresh`)

## 1. Product problem

art.kubus reads as management software instead of cultural infrastructure. The
audit found a consistent root pattern across surfaces: every module — whether
it is an artwork, a wallet balance, a nav shortcut, or a metric — is rendered
with the same visual weight (a glass card of the same size, border, and
padding). The platform's actual content (art, exhibitions, events, artists) is
either buried behind utility modules (Home), rendered without imagery
(desktop "Trending Art" uses gradient icon boxes), or compressed into uniform
tile grids (analytics overview, profile stat rows).

Systemic causes identified:

1. **Incomplete ColorScheme.** `themeprovider.dart` builds
   `ColorScheme.dark(...)`/`.light(...)` setting `primaryContainer`,
   `secondaryContainer` (and leaving `tertiary*` implicit) **without their
   `on*` pairs**. In dark mode Flutter defaults `onPrimary`,
   `onSecondaryContainer`, `onPrimaryContainer`, `onTertiaryContainer` to
   black — so the mobile Navigate button
   (`secondaryContainer@0.6` + `onSecondaryContainer`) renders black-on-dark,
   and every `primary`/`onPrimary` CTA renders black on the user-selected
   accent. This is the Navigate bug and its whole class. Additionally,
   `ThemeProvider.availableAccentColors` includes dark accents (deep blue,
   oxblood, slate) whose fills need brightness-aware foregrounds — never
   hardcoded white/black.
2. **Equal-weight modularity.** Home, analytics, and profiles compose lists of
   identically sized cards; nothing tells the eye what matters.
3. **Content is not image-led.** The only image-led module (promotion rails)
   is last on Home; artwork imagery is small inside card chrome.
4. **Semantic color collisions.** `statCoral == negativeAction` and
   `statGreen == positiveAction`, so metric category colors are
   indistinguishable from judgment colors in analytics.
5. **Glass everywhere.** Long-form/reading surfaces and static content share
   the same translucent panels as floating chrome, weakening both.

## 2. Visual principles

- **Editorial, image-led, calm.** Media first; typography establishes
  hierarchy; containers only where elevation is real.
- **Evolve, don't replace.** All work flows through the existing kit
  (`kubus_kit.dart`), tokens (`design_tokens.dart`), roles
  (`kubus_color_roles.dart`), and the canonical `GlassSurface` stack.
- **Hierarchy over uniformity.** Every screen names one primary subject and
  one primary action; everything else steps down.
- **Glass = elevation.** Liquid glass is reserved for floating/transient/
  navigational chrome. Reading surfaces are quiet tonal fills.
- **Theme-safe by construction.** New roles resolve accessible pairs
  centrally so no call site can produce dark-on-dark again.

## 3. Semantic action hierarchy (new, central)

New central helper `KubusActionEmphasis` + accent-contrast resolution in
`kubus_color_roles.dart` / `design_tokens.dart`:

- `accentFill(context)` — returns a `(background, foreground)` pair for
  accent-filled primary actions. Guarantees ≥ WCAG AA contrast of foreground
  on background AND ≥ 1.6:1 of the fill against the scaffold background by
  lightening/darkening the accent per brightness (central, tested).
- `KubusButton` gains `variant: KubusButtonVariant.accent` and
  `KubusButtonVariant.destructive` that consume this pair; `primary`
  (monochrome) and `secondary` stay as-is.
- Detail-screen action rows use: 1 accent-filled primary action, monochrome
  `primary`/`secondary` for the rest, `KubusOutlineButton` for tertiary.

Navigate/Show on map: both become kit buttons with the shared emphasis roles;
Navigate (primary when location exists) uses `accent` variant; Show on map is
`secondary`. No local colors.

## 4. Glass usage hierarchy

Allowed glass: floating map controls, sticky action bars, bottom sheets,
modals, nav chrome, compact contextual controls, media overlays.
Quiet surfaces (new `KubusReadingSurface` tonal container, no blur): long
descriptions, curatorial text, biographies, analytics interpretation, lists.
Rule: no glass-on-glass without a real depth relationship; no blur behind
long-form text.

## 5. Screen hierarchies

### 5.1 Artwork detail (mobile)
1. Media (edge-to-edge, aspect-aware, gallery-capable) with floating back/share
   over the image; 2. Title + artist byline (typographic block, no card);
3. Essential context chips (year, medium, category) — quiet, not glass pills;
4. Primary actions (Navigate/Show on map/AR) — one accent primary;
5. Description (reading surface, expandable); 6. Metadata (quiet key/value);
7. Related content; 8. Comments/community.
Owner utilities move to an overflow/manage cluster, not the main action row.

### 5.2 Artwork detail (desktop)
Two-column editorial: dominant media column (~62%) + sticky context column
(title, byline, context, actions, metadata). Comments full-width below.
Readable max width for text.

### 5.3 Event / exhibition detail
Poster/hero → what/when/where/who block (typographic) → status (badge, not
dominant) → attend/save/share actions → description on reading surface →
related entities. Exhibition adds curatorial text priority + venue/visit info.

### 5.4 Home (discovery)
Mobile order: greeting header (slimmer) → discovery hero (first promotion-rail
item or nearby art, image-led) → content rails (artworks, exhibitions, events,
artists — image-first cards, larger media) → compact "your activity" strip →
web3/quick-action utilities (collapsed, deprioritized) → support.
Desktop: editorial two-column with rails leading, utilities in sidebar.
Stats-cards module demoted/merged into a single compact strip.

### 5.5 Analytics (cultural report)
Order: context line (entity, period, freshness) → key summary (1 lead metric
+ supporting metrics, hierarchy by registry `relevance`) → trend (full-width,
no horizontal scroll on mobile — decimated labels) → insights (quiet reading
surface, meaningful icons, no index-colored decoration) → breakdown/compare →
export. Filters: compact single row on mobile (current metric+period visible,
advanced in canonical `BackdropGlassSheet`); desktop toolbar grouped, no
stretched controls. Metric category colors decoupled from judgment colors
(new `statRose`/`statSage` roles replacing collisions where category color is
meant).

### 5.6 Profiles (cultural identity)
1. Identity header (avatar, name, handle, type, concise bio, links) —
typographic, compact; 2. Primary relationship action (follow/message or edit);
3. Cultural content (artworks/exhibitions/events/collections per role);
4. Biography (reading surface, progressive disclosure); 5. Community activity;
6. Achievements/stats (compact strip, not tile walls); 7. Owner utilities
(security, wallet) behind a manage cluster with progressive disclosure —
critical security warnings stay visible but compact.
Wallet addresses never above the fold; identity resolution untouched.

## 6. Theme-safe state requirements

Every new/changed component verified in light/dark × default/hover/focus/
pressed/selected/disabled/loading/destructive × blur-on/blur-off. Tests cover
accent-contrast resolution for all `availableAccentColors` in both themes.

## 7. Accessibility

WCAG AA for essential text/controls; ≥44×44 targets; visible focus; semantic
labels on new interactive elements; no color-only meaning (icons/arrows keep
accompanying deltas); reduced motion respected via `context.animationTheme`
and `MediaQuery.disableAnimations`; text-scale and long Slovenian labels
handled with flexible layouts.

## 8. Motion

Existing `AppAnimationTheme` tokens only. Entry: subtle fade/slide of the
content column, never the whole page as a block. No new persistent motion.

## 9. Protected behavior (unchanged)

Public entity entry + contextual auth (PR #22), marker preview + Navigate
(PR #26), canonical takeover/history/exact map targeting (PR #27), marker
fallback + navigation choices (PR #28), walking navigation (PRs #29–#31):
`artwork_location_actions.dart` and `map_navigation.dart` keep their APIs and
routing logic — only presentation layers change. Feature flags, capability
resolution, analytics calculations, filter persistence, quick-action
registry/executor contracts, identity resolution all preserved.

## 10. Scope boundaries

No backend changes. No map-engine or walking-navigation rewrites. No new
design system — extensions of the existing one only. Lint ratchet stays
0/0/0/0/0. No l10n regeneration (hand-add keys to arb + 3 generated files per
repo convention).

## 11. Acceptance criteria

See task acceptance list; key measurable ones:
- No dark-on-dark action in any tested accent × theme combination (unit-tested).
- Home first viewport contains real artwork imagery.
- Analytics overview is no longer a uniform equal-tile grid.
- Profile first viewport is identity + work, not counters/banners.
- All existing tests pass (minus documented pre-existing failures);
  `flutter analyze --fatal-infos --fatal-warnings` and `dart run custom_lint`
  green; release web build green.

## 12. Screenshot matrix

Captured under `output/visual-qa/art-platform-visual-refresh/` (ignored):
{artwork, event, exhibition, home, profile-own, profile-public, analytics}
× {mobile 390×844, desktop 1440×1000} × {light, dark} before/after.
