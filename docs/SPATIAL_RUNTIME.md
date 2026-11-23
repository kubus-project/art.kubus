# Spatial runtime integration

The Flutter application treats spatial content as a versioned `kubus.spatial/1`
record. A record can describe Gaussian-splat or existing GLB/GLTF content and can
contain preview, mobile, and archive variants. Multiple records can belong to the
same artwork or marker, so the UI can present spatial history over time.

## Capture and privacy

Android capture uses the existing native ARCore session to return an RGB frame,
camera pose, intrinsics, timestamp, and depth/confidence only when the device and
ARCore session expose them. iOS uses the ARKit adapter for tracked placement and
capture metadata. Capability labels never claim depth when the platform did not
return it.

Raw frames are transferred only to a paired Kubus Node with a scoped local
credential. They are not sent to the public backend or public gateways. The
capture remains local unless the user explicitly requests publication of selected
processed variants. The app stores the local credential in secure storage and
never includes it in content URLs, analytics, or normal logs.

## Capture association

A capture is always filed under exactly one artwork, and optionally one marker.
The pair of ids is the durable authority; the record also stores display
snapshots of the artwork title, artist and marker label, used only so an offline
device can render a readable label. Snapshots never resolve, match, or relink a
record.

There is no fallback for a missing target. A capture cannot begin until the user
has named an artwork explicitly — by launching capture from an artwork or a
marker, or by choosing one in the picker. Once a capture has begun it owns its
target for its whole life: reordering the artwork provider, uploading a new
artwork, changing a selection elsewhere, or resuming after a restart cannot move
it onto different work.

Surfaces resolve each record through that record's own `artworkId` and
`markerId`. A reference that no longer resolves is reported as unavailable and
keeps its stored id, because silently relinking a capture destroys the only
evidence of what it was a scan of. Repointing a record is an explicit user
action, and is refused outright for a published record.

## Capture lifecycle

`SpatialLibraryRecord` is at schema version 3. Beyond the source and result, it
carries a user-chosen display name and note, the association snapshots, revision
lineage, a stale-result flag, and a persisted network compute request. Every
field added since v1 is optional with a safe default, so older records upgrade
in place and no capture is discarded.

- **Continue capture** reopens the record's own raw source, rebuilds coverage
  from the poses already on disk, and folds new samples back into the same
  record. Abandoning a continuation never deletes the source.
- **Stale results.** Samples added after a processed result leave that result on
  disk but mark it stale. A stale result is never presented as current and
  cannot be published; the capture has to be processed again.
- **Revisions.** A published archive is immutable. Adding to it branches a new
  private draft seeded with a copy of the parent's raw source, recording the
  parent record and the public version it came from. The parent keeps its
  archive, its result and its capture.

## Processing requests

Processing is chosen between two options that differ in kind, not degree: the
user's own paired Node, or a third party's GPU on the kubus network. Reaching
the user's own Node over remote HTTPS rather than the LAN changes the route, not
the trust, so it stays one option with a connection note. Only the network
option asks for privacy consent.

A network request is written to disk before anything is sent, and is offered
even when provider discovery currently returns nobody: discovery describes this
instant, not the capability. The persisted request advances through
`networkRequested` → `searchingProvider` → `providerOffered` →
`providerAccepted` → `queued` → `processing` → `verifying` → `downloading` →
`complete`, and can end in `failed`, `expired` or `cancelled`. Open requests are
resumed at launch, so closing the app never loses one. Provider details —
identity, tier, queue depth, estimates — are shown only when the protocol
reports them; nothing is estimated locally.

## Resolution order

On native platforms, `ipfs://` content is attempted through the paired node first,
then the configured IPFS/Kubus gateways, and finally the legacy backend fallback.
The local WebView viewer receives bytes through a loopback proxy so the credential
stays in an authorization header. Flutter Web deliberately skips insecure LAN
HTTP endpoints to avoid mixed-content and browser-origin regressions.

## Rendering boundary

`SpatialViewer` is renderer-neutral. Its bundled archive viewer currently uses
Spark 2.4.0 (MIT) and Three.js 0.185.1 for orbit/zoom inspection, quality selection,
loading, poster, and failure states. This WebView is an archive viewer; it is not
placed transparently over the camera and is not presented as tracked AR.

