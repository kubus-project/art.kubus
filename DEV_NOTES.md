# Dev Notes

## Unreleased

### Changes
- Flutter: reduced chat/notification refresh spam by gating refresh on auth context; removed widget-level chat init; gated map location tracking mode on web.
- Flutter: update chat conversation list metadata (last message/time + ordering) on incoming/outgoing messages so message menus refresh immediately; added chat metadata test.
- Flutter: web MapLibre now uses correct bundled style asset URL and avoids unsupported location render options on web.
- Flutter (Web MapLibre): fixed rare-but-fatal “map disappears after tutorial” by avoiding `BackdropFilter` glass blur in the tutorial overlay on web platform views, and forcing a post-tutorial `forceResizeWebMap()` (see `lib/widgets/tutorial/interactive_tutorial_overlay.dart`, `lib/widgets/glass_components.dart`, `lib/screens/map_screen.dart`, `lib/screens/desktop/desktop_map_screen.dart`, `lib/widgets/art_map_view.dart`).
- Backend: media proxy now preserves upstream status codes, applies CORS headers on errors, and normalizes cover URLs via shared helper; added cover URL normalization migration and event cover tests.
- Web: removed MapLibre CSP source map references to stop 404s; added `scripts/build_web_release.ps1` to build with `--no-web-resources-cdn`, optional source maps, and ensured `.htaccess` deployment. Web renderer selection is controlled in `web/flutter_bootstrap.js` (HTML renderer by default for MapLibre stability).

### Notes
- WebGL: MapLibre runs on WebGL; console warnings can still appear on some GPUs when falling back to WebGL1 or when extensions are missing. No functional regressions observed in this change set.
- Flutter web build: `flutter build web` reports wasm dry-run incompatibilities (plugins using `dart:html` / `dart:js_util`) and upstream lint warnings in `image` package; build still completes.

### Root cause summary (Web MapLibre disappearing after tutorial)
- On web, MapLibre is rendered as a platform view (MapLibre GL JS canvas). Some Flutter web composition paths can cause platform views to become blank when a `BackdropFilter` is layered above them and then removed (tutorial overlay uses `LiquidGlassPanel` → `BackdropFilter`).
- The tutorial dismiss transition also changes stacking/composition; forcing a resize after dismissal makes the WebGL canvas re-sync with its container.

### Tests
- Backend: not run (no backend changes).
- Flutter: `flutter analyze`
- Flutter: `flutter test`
- Flutter web: `flutter build web`
