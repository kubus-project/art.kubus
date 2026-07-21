# Decision log — SEO / AEO / app-distribution program

Decisions that changed intended behavior, with the evidence behind them.
Newest last. Each entry records what was decided, why, and what it costs.

---

## D-1 — `art.kubus-backend` is a submodule, not a sibling checkout

**Date:** 2026-07-21
**Status:** Settled

The program brief stated the backend is a separate repository and warned against
assuming it lives inside `art.kubus`. Prior project notes stated the opposite.

Both were partially right. `.gitmodules` and `git ls-files --stage` show
`art.kubus-backend` mounted as a **git submodule** at `art.kubus/backend`
(gitlink `160000`). It is a separate remote *and* physically nested.

**Decision:** treat `kubus-project/art.kubus-backend` as authoritative; change it
on its own branch and let the parent gitlink follow in a separate commit. Never
edit backend files expecting them to land in an `art.kubus` commit.

**Note:** a second gitlink, `backend-open-art-wt`, points at the same remote at a
*different* SHA and is dirty in `git status`. It belongs to unrelated in-flight
work and is left untouched.

---

## D-2 — Root canonicalization requires a paired PWA `start_url` change

**Date:** 2026-07-21
**Status:** Implemented, not deployed

The brief mandates `https://app.kubus.site/ → 308 /en`. The existing
`.htaccess` carried an explicit comment stating the opposite intent: *"Root
remains the established Flutter homepage."* This reverses a deliberate prior
decision, so it was checked rather than applied blindly.

Two findings made a naive redirect unsafe:

1. `web/manifest.json` declared `"start_url": "."`, which resolves against
   `/manifest.json` to `/`. Redirecting root would have launched **installed
   PWAs** into a static SEO page instead of the app.
2. `/en` carries **no** Flutter takeover. `takeoverTargetForPath()` matches only
   3-segment entity paths, so locale homepages are pure static documents. Root
   would have stopped being an app entry point entirely.

**Decision:** implement the redirect, and in the same commit point `start_url`
at `/app`, which `.htaccess` already serves and which `main.dart`
`_generateInitialRoutes` resolves to `AppInitializer` (verified by reading the
router, not assumed).

**Cost accepted:** a user who types the bare domain now lands on the semantic
page and needs one click ("Open in art.kubus") to reach the app. Installed PWAs
and `/app` links are unaffected.

**Alternative considered and deferred:** extend the takeover to locale
homepages so `/en` progressively becomes the app. This is the better end state
but requires a `home` pseudo-entity across `seo-proxy.php`, the takeover JS
identity check (`type`/`id`/`path` must match) and the Dart bridge, plus tests.
Deferred to its own change rather than smuggled into a routing fix.

---

## D-3 — The existing post-deploy smoke would have auto-rolled-back the fix

**Date:** 2026-07-21
**Status:** Fixed in the same commit

`deploy.yml` fetched `WEB_SMOKE_URL` **with `--location`** and asserted
`flutter_bootstrap.js|main.dart.js` in the response. With root redirecting to
`/en`, that assertion would resolve to the semantic page — which the *very next*
assertion requires **not** to contain the app bundle. The two assertions become
mutually unsatisfiable, the smoke fails, and the pipeline's automatic rollback
reverts a correct deployment.

**Decision:** retarget the shell assertion to `/app` and add explicit root
canonicalization, compact-alias and revision-match assertions.

**Why it matters beyond this change:** the smoke test encoded "root serves the
app" as an invariant. Any future move of the app off root would have hit the
same trap.

---

## D-4 — Revision identity is emitted only when genuinely known

**Date:** 2026-07-21
**Status:** Implemented, not deployed

`X-Kubus-Web-Revision` is read from `kubus-web-revision.txt`, written by CI into
the immutable artifact **before** checksumming so it is covered by `SHA256SUMS`
and cannot drift from the artifact it describes. The value is validated against
`^[0-9a-f]{7,64}$` and the header is **omitted entirely** when the file is
absent or malformed.

**Decision:** never emit a guessed, defaulted or build-time-approximated
revision. An absent header is honest; a wrong one would make the deploy-time
drift check silently useless.

`X-Kubus-Backend-Revision` is forwarded from upstream only. The proxy cannot
invent it, so it stays absent until `art.kubus-backend` emits it.

---

## D-5 — kubus.site keeps its own identity; only defects were removed

**Date:** 2026-07-21
**Status:** Implemented, not deployed

The brief is explicit that kubus.site must not be redirected into art.kubus.
The changes are confined to indexation defects (soft 404s, `/home` duplicate,
robots grouping) and metadata positioning.

**Decision:** the SPA fallback is now an **allowlist** derived from
`src/router/index.ts` rather than a catch-all. This is deliberately strict: a
new route added to the router without updating `.htaccess` will 404 in
production.

