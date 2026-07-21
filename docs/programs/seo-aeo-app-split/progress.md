# SEO / AEO / app-distribution program — progress ledger

Coordination repository: `kubus-project/art.kubus`
Coordinated branch name: `goal/seo-aeo-app-split`
Ledger opened: 2026-07-21

This file records **executed** state only. Anything not verified by a command
whose output was read is marked as such. Do not mark a row complete without
evidence.

---

## 1. Verified repository layout

Confirmed from `git remote -v` in each working tree on 2026-07-21.

| Repository | Remote | Local path | Role |
|---|---|---|---|
| `kubus-project/art.kubus` | `git@github.com:kubus-project/art.kubus.git` | `art.kubus/` | Flutter app, `web/` transport layer (`.htaccess`, `seo-proxy.php`), CI/deploy, QA scripts |
| `kubus-project/art.kubus-backend` | `git@github.com:kubus-project/art.kubus-backend.git` | `art.kubus/backend` (**git submodule**) | Public renderer, entity indexing policy, sitemaps, editorial APIs |
| `kubus-project/art.kubus.site` | `git@github.com:kubus-project/art.kubus.site.git` | `art.kubus.site_webpage/` | Acquisition site (generated static EN/SL HTML) |
| `kubus-project/kubus.site` | `git@github.com:kubus-project/kubus.site.git` | `kubus.site/` | Research/artistic project site (Vue 3 + Vite SPA) |
| `kubus-project/admin.kubus` | `git@github.com:kubus-project/admin.kubus.git` | `admin.kubus/` | Editorial administration |

### Resolved layout ambiguity

The backend is **both** a separate repository *and* physically located inside
`art.kubus`. It is mounted as a git submodule:

```
.gitmodules → [submodule "backend"] url = git@github.com:kubus-project/art.kubus-backend.git
git ls-files --stage → 160000 876507d2… backend
```

Earlier notes claiming "the backend lives inside art.kubus, not a separate
repo" and "art.kubus-backend is a separate repository" were both partially
correct. Treat `art.kubus-backend` as the authoritative remote and
`art.kubus/backend` as its gitlink checkout.

### Worktrees deliberately not touched

- `art.kubus/backend-open-art-wt` — a **second** gitlink to the same backend
  remote, at `47f4fe07…` while `backend` is at `876507d2…`. It shows as a
  modified gitlink in `git status`. It was left unstaged and unmodified.
- `art.kubus/../art.kubus-*-wt`, `…-release`, `…-refresh` — sibling worktrees
  from unrelated in-flight work. Not touched.
- `art.kubus.site_webpage` reported 107 modified files. `git diff` is **empty**;
  these are CRLF/LF normalization artifacts only, not content changes.

---

## 2. Baseline commit SHAs (remote `master`, 2026-07-21)

| Repository | SHA | Head commit |
|---|---|---|
| art.kubus | `04637206ab060949cb4f5f12fd7d09f440e4274a` | Merge PR #48 (profile hierarchy / home rails) |
| art.kubus-backend | `876507d22c9e4634a0531fd254cbc90c797ed724` | Merge PR #11 (render takeover host behind SSR) |
| art.kubus.site | `156d5a6e3b487a0f7253a8080df11b44dd285f6d` | Merge PR #1 (contextual public navigation) |
| kubus.site | `f979a250b46f6500d484ab795661b4235c89c573` | remove unused archive grid overlay |
| admin.kubus | `5114511a41dc1747e6a5135c5fac213fb2c00ea5` | update API base URL handling |

All five local checkouts were at their remote `master` SHA at program start.

## 3. Open PR conflicts

**None.** `gh pr list --state open` returned zero open PRs in all five
repositories. No `goal/seo-aeo-app-split` branch existed in any remote before
this program. There is no unrelated in-flight PR work to avoid colliding with.

---

## 4. Production baseline (recorded 2026-07-21, before any change)

Captured with `curl` without following redirects. Full reusable matrix:
`scripts/qa/production_seo_contract.mjs`.

### app.kubus.site — mostly already correct

