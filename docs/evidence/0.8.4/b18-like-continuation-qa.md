# B-18 like continuation: authenticated browser QA (2026-10-19)

Scope row B-18 (from the 0.8.2 release notes): "after a reload, a duplicate like request is
sent in about one of three Chromium runs, and in Firefox the like intermittently shows as not
liked."

## Result

**Not reproduced.** 24 guest-to-sign-in-to-confirm runs, 0 duplicate like requests and 0
"not liked" displays, in Chromium and Firefox.

One latent defect was confirmed (P3, not fixed): if the page reloads while the confirmed like's
response is still in flight, the stored intent slot `kubus_pending_action_v1` survives with no
completion marker. No replay happens on that reload, because `PendingActionProvider.restore()`
runs only from the post-auth flow, not on a cold start with a stored session. At the next
sign-in the same "Like this post?" sheet would be offered again. On confirmation the executor
pre-reads the server state and does not POST when the post is already liked. Fixing it means
writing the completion marker before the request, or resolving the slot from server state at
startup. That change is deferred until the duplicate is seen again.

## Sources

| Item | Value |
|---|---|
| Frontend | `integration/084-frontend-candidate` `f20b2129` (dev `9309b1ff` + nine 0.8.4 branches), release web build, rebuilt 2026-10-19 22:50 with the backend pinned (below) |
| Backend | `integration/084-backend-candidate` `b68911c`, `NODE_ENV=development`, port 53101 |
| Database | disposable `kubus-pg-084` / `staging084`, migration 108, synthetic accounts only |
| Browsers | Playwright 1.58.2 Chromium and Firefox, headless, 1440x1000, service workers blocked |
| Like code | `lib/providers/pending_action_provider.dart`, `lib/services/pending_action_executor.dart`: last change before the 0.8.2 note (`98882f7b`, `85cfb2aa`, `204aff70` are ancestors of `363bfb05`), unchanged since |

## Isolation correction

The first `f20b2129` build was **not** isolated. The build script set only
`KUBUS_BACKEND_URL`, but the client reads `BACKEND_BASE_URL` and `BACKEND_STANDBY_BASE_URL`,
which both default to production. As a guest it sent no request to 53101, and production
answered its reads with 403 (local origin). No signed-in run used that build. The rebuilt
artifact has both values pinned to `http://127.0.0.1:53101` in
`.dart_tool/public-build-defines.json` and contains no `bapi.kubus.site` string. The rig also
aborts every request to `api.kubus.site` / `bapi.kubus.site`: 0 were attempted. The repo's own
`KUBUS_REQUIRE_STAGING_BACKEND` switch rejects local origins by design, so a local build has
to pin the defines itself. Script: `G:/kubus-build-084/_staging/build_web_staging_isolated.sh`.

## Procedure

Each run starts with a fresh post by a wallet-signed author and a clean browser context:

1. As a guest, open `/community` and tap **Like** on the post (semantics `switch`, label
   "Like, 0 likes, not liked").
2. In the gate, choose **Already have an account? Sign in**, then **Continue with email**, and
   sign in with a synthetic email-only account.
3. In the continuation sheet ("You're all set / Like this post?"), tap **Like**.
4. Reload after N ms, wait 11.5 s, then read the Like control's label and `aria-checked`, the
   pending-action keys in `localStorage`, every `/posts/:id/like` request, and the server state
   (`/interactions/state` plus the `likes` table).

| Browser | Reload after | Runs | Like POSTs per run | Label after reload | Server rows |
|---|---|---|---|---|---|
| Chromium | 300 / 1500 / 4000 ms | 3 each | 1 (none after reload) | "Like, 1 like, liked", `aria-checked=true` | 1 |
| Firefox | 300 / 1500 / 4000 ms | 3 each | 1 (none after reload) | same | 1 |
| Chromium | 800 ms, response held 2.5 s | 3 | 1 | same | 1 |
| Firefox | 800 ms, response held 2.5 s | 3 | 1 | same | 1 |

Local like round trips took 67-199 ms, so even the 300 ms reloads came after completion. The
held-response rows simulate the production-latency window: the server records the like at once
and the browser gets the response 2.5 s later, so the reload lands inside the race. They are
the rows that leave the stale intent slot.

The accessibility semantics agree in both browsers: the control is a `switch` whose label states
the count and the liked state and whose `aria-checked` tracks it.

## Other observation

`POST /api/community/posts` by an email-only account (no wallet) returns 500:
`community_posts.wallet_address` is NOT NULL. This is not part of B-18 and is not verified
against the app's email sign-up path, which may provision a managed wallet. Follow-up item.

## Rig (outside Git, synthetic credentials in `_private/`)

`G:/kubus-build-084/_staging/`: `b18-seed.cjs` (accounts and post), `b18-lib.mjs` (browser
context, production-host block, network capture, optional `B18_LIKE_DELAY_MS`), `b18-run.mjs`
(the matrix), `b18-step.mjs` (step explorer). Results: `b18-out/runs-*.json` and screenshots.

```bash
cd G:/kubus-build-084/_staging
node b18-run.mjs chromium 3 300,1500,4000
node b18-run.mjs firefox 3 300,1500,4000
B18_LIKE_DELAY_MS=2500 node b18-run.mjs firefox 3 800
```
