# kubus family contract v5 — PRODUCT application

Status: authoritative design contract for the next PRODUCT work. Reviewed 2026-09-22 against `art.kubus.site@redesign/a1-foundation` (`1ca922c6`) and `kubus.site@redesign/k1-foundation` (`8174330c`). The public websites' mirrored `docs/WEB-FAMILY.md` v5 and actual implementations define the approved visual use. This document supersedes the earlier machine-only mono direction in this PR and the July glass/gradient notes in `docs/DESIGN_UNIFICATION_NOTES.md`; those notes remain history.

## Four siblings

| Surface | Role | Composition |
| --- | --- | --- |
| `kubus.site` | TIME | research, history, monograph, project lineage and scroll-linked temporal field |
| `art.kubus.site` | WORLD | cultural geography and editorial reading with an interactive MapLibre globe |
| `app.kubus.site` / native `art.kubus` | PRODUCT | canonical entities, discovery and direct actions in a platform-native application |
| `node.kubus.site` / kubus node | INFRASTRUCTURE | public runtime explanation and local operator tooling, respectively |

`node.kubus.site` is a public website; `kubus-node` is the local/distributed runtime. Their analytics and architecture are separate. The three public websites share their existing family shell. PRODUCT shares the grammar, **not** that shell: use app bars, mobile navigation, desktop rails/panels, safe areas, touch targets, sheets, forms, navigation history, keyboard handling and transient map controls.

## Typography and case

| Register | Typeface | Use |
| --- | --- | --- |
| Primary | Sofia Sans | Display, headings, ledes, body, ordinary interface language and major product text |
| Structural | Space Mono | Approved family identity and `kubus / art / node` register; compact established controls; notions; archive/register language; chapter, step and ordinal labels; selected metadata terms; technical state, coordinates, IDs, versions, hashes, ports, paths and protocol values |

Space Mono is **not machine-data-only**. It is also **not a blanket style for every button, metadata string or screen**. Preserve its approved use on the current web family; introduce it selectively through central PRODUCT primitives after audit. Case follows semantic role: brand names stay lowercase (`kubus`, `art.kubus`, `kubus node`, `kubus / art / node`); website structural notions and controls may be uppercase; machine values retain exact case; prose uses authored case. Never rename technical identifiers such as `kubus-node`, `NODE_GUI_TOKEN`, package names, environment variables or classes.

The current Flutter app still uses Inter in `lib/utils/design_tokens.dart`. That describes the present code, not the destination. No mechanical app-wide font swap belongs in this documentation pass. Wave 4 establishes central type roles and visual parity; Wave 7 inventories affected screens before broad migration.

## Visual grammar

- Semantic ground, surface, foreground, secondary, rule and active roles; 1px hairline structure; strong spacing and readable measures.
- Real records, media, geography and provenance lead. Restrained elevation supports interactions, not decoration.
- Avoid generic SaaS bento layouts, decorative AI gradients, floating rounded cards as a default, arbitrary glass nesting, glow/particles and pseudo-terminal theatre.
- Glass can serve transient PRODUCT/map chrome when the map remains legible. WORLD's optical reading veil is an editorial readability treatment, not an app shell.
- Marker category colour is **data semantics**. Keep subject/category, promotion/signal tier and selected state distinct; do not recolour categories for theme harmony.
- Theme switching on WORLD/TIME is an in-place state change, not a style reload. The public websites share an explicit `kubus_theme` choice and `kubus_cookie_consent` decision. Native PRODUCT has its own privacy and navigation surfaces; do not paste the website consent band into it.

## WORLD behaviour to port, composition to leave on the website

`art.kubus.site` uses a right-two-thirds WORLD composition beside editorial text on wide layouts. PRODUCT normally gives the map the viewport. Port continuous world-to-street geography, camera ownership/continuity, marker identity, semantic LOD and performance principles into the **existing** Flutter architecture. `src/map/recordLayers.ts` currently defines `iconStart: 5`, `iconFull: 7`, `coverStart: 10`, `coverFull: 10.5`, `maxCovers: 32`; these are reference values to retune on devices, not immutable Flutter constants.

The behaviour contract is far GPU dots → mid canonical kubus marker → close artwork cover **inside** canonical geometry; selected records remain represented and heavy covers stay bounded. Preserve clusters, same-coordinate grouping, spiderfy, promotion/signal state, subject/category meaning and complete archive in GPU-native layers. Never turn all artworks into Flutter widget markers. The renderer owns inspection camera motion; narrative scroll must not wrest it away. Respect reduced motion and usable WebGL/capability fallbacks.

## PRODUCT public entity frame

The semantic server frame and Flutter entity detail share a public presentation and hierarchy: product navigation, primary media, title, **artwork authorship**, place/context, compact facts, contextual actions, description, map relation, related entities, platform contribution and provenance/verification. Artist attribution must never be inferred from uploader ownership. Private, disputed or unverified information must respect the public disclosure policy. See `APP_NATIVE_PUBLIC_ENTRY.md`.

## Audit and evidence

Wave 7 classifies each task and major screen KEEP / REFINE / REDESIGN / MERGE / REMOVE, with P0–P3 severity, across guest, account, artist, institution and advanced users; mobile, desktop web and Android; EN/SL and light/dark; loading, empty, error, offline, permission and auth states. Do not polish REMOVE screens.

Visual changes require screenshots of the relevant before/after states. Public web work covers Chromium and Firefox, desktop/phone, EN/SL, light/dark, 200% zoom, reduced motion, keyboard, slow/no JS and failed map/bootstrap. Native work includes Android safe areas, keyboard, deep links and permission-denied paths. Tests alone do not prove visual continuity.
