# Final-head operational QA summary

Date: 2026-10-23

## Exact candidates and qualification

- App source: 6a885b2d9eca78534d6dd0a5d97cf29c07c6a312.
- Backend source/SSR renderer: 88d792ffccc4ccaff96f82f230d4b9e14b7e00a1.
- Tested web build: G:\kubus-build-084\_staging\final085-resume-20261023\app-fallback-cache-guards\build\local-finalhead-6a885b2d.
- This is a local Flutter release-mode compile with development metadata and loopback endpoints, not the uploaded CI artifact. Flutter 3.44.2, Dart 3.12.2, version 0.8.5, build 1432513261.
- Artifact manifest SHA-256: 3b7637538827c84f487e10a58953a437574d472490e7a398fce89e38f5c7cc31; main.dart.js SHA-256: 2d234319371523743f1230a78f2b1a1e5cb86cdd0a1fe8982c915f3780710238.
- main.dart.js served from the independent static preview at 127.0.0.1:4288 matched that SHA and the static preview accepted GET/HEAD only. The compiled API origin is 127.0.0.1:4285; all test contexts intercepted it and used the synthetic GET fixture on 127.0.0.1:4176. Browser address-bar routes stayed on 127.0.0.1:4178; SSR entity responses came from renderer 127.0.0.1:4175.
- App exact-head CI run 39937612488 remained in_progress when checked. Backend exact-head CI run 39938446580 completed successfully. CI states do not change the local-build qualification.
- No product source was edited. No Android emulator was started for this final-head pass.

## Results

- PASS — Flutter takeover family matrix, 64/64. Chromium 145.0.7632.6 and Firefox 146.0.1; desktop/mobile; EN/SL; artwork, collectible, profile, event, exhibition, post, collection, and marker routes. Every direct load and refresh returned 200, preserved the complete browser URL/query/hash, reached ready takeover, retained the correct route locale, hid semantic SSR only after takeover, and left Flutter active.
- PASS — No-JavaScript SSR family matrix, 64/64. Same browser/viewport/locale/family dimensions; direct load and refresh; JavaScript disabled. The first frame retained exact URL/query/hash, non-empty title/description/canonical/OG metadata, visible main/H1/public document, and pending status hidden from assistive technology. Route-specific status locale/loading/failure/refresh text matched EN or SL. The synthetic fixture text is English, so html lang and OG locale follow its English content even on an untranslated /sl/ route; status locale follows the route.
- PASS — map handoff/history, 4/4. Chromium/Firefox desktop/mobile. Show on map reached /main, rendered one MapLibre canvas, and Back restored the exact artwork route including ?history=085#cover; Forward restored /main. The map view title was art.kubus.
- PASS — MapLibre camera direct load and refresh. Chromium 145.0.7632.6; query/hash remained unchanged. Actual Map.getCenter() reported latitude 46.05, longitude 14.509999999999991; getZoom() reported 12 on both loads; map reported loaded and there were zero page errors.
- PASS — SSR-L1 takeover visibility/accessibility/layout, five scoped cases. Chromium 145.0.7632.6; 390px mobile, desktop, 320px Slovenian at 150% text, dark mode, reduced motion. Pending, 500ms loading, 8s slow, and controlled bootstrap-failure states retained the SSR title/H1/description. Refresh was hidden before failure and reloaded only from the visible failure state. Status role/live attributes and contrast passed. Status-induced CLS entries were zero; heading/main positions stayed fixed; no overlap or clipping was found.
- Network boundary. The public-family Flutter matrix attempted 92 POSTs to view-count and presence-batch APIs; every request was intercepted before network egress and answered with synthetic 405. No API writes reached a service. Map and SSR-L1 runs had zero non-GET API calls. Non-local origins were blocked in all browser runs; the map camera run allowed read-only CARTO basemap GETs only.
- Separate auth finding from app-agent flow. After the authenticated Like this artwork? prompt, selecting Not now rendered signed-in Home while the address bar stayed on the artwork URL. This is recorded as a route/screen mismatch and is outside the public history test above.

## Evidence files

- artifact-identity.json
- final-head-6a885b2d-64-matrix.json
- art-map-history-qa.json and art-map-history-*.png
- final-head-map-camera.json, final-head-map-camera-direct.png, final-head-map-camera-refresh.png
- final-head-ssr-l1-acceptance.json and ssr-l1-cssfix-*.png
- final-head-ssr-nojs-64.json and final-head-nojs-*.png
- public-api-preview.requests.jsonl, exact-head-app-preview.requests.jsonl, and preview stdout/stderr logs
- final-head-map-camera-initial-hook-attempt.json preserves the first instrumentation-hook miss; the corrected hook then passed the numeric camera assertions.

## Preview cleanup/handoff

- Stopped by this QA owner after verification: renderer 4175 (PID 14844) and app/SSR proxy 4178 (PID 66788).
- Synthetic read-only API fixture 4176 (PID 82640) was retained for the app-agent authenticated continuation, then stopped after they confirmed the flow was complete.
- App-agent-owned static preview 4288 was stopped by the app agent; auth port 4285 had no listener.
- All task preview ports 4175, 4176, 4178, 4285, and 4288 were clear at final verification. ADB reported no attached devices; the Android emulator remained off. See cleanup-state.json.
