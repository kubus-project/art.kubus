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
| Map | CARTO vector tiles, font PBFs | Expected for the active map; check only actual cache, viewport and tile budget |

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
