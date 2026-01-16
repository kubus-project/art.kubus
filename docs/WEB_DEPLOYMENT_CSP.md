# Web deployment: CSP + CanvasKit

## Why this error happens

If the deployed web host sets a strict Content-Security-Policy like:

- `script-src 'self' ...`
- `script-src-elem 'self' ...`

then Flutter Web’s **CanvasKit** renderer will fail when it tries to load:

- `https://www.gstatic.com/flutter-canvaskit/.../canvaskit.js`

This typically shows up as:

- `Loading failed for the module with source .../canvaskit.js`
- `Content-Security-Policy: ... blocked a script (script-src-elem)`

## Recommended fix (keep strict CSP): self-host Flutter web resources

Build your web app with Flutter’s CDN disabled so CanvasKit is served from your own origin:

- `--no-web-resources-cdn`

The helper script also applies a small post-build patch to `build/web/flutter_bootstrap.js` (if needed) to force `useLocalCanvasKit=true` before the loader runs. This prevents a default fallback to the CDN in builds where `useLocalCanvasKit` is omitted from the generated `_flutter.buildConfig`.

A ready-to-use helper script is included:

- `scripts/build_web_release.ps1`

Example:

```powershell
./scripts/build_web_release.ps1 -BaseHref '/' -Renderer canvaskit
```

Note: `flutter_bootstrap.js` may still contain `gstatic.com/flutter-canvaskit` **strings** in unused code paths. The real validation is runtime:

- In the browser Network tab, CanvasKit should be fetched from your own origin, e.g. `https://app.kubus.site/canvaskit/canvaskit.js`.

### If production still loads old/stale assets

Flutter Web uses a service worker by default, which can pin an older bootstrap/config even after you redeploy.

Two practical options:

1) **Disable the service worker during debugging/rollout**

```powershell
./scripts/build_web_release.ps1 -BaseHref '/' -Renderer canvaskit -DisableServiceWorker
```

2) **Force-clear SW + caches in the browser**

This repo’s `web/index.html` includes an opt-in escape hatch:

- Open your deployed app once with: `https://<your-host>/?clear_sw=1`

It will unregister service workers, clear Flutter-related caches, then reload once without the flag.

## Alternative fix (loosen CSP): allow gstatic CDN

If you intentionally want to keep using the CDN, update the CSP on the **web app host** (the origin that serves `flutter_bootstrap.js`, e.g. `https://app.kubus.site`).

At minimum, you need to allow `https://www.gstatic.com` for scripts. Depending on your CSP structure, that may mean adding it to:

- `script-src-elem`
- `script-src`
- (sometimes) `connect-src` (for fetching WASM/resources)

Self-hosting via `--no-web-resources-cdn` is usually the safest option for locked-down deployments.