**Mitigation owed:** a test asserting the `.htaccess` allowlist matches the
router's route table. Not yet written — recorded as a known gap rather than
left implicit.

---

## D-7 — QSA cannot express "drop one parameter", so four rules do

**Date:** 2026-07-21
**Status:** Implemented and verified under Apache, not deployed

The first root canonicalization used `QSA` on both rules and this program's
ledger claimed `/?lang=sl` produced a clean `/sl`. It did not. `QSA` *appends*
the original query to the target, so the result was `/sl?lang=sl`: the obsolete
language parameter retained on a URL whose locale is already in the path, and a
second crawlable variant of the same document.

Two requirements conflict. `lang=` must be **dropped**, because it is
superseded by the path. Tracking parameters must be **kept**, or attribution
dies at the redirect. `QSA` is all-or-nothing and `QSD` discards everything.

**Decision:** match the four positions `lang=` can occupy in a query string —
only, first, last, middle — and reassemble the surviving parameters in each
case. Verbose, but each rule is independently testable and the middle case is
the one that silently produces `?a=1b=2` if the separator is mishandled.

Matching is **case-sensitive** because the captured locale becomes the redirect
target: accepting `?lang=SL` would emit `/SL`. Unrecognized values fall through
to `/en` with the query untouched.

**Why it was missed:** the rule was reviewed by reading, and the reading was
wrong about what `QSA` does to a target that already has no query. This is the
class of error that only execution catches — hence D-8.

---

## D-8 — Rewrite rules are not reviewable, only executable

**Date:** 2026-07-21
**Status:** Implemented, running in CI

Three separate defects in this program came from rules that read correctly and
behaved differently: the `QSA` retention above, the kubus.site fallback ordering
that made HTTPS and trailing-slash rules unreachable dead code, and a `/home/`
→ `/home` → `/` redirect **chain** that only appeared when the assertions were
actually run.

`mod_rewrite` semantics depend on rule order, `[L]` termination, per-rule query
handling and `RewriteCond` scoping. None of that is visible by inspection.

**Decision:** every `.htaccess` change must be executed against a real Apache
serving the real build with `AllowOverride All`, in CI.

- `art.kubus`: `scripts/qa/web_routing_contract.mjs`, `web_routing` job — 14/14.
- `kubus.site`: `scripts/qa/routing-contract.mjs`, new CI — 29/29.

`AllowOverride All` matters: without it Apache ignores `.htaccess` entirely and
every assertion would pass against default behavior, producing a green build
that proves nothing.

**Cost accepted:** CI now depends on pulling `httpd:2.4`.

---

## D-9 — The backend gitlink must move as a pair, so it does not move yet

**Date:** 2026-07-21
**Status:** Deliberately deferred

`art.kubus` pins the backend **twice**: `backend` and `backend-open-art-wt`.
`ci.yml` does not merely tolerate this, it *enforces* equality:

```bash
if [ "$canonical_expected" != "$public_expected" ]; then
  echo "The two backend gitlinks must point to the same verified backend commit."
```

This collides with the instruction to leave the dirty `backend-open-art-wt`
gitlink untouched: bumping only `backend` to pick up the backend revision work
would fail CI immediately.

**Decision:** do **not** bump either gitlink in this program's art.kubus PR. The
backend change ships as its own PR (art.kubus-backend#12). Once merged, a
separate deliberate commit moves **both** pins to the same merged SHA.

Neither gitlink was staged in any commit here; both remain modified in the
working tree only.

---

## D-10 — The editorial API is empty, so the seed cannot be trusted away

**Date:** 2026-07-21
**Status:** Recorded; migration outstanding

`services/journal.ts` documents itself as hydrating admin-published content with
the bundled seed as fallback. In reality
`GET /api/editorial/articles?site=kubus&locale=en` returns `items: []`, while
the site renders four articles from `JOURNAL_SEED`.

So admin is **not** currently the source of truth for kubus.site journal
content, despite the code comment.

**Decision:** the generated journal allowlist is the **union** of API slugs and
seed slugs, not "prefer the API". Trusting the API alone would have generated an
allowlist that 404s all four live articles the moment it shipped. Union can only
over-permit, which degrades to the SPA rendering its own not-found state —
never to a live article disappearing.

**Outstanding:** migrating the four seed articles into admin so the editorial
system genuinely owns them. Until then, any claim that admin is the editorial
source of truth for kubus.site is false.

---

## D-6 — A failing contract check was a test bug, and was fixed as one

**Date:** 2026-07-21
**Status:** Settled

The first contract run reported compact-alias failures. Production was correct:
it returns a **relative** `Location` (`/en/artworks/{id}`), which is valid per
RFC 7231. The assertion wrongly demanded an absolute URL.

**Decision:** fix the assertion to resolve `Location` against the origin.
Explicitly *not* "fix" production to satisfy a bad test. Recorded because the
opposite reflex is the more common failure mode.
