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
