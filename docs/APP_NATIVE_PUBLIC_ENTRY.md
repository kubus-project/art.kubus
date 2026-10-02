# app.kubus.site — app-native public entity entry

Status: **target architecture for the next SEO/web phase**
Last updated: 2026-09-22. Implementation package: `AGENT_EXECUTION_PLAN.md` Wave 2; native association is Wave 3.

## 1. Problem

The current canonical entity architecture solved crawlability and real status
codes, but the visible first response is still a separately designed generic
HTML document before Flutter takes over. This creates an artificial transition:

```
search / link
→ generic semantic HTML
→ Flutter engine/entity load
→ visually different product screen
```

That is technically progressive enhancement but poor product continuity.

The required target is:

```
canonical entity URL
→ app-native semantic first frame
→ seamless Flutter continuation on web
```

and, where the native application is installed:

```
same canonical URL
→ verified Android App Link / iOS Universal Link
→ native entity screen
```

There must be no extra canonical URL and no marketing/SEO bridge page.

## 2. Important technical constraint

Flutter web does not provide server-rendered semantic entity HTML for this
application. Removing the server renderer would regress crawlability, metadata,
structured data, no-JS behaviour and real entity-specific status codes.

Therefore **SSR remains**, but it changes role:

> SSR is the first product frame, not a separate SEO page.

Humans should not perceive a jump from "web page" to "app".

No user-agent branching or crawler-only markup is permitted.

## 3. Canonical route contract

Keep the localized stable-ID routes:

| Entity | EN | SL |
| --- | --- | --- |
| artwork | `/en/artworks/:id` | `/sl/umetnine/:id` |
| profile | `/en/profiles/:id` | `/sl/profili/:id` |
| event | `/en/events/:id` | `/sl/dogodki/:id` |
| exhibition | `/en/exhibitions/:id` | `/sl/razstave/:id` |
| post | `/en/posts/:id` | `/sl/objave/:id` |
| collection | `/en/collections/:id` | `/sl/zbirke/:id` |
| collectible | `/en/collectibles/:id` | `/sl/zbirateljski-predmeti/:id` |
| map record | `/en/map/:id` | `/sl/zemljevid/:id` |

Compact aliases remain compatibility/share redirects; they are not the primary
product URL.

## 4. Server first-frame contract

Refactor `art.kubus-backend/src/services/seoPublicPagesService.js` so entity
responses render the same hierarchy as the corresponding app detail.

Current implementation evidence: `seoPublicPagesService.js` uses Inter, an
independent header/footer, rounded hero/related cards and strings such as
“Explore this artwork” and “Open interactive artist profile”. The target is
PRODUCT composition, not WORLD's editorial two-thirds layout. The current
backend `seoPublicPagesRepository.js` can select
`COALESCE(profile.display_name, profile.username, artwork.artist_name)`;
that can show an uploader as artist. The normalized presentation must keep
**artwork authorship** (artist/attributed/unknown), **platform contribution**
(uploaded/documented/managed by) and **provenance** (source URL/ID,
verification, image photographer/Commons credit) separate. Missing authorship
stays unknown; do not infer it from the account.

Remove the generic marketing-page treatment:

- no separate marketing site header;
- no generic footer as the main entity chrome;
- no oversized SEO hero card;
- no generic "Explore this artwork" bridge as the primary action;
- no design system independent from the product.

Retain:

- semantic landmarks/headings;
- crawlable factual body content;
- canonical/hreflang;
- OpenGraph/Twitter metadata;
- structured data;
- provenance and factual entity metadata;
- real 404/503 status semantics.

The renderer should consume a shared/derived family token contract and use the
same product information hierarchy as Flutter.

## 5. Bootstrap and data continuity

The semantic response should embed a versioned, escaped, size-bounded public
entity bootstrap
payload derived from the same normalized presentation used to render HTML.

Flutter startup should:

1. parse the canonical localized route;
2. consume the bootstrap payload only when its type + stable ID + locale +
   canonical path (and validity marker) match; otherwise fetch normally;
3. render the exact entity without an avoidable duplicate fetch;
4. revalidate in the background where necessary;
5. signal readiness only after the correct entity frame is meaningful.

This reduces the visual/time gap between HTML and Flutter.

The serialized payload is public entity data only. Never include auth/session
state, private moderation fields, unpublished content or secrets. Escaping
must prevent a script terminator or untrusted markup from changing the page.
The existing route/parser owners include
`lib/services/share/share_deep_link_parser.dart`,
`lib/core/deep_link_startup_routing.dart`,
`lib/core/deep_link_bootstrap_screen.dart`,
`lib/providers/public_entity_takeover_provider.dart` and
`lib/widgets/public_entity_takeover_ready.dart`; inspect their actual
contracts before modifying the handoff.

## 6. Takeover correctness

`web/public_flutter_takeover.js` currently contains a 1500 ms fallback that
can synthesize `kubus:public-entity-ready` after the engine and route are ready
even if the entity screen itself has not declared a meaningful frame.

That contradicts the documented readiness contract and must be removed or
replaced with a non-takeover failure path.

Target rule:

> Only the exact entity screen can declare the handoff ready.

If Flutter is slow or fails, the semantic product frame remains usable.

The final transition should be visually negligible because both layers use the
same layout/token contract.

## 7. Native platform handoff

### Android

The app already declares `autoVerify` links for compact/legacy path families, but
the manifest must also claim the actual localized canonical families used by
search results.

Add/verify prefixes for EN/SL canonical entity routes and serve a versioned
`/.well-known/assetlinks.json` with the real production signing certificate
fingerprint(s).

Acceptance includes `adb shell pm get-app-links` / equivalent verification,
cold start, warm start and already-running navigation to the exact entity.

Do not invent signing fingerprints in source/docs.

### iOS

When the iOS distribution target is active, add Associated Domains and a valid
`apple-app-site-association` covering the same canonical route families.

## 8. Web-native behaviour

When no native app owns the URL:

- desktop/mobile browser stays on the canonical URL;
- semantic frame appears immediately;
- Flutter continues on the same route;
- Back/Forward reflects visible product navigation;
- auth begins only at protected actions;
- opening from search must not create canonical → compact → `/app` history hops.

The existing `/app/*` route remains only as an internal/backward-compatible
surface while migration is in progress; new public entry should not depend on it.

## 9. Index-quality and duplication

The programme must audit the nearly 10k indexed pages before widening coverage.

Required analysis:

- indexable entity count by type;
- impressions/clicks by entity quality;
- title/description/provenance/image/artist/location completeness;
- EN/SL true localization vs fallback duplication;
- artwork vs marker duplicate ownership;
- source/import quality distribution.

Do not mass-deindex blindly. Introduce a measured quality tier and roll out
`noindex, follow` only from evidence.

When a map marker is merely the spatial representation of an artwork, the
artwork should own the search canonical. A marker should have an independent
indexable document only when it is genuinely a distinct public entity/place.
The “875 URLs” in an earlier performance export were URLs with impressions,
**not** the indexed count. Near-10k indexed overall is a separate Search
Console baseline to refresh. Audit first; do not change `seoIndexingPolicy.js`
or mass-deindex in the entry implementation package.

## 10. Acceptance

A canonical artwork opened from Google should:

- have useful HTML before JavaScript;
- visually already look like art.kubus;
- keep the exact canonical localized URL;
- become interactive without a visible redesign jump;
- open the installed Android app directly when verified;
- retain a useful browser experience when the native app is absent;
- remain usable if Flutter fails;
- return a real 404 for a missing/private entity;
- expose no duplicate indexable bridge page.