| Route | Observed | Verdict |
|---|---|---|
| `/` | `200 text/html` (LiteSpeed static, no charset) — **Flutter shell** | defect |
| `/?lang=sl` | `200` — no canonicalization | defect |
| `/en`, `/sl` | `200`, semantic renderer, canonical + reciprocal hreflang + H1 | correct |
| `/a/{id}` | `308 → /en/artworks/{id}` | correct |
| `/a/{id}?lang=sl` | `308 → /sl/umetnine/{id}` | correct |
| `/en/artworks/{id}` | `200`, self-canonical, JSON-LD, takeover present | correct |
| `/en/artworks/{missing}` | `404` | correct |
| `/__unknown-test-path` | `404` | correct |
| `/robots.txt`, `/sitemap.xml` | `200`, backend sitemap **index** | correct |
| revision headers | **absent** | defect |

Contract run at baseline: **25/27 pass**. The 2 failures are root
canonicalization only.

Important correction to the program brief: the audit premise that app.kubus.site
needed a public renderer built is **wrong**. The renderer, compact aliases,
localized canonicals, real 404s, entity sitemaps and progressive Flutter
takeover all already exist and work in production. Only root canonicalization
and revision identity were missing.

### Takeover surface — narrower than assumed

`takeoverTargetForPath()` in `web/seo-proxy.php` matches **only** 3-segment
entity paths (`/{locale}/{segment}/{id}`). Consequences:

- Entity pages carry `flutter_bootstrap.js` + `public_flutter_takeover.js`. ✅
- `/en` and `/sl` are pure static documents with **no** takeover and no scripts.

This is why root canonicalization required a paired PWA change (see decision
log D-2).

### kubus.site — broadly broken

| Route | Observed | Verdict |
|---|---|---|
| `/` | `200` | correct |
| `/home`, `/home/` | `200` (SPA shell) — never a router route | defect |
| `/does-not-exist` | `200` | defect (soft 404) |
| `/journal` | `200` | correct |

Search Console corroboration: `/home/` = 355 impressions, position 32.2, 0
clicks, duplicating `/` at 1065 impressions.

### art.kubus.site

`/en/`, `/sl/`, `/en/ljubljana/`, `/sl/ljubljana/`, `/robots.txt`,
`/sitemap.xml` all `200`; `/__unknown-test-path` → `404`. No transport defect
found at baseline.

---

## 5. Search Console inputs

**Located.** Supplied as attachments (`Chart.csv`, `Pages.csv`, `Queries.csv`,
`Devices.csv`, `Countries.csv`, `Search appearance.csv`, `Filters.csv`), filtered
to Web search, last 3 months, ending 2026-07-19.

Headline figures: 33 clicks / 2 606 impressions. Mobile 21 clicks at 2.42% CTR
vs desktop 12 clicks at 0.69%. Slovenia is the only market with meaningful
qualified demand (14 clicks, 358 impressions, position 7.5).

Demand separation (per program brief):

- **Qualified art.kubus brand**: `art kubus` (3 clicks / 5 impressions / pos 1).
- **Ambiguous `kubus`**: 604 impressions, 1 click, position 26 — contaminated by
  unrelated entities (`kubus apple juice`, `kubus dj`, `kubus festival`,
  `kubus servers`, `kubabonus com`). Explicitly **not** a success metric.
- **Public-art / mural discovery**: `murali` (24 impr, pos 7), `mural`,
  `murali na zidu`, `mural map`, `street art map`, `public art`.
- **City discovery**: `artist alley ljubljana` (14 impr, pos 9.9),
  `pavšlarjeva hiša kranj` (17 impr, pos 9.4), `vienna street art map`,
  `street art trieste`, `art celje`, `zagreb soseske`.
- **Educational**: `kaj je ar` (2 clicks / 12 impr / 16.7% CTR), `kaj je mural`.
- **Research/infrastructure**: `infrastruktura kot koda`.

Top opportunity pages in the 3–15 position band with real impressions:
`/en/ljubljana/` (220 impr, pos 8.2, 3.64% CTR), `/en/zagreb/` (116 impr,
pos 7.7), `/en/` (137 impr, pos 6.05, 1.46% CTR), `/sl/murali-v-blizini/`
(58 impr, pos 7.0), `/en/availability-node/` (66 impr, pos 4.2, **0 clicks**),
`/en/what-is-kubus-node/` (64 impr, pos 3.9, **0 clicks**).

---

## 6. Ordered batches and status

