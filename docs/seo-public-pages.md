# Public entity pages and technical SEO

## Architecture

`app.kubus.site` has two deliberately separate web surfaces:

- The existing Flutter application owns `/`, `/app/*`, and the finite set of
  interactive routes listed in `web/.htaccess`.
- The existing Express service renders localized public HTML for `/en/*`,
  `/sl/*`, compact share aliases, robots, and sitemaps. Apache/LiteSpeed proxies
  only that finite route surface to `api.kubus.site`.

The renderer reads the existing PostgreSQL public models. It does not call an
authenticated API, branch on user agent, or load Flutter, MapLibre, wallet, or
analytics JavaScript. This keeps initial responses useful without JavaScript
while preserving Flutter as the interactive product. The public page's “Open
in art.kubus” link targets `/app/<compact-entity-path>`; the existing deep-link
parser ignores the prefix and opens the same entity screen. Flutter then keeps
its established compact in-app route name in browser history.

This design is deployable through the current atomic static release and Node
deployment. The web origin must have Apache `mod_proxy`/`mod_proxy_http` or the
equivalent LiteSpeed proxy feature enabled for `RewriteRule [P]`.

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

1. Deploy the backend with `FEATURE_ENABLE_SEO_PUBLIC_PAGES=true` and the public
   URL variables documented in its `.env.example`.
2. Verify the renderer directly on the backend before promoting web routing.
3. Ensure web-origin proxy support is enabled, then atomically deploy the Flutter
   web artifact. The workflow smoke test checks public HTML, robots, sitemap, and
   an unknown-path 404.
4. Purge CDN HTML/XML entries if a release must become visible immediately.

Rollback is feature-flagged: disable `FEATURE_ENABLE_SEO_PUBLIC_PAGES`, restore
the prior web release symlink, and purge route caches. Flutter sharing has the
compile-time `SEO_PUBLIC_PAGES_ENABLED=false` fallback to compact URLs. A web
rollback and backend rollback should be coordinated so proxy routes never point
at a disabled renderer.

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

For the Flutter repository run `flutter test`, the QA contract tests under
`scripts/qa`, `flutter analyze`, and `flutter build web --release`. For the
backend run lint and Jest. The generated screenshots belong under
`output/playwright/artifacts/seo-public-pages/` and are not runtime assets.

## Accessibility and known limitations

Public HTML provides landmarks, headings, alt text, visible focus styles,
keyboard links, contrast-aware colors, and reduced-motion rules. Flutter web
semantics remains controlled by the existing opt-in build flag; SEO does not
enable it. This preserves the current Google Sign-In DOM-overlay mitigation.

The static host-to-backend proxy is an infrastructure dependency. Search engines
and social crawlers cannot receive distinct HTML until that proxy feature and
the backend environment values are active together. Entity translations are
limited to fields already stored by the product.