Camera-aligned placement remains owned by `SpatialTrackingAdapter` and the native
ARCore/ARKit path. A future native splat renderer can implement that boundary
without changing domain records or publication APIs.

## Platform verification

Android is exercised by the repository Android build. The iOS ARKit dependency is
enabled with its current adapter, but an iOS native build still requires macOS and
Xcode and cannot be verified from the Windows development environment.

## Flutter web viewer

On Flutter web `SpatialViewer` resolves to `spatial_viewer_web.dart`: the same
bundled viewer page runs in a same-origin iframe (`HtmlElementView`). The widget
chooses and downloads the bytes and relays messages (`viewer-ready`, `ready`, `escape`,
`error:*` from the page; `load` / `reset` / `activate` / `deactivate` commands to
it, same-origin only). Each load attempt puts its number in the page URL
(`index.html?a=<n>`); the page echoes it in every message and the widget drops any
message that does not carry the current attempt, so a page that is being replaced
(a timed-out tier, a retry) cannot answer for the attempt after it. Attempt numbers
never restart within one viewer: a refreshed record replaces the session but
continues the count, so a message in flight from the old page cannot match. A final
failure empties the iframe (`about:blank`), so a stalled download stops. All tier, timeout
and consent decisions live in `SpatialWebLoadSession` and `SpatialWebDelivery`
(pure Dart, tested in the VM suite).

- Tier: `spatial_mobile`, then `spatial_preview`; when the first cannot be loaded
  (a format Spark rejects, a failed route) the next one is tried. The archive tier
  never opens by default and never falls back; the visitor asks for it, sees its
  size on the button, and confirms above 50 MiB or when the record states no size
  (the archive is the large tier by definition). `rad` is not offered (paged RAD
  needs sibling chunk URLs the single route cannot give), and `sog` is not offered
  on the web until a SOG fixture has been loaded through the browser smoke (Spark
  opens it as `pcsogszip`, which the byte route gives no extension to detect). The
  native viewer (`spatial_viewer_native.dart`) still lists `sog`: that is intended,
  it loads through the node proxy, not the single public byte route, so the
  two paths differ on purpose until the web path has a proven SOG fixture. A record whose only
  viewable variant is not offered (RAD or SOG only) shows "currently unavailable"
  with no retry button, because there is nothing a retry could start.
- Timeouts: 120 s for the optimised and preview tiers, 10 minutes for the archive,
  so a large archive is not declared dead while it is still downloading.
- Bytes: the widget (not the page) downloads them with `fetch` (`credentials:
  omit`, `referrerPolicy: no-referrer`, an `AbortController`), turns the answer
  into a Blob and hands the page its object URL (`blob:`); the object URL is
  revoked when the attempt ends or the page reports `ready`, and an attempt that
  is replaced, times out, fails without a fallback tier or is disposed aborts its
  download and revokes any object URL it had not yet handed over. The route is
  `GET {backend}/api/upload/file/<cid>`, anonymous and registry-authorised:
  only CIDs of a currently public publication resolve (withdrawn or unregistered
  content answers 404, a failing withdrawal lookup answers 503; whole body, no
  Range). That route is the publication gate and the only route the web viewer
  uses: there is no public-gateway fallback, because a gateway has no withdrawal
  gate and would keep serving pinned bytes of withdrawn content (and learn the
  visitor's address). A CID must be CID-shaped (`[A-Za-z0-9_-]`, 4 to 128
  characters) before it becomes a URL. Never a LAN node, never plain http (except a
  loopback backend in a local build; that works end to end now, because the host
  page downloads it and the viewer page only ever sees a `blob:` URL). The legacy `/uploads/<cid>` path is a
  different store and does not serve published spatial variants.
