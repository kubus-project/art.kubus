# Continue the art.kubus SEO/AEO/app-distribution program

You are continuing an in-flight multi-repository program. **Do not restart the audit.
Do not re-derive the architecture. Do not ask which batch to work on.**

Batches 1–8 are implemented. Your job is to land what is open, then continue with
Batches 9–13 in order.

---

## Repositories and local paths

```
kubus-project/art.kubus            /g/WorkingDATA/art.kubus/art.kubus
kubus-project/art.kubus-backend    /g/WorkingDATA/art.kubus/art.kubus/backend   (git submodule)
kubus-project/kubus.site           /g/WorkingDATA/art.kubus/kubus.site
kubus-project/art.kubus.site       /g/WorkingDATA/art.kubus/art.kubus.site_webpage
kubus-project/admin.kubus          /g/WorkingDATA/art.kubus/admin.kubus
```

Note the last path: the art.kubus.site checkout is the `_webpage` directory.

**Program ledger** (read this first): `art.kubus/docs/programs/seo-aeo-app-split/`
— `progress.md`, `decision-log.md`, `release-matrix.md`.

---

## State: merged

| PR | Contents |
|---|---|
| art.kubus#49 | root canonicalization (`/` → 308 `/en`), lang-query stripping, PWA `start_url` → `/app`, `X-Kubus-Web-Revision`, PHP lint, Apache rewrite contract, production SEO contract in the deploy path |
| art.kubus-backend#12 | `X-Kubus-Backend-Revision`, migration `082_editorial_kubus_journal_seed.sql`, PostgreSQL migration contract CI |
| kubus.site#1 | soft-404 elimination, route manifest, committed editorial snapshot, journal fallback semantics, tracked lockfile, Apache routing CI |
| art.kubus.site#2 | typed structured-data resolver (Batch 5 only — see the correction comment on that PR) |

## State: open

| PR | Contents | Status |
|---|---|---|
| **art.kubus.site#3** | Batches 6–7: search-intent ownership, city indexability policy | **CI 2/2 green @ `4f8345f`**, mergeable |
| **art.kubus.site#4** | Batch 8: per-page 1200×630 social cards. **Stacked on #3** | CI status: verify before trusting |
| **art.kubus#52** | program ledger (docs only) | **FAILS on an inherited base defect — not its own diff** |

### art.kubus#52 is blocked, and not by its own contents

`master` carries divergent backend gitlinks:

```
backend             a2229f7bfafc91596b788afa1b8d6633cc0f5863
backend-open-art-wt 47f4fe071c16c968246e3734a4c23d6eef413f34
```

CI (`Guardrails > Require both backend checkouts at their pinned gitlinks`) requires
them equal, so **`master` itself fails** and every branch inherits it.
**`art.kubus#51 fix(ci): align backend gitlinks`** is open to fix it.

**First action:** once #51 merges, rebase #52 onto master and confirm it goes green.

---

## Hard constraints (violating these has already caused damage once)

1. **Never stage either backend gitlink.** They must move together in one deliberate
   commit, and only after a backend PR merges. Do not "fix" #52 by touching them.
2. **Never push to a default branch.** Verify with
   `git rev-list --count origin/master..HEAD` before every push.
3. **Verify pushes actually landed.** `git push` can report success while pushing an
   *unchanged* branch if your commits went somewhere else. Always confirm:
   `git branch -r --contains <sha>`. This bit me: two commits were reported as pushed
   when they had reached no remote at all.
4. **Check your current branch before committing.** Concurrent merges have switched
   the checkout to `master` mid-session more than once. `git branch --show-current`.
5. **Never use backticks inside `git commit -m "..."`.** They run as shell command
   substitution and inject command output into the message (this corrupted one commit
   and executed a build as a side effect). Use `git commit -F -` with a
   `<<'MSG'` heredoc.
6. **Do not fabricate content.** No invented artworks, artists, institutions, routes
   or verification claims. If data does not exist, say so and mark `BLOCKED_EXTERNAL`.
7. **Never claim a check passed without executing it.** Status vocabulary:
   `PASS` · `FAIL` · `IMPLEMENTED_NOT_DEPLOYED` · `BLOCKED_EXTERNAL` · `NOT_APPLICABLE`
   · `NOT_STARTED`. A green *old* workflow does not validate new commits.
8. **Prove new assertions can fail.** Negative-test them. A check that cannot fail is
   worse than no check because it manufactures false confidence.

---

## Standing architecture decisions (do not relitigate)

- **Builds are offline and reproducible.** `npm run build` / `routes:check` /
  `routes:generate` must make **no network calls**. Live data enters only through
  explicit, committed snapshot steps: `npm run editorial:sync` (kubus.site),
  `npm run social:generate` (art.kubus.site). kubus.site CI enforces this with a
  `--require` preload that exits 86 on any socket use, and self-tests that guard first.