| Batch | Scope | Status |
|---|---|---|
| 1 | Baseline + production contract | **COMPLETE** |
| 2 | app.kubus.site routing / SEO transport | **IMPLEMENTED_NOT_DEPLOYED** |
| 3 | kubus.site technical cleanup | **IMPLEMENTED_NOT_DEPLOYED** |
| 4 | Editorial authority + admin integration | NOT STARTED |
| 5 | Structured-data correction | NOT STARTED |
| 6 | Search-intent consolidation | NOT STARTED |
| 7 | Ljubljana + reusable city pages | NOT STARTED |
| 8 | Page-specific social images | NOT STARTED |
| 9 | Native / full-web distribution split | NOT STARTED |
| 10 | Public deep links | NOT STARTED |
| 11 | Entity SEO + provenance | NOT STARTED (defect evidence captured, §8) |
| 12 | Analytics | NOT STARTED |
| 13 | Integrated QA + release prep | NOT STARTED |

---

## 7. Completed work

### Batch 1 — Baseline (COMPLETE)

- Verified layout, remotes, submodules, dirty worktrees, open PRs, baseline SHAs.
- Recorded production behavior across all three public domains.
- Added `scripts/qa/production_seo_contract.mjs`, a reusable contract runner
  covering root canonicalization, locale homepages, app namespace, robots,
  sitemap index, compact aliases, entity rendering, takeover presence, JSON-LD,
  missing-entity 404 and unknown-route 404.

### Batch 2 — app.kubus.site transport (IMPLEMENTED_NOT_DEPLOYED)

Commit `7b6c8202` on `goal/seo-aeo-app-split`.

- `web/.htaccess`: root now `308 → /en`; `?lang=sl` → `/sl`. `/app` keeps the
  interactive shell.

  **Correction (superseded).** The first implementation used `QSA` and this
  ledger claimed it produced a clean `/sl`. It did not: `QSA` *appends* the
  original query, so `/?lang=sl` resolved to `/sl?lang=sl` — the obsolete
  language parameter retained on a URL whose locale is already in the path.
  Fixed in `8f359538` by matching the four positions `lang=` can occupy and
  reassembling the surviving parameters. Now verified under real Apache.
- `web/manifest.json`: `start_url` `"."` → `"/app"` (see decision log D-2),
  `scope: "/"`, and the blockchain-forward description replaced with
  discovery-first positioning.
- `web/seo-proxy.php`: emits `X-Kubus-Web-Revision` from a CI-written
  `kubus-web-revision.txt`, omitted entirely when absent; forwards
  `X-Kubus-Backend-Revision` from upstream.
- `.github/workflows/ci.yml`: stamps the revision file into `build/web` before
  checksumming, so it is covered by `SHA256SUMS`.
- `.github/workflows/deploy.yml`: post-deploy smoke now asserts the shell at
  `/app` (**it previously asserted it at the followed root URL and would have
  failed and auto-rolled-back against the redirected root**), plus root
  canonicalization, compact-alias resolution, and served-revision equality with
  the deployed commit.

### Correction round (2026-07-21, after PR review)

Executed evidence replaced three claims that had been asserted from reading
code rather than running it.

| Claim previously made | What execution showed |
|---|---|
| `?lang=sl` redirects cleanly to `/sl` | `QSA` retained it: `/sl?lang=sl` |
| kubus.site unknown routes all 404 | `/contact/anything`, `/monograph/anything` etc. returned 200; any invalid `/journal/{slug}` returned 200 |
| `/home/` → `301 /` | Two hops: `/home/` → `/home` → `/`, because the trailing-slash rule ran first |

Work added in this round:

- **art.kubus** `8f359538`: four-rule `lang=` stripping; `scripts/qa/web_routing_contract.mjs`
  executed under `httpd:2.4` (**14/14**) and wired into a new `web_routing` CI
  job; `php -l` over every `web/*.php` in the guardrails job; the production
  contract moved *inside* the post-deploy smoke step so failures reach the
  existing rollback guard, extended with the Slovenian canonical entity and all
  language-query cases.
- **kubus.site** `8f9b002`: `route-manifest.json` as the single source of truth;
  router resolves paths via `routePath(name)`; `.htaccess` allowlist and sitemap
  generated from it; `npm run routes:check` fails on drift or hardcoded literals;
  static routes matched exactly; journal slugs enumerated, not wildcarded;
  redirects emitted above the trailing-slash rule to remove the 301 chain;
  HTTPS rule honors `X-Forwarded-Proto`; new CI runs **29/29** routing
  assertions against real Apache. `seo.config.json` and `generate-sitemap.cjs`
  removed as duplicate sources.