- Orientation: the published manifest (`canonicalManifestCid`, same route, read
  with the same anonymous `fetch` options as the bytes, through
  `AnonymousFetchClient`) is read
  best effort and its `transform` is applied; without a readable transform the
  piece opens untransformed. Contract, to be mirrored by the backend manifest
  contract and the Node docs when the backend accepts `matrix`:
  - `matrix` is 16 finite numbers in COLUMN-MAJOR order (three.js
    `Matrix4.fromArray`, the order the kubus-node GUI viewer reads); `matrixOrder`
    is absent or `column-major`, anything else is not applied. A matrix is a plain
    placement or it is refused whole (the piece then opens untransformed): bottom
    row (0, 0, 0, 1), translation within 1e6, per-axis scale within 1e-6 to 1e4,
    mutually perpendicular axes (no shear, 1e-3 tolerance) and a right-handed
    basis (no mirror). The app checks this before handing the transform over
    (`SpatialWebDelivery.transformFromManifest`) and the viewer page checks it
    again (`assets/spatial_viewer/src/manifest_transform.mjs`). Both are tested
    against one shared vector file, `test/fixtures/spatial/manifest_transform_vectors.json`
    (a Dart test and a node test read it), so a change to one rule set that is not
    made in the other fails CI. The Node's pose helper (`poseConversion.ts`)
    is ROW-MAJOR: a producer that reuses it must transpose, or pieces stand on
    their side.
  - Otherwise `position` (3 numbers), `rotation` (4 numbers = quaternion xyzw, or
    3 numbers = Euler angles in radians, order XYZ) and `scale` (number or 3
    numbers, each within 1e-6 to 1e4); `position` components are within 1e6.
    Anything outside those bounds is dropped, because a published 1e30 scale only
    renders an empty or exploded view.
  - Publication: the backend manifest contract accepts only `position`, `rotation`
    and `scale` in `transform` (it rejects `matrix` as an unknown key). The app's
    `sanitizePublicationManifest` therefore splits an accepted Node `matrix` into
    those three (`SpatialWebDelivery.decomposePlacementMatrix`: position, rotation
    as a quaternion x y z w, scale as a 3-vector; the viewer composes the same
    translation * rotation * scale), so a piece the Node placed opens upright after
    publication. A matrix the viewer would refuse is dropped whole and is never mixed
    with the other fields. The backend can then take `matrix` later without an
    app change being needed first.
- Isolation: the iframe is `sandbox="allow-scripts allow-same-origin"`, which is
  not a security boundary: it stops popups, forms and top navigation, but a
  same-origin frame can remove its own attribute and can reach the app origin's
  storage.
  What bounds the risk: the page runs only this app's own bundle; its CSP is
  `default-src 'none'` with scripts from `'self'` and `'wasm-unsafe-eval'` only (no
  inline script, no eval); splat bytes are parsed by Spark's WASM, never executed;
  the host hands it no token, header or cookie (URLs, file type, transform and an
  accessible label only); the frame has `referrerpolicy="no-referrer"` and
  `allow=""`; messages are accepted only from the parent window of the same
  origin and URLs only if they are `blob:` URLs of that origin. `window.loadSpatial(url)`
  is the native WebView contract and deliberately skips the URL allow-list; it is
  reachable only by script already inside the page.
  Network: the viewer page cannot reach the network. Its CSP is `connect-src
  http://127.0.0.1:* blob:` (the loopback entry is the native WebView's content
  proxy; on the web the HTML header in `web/.htaccess` intersects it away): no
  `https:`, no `'self'`. The web host downloads the bytes itself and hands over a
  `blob:` URL of its own origin, which is the only kind of URL the page accepts
  (an https, http, same-origin route, `file:` or foreign `blob:` URL is refused
  with `error:url-not-allowed`; the browser smoke asserts that and that a `fetch`
  from inside the page is blocked). So a script that escaped the page's script
  policy would share the web app's storage but would have no channel to send it
  to. The backend origin is configured per build, so instead of writing it into
  the page the host does the downloading. The frame is still same-origin; a separate cookieless
  origin would remove that too and is not done. Before the first deploy,
  verify that the nginx front adds no `X-Frame-Options` or `frame-ancestors` to
  `/assets/assets/spatial_viewer/index.html` (outside this repo; the smokes apply
  only the `web/.htaccess` policy).
- Render loop: it runs only while the canvas is on screen, the tab is visible and
  a piece is loaded or loading.
