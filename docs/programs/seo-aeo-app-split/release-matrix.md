# Release matrix — SEO / AEO / app-distribution program

Last updated: 2026-07-21

Status vocabulary: `PASS` (verified by executed evidence in the relevant
environment) · `FAIL` (executed validation showed incorrect behavior) ·
`IMPLEMENTED_NOT_DEPLOYED` · `BLOCKED_EXTERNAL` · `NOT_APPLICABLE` ·
`NOT_STARTED`.

**`PASS` is never written from inference.** Where a row says PASS, the command
that produced the evidence is named.

| Component | Status | Evidence |
|---|---|---|
| Repository layout verified | PASS | `git remote -v` ×5, `.gitmodules`, `git ls-files --stage` — backend is a submodule of art.kubus pointing at `art.kubus-backend` |
| Search Console inputs located | PASS | 7 CSVs supplied; Web search, last 3 months, to 2026-07-19; 33 clicks / 2 606 impressions |
| Production baseline recorded | PASS | `production_seo_contract.mjs` → 25/27 at baseline; curl matrix across 3 domains |
| Open-PR conflict check | PASS | `gh pr list --state open` → 0 PRs in all 5 repos |
| app.kubus root canonicalization | IMPLEMENTED_NOT_DEPLOYED | `.htaccess` `^$ → /en` 308; contract asserts it; production still 200 pending deploy |
| Compact alias redirects | PASS | Already correct in production: `/a/{id}` → 308 `/en/artworks/{id}`; `?lang=sl` → 308 `/sl/umetnine/{id}` |
| Canonical entity rendering | PASS | `/en/artworks/{id}` → 200, self-canonical, H1, JSON-LD (contract run) |
| Entity sitemap index | PASS | `/sitemap.xml` → 200 and contains `<sitemapindex` (contract run) |
| Real 404 behavior (app.kubus) | PASS | missing entity → 404; unknown route → 404 (contract run) |
| Flutter public takeover | PASS | entity pages carry `public_flutter_takeover.js` + `flutter_bootstrap.js` (contract run) |
| Takeover on locale homepages | NOT_APPLICABLE | By design today: `takeoverTargetForPath()` matches entity paths only. Extension deferred — decision log D-2 |
| Deployment revision identity | IMPLEMENTED_NOT_DEPLOYED | proxy emits `X-Kubus-Web-Revision`; CI stamps it pre-checksum; absent in production pending deploy |
| Backend revision header | BLOCKED_EXTERNAL | Proxy forwards `X-Kubus-Backend-Revision`; art.kubus-backend must emit it first |
| Deployment revision-drift gate | IMPLEMENTED_NOT_DEPLOYED | `deploy.yml` fails the release when served revision ≠ deployed commit |
| kubus.site duplicate cleanup | IMPLEMENTED_NOT_DEPLOYED | `/home`, `/home/` → 301 `/`; built into `dist/.htaccess` |
| kubus.site unknown-route handling | IMPLEMENTED_NOT_DEPLOYED | fallback restricted to router surface; `ErrorDocument` → `404.html` |
| kubus.site robots correctness | IMPLEMENTED_NOT_DEPLOYED | single wildcard group; own sitemap only; verified in `dist/robots.txt` |
| kubus.site metadata | IMPLEMENTED_NOT_DEPLOYED | mandated title/description in `dist/index.html`; `npm run build` clean |
| kubus.site pre-rendered metadata | NOT_STARTED | Route-level metadata is still client-side (`@vueuse/head`). Only the global head is server-visible |
| kubus.site route/htaccess parity test | NOT_STARTED | Known gap — decision log D-5 |
| Admin editorial authority | NOT_STARTED | Batch 4 |
| Editorial snapshot and rollback | NOT_STARTED | Batch 4 |
| Marketing schema resolver | NOT_STARTED | Batch 5 |
| Page consolidation | NOT_STARTED | Batch 6 — Search Console data in hand |
| Ljubljana EN | NOT_STARTED | Batch 7 |
| Ljubljana SL | NOT_STARTED | Batch 7 |
| City indexability policy | NOT_STARTED | Batch 7 |
| City social-image workflow | NOT_STARTED | Batch 8 |
| Native/full-web positioning | NOT_STARTED | Batch 9. Partial: PWA manifest description de-crypto'd in Batch 2 |
| Native wallet exclusion | NOT_STARTED | Batch 9 |
| Distribution links | NOT_STARTED | Batch 9 |
| Android App Links | NOT_STARTED | Batch 10 |
| Apple Universal Links | NOT_STARTED | Batch 10 |
| Entity provenance | NOT_STARTED | Batch 11. Defect evidence captured (progress §8) |
| EN/SL parity | PASS (transport only) | `/en` and `/sl` both 200 with reciprocal hreflang and localized H1 (contract run). Content parity not yet audited |
| Analytics | NOT_STARTED | Batch 12 |
| Accessibility | NOT_STARTED | Batch 13 |
| Mobile QA | NOT_STARTED | Batch 13 |
| Desktop QA | NOT_STARTED | Batch 13 |
| Production deployment | BLOCKED_EXTERNAL | Protected workflow: SSH credentials + environment approval unavailable to the agent |
| Rollback verification | BLOCKED_EXTERNAL | Rollback path exists in `deploy.yml`; exercising it requires the same credentials |

## Explicitly corrected premises

Two assumptions in the program brief did not survive inspection and should not
be carried forward:

1. **app.kubus.site does not need a public renderer.** It already has one, in
   production, with compact aliases, localized canonicals, real 404s, entity
   sitemaps and progressive takeover. Only root canonicalization and revision
   identity were missing.
2. **`/en` and `/sl` are not takeover surfaces.** Only 3-segment entity paths
   are. Any plan that assumes locale homepages boot the app is wrong today.
