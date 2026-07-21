# Release matrix — SEO / AEO / app-distribution program

Last updated: 2026-07-21 (post-correction round)

Status vocabulary: `PASS` (verified by executed evidence in the relevant
environment) · `FAIL` (executed validation showed incorrect behavior) ·
`IMPLEMENTED_NOT_DEPLOYED` · `BLOCKED_EXTERNAL` · `NOT_APPLICABLE` ·
`NOT_STARTED`.

**`PASS` is never written from inference.** Where a row says PASS, the command
that produced the evidence is named.

`PASS (Apache)` means verified against `httpd:2.4` serving the real build with
`AllowOverride All` — the rule logic is proven, but production has not been
redeployed. It is stronger than `IMPLEMENTED_NOT_DEPLOYED` and weaker than a
production `PASS`.

| Component | Status | Evidence |
|---|---|---|
| Repository layout verified | PASS | `git remote -v` ×5, `.gitmodules`, `ls-files --stage` — backend is a submodule pinned twice |
| Search Console inputs located | PASS | 7 CSVs, Web/3mo to 2026-07-19, 33 clicks / 2 606 impressions |
| Production baseline recorded | PASS | `production_seo_contract.mjs` + curl matrix, 3 domains |
| Open-PR conflict check | PASS | `gh pr list --state open` → 0 PRs in all 5 repos at program start |
| app.kubus root canonicalization | PASS (Apache) · IMPLEMENTED_NOT_DEPLOYED | `web_routing_contract.mjs` 14/14 under httpd:2.4; production still 200 |
| Root language-query cleanup | PASS (Apache) · IMPLEMENTED_NOT_DEPLOYED | `/?lang=sl`→`/sl`, `/?a=1&lang=sl&b=2`→`/sl?a=1&b=2`, `?lang=SL`→`/en?lang=SL` |
| UTM survives root redirect | PASS (Apache) | `/?utm_source=test` → `308 /en?utm_source=test` |
| Compact alias redirects | PASS | Already correct in production (contract run) |
| Canonical entity rendering (EN) | PASS | 200, self-canonical, H1, JSON-LD (contract run) |
| Canonical entity rendering (SL) | PASS | `/sl/umetnine/{id}` 200, self-canonical, EN alternate present |
| Entity sitemap index | PASS | `/sitemap.xml` contains `<sitemapindex>` |
| Real 404 behavior (app.kubus) | PASS | missing entity + unknown route → 404 |
| Flutter public takeover | PASS | entity pages carry `public_flutter_takeover.js` + `flutter_bootstrap.js` |
| Takeover on locale homepages | NOT_APPLICABLE | By design: `takeoverTargetForPath()` matches entity paths only (D-2) |
| PHP gateway validity | IMPLEMENTED_NOT_DEPLOYED | `php -l` over all `web/*.php` in guardrails job; PHP unavailable locally so not executed here |
| Deployment revision identity (web) | IMPLEMENTED_NOT_DEPLOYED | proxy emits `X-Kubus-Web-Revision`; CI stamps pre-checksum |
| Deployment revision identity (backend) | PASS (tests) · IMPLEMENTED_NOT_DEPLOYED | jest 54/54 incl. 4 new; needs `GIT_COMMIT` set in runtime env |
| Deployment revision-drift gate | IMPLEMENTED_NOT_DEPLOYED | `deploy.yml` fails release when served revision ≠ deployed commit |
| Production contract in deploy path | IMPLEMENTED_NOT_DEPLOYED | runs inside smoke step so failure reaches the rollback guard |
| kubus.site exact static routes | PASS (Apache) | `/contact/invalid`, `/monograph/invalid`, `/manifesto/invalid`, `/history/invalid`, `/projects/invalid` → 404 |
| kubus.site journal slug allowlist | PASS (Apache) | 4 enumerated slugs → 200; `/journal/definitely-not-a-real-article` → 404 |
| kubus.site `/home` one-hop redirect | PASS (Apache) | `/home` and `/home/` → `301 /` with no chain |
| kubus.site unknown-route handling | PASS (Apache) | `/random`, `/deeply/nested/unknown` → 404 |
| kubus.site 404 document | PASS (Apache) | real 404 body, `noindex`, not the SPA shell |
| kubus.site trailing-slash + index.html | PASS (Apache) | `/journal/`→`/journal`, `/index.html`→`/` |
| kubus.site HTTPS canonicalization | PASS (Apache) | plain HTTP upgrades; `X-Forwarded-Proto: https` does not loop |
| Router / allowlist parity | PASS | `npm run routes:check` — 8 routes agree; hardcoded literals rejected |
| kubus.site robots correctness | IMPLEMENTED_NOT_DEPLOYED | single wildcard group, own sitemap only, verified in `dist/robots.txt` |
| kubus.site metadata | IMPLEMENTED_NOT_DEPLOYED | mandated title/description; `npm run build` + `vue-tsc` clean |
| kubus.site pre-rendered metadata | NOT_STARTED | route-level metadata still client-side (`@vueuse/head`) |
| Admin editorial authority | FAIL | `GET /api/editorial/articles?site=kubus` returns `items: []` while the site renders 4 seed articles — admin does **not** own this content yet (D-10) |
| Editorial snapshot and rollback | NOT_STARTED | Batch 4 |
| Marketing schema resolver | NOT_STARTED | Batch 5 |
| Page consolidation | NOT_STARTED | Batch 6 — Search Console data in hand |
| Ljubljana EN / SL | NOT_STARTED | Batch 7 |
| City indexability policy | NOT_STARTED | Batch 7 |
| City social-image workflow | NOT_STARTED | Batch 8 |
| Native/full-web positioning | NOT_STARTED | Batch 9. Partial: PWA manifest description de-crypto'd |
| Native wallet exclusion | NOT_STARTED | Batch 9 |
| Distribution links | NOT_STARTED | Batch 9 |
| Android App Links | NOT_STARTED | Batch 10 |
| Apple Universal Links | NOT_STARTED | Batch 10 |
| Entity provenance | NOT_STARTED | Batch 11. Defect evidence captured (progress §8) |
| EN/SL parity (transport) | PASS | both locales 200, reciprocal hreflang, localized H1, SL entity canonical |
| Analytics | NOT_STARTED | Batch 12 |
| Accessibility | NOT_STARTED | Batch 13 |
| Mobile / Desktop QA | NOT_STARTED | Batch 13 |
| Backend gitlink bump | BLOCKED_INTERNAL | Must move `backend` **and** `backend-open-art-wt` together after art.kubus-backend#12 merges; CI enforces equality (D-9) |
| Production deployment | BLOCKED_EXTERNAL | Protected workflow: SSH credentials + environment approval |
| Rollback verification | BLOCKED_EXTERNAL | Rollback path exists; exercising it needs the same credentials |

## Claims retracted after execution

Three statements in the previous revision were asserted from reading code and
were wrong. Recorded so the pattern is visible, not buried:

1. **"`?lang=sl` → clean `/sl`."** `QSA` retained it: `/sl?lang=sl`.
2. **"All unknown kubus.site routes return 404."** Every section accepted an
   arbitrary child path, and any invalid journal slug returned 200.
3. **"`/home/` → `301 /`."** It was a two-hop chain via `/home`.

All three are now fixed and verified under real Apache. The common cause: rewrite
rules were reviewed rather than executed (D-8).

## Explicitly corrected premises

1. **app.kubus.site did not need a public renderer.** It already had one in
   production with compact aliases, localized canonicals, real 404s, entity
   sitemaps and progressive takeover.
2. **`/en` and `/sl` are not takeover surfaces.** Only 3-segment entity paths are.
3. **admin.kubus is not yet the editorial source of truth for kubus.site.** The
   editorial API returns zero articles for `site_scope=kubus`.
