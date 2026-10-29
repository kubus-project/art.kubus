# Web cold-start network audit — 2026-10-18

Status: browser-console evidence from a Firefox session supplied by the project owner. This is **not** a synthetic Lighthouse result or a HAR with complete timing. No changes have been measured in production.

## Observed requests

| Area | Observed | Interpretation |
| --- | --- | --- |
| Solana Devnet RPC | Six `POST api.devnet.solana.com` | Multiple wallet/account operations may be overlapping; methods are not visible in the console export |
| Profile | Same `GET /api/profiles/:wallet` at least three times, with 304 revalidation | May originate from initialization and warm-up; needs initiator/network tracing |
| Achievements and DAO | Repeated `GET /api/achievements/users/:wallet`, `GET /api/dao/reviews/:wallet` | Profile package or activity loading may overlap warm-up |
| Stats | Two user snapshot queries with different metric lists | Distinct outputs: should consolidate only if compatible |
| Off-chain metadata | `dweb.link` and `ipfs.io` 403/CORS, then Pinata fallback | KUB8 metadata availability, not a reason to disable CORS |
| Auth | `GET /api/profiles/me` 401 | Investigate session state and initiator; don't blindly retry for anonymous users |
| Artworks | Public `GET /api/artworks?page=1&limit=100` and wallet-scoped query | May have different privacy semantics; don't merge blindly |
| Map | OpenFreeMap vector tiles, font PBFs | Expected for the active map; check only actual cache, viewport and tile budget |

### Console notes
- Firefox's `user-select: undefined` CSS parsing warning is real, but not a confirmed fatal listener exception.
- `myLocationRenderMode not available in web` and `setAttributionButtonMargins not available in web` indicate unsupported web-method dispatches. Audit the Dart/web adapter but do not conflate them with network startup cost.
- The forced-layout warning points to `contentscript.js`, probably an extension. Reproduce in a clean profile before blaming application listeners.
- `WEBGL_debug_renderer_info` deprecation comes from CanvasKit/Firefox and should be tracked separately.

## Small reduction implemented in draft PR #312

- Account-shell restore sets `loadWalletData: false`, avoiding another balance/transaction fetch after `WalletProvider.initialize()`.
- Global warm-up stops rerunning `WalletProvider.refreshData()` and profile + stats fetches.
- Artwork warm-up no longer requests a forced refresh; provider/cache and map screen choose whether data is needed.

This does **not** yet defer initial cached-wallet `_loadData()` or eliminate all RPC/IPFS requests.

## Required regression matrix

Use the exact same production or staging build and throttling profile before and after:
- Firefox and Chromium at 390x844 and 1440x900; clean and returning browsers; cold and warm caches.
- Anonymous user with no wallet; signed-out user with stale wallet preferences; valid account-only session; account with linked read-only wallet; local/external signer; expired JWT; public map deep link.
- Capture `/en`, `/sl`, `/map`, a public profile deep link, Wallet, DAO and Creator Studio, plus after sign-in and manual refresh.
- Record: time to Flutter first frame, time to shell, time to map first interaction, total JS/wasm bytes, total requests, Solana JSON-RPC method counts, unnecessary duplicate GETs, backend auth failures, IPFS retries and long tasks.
- Confirm no missing wallet balances when opening Wallet (or an explicit loading/freshness state), preserved re-auth/onboarding, geolocation, map markers, owner-only visibility, and service-worker update behavior.

**Merge gate:** Flutter format/analyze/tests green; no regressions in both browsers; actual before/after HAR and Performance trace demonstrate fewer requests and better user-perceived startup. Do not use a static screenshot or block functionality merely to improve Lighthouse scoring.

## Measured baseline and result (2026-10-18)

Tool: `scripts/qa/web_startup_baseline.mjs`.
- **Builds:** release web, built with `KUBUS_BOOT_TRACE=true` and the flags of `web-artifact.yml`. A local static server serves each one, and service workers are blocked so every cold load is comparable.
- **API:** the production API admits only its own origins, so reads are replayed with the `app.kubus.site` origin. Every non-GET call (analytics, diagnostics, wallet bootstrap) is answered locally and never reaches production.
- **Milestones:** `[BOOT]` marks; the MapLibre canvas; the first map tile; the first frame the main thread answers after the map has content ("first map interaction").
- **Requests:** classified by origin. Solana JSON-RPC methods are read from the POST bodies.
- **Duplicates:** a duplicate means the same method, URL and body again. Map tiles and preflights are excluded.

Matrix: Chromium and Firefox; 390x844 and 1440x900; anonymous and returning-wallet (a remembered address with no key and no session); entry `/map`; 5 runs per cell, cold and then warm, builds interleaved. Baseline: the 0.8.3 tree (`dev` `a56fd943`, with `lib`, `web` and `pubspec.yaml` identical to `master` `2f93f64e`).

### Returning wallet: the dominant startup cost

In 0.8.3 the shell route waits, serially, inside `AppInitializer`:

1. **`wallet.initialize`:** a full wallet sync for a read-only remembered address. That is four Solana RPCs (`getBalance`, `getTokenAccountsByOwner`, `getSignaturesForAddress`, `getSlot`) and a backend profile/stats sync, about 3.6 s.
2. **`profile.initialize` and `loadProfile`:** for a wallet without a profile, `GET /api/profiles/<wallet>` answers 404. `_fetchJson` then retries it with `?source=orbit`, which hangs for about 30 s, so these steps run to their 8 s and 6 s timeouts.

Fixes:
- **Item 1:** this PR. The read-only address is restored locally, and wallet screens load values through `ensureWalletData()`.
- **Item 2:** #318. Orbit is tried only on outages, so a 404 is final.

Cold first map interaction, medians of 5 (base vs this PR with #318):

| Browser | Viewport | Base | Candidate | Change | Solana RPC |
| --- | --- | --- | --- | --- | --- |
| Chromium | 1440 | 21.7 s | 2.4 s | -89% | 5 -> 1 |
| Chromium | 390 | 21.8 s | 4.9 s | -77% | 4 -> 0 |
| Firefox | 1440 | 21.9 s | 2.4 s | -89% | 5 -> 1 |
| Firefox | 390 | 22.2 s | 2.6 s | -88% | 4 -> 0 |

The base runs are bimodal: about 22 s when the Orbit lookup hangs, 3.6-12 s otherwise. The candidate's slowest run was 5.9 s.

Each half was also measured on its own, in an earlier run of the same matrix. This PR before its read-only restore commit still hit the 23 s case in about half the runs. With #318 alone added, no run exceeded 8.3 s, but Chromium kept a steady ~4 s wallet-restore stall. That stall is the one the read-only restore commit removes.

### Anonymous visitor

There is no change, and none was expected: anonymous startup never ran the wallet or profile paths. Cold first map interaction is 1.9-2.2 s, the shell takes 1.1-1.3 s, and about 1 s of it is the JS/CanvasKit download before `main` starts. A 30% cut here needs bundle and renderer work, not request scheduling.

### Still open

- **One Solana RPC on desktop, even for anonymous visitors:** a `getTokenAccountsByOwner` call at 1440 px only, initiator not yet identified.
- **No deferred warm-up at 390 px:** `deferred warm-up start` never fires there for anonymous visitors.
- **Managed (mnemonic) wallets** still sync at startup, because their import includes the backend sign-in. They need their own measurement with a test account.
- **Not measured:** account-only and wallet-linked *signed-in* sessions (they need test credentials), an expired session, deep links, and degraded network.

Medians of 5 runs support median claims only, not tail-latency claims. Raw traces stay outside the repository.
