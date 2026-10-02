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