- Gestures and page scroll: an iframe is its own document, so wheel and touch
  events that start on it never reach Flutter and cannot scroll the page behind
  it. Inside a page that scrolls, the widget therefore keeps the iframe inert
  (`pointer-events: none`) under a "Tap to interact" overlay: wheel and swipes
  there scroll the page. A tap activates the viewer (it takes every gesture, the
  canvas is focused, and a Done button appears); Escape in the viewer, a tap
  outside it or Done make it inert again. Escape pressed while the iframe has focus
  never reaches Flutter's key handling: the viewer page relays it as `escape`, and the
  widget hands it to its host through `SpatialViewer.onEscape`. Only the fullscreen
  dialog passes one (it closes itself, and only while it is the current route, so the
  archive-consent prompt above it is not dismissed); the inline viewer passes none, so
  Escape there closes nothing (smoke step). Where no vertical scroller encloses it
  (the fullscreen dialog, the native WebView) it is interactive at once. The page
  uses `touch-action: none` (a `pan-y` page hands vertical drags to the browser
  and leaves touch users without pitch); a wheel zooms only once the canvas has
  focus (or on a pinch). The browser smokes assert all of this: inert wheel and
  touch scroll the page, a tap activates, Escape and a tap outside release, and a
  vertical touch drag pitches the camera.
- CSP: the viewer page allows `'wasm-unsafe-eval'` (Spark's WASM); the SEO takeover
  policy in `web/seo-proxy.php` allows `frame-src 'self'` so the iframe is not blocked
  on public pages.
- Inline section: the artwork detail screens (desktop and mobile) show the viewer
  inline when the public spatial history is non-empty, created when it scrolls into
  view (`SpatialLazyReveal`); "View in 3D" opens the fullscreen dialog. Only one
  WebGL context runs at a time, so the inline viewer is replaced by a placeholder
  while the dialog is open and reloads its variant (tens of MB) when the dialog is
  closed: a visible cost on mobile data.
- Known limits: the download shows a busy indicator only (up to 120 s, 10 minutes
  for the archive), no progress. The "Tap to interact" overlay carries button
  semantics for screen readers but is not a focusable control, so a keyboard-only
  visitor reaches the viewer only through the canvas inside the frame. The Node
  rounds the matrix to 6 decimals, so the 1e-3 shear tolerance holds for a uniform
  scale above about 1e-3 (a scene extent below about 2000 splat units); a larger
  scene is refused whole and opens untransformed.
- Backend cross-lane: the byte route sends the whole body (up to 512 MiB per
  variant) from memory on an anonymous route. The app now shows the size and asks
  first, but a route-level rate limit and concurrency cap belong to the backend and
  must be confirmed before this reaches the public.
- Browser proof: `scripts/qa/spatial_viewer_smoke.mjs` (viewer page) and
  `scripts/qa/spatial_viewer_flutter_smoke.mjs` (the built Flutter widget), both on
  the synthetic `test/fixtures/spatial/sample_flower.splat`. Both run in the PR
  workflow (the Chrome job builds the harness with `flutter build web --release -t
  tool/qa/spatial_viewer_web_harness_main.dart --output build/spatial-harness`).
  `test/spatial_viewer_asset_contract.test.js` (licence pin, notices, CSP, bundle
  hygiene) runs in the PR workflow's Node step. Locally the page smoke serves
  `build/web` when it exists; set `WEB_ROOT` to a missing directory to test the
  checked-in `assets/spatial_viewer` instead. The Flutter smoke is not fully hermetic:
  it needs internet access on the runner, because CanvasKit and the fonts still come
  from the real network (and can flake on a CDN hiccup). Only the Google Identity
  script that `google_sign_in_web` injects at startup is stubbed
  (the real script can call the plugin's `onGoogleLibraryLoad` twice, which
  surfaces as an uncaught `StateError: Future already completed` from the
  plugin's `loadWebSdk`, not from the viewer; it was the intermittent
  `pageerror` of the first smoke runs). It exercises the harness section
  (`ArtworkSpatialArchiveSection`), not the two detail screens themselves; the
  screens only mount that section.
