# art.kubus 0.8.3: stabilization

Status: **the five packages are merged into `dev` (#303); the version is bumped to 0.8.3
(build `261016.01`, 2026-10-16) in the release-preparation commit (#304); the P0 artwork
Save correction is merged (#305, merge commit `090ae390`) and the development deployment
of `090ae390` succeeded. The release-review corrections (#308) and the release-record
correction (#307) are merged; `dev` is `74923da1`. Owner acceptance on the authenticated
development site is still owed. Not tagged, not released; the promotion pull request is
#306 (`dev` to `master`).**
Maturity stays 0.8.x-alpha. The version bump is its own commit (see "Version bump"),
not part of the feature changes.

0.8.3 is a corrective release on top of 0.8.2 (`v0.8.2`, `v0.8.2.1`; production is
`master` `4181b4d2`). It corrects map cluster motion and marker loading, the globe
and the user-location marker, owner profile routing and artwork authorship,
Community video geometry and the Art feed, and the family wordmark. It adds no new
product surface and needs no backend or admin change.

Statuses below are kept separate: **implemented**, **tested**, **browser validated**,
**exact-head CI**, **integration validated**, **merged**, **staged**, **owner
accepted** and **released** are never inferred from one another.

## Scope

| PR | Package | Head | Exact-head CI |
| --- | --- | --- | --- |
| [#298](https://github.com/kubus-project/art.kubus/pull/298) | Map cluster motion, marker source work, cover pacing, search drops the far-zoom overview | `55e2a528` (code `c3a93c7a`) | see "Candidate" |
| [#300](https://github.com/kubus-project/art.kubus/pull/300) | Globe ground and sunlight, shared user location, heading | `18a52e55` | passed |
| [#299](https://github.com/kubus-project/art.kubus/pull/299) | Owner profile routing, identity actions, recorded-artist links | `500d3185` | passed |
| [#301](https://github.com/kubus-project/art.kubus/pull/301) | Community video geometry, Art-feed videos, hashtag contrast | `cdee7298` | passed |
| [#291](https://github.com/kubus-project/art.kubus/pull/291) | Family wordmark typography | `2199de0e` | passed |

Integration: the five packages reach `dev` through **one integration pull request,
[#303](https://github.com/kubus-project/art.kubus/pull/303)**, built from `dev`
`332e13a9` with `git merge --no-ff` of the exact heads above in this order, with no
textual conflicts: #298, #300, #299, #301, #291. The `dev` ruleset requires branches to
be up to date, so five sequential merges would each have needed a refreshed head and a
new required run, and five development deployments. #303 is merged with a **merge
commit** so all five original heads stay reachable from `dev` and the five pull requests
are recorded as merged. The merged SHAs are recorded in "Merged state" below once it lands.

Three review findings were still open on #300, #299 and #301. All three were confirmed
against the code and fixed on the integration branch (commit `affd4696`), each with a
regression test:

| Finding | Package | Fix |
| --- | --- | --- |
| The location pulse and the heading cone kept their creation-time colour after an accent change without a style reload | #300 | `MapLayersManager.refreshLocationAccent` re-colours the pulse paint and registers a colour-keyed heading image; both map screens call it from the theme resync |
| A hyphenated UUID matched the generic long-string branch of the wallet heuristic, so its case was kept and an upper-case UUID of the signed-in account opened a visitor profile | #299 | A UUID is recognised first and compared case-insensitively; wallet addresses stay case-sensitive |
| A static (non-tappable) token chip used `Ink` with no `Material`, which paints behind the post card's opaque surface and loses its fill and border | #301 | The static chip is a decorated `Container`; the tappable chip is unchanged |

### Merged state

| Item | Value |
| --- | --- |
| Integration pull request | [#303](https://github.com/kubus-project/art.kubus/pull/303), merged with a merge commit on 2026-10-16 |
| `dev` after the merge | `d0862d9127e546d5ff76937d6dc3776405de7a3a` |
| Integration branch head | `36d0e844b90dc2cb49e43c3ae4bd071b64794864` (required run: every job green, 0 unresolved threads) |
| #298, #300, #299, #301, #291 | recorded as merged by GitHub at the same instant (their heads are ancestors of `dev`) |
| `master` | `4181b4d2`, unchanged; `origin/master...origin/dev` reads 0 on the master side |

The integration branch carries two commits on top of the five merges, both from
review: `affd4696` (the three findings above) and `36d0e844` (a globe-ground style
with no `paint` no longer throws; the product name is `kubus Node`, capital N, in both
locales and the Node model fallback). One review finding was declined: `video.path()`
in the performance script does not hang with the pinned Playwright 1.61.1. The full
suite ran in the required check at `36d0e844`, not only in the candidate.

### Release-review corrections (#307, #308)

Three review findings on the release pull request #306 were confirmed and corrected
on `dev` before the release; #307 corrected this record and #308 carries the code.

| Finding | Correction |
| --- | --- |
| The optional globe-atmosphere module was awaited inside `kubusMapLibreRuntimeReady`, so a failed request left the whole web map on its loading backdrop | The import is isolated in a `try`; a failure is recorded on `kubusGlobeAtmosphereError` and the map opens without the night shade. `scripts/qa/maplibre_runtime_atmosphere.test.mjs` runs the real script in a `vm` and fails on the previous code. |
| Mixed-media carousels resized as the user swiped, against the 4:3 stage contract | Only a single-video post adapts its stage; every multi-item carousel keeps one 4:3 stage. `community_video_stage_test.dart` and `community_video_audio_geometry_test.dart` assert it. |
| Running Node prose was wrapped in `KubusFamilyBrandText`, making the embedded wordmark bold italic | The Node entry subtitle, both pairing bodies and the operator hero body are plain `Text`. |

| Item | Value |
| --- | --- |
| #307 (release record) | squash merge `85c5699a` |
| #308 (corrections) | squash merge `74923da1`; required checks green at its validated head |
| `dev` after both | `74923da19503c46d0fc8b2491e2e8a17bda56e84` |
| Development deployment | `deploy-development` run 39064707394 built and promoted `74923da1` and verified the artifact checksum manifest including `kubus-web-revision.txt`. `dev.kubus.site` is behind Basic Auth, so the served revision could not be read independently without the staging credentials. |

### P0 correction: artwork Save blanked the app (release blocker)

Reported on `dev.kubus.site`: editing an existing artwork on desktop and pressing Save
left a blank screen. It is a 0.8.3 blocker and is corrected on
`fix/083-artwork-save-black-screen` and merged into `dev` as #305 (merge commit
`090ae390`). It is **implemented, tested, browser validated on a local compatible
backend, exact-head CI green (run 39026179071), merged and deployed to development**
(`deploy-development` run 39028288595 smoke-tested revision `090ae390`). It is **not
owner accepted**: the local browser runs used a disposable fixture account, not the
authenticated development site.

| Item | Value |
| --- | --- |
| Starting point | `dev` `ba2f6760`, `master` `4181b4d2` (both re-fetched first) |
| Root cause | The desktop editor is pushed into the shell's own screen stack (`DesktopShellScope.pushScreen`), which is not a Navigator route. `_save()` closed it with `Navigator.of(context).pop()`, which ignores the shell's `PopScope` and removes the route that hosts the whole shell. |
| Reproduced | Unfixed `ba2f6760` built for web and driven in Chromium against the real local 0.8.2 backend: PUT 200, the value is persisted, no "Saved" toast, blank page (`docs/evidence/0.8.3/artwork-save/before-dev-ba2f6760-desktop-blank-after-save.png`). |
| Second defect | `ArtworkProvider.updateArtwork` returned null for a failed write, and the screen then accepted `refreshArtwork()` (the unchanged record) as proof of a save, so a failed write could report "Saved" and leave. A bare `{"success": true}` was also parsed into an artwork with an empty id. |

What changed (no backend or schema change; compatible with the 0.8.2 backend):

- The editor closes through the navigation that opened it: the desktop workspace only
  through `DesktopShellScope.popScreen` (never falling back to `Navigator.pop` while a
  shell is present), a standalone route through its Navigator but never the last route,
  and a `bodyOnly` editor closes nothing.
- `ArtworkProvider.saveArtwork` returns an explicit result: **confirmed** (artwork
  returned), **acknowledged** (HTTP 200 without a usable artwork and a failed read-back;
  the write happened, the cache is patched with the edits and the portfolio refresh
  fetches the record), **failed** (typed: network, timeout, 401, 403, 409, 429, 400/404/422,
  5xx) or **already in flight**. A failed write never reads the old record back.
  `updateArtwork` remains as a thin wrapper.
- `BackendApiService.updateArtwork` throws `BackendApiRequestException` with the HTTP
  status, and only trusts a payload that carries an artwork id.
- On failure the editor stays open with every typed value and shows a contextual message
  from existing strings (no new l10n). Saving with nothing changed sends nothing. The
  portfolio refresh and success toast do not depend on the editor still being mounted.

Tests: `test/screens/art/artwork_edit_save_navigation_test.dart` (real Save button on the
workspace, detail-to-editor stack, acknowledged payload, 400/401/403/409/429/500, timeout and
offline, stale read after a failed write, no changes, double tap, leaving mid-request,
cover and AR upload failures, standalone route, never popping the app root, shell scope
without a stack) and `test/services/backend_api_update_artwork_test.dart` (HTTP to typed
result). The first test was red on `ba2f6760`. Full suite on the first fix commit: 5177
passed, 27 skipped, 0 failed.

Rendered validation (release web build of head `4be499bb`, real local 0.8.2 backend,
disposable account and artwork): Chromium and Firefox at 1440 px (desktop workspace) and
390 px (mobile route), EN light and SL dark, success and a forced HTTP 500. All 16 runs
pass: the editor opens, a changed title is saved, the app shell stays visible, the user
returns to the Artist Studio (desktop) or the artwork detail (mobile), the new title is
shown and survives a reload, and a failed save keeps the editor and the typed value with
an error toast and an unchanged server record; no `pageerror`. Results and screenshots are
in `docs/evidence/0.8.3/artwork-save/`.

Known limitations: after Save the desktop studio is rebuilt on its persona's default tab
(Create for a creator), not the Gallery tab, as for any in-shell Back; the first open of the
Artist Studio gallery rendered "0 artworks" until the tab was revisited in the local rig
(observed, not investigated, not part of this change); a save in flight when the user
opens another in-shell screen over the editor would close that screen instead.

### What changes for people

- **Map.** Cluster splits and merges keep the dissolving parent and retarget from the
  positions currently displayed, so a reversal does not jump. Marker source plans are
  cached and source payloads are smaller. Low-zoom globe aggregation is more
  detailed. Cover images prefetch within a bound during continuous zoom. Typing a
  search now removes the server overview bubbles it cannot filter, and clearing the
  search restores them (before, every bubble stayed on a map the search said it had
  restricted).
- **Globe and location.** Exact black ground in dark mode and white in light mode.
  Continuous solar geometry with a day and night terminator, paused while hidden and
  under reduced motion. The location marker has one real point, a static measured
  accuracy ring and a paint-only pulse. The heading cone appears only for a reliable
  heading, relative to the map bearing.
- **Profiles and artwork.** Opening your own identity from Community, an artwork or a
  profile link opens the owner surface (the Profile tab on mobile, the owner profile
  in the desktop shell) with Edit profile and never Follow or Message. A visitor still
  sees a visitor profile. Roles, verification and presence are separate. The recorded
  artist is a link and is never inferred from the uploader. The dark cover-led
  identity panel from #289 is preserved.
- **Community.** A post whose only item is a video sizes its stage to the clip, and
  every multi-item carousel (images, videos or both) keeps one fixed 4:3 stage that does
  not change as the user swipes, with the clip contained and fullscreen available. Late
  metadata does not move the feed. The Art feed keeps one still and one video per artwork.
  Hashtag chips have readable contrast in both themes.
- **Wordmark.** `kubus` is weight 800 italic and `art.` and `Node` stay regular,
  through `KubusFamilyBrandText`. Headers never detect the brand themselves, because
  their titles can carry user content; `brandTitle: true` is an explicit opt-in.
  Hosts, package identifiers and paths stay plain.

### Not in 0.8.3

- The wallet-optional participation stack (see "0.9 handoff").
- The progressive spatial viewer (#258) and any spatial feature.
- Workflow dependency bumps (#281): separate maintenance.
- Release-snapshot documentation (#266): superseded by this file and the corrected
  [release-0.8.2.md](release-0.8.2.md).
- Backend, admin, infrastructure, migrations, secrets.

## Feature flags

| Flag | Source default | Pipeline default | 0.8.3 position |
| --- | --- | --- | --- |
| `COMMUNITY_MULTI_MEDIA_ENABLED` (compile-time `--dart-define`; CI input `community_multi_media_enabled`) | `!isProduction`: off in a release build made without the define | **on**: `prepare_public_build_config.mjs` defaults it to `true`; the `web-artifact`, `deploy-development` and `release-production` inputs default to `true`; a push to `dev` builds the enabled artifact | Unchanged from 0.8.2. Live production (`app.kubus.site`, source `4181b4d2`) serves `kubus-community-build.json` with `COMMUNITY_MULTI_MEDIA_ENABLED: true`, autoplay `true` and posters `true`. `false` stays the emergency rollback input. |
| `KUBUS_SUPPORT_TICKETS_ENABLED` | repository variable | fail closed when unset | Unchanged. |
| `KUBUS_COMMUNITY_VIDEO_AUTOPLAY_ENABLED`, `KUBUS_COMMUNITY_VIDEO_POSTERS_ENABLED` | repository variables | per variable | Unchanged. |

The Dart default describes only a build that skips the pipeline; it does not
describe any deployed artifact. The deployed configuration is whatever the build
metadata file `kubus-community-build.json` in the artifact records, and the
release check is to read that file from the running site, not to infer it from a
default. Backend `art.kubus-backend#79` is live on every writable instance (see
[release-0.8.2.md](release-0.8.2.md)).

With the flag off a post shows only its first item ("Media 1 of 1"), so a
two-item carousel cannot be accepted on a build made without the define. Both
configurations were built from the candidate and checked (see "Evidence"); the
flag-on build is the one that matches what is deployed.

## Candidate and evidence

All results below are from the disposable integration candidate (branch
`chore/083-release-candidate`, local, never pushed, not a release branch), assembled
from fetched `dev` `332e13a9` plus the five PR heads above and used only to prove
that the packages work together. It is not the release; the release is whatever the
protected `dev -> master` path produces.

| Gate | Result |
| --- | --- |
| Base and graph | `dev` `332e13a9` plus #298 `c3a93c7a`, #300 `18a52e55`, #299 `500d3185`, #301 `cdee7298` and #291 `98c42e3f`, merged `--no-ff` in that order with no textual conflicts; candidate head `d36d07e3`. The later heads of #298 and #291 only add documentation and evidence. |
| Static | `flutter analyze` (whole repository), `dart format` on changed files, `git diff --check`: clean. Generated localization matches the ARB source. |
| Full Flutter suite | 5129 passed, 27 skipped, 0 failed (previous four-package baseline: 5125 passed, 27 skipped). |
| Release web build, flag on | `COMMUNITY_MULTI_MEDIA_ENABLED=true`: `main.dart.js` SHA256 `26a71114d225ee3cbf46ad7790ad1912e0a9065bd2a66d992182566a93bfe396`. |
| Release web build, flag off | Release default: `main.dart.js` SHA256 `b22bdcd9176c7f406fb202096e629c238c98b7ad4986012c026ebbb62b5f428d`. |
| Community flag | Mixed image and clip post, Chromium and Firefox, 320, 390 and 1440 px: flag on shows "Media 1 of 2" and a "1 / 2" counter in 6 of 6 contexts, flag off shows "Media 1 of 1" in 6 of 6. |
| Owner routing | Own identity opened from a Community post, EN and SL, Chromium and Firefox, 390 and 1440 px: 8 of 8 reach the owner profile with Edit profile or Uredi profil and no Follow, Sledi, Message or Sporoči action. The earlier Slovenian 390 px gap was a harness entry URL (`/sl/community`, which the app does not serve), not a product defect. |
| PRODUCT motion | 10 of 10 sampling unit tests, and 9 of 9 gallery cases in each of Chromium and Firefox with normal and reduced motion. The sampling fix, thresholds and phase-coverage gate are unchanged. |
| Globe and location | 16 contexts (2 browsers, light and dark, EN and SL, normal and reduced motion): 758 of 760 checks first run; the one failing context passed 3 of 3 reruns and on the earlier combined build, recorded as a flake. |
| Map search | Product defect found and fixed in #298: a search left every server-overview bubble on the map. After the fix the `ui` flow removes the markers (0 dots) and Reset all restores them (23 at 390 px, 59 at 1440 px) in both browsers. The 1440 px layout-swap failure was a harness tap that opened a marker's detail page; the harness now taps a marker-free point. Both failures were identical on the `febffbe5` baseline. |
| Map main flow | Re-established offline with the clock pinned (fixture, `QA_CLOCK`): candidate `d36d07e3` passes 24/24 in Chromium at 1440 and 390 px and 23/23 in Firefox at 1440 px at both 12:45Z and 16:40Z. The two earlier failures were harness defects, not product defects: the badge-pixel check read through the globe's night shade (clock dependent) and the theme-switch check raced the style swap. The untouched `dev` baseline fails the selection-continuity checks at 1440 px, which #298 fixes. The corrected harness and evidence are a follow-up change (`test/083-main-flow-offline`), not part of the five packages. Light scheme only in that matrix; the 192-check earlier pass covered both. |
| Wordmark | Chromium and Firefox, light and dark, EN and SL, 390 and 1440 px, four to five surfaces: renders and accessible labels in `docs/evidence/0.8.3/brand/` on #291. Onboarding headings are not rendered (they need an authenticated new-account state). |

Exact-head CI at the PR heads, read from GitHub on 2026-10-16: #299, #300 and #301
passed every required check; #291 passed every required check at `2199de0e`; #298 is
recorded in its pull request (its first run at `c3a93c7a` failed once on a pending
timer in `feed_like_settlement_test.dart`, a Community test the change does not touch,
which passed on the previous head and in the full local suite; the failed jobs were
re-run and the final head `55e2a528` carries its own run).


## Known limitations

- **Physical devices.** No Android or iOS frame rates, native compass heading,
  fullscreen or audible playback were exercised. Browser emulation is not native
  proof. Heading acceptance is browser-synthetic only.
- **Live authenticated Community.** Coverage used deterministic fixtures. No
  disposable authorised account on a compatible staging backend was available, so
  authenticated feed, post-detail playback, group feed, profile history and media URL
  authorisation were not run against a live service.
- **Cold-cover tail and frame stalls.** Warm cover completion improved (about 1.4 s to
  0.46 s at 390 px, 1.9 s to 1.1 s at 1440 px) and the first cold cover appears in
  0 to 57 ms instead of about 300 ms, but the last cold cover still arrives late and
  occasional severe frame stalls remain. p95 frame interval stayed near 16.8 ms in
  the later pacing comparison, which did not show a meaningful pacing gain. The
  earlier dense-map p95 improvement (about 117 ms to 16.8 ms) is a separate,
  controlled measurement. The performance benchmark was not repeated for the final
  candidate: the later changes (the search reload, the wordmark) do not touch
  frame-time code.
- **Legacy videos** without recorded aspect keep a documented 16:9 fallback. No
  dimensions are invented and no backend migration is proposed to hide this.
  **Owner-reported on a phone: a portrait legacy clip renders as a very narrow player
  inside a much wider post.** The stage keeps its stable 16:9 geometry while the player
  fits the real portrait video inside it, so the visible frame is small. The 0.8.3
  geometry tests establish a stable stage and no layout shift, not an adequate visible
  video size. This is a known defect of 0.8.3, tracked for 0.8.4.
- **Onboarding heading wordmark** is covered by source and widget tests, not by a
  render: the branded onboarding steps need an authenticated new-account state that
  the fixture runs cannot enter.
- **Uncaught `Orbit fallback failed` page error** appears in the map `ui` flow at
  1440 px in Chromium when a live public-API read returns a non-2xx status. It is
  identical on the `febffbe5` baseline, sits in `BackendApiService`, and is left for a
  separate change. The harness passes public GETs through to the production API, so
  the outcome depends on the network.
- **Unlabeled desktop bell and gear icon buttons** expose no accessible name. Pre-
  existing, not part of this release.

## Staging and release procedure

Merges, staging and production each need their own authorisation. None is implied
by this document.

1. **Merge** the integration pull request #303 into `dev` with a merge commit, once
   its required run at the exact head is green. The `dev` ruleset requires branches to
   be up to date before merging (`strict_required_status_checks_policy`), which is why
   the five packages are integrated in one pull request and not merged one by one
   (each later one would have needed `dev` merged into its branch and a new required
   run, unless the owner's ruleset bypass were used). Confirm afterwards that #298,
   #300, #299, #301 and #291 show as merged.
2. **Version bump** on a `release/0.8.3` branch from the merged `dev`:
   `node scripts/sync_all_versions.mjs --target frontend` after editing `version.json`
   (`version` `0.8.3`, a new `buildNumber` and `buildDate`); it rewrites `pubspec.yaml`,
   `lib/config/config.dart` and `package.json` and does not honor a dry-run flag. Then
   `node scripts/sync_all_versions.mjs --check --target frontend`. Use the frontend
   target for both: this release changes no backend, and the unscoped
   `npm run sync:all-versions` / `npm run check:versions` also reach the `backend`
   submodule and the sibling repositories. In a checkout without them (CI uses
   `submodules: false`) the sync stops at the first missing sibling after leaving an
   untracked `backend/version.json` that makes the unscoped check pass only locally.
   The bump is a release-preparation commit, as in 0.8.1.
3. **Staging.** `deploy-development.yml` runs on every push to `dev` and can be
   dispatched on the exact `dev` head, with the `development-web` environment.
   Choose the `community_multi_media_enabled` input deliberately. After the run,
   confirm the running revision from `kubus-web-revision.txt` and its checksum, not
   from the workflow result. Check `/app`, a refresh on a deep route, Map, Community,
   the owner route, `X-Robots-Tag: noindex, nofollow, noarchive` and the deny-all
   `robots.txt`; capture representative screenshots; read the browser console.
4. **Production** is a `dev -> master` release PR with a merge commit, then the
   protected production deployment. Afterwards reconcile `master` back into `dev`
   (`git rev-list --left-right --cherry-pick --count origin/master...origin/dev` must
   read `0` for the first number).
5. **Android and iOS** release builds compile in CI without signing. Signed builds,
   store submission and physical-device acceptance are separate and not done.

### Rollback

Web staging and production restore the previous physical document root
(`/deploy/<site>/rollback-<SHA>`) automatically on a failed smoke and can be restored
by hand. A merged change is undone with a revert PR to `dev` (and a hotfix path to
`master` if already released), never by rewriting a protected branch. The map search
change is self-contained in the two map screens' search handlers.

### Backend compatibility

0.8.3 sends and expects the same API contracts as the released 0.8.2 app and needs
no backend, admin or migration change. The released backend (art.kubus-backend
`32fb3160` and the later art-feed fixes recorded in [release-0.8.2.md](release-0.8.2.md))
stays as it is. Do not deploy any 0.9 backend change for this release.

## 0.9 handoff

These open pull requests introduce account-owned participation and new backend
contracts. They are 0.9 work, stay isolated from 0.8.3, and must not be
cherry-picked piecemeal (wallet-free posting, account chat identity, wallet-free
achievements, account-owned rewards, creator authorisation).

| PR | What | Base | State at 2026-10-16 |
| --- | --- | --- | --- |
| #254 | Creator capabilities discoverable without a wallet | `dev` | open, conflicts with `dev` (DIRTY) |
| #256 | Wallet-optional creator applications, publishing and map contributions | #254's branch | open, clean against its base |
| #280 | Account Community posting, login continuation, chat identity | #256's branch | open draft, clean against its base |
| backend #81 | Account-owned creator content and wallet-free participation | `master` | open |
| backend #82 | Wallet-free community, messaging, attendance, achievements, reward eligibility | #81's branch | open draft |
| backend #88 | Validates account participation against real PostgreSQL | #81 stack | open draft |

Requirements before any of it ships: a coordinated schema migration plan and
deployment order across app and backend, a security review of the account-owned
authorisation paths, a data-migration acceptance run on a copy of production data,
and preservation of the released backend's compatibility contract for older app
builds. `#258` (progressive spatial viewer) is a separate future feature: its Dart
integration and the backend publishing contract are not complete, so it is not a
0.8.3 candidate.

## Dependency maintenance (#281)

The action pins in #281 (`actions/setup-node` v7.1.0, `actions/upload-artifact`
v7.0.2, `actions/download-artifact` v8.0.2) are commit SHAs and each resolves to its
release tag. Its old exact-head failure was the Firefox PRODUCT motion gate sampling
the float animation on a cadence that aliased with its period; the fix is in the
0.8.3 branches, so #281 can only go green once those are merged into `dev`. After
that, update #281 against `dev` without rewriting its history, run exact-head CI,
and merge it separately. It is not part of the 0.8.3 candidate.