- **art.kubus-backend** `b3fbf10`: `X-Kubus-Backend-Revision` at the
  `setPublicHeaders` choke point, reusing `deploymentMetadataService`; **54/54**
  jest tests pass including 4 new; `docs/DEPLOYMENT_REVISION_IDENTITY.md`.

### Batch 3 — kubus.site cleanup (IMPLEMENTED_NOT_DEPLOYED)

Commit `db2d4bf` on `goal/seo-aeo-app-split` in `kubus.site`.

- `public/.htaccess` reordered: HTTPS and canonicalization now run **before** the
  SPA fallback (they were unreachable dead code behind a terminating `[L]`);
  fallback restricted to the finite router surface; everything else `404`.
- `/home` and `/home/` → `301 /`.
- `ErrorDocument 404|403` → new static noindex `public/404.html` (was
  `/index.html`, which made every missing URL a homepage duplicate).
- `public/robots.txt`: collapsed to one wildcard group. Previously each
  `Disallow` bound to `LinkedInBot` because it followed the last per-bot group,
  so **none applied to Googlebot**. Removed cross-domain art.kubus sitemap,
  hash-fragment `Allow` entries, `/*.json$` (blocked the PWA manifest) and a
  stale Next.js path.
- `index.html`: mandated research-project title/description across primary, OG
  and Twitter tags; `Organization` JSON-LD replaced by a `WebSite` / `Person` /
  `Project` graph keeping kubus and art.kubus as distinct entities.

---

## 8. Captured defect evidence for later batches

**Batch 11 (entity SEO) — confirmed in production.** Artwork
`3ae86a4b-bbab-4392-8353-829c2bd80275` is indexed (Search Console: position 1)
and renders:

```
<title>Ljubljana (15462145848) by kubus public art | art.kubus</title>
<meta name="description" content="_MG_3111">
```

Three distinct defects in one record: a Flickr-style numeric ID inside the
artwork title, an imported source credited as an artist (`kubus public art`),
and a raw camera filename as the meta description. This is the thin-imported-
record class the indexing policy must exclude or repair.

**Batch 5 (structured data).** `/en` emits a `WebApplication` node declaring
`"operatingSystem": "Web, Android, iOS"`. Per the native/full-web split this
must be verified against real distributions and probably split into
`WebApplication` + `MobileApplication`.

**Transport nit.** `/en` returns two `Cache-Control` headers: the backend's
`public, max-age=60, s-maxage=300, …` followed by LiteSpeed's `private`. The
trailing `private` likely defeats shared/CDN caching. Not yet fixed.

---

## 9. Cross-repository dependencies

- Batch 2's `X-Kubus-Backend-Revision` only appears once **art.kubus-backend**
  emits it; the proxy forwards but cannot invent it. Backend change still owed.
- Batch 4 (editorial) spans admin.kubus + art.kubus-backend + art.kubus.site and
  must not fork the existing editorial schema.
- Batch 7 city pages consume backend eligibility data; marketing cards must link
  to canonical `app.kubus.site` entity URLs, never re-host entities.

---

## 10. External blockers

| Item | Blocker |
|---|---|
| Production deployment | Protected workflow requiring SSH credentials + environment approval. Not available to the agent. |
| Post-deploy production verification of Batches 2–3 | Depends on the above. |
| Rollback verification | Depends on the above. |
| Apple Universal Links final validation | Apple developer account. |
| Android App Links final validation | Play Console / signing key. |

Repository-level work for each remains executable and is not blocked.

---

## 11. Next executable action

Open draft PRs for the two committed branches, then start **Batch 5**
(structured-data resolver) in `art.kubus.site`, which is fully executable
offline: replace blanket `SoftwareApplication` emission with a typed resolver
and apply `noindex, follow` to utility/legal pages.

Batch 6 is also unblocked and has strong data: `/en/availability-node/` and
`/en/what-is-kubus-node/` hold positions 4.2 and 3.9 on 130 combined impressions
with **zero** clicks, which is an intent/title mismatch rather than a ranking
problem.
