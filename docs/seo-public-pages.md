# Public entity pages and technical SEO

## Architecture

`app.kubus.site` has two coordinated web layers:

- The Flutter application owns `/`, `/app/*`, and progressively enhances
  eligible canonical entity responses in place.
- The existing Express service renders localized public HTML for `/en/*`,
  `/sl/*`, compact share aliases, robots, and sitemaps. The static host routes
  only that finite surface through `web/seo-proxy.php` to `api.kubus.site`.

The renderer reads the existing PostgreSQL public models. It does not call an
authenticated API or branch on user agent. The semantic response is complete
before any optional Flutter, MapLibre, wallet, or application JavaScript runs.
With takeover disabled or unavailable, the existing “Open in art.kubus” bridge
continues to target `/app/<compact-entity-path>`.

The Flutter handoff and authenticated-action boundary are defined in
[`public-entry-access-policy.md`](public-entry-access-policy.md). In particular,
ordinary eligible entity handoffs are public reads even when local account
metadata is stale; authentication begins at an identity-required action.

## Progressive takeover runtime contract

The browser URL is the routing source of truth. A canonical entry such as
`/en/artworks/:id` is parsed directly by Flutter and is not rewritten to a
compact or `/app/*` path during initial takeover. Compact paths remain an
internal routing abstraction and a compatibility entry surface.

With the takeover flag enabled, an eligible `200` entity response contains its
complete semantic document, an inert full-viewport Flutter host, and
non-blocking root-relative bootstrap resources. Flutter 3.44.2 uses the
single-view `hostElement` engine option; multi-view mode is not needed. The
application dispatches `kubus:public-entity-ready` only after the requested
entity screen has produced a meaningful frame. The controller validates entity
type, stable ID, and current pathname before atomically switching accessibility
state and crossfading for 200 ms. Reduced-motion clients switch without the
crossfade. A generic engine frame, loader completion, or fixed delay is never a
readiness signal.

The inactive surface is inert and `aria-hidden` according to its actual visual
state, so only one interface is keyboard- and screen-reader-active. The SSR DOM
is retained as the no-JavaScript, slow-network, unsupported-browser, and
bootstrap-failure fallback. Private, missing, hub, XML, and error responses do
not contain takeover resources.

The generated service worker remains an unregister-only tombstone. It has no
fetch listener, navigation fallback, precache manifest, or cached `index.html`;
canonical navigations therefore continue to reach the renderer and preserve
real `404`/`503` status codes. Root-relative entrypoint, asset, CanvasKit,
MapLibre, font, and worker paths prevent nested canonical routes from resolving
assets below the entity URL. MapLibre is not downloaded with an entity detail;
the shared map widget loads and awaits its runtime only when the visitor enters
the map.

## Browser history policy

- Initial canonical entry retains the exact localized pathname, query, and
  fragment; startup replacement uses that same route name and creates no
  canonical-to-compact hop.
- Mobile detail, map, artist, and authentication screens use the existing
  Navigator stack. Back returns to the prior interactive entity frame rather
  than revealing the inactive SSR surface.
- Desktop shell sub-screens retain their in-shell stack. Browser Back consumes
  that stack before it may leave the canonical entry route, matching the visible
  back control.
- Contextual sign-in receives the exact canonical return route. Cancellation
  returns to the entity without a second canonical/compact history entry.
- Subsequent explicit app navigation may use the established compact internal
  route model; it must not redirect the initial entry between compact and
  localized forms.

This design is deployable through the current atomic static release and Node
deployment on the existing LiteSpeed/cPanel host. The local PHP gateway removes
the need for server-level `mod_proxy` or a LiteSpeed External App. It has a
compile-time fixed HTTPS upstream, accepts only the public route allowlist,
forwards no cookie or authorization header, rejects non-GET/HEAD methods, and
preserves only an explicit response-header allowlist.

## Route ownership and canonicals

Canonical public routes use stable IDs, not mutable or synthetic slugs.

| Entity | English | Slovenian | Compact alias |
| --- | --- | --- | --- |
| Artwork | `/en/artworks/:id` | `/sl/umetnine/:id` | `/a/:id` |
| Profile | `/en/profiles/:id` | `/sl/profili/:id` | `/u/:id` |
| Event | `/en/events/:id` | `/sl/dogodki/:id` | `/e/:id` |
| Exhibition | `/en/exhibitions/:id` | `/sl/razstave/:id` | `/x/:id` |
| Public post | `/en/posts/:id` | `/sl/objave/:id` | `/p/:id` |
| Collection | `/en/collections/:id` | `/sl/zbirke/:id` | `/c/:id` |
| Collectible | `/en/collectibles/:id` | `/sl/zbirateljski-predmeti/:id` | `/n/:id` |
| Map marker | `/en/map/:id` | `/sl/zemljevid/:id` | `/m/:id` |

Compact and known long-form aliases redirect directly to the English canonical
with HTTP 308. `?lang=sl` redirects directly to Slovenian. Canonical documents
never redirect. Arbitrary static-host paths return `web/404.html` with HTTP 404;
unknown localized routes return the renderer's equivalent accessible HTML 404.
Private, draft, moderated, deleted, placeholder, duplicate, or missing entity
identifiers all return the same safe 404 and disclose no existence information.

## Localization and discovery

Each localized document sets `html[lang]`, a same-language canonical, reciprocal
English/Slovenian alternates, and English `x-default`. Stored localized fields
are used when present. Missing translations fall back to the existing public
source text without claiming machine translation.

