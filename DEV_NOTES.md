# Dev Notes

## Unreleased

### Changes
- Flutter: reduced chat/notification refresh spam by gating refresh on auth context; removed widget-level chat init; gated map location tracking mode on web.
- Backend: media proxy now preserves upstream status codes, applies CORS headers on errors, and normalizes cover URLs via shared helper; added cover URL normalization migration and event cover tests.
- Web: removed MapLibre CSP source map references to stop 404s; added `scripts/build_web_release.ps1` to build with `--no-web-resources-cdn`, optional source maps, and ensured `.htaccess` deployment.

### Tests
- Backend: `npm test -- --runTestsByPath __tests__/eventsService.test.js __tests__/exhibitionsService.test.js`
- Flutter: `flutter analyze`
- Flutter tests: not run (known failing tests remain in `map_style_service_test` and `share_deep_link_navigation_marker_test`).
