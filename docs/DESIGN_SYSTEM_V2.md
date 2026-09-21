# kubus Design System v2 — product + web family contract

Status: **current direction / implementation contract**
Last updated: 2026-09-21.

This document supersedes the visual direction implied by the older
`docs/DESIGN_UNIFICATION_NOTES.md` creator-flow pass. That pass remains useful
as an implementation history, but its glass/gradient-heavy surface treatment is
not the target for the next product-wide redesign.

## 1. Source material

The current design direction is grounded in shipped/in-progress repository work,
not a hypothetical moodboard.

### WORLD — art.kubus.site

Reference branch: `kubus-project/art.kubus.site@redesign/a1-foundation`.

Its active agent contract defines the site as:

- spatial-first;
- typographic;
- editorial;
- cartographic;
- archival;
- data-driven.

It explicitly rejects glass-first layouts, floating rounded product cards,
large decorative gradients, generic bento/SaaS composition, decorative glow,
shimmer/float effects, and generic AI-looking visual language.

The world/globe is a semantic surface carrying real records, not wallpaper.

### TIME — kubus.site

Reference branch: `kubus-project/kubus.site@redesign/k1-foundation`.

It uses the same structural vocabulary while keeping a different content model:
TIME rather than WORLD. The redesign moves structural tokens into
`src/styles/tokens.css`, removes the old duplicated Tailwind theme and replaces
the previous generic card/cube-marketing system with shell/index/colophon and
flat editorial composition.

### INFRASTRUCTURE — kubus Node

The node remains an operator surface. It can be denser and more utilitarian
than public editorial pages, but should use the same family identity,
typographic discipline, semantic colours and restrained elevation.

### PRODUCT — app.kubus.site / native art.kubus

The app is not another editorial site. It is the interactive product member of
the family. It should inherit family identity and structural grammar while
retaining platform-native navigation, touch targets, safe areas, app bars,
sheets, menus, forms and high-frequency controls.

## 2. Shared family grammar

### Typography

Target family:

- **Sofia Sans** — display, headings, body and ordinary metadata.
- **Space Mono** (or the approved technical mono fallback on surfaces that cannot
  ship it) — coordinates, identifiers, versions, exact dates/times, system
  state and machine values.

The mono face is a recorded/technical register, not cyberpunk decoration.

Flutter currently uses Inter through `lib/utils/design_tokens.dart`. Do not
blindly replace typography throughout the app in one mechanical pass. The UI/UX
audit must identify typography-sensitive controls and establish migration
coverage first; then migrate centrally rather than per screen.

### Structure

Prefer:

- semantic ground / surface / foreground / secondary / rule / active roles;
- 1px hairlines;
- open layouts;
- strong spacing hierarchy;
- asymmetric composition where appropriate;
- readable text measures;
- real media and real geographic context;
- restrained elevation only when interaction requires it.

Avoid as a default language:

- glass-on-glass nesting;
- `rounded-2xl` everywhere;
- large shadows;
- floating marketing cards;
- gradient panels;
- decorative blur;
- bento grids;
- duplicated framed containers around every content group.

Glass remains valid for genuinely overlapping transient app chrome where the
underlying map/content must remain spatially legible. It is not the base surface.

### Colour

Do not collapse semantic roles into one brand accent.

- Interaction/state needs its own role.
- Error/success/warning remain semantic.
- Marker colour remains **data meaning** and must not be recoloured to match a
  theme.
- Promotional/signal-tier state must remain distinct from subject/category.

The current Flutter token system remains the authoritative implementation until
v2 tokens are migrated. New v2 roles should be introduced centrally and tested,
not hard-coded screen by screen.

## 3. Public entity composition

Artwork/profile/institution/event/exhibition pages on `app.kubus.site` must
look like first-class product screens, not SEO documents.

A public artwork first frame should generally be:

1. product-family shell/chrome;
2. primary media;
3. title + attribution/creator + place/context;
4. compact factual metadata;
5. primary actions;
6. description/context;
7. location/map relation;
8. related entities;
9. provenance/source/verification;
10. claim/correction action when relevant.

The semantic HTML first frame and Flutter/native detail screen must use the same
information hierarchy even when implementation differs.

## 4. Map / WORLD contract

The app map should converge on the spatial model proven in
`art.kubus.site@redesign/a1-foundation`.

### Globe

- WORLD framing uses a MapLibre globe where the runtime supports it.
- Locale/default framing remains meaningful (e.g. Slovenia vs Europe) but the
  globe is the continuous spatial surface.
- Theme/time lighting and optical veil are presentation concerns and must not
  distort marker semantics or map data.
- Reduced motion, WebGL failure and low-capability devices require usable
  fallbacks.

### Marker LOD

The current web-family implementation in
`src/map/recordLayers.ts` establishes the reference progression:

- zoom < 5: data-coloured dots;
- zoom 5–10: canonical kubus marker sprites;
- zoom >= 10: close visible records may become cover-image markers;
- cover reveal completes around 10.5;
- selected record stays represented even outside the normal cover set;
- DOM-heavy cover markers are bounded (currently max 32);
- complete archive remains in GPU-native map layers;
- marker lifecycle is independent of camera animation.

These numbers are a starting cross-surface contract, not untouchable constants:
validate them on phone, tablet, desktop, Android and web before freezing them in
shared map configuration.

### Canonical marker identity

The redesign branch already consumes exported canonical Flutter marker pixels
instead of redrawing an approximate web glyph. App and web must preserve the
same marker subject + signal tier + selected/promoted state identity.

At high zoom, the artwork cover fills the marker body while retaining the
canonical outline/stem/state language so a cover image does not become a random
square thumbnail pinned to a map.

## 5. Product density

The same design language supports different density modes:

- **editorial** — kubus.site, long-form art.kubus.site content;
- **discovery** — globe, city, route and entity exploration;
- **product** — app details, community, contribution and account flows;
- **operator** — institution tools, admin, kubus Node;
- **governance** — DAO proposals/reviews/votes after the deep-polish phase.

Do not make every mode visually identical. Consistency means shared rules, not
one template.

## 6. App audit rules

Before broad app restyling, every major flow is classified:

- KEEP;
- REFINE;
- REDESIGN;
- MERGE;
- REMOVE.

Audit dimensions:

- task purpose;
- information architecture;
- navigation/back behaviour;
- primary action hierarchy;
- guest/auth boundary;
- loading/empty/error/offline state;
- mobile/desktop/native parity;
- accessibility;
- localization;
- performance;
- duplication of components or domain concepts.

A screen that should be merged or removed must not receive a cosmetic polish
first.

## 7. QA contract

Visual changes require evidence, not only tests.

For web/public-entry/map work:

- Chromium + Firefox;
- desktop + phone widths;
- EN + SL where copy affects layout;
- light + dark;
- 200% zoom;
- reduced motion;
- keyboard/focus;
- slow bootstrap/no-JS public entity;
- WebGL unavailable/degraded map fallback.

For native:

- Android phone baseline;
- safe areas and keyboard;
- deep-link cold/warm start;
- low-memory/back-stack recovery;
- permission-denied paths for location/camera.

Keep screenshots or structured visual evidence with the work when practical.
