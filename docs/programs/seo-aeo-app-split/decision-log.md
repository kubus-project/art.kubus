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

## D-6 — A failing contract check was a test bug, and was fixed as one

**Date:** 2026-07-21
**Status:** Settled

The first contract run reported compact-alias failures. Production was correct:
it returns a **relative** `Location` (`/en/artworks/{id}`), which is valid per
RFC 7231. The assertion wrongly demanded an absolute URL.

**Decision:** fix the assertion to resolve `Location` against the origin.
Explicitly *not* "fix" production to satisfy a bad test. Recorded because the
opposite reflex is the more common failure mode.
