# Web QA Harness

Maintained Playwright/browser smoke checks live here. Generated screenshots,
JSON diagnostics, and proxy logs are written under:

```text
output/playwright/artifacts/
```

Install dependencies once:

```powershell
npm --prefix scripts/qa ci
```

Run the default web smoke:

```powershell
npm run qa:web
```

For localized public HTML, start the backend repository's `npm run seo:preview`
server after building Flutter web, then run:

```powershell
npm run qa:seo
```

This checks Chromium and Firefox, desktop and mobile public pages, social
images, keyboard focus, the custom 404, and the explicit Flutter handoff.
Evidence is written to `output/playwright/artifacts/seo-public-pages/`.

By default, the smoke starts `scripts/qa/dev_spa_proxy.mjs`, serves
`build/web`, proxies `/api/*` to `https://api.kubus.site`, and captures desktop
and mobile home screenshots. Build the Flutter web bundle first if
`build/web/index.html` is missing or stale.

Useful overrides:

```powershell
$env:APP_URL='http://127.0.0.1:8080'
$env:QA_ARTIFACT_DIR='output/playwright/artifacts/my-task'
$env:QA_API_ORIGIN='http://127.0.0.1:3000'
npm run qa:web
```

Older ad hoc scripts remain under `output/playwright/` for reference, but new
or maintained browser QA should be added here and exposed through root
`package.json` scripts.

## Local staging (authenticated QA against a disposable backend)

Signed-in browser QA runs only against a local backend with synthetic data. The rules
are code in `scripts/qa/staging/` and are tested by `isolation.test.mjs` (CI guardrails
job):

- The web client reads `BACKEND_BASE_URL` and fails over to `BACKEND_STANDBY_BASE_URL`;
  both default to production. `KUBUS_BACKEND_URL` alone does not move it. A staging build
  pins all three:

  ```powershell
  $env:KUBUS_STAGING_API_ORIGIN='http://127.0.0.1:53101'
  # plus the three public KUBUS_GOOGLE_*_CLIENT_ID values the public build requires
  node scripts/qa/staging/build_web.mjs
  ```

  It refuses to run without a loopback origin and fails if `build/web/main.dart.js`
  names `api.kubus.site` or `bapi.kubus.site`.
- `launch_backend.mjs --backend <checkout> --private <dir outside the repo> --database-url
  postgresql://...@127.0.0.1:<port>/<db>` starts the backend with `LISTEN_HOST=127.0.0.1`
  (art.kubus-backend #100). The child environment is built from an allowlist. The launcher
  refuses a backend tree with a `.env` file and a non-loopback database, and stops the
  backend if its port answers on any external address.
- `preflight.mjs --api <origin> --web <origin> --web-root build/web` must pass before a
  browser opens. It checks the pinned defines, the artifact scan, `/health`, and that both
  ports are reachable on loopback only.
- Every staging browser context calls `installStagingGuard(context, { apiOrigin, webOrigin })`
  from `playwright_guard.mjs`. The guard aborts any request to a production API host and
  any write outside the two staging origins. A run fails if its blocked list is not empty.
  Solana JSON-RPC uses POST even for reads, so wallet balance reads do not work under the
  guard: no transaction can leave a staging run.
- The defines file may carry only known public keys (`STAGING_PUBLIC_DEFINE_KEYS`); an
  unknown key fails the build and the preflight.

The admin dev server already binds `127.0.0.1:5174` (`vite.config.ts` in admin.kubus).

## Guest-first entry QA

`guest_first_entry_browser_qa.mjs` drives a fresh-storage visitor through the
guest-first contract in Chromium and Firefox (fresh `/`, `/main`, `/map`; a
public artwork entity with Back/Forward/refresh; Save opening the contextual
activation sheet, dismiss, retry, account step; explicit `/register`,
`/sign-in`, and a bare `/onboarding`). Flutter draws to a canvas, so it asserts
on the accessibility semantics tree. Public read GETs pass through to the API;
analytics and every write are answered locally.

```powershell
flutter build web --release
$env:QA_LABEL='after'; node scripts/qa/guest_first_entry_browser_qa.mjs
```

Env: `QA_BROWSERS`, `QA_VIEWPORTS`, `QA_SCHEMES`, `QA_LOCALES`, `QA_SCENARIOS`,
`QA_ARTWORK_ID`. `QA_LOCALES` only varies the browser locale; it does not switch
the app language. Known pre-existing issues are reported as `~ known:` and do not
fail the run.

## Map continuity probe

`map_continuity_probe.mjs` drives the real map across the cluster -> marker
threshold (cold entry, slow and fast zoom, zoom out, pan, camera jitter around
z12, selection crossing the threshold with the map's zoom buttons, card open)
and records what the renderer did: every `kubus_markers` source write (features,
clusters, ids added/removed, animation-only writes, writes < 60 ms apart), cover
images registered, media requests with duplicates and failures, requestAnimationFrame
intervals, long tasks and the app's own cover-pipeline timings. Public read GETs
reach the API; writes and analytics are answered locally.

```powershell
flutter build web --release
$env:QA_WEB_ROOT='build/web'; $env:QA_LABEL='after'; $env:QA_WARM='1'
node scripts/qa/map_continuity_probe.mjs
```

Env: `QA_VIEWPORT`, `QA_SCHEME`, `QA_GL` (`hardware`|`swiftshader`), `QA_BROWSER`
(`chromium`|`firefox`), `QA_CENTER`, `QA_WARM`. Output goes to
`output/playwright/artifacts/map-continuity/<label>/report.json`. Frame timings
depend on the machine and on what else runs on it: compare two builds in
alternating runs in one session and read the write/request counts as the
architecture-level result.