Public collection hubs use real links, paginated canonical URLs, and become
`noindex, follow` when empty. Supported artist, institution, artwork, event,
exhibition, collection, collectible, profile, post, map, Ljubljana, and Maribor
routes are derived from real eligible rows. Unsupported filters and pages return
404 rather than creating indexable combinations.

## Indexing and structured data

`seoIndexingPolicy.js` is the single eligibility policy. It requires public,
published, non-deleted, non-moderated, non-placeholder, substantive content and
applies entity-specific checks. The same policy gates documents, hubs, and
sitemaps.

Visible content and JSON-LD share the same normalized presentation:

- artwork: `VisualArtwork`
- artist profile: `ProfilePage` plus `Person`
- institution profile: `ProfilePage` plus the closest stored organization type
- event: `Event`
- exhibition: `ExhibitionEvent`
- post: `SocialMediaPosting`
- collection: `CollectionPage` plus `ItemList`
- collectible: `VisualArtwork`
- map marker: `Place`
- every entity: `BreadcrumbList`
- localized homepage: `WebSite`, `Organization`, and `WebApplication`

All text is stripped, normalized, escaped, and truncated at a word boundary.
JSON-LD is serialized with `<`, `>`, `&`, and Unicode line separators escaped.
Only HTTP(S) media URLs or known relative storage paths are emitted. Entity
images are preferred; `web/images/social-preview-default.webp` is the 1200×630
branded fallback.

## Sitemaps, robots, caching, and failures

`/sitemap.xml` indexes paginated entity sitemaps below configured limits.
`/sitemaps/<type>-<page>.xml` contains only eligible canonicals, valid `lastmod`,
reciprocal locale alternates, and useful image metadata. `/robots.txt` references
the sitemap and discourages private/infinite surfaces without using robots rules
as an indexing policy.

Public HTML is cacheable for 60 seconds in a browser and 300 seconds at a shared
cache with stale controls; XML has a longer shared TTL. Redirects are immutable.
404 and 503 responses are not stored. Renderer/database failures return a
controlled HTML 503 and never a fake 404 or empty 200. Responses set a restrictive
CSP and do not vary on cookies or authentication state.

## Deployment and rollback

1. Deploy the root-hosted Flutter web artifact while
   `FEATURE_ENABLE_PUBLIC_FLUTTER_TAKEOVER=false`.
2. Verify bootstrap, CanvasKit, MapLibre, fonts, and the unregister-only service
   worker from their root URLs.
3. Deploy the renderer with `FEATURE_ENABLE_SEO_PUBLIC_PAGES=true` and takeover
   support still disabled, then verify raw canonical HTML and error semantics.
4. Enable `FEATURE_ENABLE_PUBLIC_FLUTTER_TAKEOVER`, purge cached canonical HTML,
   and smoke-test EN/SL, slow load, failed bundle, browser Back, and no-JS.

Immediate takeover rollback is feature-flagged: disable
`FEATURE_ENABLE_PUBLIC_FLUTTER_TAKEOVER` and purge canonical HTML. This restores
the known-good SSR document and explicit `/app/*` bridge without a database
migration or app rollback. If the web artifact itself must be rolled back,
restore the prior atomic release after disabling takeover, retain the service
worker tombstone, and repeat raw HTML, real 404, bridge, and `/app/*` smoke tests.
Disabling `FEATURE_ENABLE_SEO_PUBLIC_PAGES` is reserved for renderer rollback.

## Local development and validation

From the backend worktree, after building Flutter web in the adjacent app
worktree:

```text
npm ci
npm test
npm run seo:preview
```

The QA server listens on `http://127.0.0.1:4175`, serves deterministic public
records, and mounts the Flutter build at `/app`. Validate raw responses with
`curl`, parse sitemap XML and JSON-LD in tests, then run the browser suite at
desktop and mobile sizes in Chromium and Firefox. The preview fixture exists
only under `scripts/qa`; production always uses PostgreSQL.

### Deployed canonical takeover smoke check

After a production rollout, run the versioned smoke contract against a real
eligible canonical entity and a real missing entity. It is deliberately opt-in:
local development can keep takeover disabled, while a production activation
fails closed when the renderer does not emit its complete takeover contract.

```text
PUBLIC_TAKEOVER_URL=https://app.kubus.site/en/artworks/<real-id>
PUBLIC_TAKEOVER_MISSING_URL=https://app.kubus.site/en/artworks/<missing-id>
EXPECT_PUBLIC_FLUTTER_TAKEOVER=true
npm --prefix scripts/qa run qa:public-takeover
```

The check validates raw SSR content and canonical metadata, real 404 semantics,
root JavaScript asset MIME types, the unregister-only service worker, exact
entity-ready handoff in Chromium and Firefox, and that the browser retains the
canonical localized URL. Set `EXPECT_PUBLIC_FLUTTER_TAKEOVER=false` only for
the intentional pre-activation rollout phase.

For the Flutter repository run `flutter test`, the QA contract tests under
`scripts/qa`, `flutter analyze`, and `flutter build web --release`. For the
backend run lint and Jest. The generated screenshots belong under
`output/playwright/artifacts/seo-public-pages/` and are not runtime assets.

## Accessibility and known limitations

Public HTML provides landmarks, headings, alt text, visible focus styles,
keyboard links, contrast-aware colors, and reduced-motion rules. Flutter web
semantics remains controlled by the existing opt-in build flag; SEO does not
enable it. This preserves the current Google Sign-In DOM-overlay mitigation.

The web origin requires its standard PHP cURL extension. Renderer availability
still depends on the Oracle API origin; gateway connection failures return a
non-cacheable, non-indexable 503. Entity translations are limited to fields
already stored by the product.