- **Admin is the editorial source of truth.** Content flows from the editorial API →
  committed snapshot → build. Do not hand-edit content into source files.
- **Migration 082 conflict policy:** updates only rows where **both** `created_by` and
  `updated_by` are still `editorial-kubus-journal-seed`. Human drafts and human edits
  survive re-runs untouched.
- **City indexability is data OR demand**, never both-required. Zagreb has zero entity
  backing but 4 clicks / 140 impressions; deindexing it would destroy demonstrated
  value. See `scripts/city-eligibility.cjs`.
- **`sharp` renders text using host fonts**, so social cards cannot be byte-identical
  across platforms. They are committed artifacts, validated — not regenerated — in CI.

---

## Known blockers

| Blocker | Detail |
|---|---|
| **Production deployment** | All merged work is on `master` and **undeployed**. `app.kubus.site/` still returns 200 (not 308); `kubus.site/does-not-exist` still 200; no revision headers. Needs the protected workflow's SSH credentials + environment approval. |
| **`GIT_COMMIT` unset** | Backend must set it or `X-Kubus-Backend-Revision` stays absent (by design — it is never faked). See `backend/docs/DEPLOYMENT_REVISION_IDENTITY.md`. |
| **Editorial content** | The city editorial API returns **zero records for every city**; `site_scope=kubus` articles exist only via migration 082, which has not been run against production. |
| **Ljubljana rich content** | Blocked by the above. Neighbourhoods, routes, institutions and verification cannot be written without records. |
| **Rich social imagery** | Real map tiles + artwork photography unavailable offline. Slots and validation are complete and will carry them unchanged. |
| **Pre-existing test flake** | `art.kubus.site` `src/utils/firstPartyAnalyticsConsent.test.ts` intermittently throws `self is not defined` in CI (same SHA has both passed and failed). Untouched by this program. Worth fixing properly. |

---

## Next work, in order

**1. Land what is open.** Rebase #52 after #51 merges; confirm #3 and #4 green; merge
in stack order (#3 before #4).

**2. Batch 9 — public entity SEO and provenance** (`art.kubus-backend`). Improve the
*existing* renderer; do not build a second one. Production evidence already captured:
artwork `3ae86a4b-bbab-4392-8353-829c2bd80275` is indexed at position 1 rendering

```
<title>Ljubljana (15462145848) by kubus public art | art.kubus</title>
<meta name="description" content="_MG_3111">
```

Three defects in one record: a Flickr numeric ID inside the title, an import source
credited as the artist, and a raw camera filename as the description. Target
`{Artwork} by {Artist} — Public Art in {City} | art.kubus` **only where reliable data
exists**; otherwise degrade honestly. Add related-entity links and provenance fields.
Do not conflate image verification, metadata verification, location verification and
account ownership.

**3. Batch 10 — deep links.** Android App Links + Apple Universal Links for
native-safe public routes only. Exclude wallet, swap, marketplace, DAO, settings,
recovery, auth callbacks. Repository files, manifests, entitlements and tests are
completable now; console validation is `BLOCKED_EXTERNAL`.

**4. Batch 12 — analytics**, then **Batch 13 — integrated QA**.

**Batch 11 (Ljubljana/city content) stays blocked** until editorial records exist.

---

## Useful commands

```bash
# art.kubus.site
npm run ci:seo          # build + sitemap + vue-tsc + vite + all SEO assertions
npm test                # vitest (55 tests)
npm run social:generate # regenerate committed social cards (deliberate)

# kubus.site
npm run routes:check    # manifest ↔ router ↔ .htaccess parity
npm run editorial:sync  # refresh committed editorial snapshot (only networked step)

# art.kubus
node scripts/qa/production_seo_contract.mjs   # live production contract
node scripts/qa/web_routing_contract.mjs      # Apache rewrite contract

# art.kubus-backend
npm run migration:contract:editorial          # needs DATABASE_URL to a scratch PG
```

Apache-under-Docker pattern used by both routing contracts (`AllowOverride All` is
load-bearing — without it Apache ignores `.htaccess` entirely and every assertion
passes against default behaviour, proving nothing):

```bash
docker run -d --name kubus-apache -p 8080:80 \
  -v "$(pwd -W)/dist:/usr/local/apache2/htdocs:ro" httpd:2.4 \
  sh -c "sed -i -e 's|^#LoadModule rewrite_module|LoadModule rewrite_module|' \
     -e 's|^#LoadModule headers_module|LoadModule headers_module|' conf/httpd.conf \
   && printf '%s\n' '<Directory \"/usr/local/apache2/htdocs\">' \
     '  AllowOverride All' '  Require all granted' '</Directory>' >> conf/httpd.conf \
   && httpd-foreground"
```

Start by reading the ledger, verifying the three open PRs' real CI state, and landing
them.
