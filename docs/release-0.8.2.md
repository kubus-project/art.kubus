# art.kubus 0.8.2

Status: **draft, not released (release state refreshed 2026-10-10, second pass).**
Nothing is tagged, version-bumped or deployed. Merges are owner-run.

Merged so far: app #248, #249, #250 and #255 into `dev`; backend #78 and #79 into
`master`; app #263 into the #257 branch only (not into `dev`). Every other package
listed below is open. `master` is 0.8.1 (`23abf028`) and `dev` is `b38b8728`.
Version files (`version.json`, `pubspec.yaml`, `package.json` and the app version
constant) are bumped in the release-preparation commit, as in 0.8.1, not in any
feature change. Maturity stays `0.8.x-alpha`.

This file records the 0.8.2 release state: scope, cross-repo contracts, rollout
gates, verification evidence and open decisions. The merged Community media slice
is described in detail further down. Its rollout sections are historical and are
marked as such.

## Release state

Heads, states, CI and review threads were read from GitHub at this refresh
(2026-10-10). Heads move. Re-read them before any decision.

| Package | PR | Head | Base | State | CI at head | Unresolved review threads |
| --- | --- | --- | --- | --- | --- | --- |
| Community video: audio, player frame, fail closed | app #257 | `59359586` | dev | open, clean | 12 checks, none failing | 0 |
| Video fail closed on unresolvable URL | app #263 | `8c447dc3` | `claude/intelligent-allen-m220xd` | merged into the #257 branch on 2026-10-10 17:03 UTC as `59359586` (squash style; `8c447dc3` is not an ancestor) | GitGuardian | 0 |
| D: map quick card, directions, one navigation path | app #251 | `36a1f9aa` | dev | open, clean | 12 checks, none failing | 0 |
| E: map chrome | app #264 | `c85eca9b` | dev | open, clean | 12 checks, none failing | 0 |
| G: analytics chart scales | app #259 | `754135b2` | dev | open, clean | 12 checks, none failing | 0 |
| H: one media resolver | app #260 | `2d8679c1` | dev | open, clean | 12 checks, none failing | 0 |
| Support Center (client) | app #261 | `8a619822` | dev | open, clean | 12 checks, none failing | 0 |
| F: community guest gating and intents | app #262 | `beccba9b` | dev | open, clean | 12 checks, none failing | 0 |
| Search institutions picker (latent path on dev) | app #265 | `cc592edc` | dev | open, clean | 12 checks, none failing | 0 |
| I/H: SEO entities, sitemap, media contract | backend #84 | `d27bf9b` | master | open, clean | Backend CI required: success | 0 |
| Support backend, migration 105 | backend #80 | `cc2b06be` | master | open, **draft**, clean | Backend CI required: success | 0 |
| Search institutions on the migrated schema | backend #85 | `a8c7cce` | master | open, clean | Backend CI required: success | 0 |
| Support console | admin #13 | `71c2f48b` | master | open, **draft**, clean | Lint, typecheck, test and build: success | 0 |
| Release-state record (this file) | docs #266 | see the PR | dev | open; blocked by its own review threads | green | 3 at the refresh; addressed in the commit that adds this text; not resolved by this record |

Notes on the table:

- #263 is merged into the #257 branch, so #257 at `59359586` carries the fail-closed
  guard. It reaches `dev` only when #257 merges.
- #265: the P1 (a legacy `data` fallback in `lib/utils/community_search_results.dart`)
  is removed at `cc592edc`. On `dev` no reachable community picker tab requests
  institutions, so this is a latent-path fix.
- Backend #80 and admin #13 are drafts. They are not deployment candidates until
  they leave draft and are reviewed.
- Backend #84 at `d27bf9b` also fixes an admin artworks list 500 regression (the
  list now selects the uploader name columns it references, with a real-PostgreSQL
  suite in CI), excludes stored generated default avatars from profile media, and
  makes locale-scoped robots rules win over the query-string Disallow (see limits).
- Unresolved review threads: at the refresh every package above had 0. Earlier
  counts in this file are superseded.

What each package changes:

- **#257 and #263.** A video plays with sound at the viewer's last volume. If a
  browser refuses sound, it plays muted and says so. The player is framed to the
  clip's own aspect ratio. A video reference that cannot be resolved never creates
  a player (#263).
- **#251 (D).** `MapDestination` is the one navigation path (provider choice,
  web fallbacks, the "navigate to" sheet). Directions is pinned on the desktop
  artwork panel. One coordinate rule. A guard test rejects map provider tokens
  outside that file.
- **#264 (E).** One logo, in the shell rail. Map chrome is one flat surface level
  with hairline dividers. Accent marks only the selected state. Visible attribution
  text meets 4.5:1 in both themes. Engines, controller and search behaviour are
  unchanged.
- **#259 (G).** One pure `ChartScale` helper for the analytics line and bar charts:
  nice ticks, and single, flat, empty and non-finite series handled. Outliers above
  4 x p95 are clipped at p95 x 1.15, and tooltips keep true values.
- **#260 (H).** One `MediaUrlResolver` contract (table below). An unsafe field falls
  through to the next field. IPFS covers step through the gateway chain, then the
  placeholder. Gateways are fetched directly on web, not through the proxy.
- **#261, backend #80, admin #13.** Support Center: FAQ, contact form, bug report,
  request history, replies, closed read-only state. Tickets have kind `support` or
  `bug` and a `messages` conversation. Admin sets status, priority, assignee and an
  internal note. Email goes only to a verified account address.
- **#262 (F).** Guest gating for comments, likes, chat and the desktop composer, using
  the existing `ContextualAuthGate` and pending-action flow. Intents survive sign-in,
  and a confirmed like shows on its card.
- **#265.** The community search picker reads only `results[kind]`. The legacy
  `data` fallback is removed (`cc592edc`), because the backend never sends it.
  Institution rows render from the migrated backend shape.
- **Backend #84.** Public pages output https only. Unknown artists are never
  bylines. Sitemap `<lastmod>` comes from `updated_at`. Robots: locale-scoped Disallow
  rules now win over the query-string allowance, and extra-parameter and empty
  `page` forms are disallowed. Generated default avatars are not profile images. Media follows
  the contract below. Admin lists gain separate `artist_display_name` and
  `uploader_*` fields.
- **Backend #85.** Institution search reads the migrated columns. A failed kind is
  logged and reported in a new `degradedKinds` array.

## Cross-repo media contract

Backend column: public page output from backend #84 (`d27bf9b`). App column: resolver
output from app #260 (`2d8679c1`).

| Stored reference | Backend #84 (public output) | App #260 (Flutter) |
| --- | --- | --- |
| `https://<public host>/...` | kept | kept |
| `/uploads/`, `/profiles/`, `/avatars/`, bare file name | `https://` media origin: `SEO_MEDIA_BASE_URL`, else `HTTP_BASE_URL`, else `https://api.kubus.site` | rewritten to the storage API host (bare name becomes `<api>/uploads/<name>`) |
| Same path on another https host | kept as given | kept as given, never rewritten |
| `ipfs://<cid>`, `/ipfs/<cid>`, bare `bafy...` | first https gateway from `IPFS_GATEWAY_URL`, then `https://ipfs.io/ipfs/` | gateway chain `dweb.link`, `ipfs.io`, `pinata` (from `StorageConfig`), stepping on failure |
| Bare `Qm...` (CIDv0) | not a CID: `isLikelyCid` recognises `bafy...` only | a CID, same gateway chain |
| `http://` | dropped | dropped (dev builds: only the storage origin itself) |
| `//host`, backslash forms, `user:pass@`, IP literals, `localhost`, single-label hosts, `*.local`, `*.internal`, `..` segments, control characters | dropped | dropped |
| `javascript:`, `data:`, `blob:`, other schemes | dropped | dropped |
| Loopback (`localhost`, `127.*`) | dropped | dropped in release builds; rewritten to the storage host in dev builds |
| Literal `null` or `undefined` | no media | placeholder |
| Post video | `<video>` only with a video extension, the `#kubus-media=video` marker, or a stored `video/*` type | extension or marker only (the community API returns no per-post media type yet) |

Known intentional differences:

1. Gateway order and set. The app tries `dweb.link` first. The backend uses the
   configured https gateway first, then `ipfs.io`.
2. Bare `Qm...` CIDs. The app treats them as CIDs. The backend does not, because
   `isLikelyCid` is not widened in this release.
3. Own-host rewrite only. Both sides rewrite the API or media origin and nothing
   else. A third-party https `/uploads` path is kept as stored.
4. Loopback. The app rewrites loopback to the storage host in dev builds only. The
   backend always drops it.
5. Video detection. The backend also reads a stored `video/*` type. The app does not,
   until the community API returns one.

## Rollout order and gates

Proposed owner order. None of these steps has been run, and nothing is deployed.

**Gate 0, before any 0.8.2 merge into `dev` or `master`, and before any release step.**

- Final-head evidence. The integration trees are stale. `int/0.8.2-app` (`9ba31273`)
  was built with #257 at `038b3a0a`, #265 at `05124be3` and #262 at `460c7b52`. All
  three have since moved (see Release state). `int/0.8.2-backend` (`c36028d`) was
  built with #84 at `012837b5` and #85 at `e9591467`. Both have since moved. Rebuild
  both integration trees at the final SHAs, then run the suites, and the checksum
  and smoke run on the built artifact.
- Browser gates: see the browser status below. C5, the integrated MD-2 confirmation
  and the integrated MP-D run are still open.
- Zero unresolved review threads on every package in the table (true at the refresh).

Steps:

1. Verify backups and migration readiness for the target database.
2. Support chain, in this order:
   - (a) Take backend #80 out of draft and review it. Merge it, apply migration 105
     on every writable instance, deploy, and verify readiness, writable-role health
     and migration parity on every instance. Run the Support end-to-end gate against
     the deployed backend. On the rig at the time of writing: 84 of 84, and the
     PostgreSQL contract 9 of 9.
   - (b) Take admin #13 out of draft, merge it, and deploy the console against #80.
     Its own rig run recorded 107 of 107 checks at `cc2b06b`.
   - (c) Only then release the client build with app #261. The `supportTickets` flag
     is `enableSupportTickets = true` in source, with no build define, so any build
     that contains #261 shows Support at once. Do not release that build before (a)
     and (b) are live.
3. Backend #84 before, or together with, app #260. Set `SEO_MEDIA_BASE_URL` or
   `HTTP_BASE_URL`, and an https `IPFS_GATEWAY_URL`, for public pages. The production
   env examples already use https values (per #84).
4. Backend #85 before, or together with, app #265. #265 reads the additive
   `degradedKinds` field. It is not verified whether #265 tolerates a response without
   that field, so deploy #85 first. The production institutions source still needs a
   decision (see open decisions).
5. App merges, in this order, owner-run: #257 (it carries #263); then #251, #264, #259
   and #262, which do not depend on each other; then #261 (after step 2); then #260
   (after step 3); then #265 (after step 4).
6. Flags, as read from the code on `dev`:
   - `supportTickets`: see step 2(c).
   - `communityMultiMedia`: `COMMUNITY_MULTI_MEDIA_ENABLED`, default `!isProduction`
     in source, so off in a release build with no define. The public build pipeline
     (`scripts/prepare_public_build_config.mjs`) defaults
     `KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED` to `true`. `false` is the rollback switch.
     Backend #79 is already on `master`.
   - `analytics` (`ANALYTICS_APP_ENABLED`): source default `isProduction`. The public
     pipeline defaults `KUBUS_ANALYTICS_APP_ENABLED` to `true`.
   - `externalImageProxy`: `enableExternalImageProxy = true` on web. Its host
     allowlist must be checked in production (see limits).
   - No new flag is added. #251 moves existing reads (`mapWalkingNavigation`,
     `streetArtClaims`, `collabInvites`). #260 reads `externalImageProxy`, and #261
     reads `supportTickets`. #257, #259, #262, #264 and #265 add no flag reads.
7. Merges are owner-run. This record does not merge, deploy, tag or bump versions,
   and no production change is implied by any PR listed.

## Invariants kept

- A cultural artist is never the uploader, owner, contributor, wallet holder,
  importer or photographer. Backend #84 removes the `artist_name` fallback from the
  uploader display name and stops profile saves from writing `artworks.artist_name`
  (I-02, G). Admin shows recorded artist and uploader as separate fields.
- Unknown stays unknown. `Unknown artist`, and its Slovenian equivalents, are
  unattributed in the backend (B) and render as "Unknown artist" in the app (#251). A
  wallet never reads as the artist.
- No backfill. Historical rows where the uploader was stored as the artist are not
  repaired (owner decision, #84).
- An unsafe media field falls through to the next field and never renders (#260, #84).

## Verification evidence

CI is per head, as in the table above. CI is the authority for each head. Local
integrated evidence lives outside the repository, under `C:/kubus-build/evidence/`.
It was recorded at the heads named below, which have since moved.

- **Integrated app tree.** Branch `int/0.8.2-app` (worktree `C:/kubus-build/int-app`,
  HEAD `9ba31273`) merges #257 at `038b3a0a`, #263 at `8c447dc3`, #251, #264, #259,
  #260, #261 and #265 at `05124be3`, and #262 at `460c7b52`. The full suite in
  `evidence/j4/flutter-test-full.log` ends `+4519 ~26`, `All tests passed!`, exit 0.
  `evidence/j4/analyze.log` reports no issues. The log does not record its commit, so
  it cannot be tied to a head.
- **Integrated backend tree.** Branch `int/0.8.2-backend` (worktree
  `C:/kubus-build/int-backend`, HEAD `c36028d`) contains #84 at `012837b5`, #85 at
  `e9591467`, #80 at `cc2b06be`, and #78 and #79. Jest in
  `evidence/j/jest-test-ci.log`: 211 suites passed (7 skipped), 1964 tests passed (59
  skipped). The log does not record its commit. Support end-to-end on the rig: 84 of 84
  PASS (`evidence/j/support-e2e-run/support-e2e-results-run.json`). PostgreSQL support
  contract: 9 of 9 (`evidence/j/pg-support.log`).
- **Current heads.** The app heads of #257 (now `59359586`), #262 (now `beccba9b`) and
  #265 (now `cc592edc`), and the backend heads of #84 (now `d27bf9b`) and #85 (now
  `a8c7cce`), are covered by their own per-PR CI. Their integrated runs are not
  current. The browser reruns in the next section were run on the current heads
  where stated.
- **SEO on the rig** (`evidence/j/seo-results.json`): 41 URLs, 29 return 200, and 12
  are expected 404s. No JSON-LD errors. This ran before the #84 review fixes at
  `d27bf9b`. The refresh did not re-run it.
- **Browser, Chromium.** The J4 results in `evidence/j4/results` were first recorded
  with 17 PASS and 7 FAIL rows. The current status, from the coordinator's rerun
  summary (F, E and H agents' reruns on the final heads; the artefacts are not
  re-counted in this file):
  - C1, like after sign-in: PASS in the final reruns on `beccba9b` (EN and SL at 390
    px, EN at 1440 px). The earlier FAIL rows are superseded.
  - C4, comment with the first Send: PASS.
  - Chat resumes to Messages after sign-in: PASS with the profile step skipped.
    Profile Save for wallet-less accounts is out of scope (wallet-optional programme).
  - SR-6, search institutions: PASS. The community modal institutions path it exercises
    is latent on `dev` (no reachable request), so this is not user-visible acceptance.
  - MD-2, IPFS cover: rendered in H's own browser run. The J4 harness could not confirm
    it.
  - MP-D, Directions on a seeded wallet marker: not re-verified in the integrated run.
    It is verified in #251's own Chromium and Firefox runs (390, 820 and 1440 px; light
    and dark).
  - C5, post after the profile step: not in the rerun summary used here. Its last
    recorded result is FAIL (`evidence/j4/results/j4-C5-1440-en-light-chromium.json`).
    Treat as open.
- **Browser, Firefox.** No integrated Firefox matrix. Firefox runs exist for Slice D
  (#251) only, as reported in #251.
- **Not verified:**
  - The final-head integrated rebuild, checksums and smoke run (gate 0).
  - Native Android and iOS navigation schemes (`google.navigation`, `comgooglemaps`,
    `geo:`). The manifest `<queries>` and iOS `LSApplicationQueriesSchemes` are a
    follow-up (#251).
  - Physical devices and real speakers. Audio was checked in headless Chromium by
    element state and decoded audio bytes only (#257). No spoken screen-reader output.
  - Production. Nothing was deployed or byte-compared. Gateway CORS cannot be checked
    from the sandbox (#260).
  - Analytics with live data. The charts were rendered from a fixture series, because
    the analytics screen needs a signed-in account (#259).
  - The Firefox matrix, and real iOS and Android browsers (#257).
  - Authenticated live community publish flows (#257).
  - `dart run custom_lint` on #261 exits 1 locally, the same as on a dev export
    (author's report).

## Open owner decisions and known limits

Data and contracts:

- **Uploader-as-artist history.** Historical rows where a profile save wrote the
  uploader name into `artworks.artist_name` are not repaired. The candidate-set query
  is in the #84 body. It cannot separate a real artist who is also the uploader.
- **Sitemap `<lastmod>` churn.** View counts and like, unlike and discovery actions
  bump `artworks.updated_at`, so sitemap freshness moves with views (reproduced in
  #84). The fix needs a `content_updated_at` column that changes only on content
  edits. That needs a migration in both schema snapshots, so it is deferred.
- **Robots cannot express a digits-only `page`.** `Allow: /*?page=` also admits
  non-numeric `page` values. Those answer with a noindex 404 (per #84). robots.txt has
  no digit matching, so this cannot be closed in robots alone.
- **Institutions source in production.** The `institutions` table had 0 active rows
  in the 2026-09 audit. Production institutions are profiles with `is_institution =
  true` (2 rows). Search reads the table, so production returns no institutions until
  this is decided (#85).
- **Institutions picker.** #85 says the app's community search institutions tab sends
  `type=institutions` but reads `results.all`. #265 says no reachable picker tab on
  `dev` sends it, and that the fix is a latent-path fix. Confirm before relying on an
  institutions tab.
- **Events** are not a backend search kind (#85). No app code reads `results.events`.
- **Support viewer role.** Viewer accounts log in but get 403 on `/auth/me` and on
  every ticket route. The console explains this. Whether viewers get read access is an
  owner decision (#13).
- **Support email and notes.** Request-supplied email is ignored. Receipts and status
  mail go only to a verified account email (#80). `admin_note` is internal: it is
  never emailed and never returned to the requester (#13).
- **Support rate limits** are per process, like the other route limiters (#80).
- **Account deletion** leaves support tickets in place. This is from the release brief
  and is not in any PR body (unverified).
- **Local QA base URL.** With `HTTP_BASE_URL=http://localhost:3000` and no https
  `SEO_MEDIA_BASE_URL`, relative media on public pages is dropped. This affects
  `scripts/qa/seoPreviewServer.js` (#84, QA tooling follow-up).
- **IPFS CIDs.** `isLikelyCid` reads a `bafkrei...` value as a file name. Left
  unchanged, because the helper is shared with the API (#84).
- **Post dates** on public pages use `Europe/Ljubljana` by design. Flagged for review
  (#84).
- **Wallet-less accounts** belong to the wallet-optional programme, which is not in
  0.8.2. The like route records a like and then answers 500, and the client treats the
  recorded like as success (#262). The profile Save does not persist without a wallet,
  so the profile step cannot advance for email-only accounts (#262). Community post
  create returns 500 for wallet-less accounts (from the release brief; not in a PR
  body, unverified).

Product and UI:

- **Desktop FAB "post" after sign-in** returns to the inline composer, not the dialog,
  because the resume intent is one value (#262). Accepted.
- **Map quick card focus.** The card does not take focus on open, so Tab walks the
  sidebar first (18 presses to Directions at 1440 px). This predates 0.8.2. #264's
  body does not address it (#251).
- **Native navigation schemes.** Android `<queries>` and iOS `LSApplicationQueriesSchemes`
  are missing. Web fallbacks work (#251).
- **Gateway CORS and media proxy.** Gateways are fetched directly on web. Their CORS
  headers must be probed in production. If absent, the next candidate is tried, then
  the placeholder. The production proxy host allowlist does not include the gateways,
  so the proxy answers `403 HOST_NOT_ALLOWED` for IPFS covers (#260). Check this in
  production before release.
- **Visual items from the release brief (unverified, not in PR bodies):** keyboard
  focus ring faint in dark mode; `node.kubus.site` index navigation at Sofia Sans
  40 px; Inter on `art.kubus.site`; HSTS and CSP headers on the art and node hosts;
  the `kubus.site` deploy had no smoke test or rollback (plesk-git).

Community media (see the detail below): the IPFS-only extensionless video case,
native platform playback limits, per-process upload budgets, and the native Slovenian
copy review remain documented limitations.

## Community posts with several photos and videos

- **One ordered set of up to ten items.** A post can hold photos and videos in
  any order. Photos are chosen with multi-select, so ten can be picked in one
  go. Videos are added one at a time, each up to five minutes long. Items keep
  the order you chose, and that order is what readers see.
- **Edit before posting.** Items can be reordered, moved one place, removed, or
  added to. The count and the ten-item limit are always visible.
- **Same composer everywhere.** The mobile composer, the desktop composer, the
  inline desktop composer, and group composers all use the same media set.
  The desktop inline composer previously dropped attached images on post; it
  now uploads them.
- **Resilient uploads.** Items upload one at a time, in order. If an upload
  fails, the draft stays. Completed items are kept, and a retry uploads only
  the items that did not finish. A post is created only after every item has
  uploaded.

## Carousel in the feed and in the post

- **One stage for every page.** Images share a 4:3 stage, so changing slides
  never moves the feed. An image fills the stage when its shape is close to
  it. Otherwise it is fitted whole, so tall portraits and wide panoramas are
  not cropped away.
- **Controls.** Swipe, a `1 / N` counter and dots, hover arrows on pointer
  devices, and left and right arrow keys when the carousel has focus.
- **Videos play.** A video starts muted and plays on tap. Its player loads on
  first play and is released when you scroll away. Only one video plays at a
  time.
- **Quoted posts.** A reposted post shows a compact preview of its first item
  with a `+N` badge that opens the original. The original's media is no longer
  shown twice in a repost.

## Longer posts, with adaptive captions

- **2,200 characters.** Post text is limited to 2,200 characters on create,
  edit, repost comments, and group posts. Length is counted in characters (code
  points), so accented letters and emoji count once each. A counter appears as
  you approach the limit. Text is never cut off silently: an over-limit post is
  refused, and the text stays in the composer.
- **Collapsed captions.** In the feed, a caption that runs past four lines on a
  post with media, or past eight lines on a text-only post, collapses with a
  `more` control. Short captions show no control. The measurement follows the
  real width and text scale.
- **Full text on the post.** The post screen always starts with the complete
  caption. Stored text is never shortened.

## Upload reliability

- **Upload budget counts files.** A signed-in user may upload 20 files a minute
  and 120 an hour. A batch of ten spends ten, from the same budget as single
  uploads. A batch that does not fit is refused whole, before anything is
  stored, and spends nothing. The per-IP ceiling is 600 files an hour, so
  batches cannot multiply an address's allowance. Several users behind one
  NAT each keep their own user budget and share the address ceiling.
- **Clear waiting message.** A quota rejection tells you how long to wait,
  such as "Try again in 45 seconds" or "about 50 minutes". The app does not
  retry long waits automatically. It retries only very short ones, at most
  twice.
- **Client errors are not retried.** Validation and permission errors fail at
  once. Timeouts, server errors and network drops are still retried.

## Compatibility

- Posts and media created before this release display unchanged. A legacy post
  with one image shows that image as a one-item carousel.
- Stored media references keep their formats (`/uploads/...`, `https://...`,
  `ipfs://...`). Migration 098 adds durable creation deduplication; `community_posts.content`
  is already unbounded text.
- Repost comments and post edits that were valid before remain valid.
- Group posts now store the full ordered media set in `media_urls`.
- The old `UPLOAD_RATE_LIMIT` setting is no longer read. Deployment
  environments should use `UPLOAD_RATE_LIMIT_IP_PER_HOUR` (default 600) and,
  optionally, `UPLOAD_USER_RATE_LIMIT_PER_MINUTE` (20) and
  `UPLOAD_USER_RATE_LIMIT_PER_HOUR` (120).

## Rollout

> Historical, from the community acceptance pass that wrote this section (before backend #79 merged to `master` on 2026-10-09, and before app #255 merged to `dev` the same day). The step list records the gate sequence as written. This record does not show whether any step was executed, and no production migration or deploy evidence is recorded here. The current merge and release state is in Release state above.

Two repositories ship this slice. Apply the additive migration before deploying the updated backend; only enable the matching frontend after acceptance.

1. Verify backup/restore readiness and the migration plan for the intended database.
2. Apply migration 098 with the existing runner (`node src/db/migrate.js`) using authorized environment configuration.
3. Verify `community_post_submissions` exists, its wallet/operation/key primary key and post foreign key are correct, and schema parity passes. Migration 098 only adds a ledger table and its constraints: old backend code does not query it and remains compatible during rolling deployment.
4. Deploy backend PR #79 (`art.kubus-backend`, target `master`) to every writable instance.
5. Verify backend readiness, writable-role health and migration compatibility on every instance.
6. Run authenticated staging acceptance for mobile, desktop inline, desktop dialog and group composers using the intended API topology and real picker/uploads.
7. Build the frontend. Community multi-media is **enabled by default** in the public build pipeline once backend #79 is live: `scripts/prepare_public_build_config.mjs` reads `KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED` (default `true`, validated as `true|false`) and emits `COMMUNITY_MULTI_MEDIA_ENABLED`; the reusable, development and production workflow inputs default to `true`, and a push to `dev` builds the enabled artifact. The Dart source default is unchanged (`!isProduction`), so a build that skips the pipeline and ships release mode without the define still comes out disabled. `false` is the emergency rollback switch.
8. Verify the artifact's `kubus-community-build.json` source SHA and capability, checksum integrity and actual behavior; monitor errors, uploads and duplicate submissions.

Compatibility gate. Before any enabled build is promoted to an environment, confirm that environment's backend runs #79 on **every** writable instance, with migration 098 applied. The production command `KUBUS_API_BASE=<origin> node scripts/verify_community_backend_contract.mjs` performs only GET /health, never sends credentials or create requests, and returns UNKNOWN (exit 2). Health cannot attest publishing validation, revision, migration or HA safety. Verify deployed #79 revision, migration 098 and writable-instance/witness status through read-only operator evidence. Exercise 2,200-code-point and ten-item publishing boundaries only against disposable infrastructure. A healthy response alone does not open the promotion gate.

PowerShell local build commands (supply the existing required public build variables first). The pipeline default is already `true`; set it explicitly to document intent:

```powershell
$env:KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED = 'true'
node scripts/prepare_public_build_config.mjs --web
flutter build web --release --dart-define-from-file=.dart_tool/public-build-defines.json
```

Workflow dispatch (the inputs default to `true`):

```text
gh workflow run deploy-development.yml --ref dev
gh workflow run release-production.yml --ref master
```

Rollback rebuilds with the switch disabled; it does not delete stored media or revert the migration. Roll the frontend back first, then the backend only if needed:

```powershell
$env:KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED = 'false'
node scripts/prepare_public_build_config.mjs --web
flutter build web --release --dart-define-from-file=.dart_tool/public-build-defines.json
```

```text
gh workflow run deploy-development.yml --ref dev -f community_multi_media_enabled=false
gh workflow run release-production.yml --ref master -f community_multi_media_enabled=false
```

The equivalent direct local flag is `flutter build web --release --dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=true|false`. Existing protected deployment gates still apply to workflow dispatch.

When the switch is off, composers accept one attachment, a photo or a video,
and captions of up to 1,000 characters (the pre-#79 backend limit), as before. Other composer behaviour is unchanged. The flag is read once at
build time, through `AppConfig.isFeatureEnabled('communityMultiMedia')`.

## Known limitations

- **Video playback** uses the platform video player. It works on web, Android,
  iOS and macOS. On Windows and Linux desktop builds a video shows a clear
  "cannot be played here" message instead of playing.
- **No server-side transcoding.** Videos are stored as uploaded and must be in
  a format the reader's browser or device can play.
- **Video is recognised by file extension.** HTTP-stored uploads keep their
  validated extension, so their videos play. An IPFS-only storage response
  returns a gateway URL with no filename. That URL would be shown as an image.
  The upload route prefers the HTTP copy when one exists. This IPFS-only case
  was not reproduced in this pass and needs a follow-up before IPFS-only
  storage is used for posts.
- **Rate limits are per process.** The upload budgets are kept in memory, as
  the existing per-user limits are. Several backend instances each keep their
  own count. The nginx upload zone was raised to a burst of 30 and must be
  deployed with the backend.
- **Over-limit batches are read before they are refused.** Settling a batch
  needs its files, so a batch that does not fit is buffered in memory and then
  rejected. Reservations cap how many such requests run at once to the
  remaining budget. A single batch can still hold up to 10 files at 50 MB each.
- **Publishing locks the composer, and the mobile sheet closes only from its
  header.** The mobile composer no longer closes on barrier tap or drag, so a
  draft cannot be dropped mid-post. Back is blocked while publishing. This is a
  visible change from before, and the owner should confirm it.
- **Editing an existing post keeps its media as stored.** The edit sheet does
  not change a post's media set.
- **Drag reordering** starts after a long press on any platform. Move buttons
  on each item make the same change with a mouse, a keyboard or a screen
  reader.
- **Mixed picking** uses two actions, Add photos and Add video, instead of one
  combined picker. Both append to the same ordered set.
- **Localization.** New strings are in English and Slovenian. Slovenian copy
  is a first translation and has not been reviewed by a native speaker.

## Duplicate-post safety

Every composer owns a stable UUID for one logical submission. Failed creates retain the key, uploaded URLs and draft; success or explicit draft clearing resets it. Both providers forward the key. Direct API callers can supply `idempotencyKey` for their own retries; omission generates a fresh key per call. Legacy backend requests without a key remain compatible and are not server-deduplicated.

The backend ledger is PostgreSQL-backed, with a primary key over authenticated wallet identity, operation (`community` or `group:<id>`) and submission key. Reservation, post insertion, group membership changes and subject persistence commit in one transaction. Concurrent matching requests cannot insert two posts. Completed submissions replay the saved original HTTP 201 envelope without repeating achievements, socket events, public sync or analytics. Different users, operations and keys are isolated; changed payloads with a committed key return 409. Group membership is checked before every replay.

Both creation API methods disable implicit backend replay on ambiguous 5xx and transport failures, including while an older backend is deployed. Unrelated write failover, safe pre-write `NODE_NOT_WRITABLE` redirects and authentication rejection retries remain intact. No failed request is silently reported as successful.

A crash between post commit and response persistence returns 409 on subsequent keyed retries instead of inserting again. Check the feed before clearing a draft or starting a new submission. This provides at-most-one insertion per key, not guaranteed delivery of asynchronous side effects after a process crash. The existing background side-effect mechanism has no durable outbox. The guarantee also assumes failover preserves the committed PostgreSQL ledger; replica data loss or a fresh key cannot be deduplicated. Manual retries against an old backend remain ambiguous until all writable instances have the new code and migration.

## Final acceptance verification

Actual authenticated browser acceptance succeeded against the isolated real Flutter/Node/PostgreSQL/HTTP-storage topology. Mobile, desktop inline, desktop dialog and group publishing, real media uploads, ordered persisted payloads, manual failure recovery, permissions, two writable backends and browser video playback were exercised. This is distinct from the earlier mock-authenticated widget coverage.

Fresh final validation: full Flutter 4,035 passed/25 skipped/zero failures; enabled focused 148 passed/10 skipped; disabled focused 107 passed/36 skipped; visual scenarios 8 passed; analysis and formatting clean. Backend Jest 1,853 passed/33 skipped/zero failures, 209 passed/5 skipped suites. Both final capability artifacts built and their 192-file manifests verified at source `cca7ae13d5f4aa66a4500f5d5b8007352285fd93`.

See [the complete acceptance report](community-082-e2e-qa.md) for exact commands, reproduction topology, database/network assertions, corrections, artifact hashes and limits. See [46 reviewed real browser screenshots](../output/qa/community-082-e2e/README.md). Earlier widget evidence remains available under [evidence/community-082-final](evidence/community-082-final/README.md).

## Remaining deployment gates

> Historical snapshot, written before backend #79 merged to `master` (ce11d5f, 2026-10-09). Its "no merge" statement describes that pass only. The current state is in Release state above.

No merge, tag, version bump, production migration/deployment or production secret change occurred. Owner-controlled integration must still verify backups, apply migration 098 before updated writable backends, run deployed authenticated staging acceptance, verify the exact matching frontend artifact and explicitly enable it. Isolated browser QA does not establish deployed staging, Google SSO, physical-device or OS-level text-scale acceptance. Browser page zoom and separately identified widget text-scale tests were exercised.

Extensionless IPFS-only video, native platform playback limits, per-process upload budgets and owner/native Slovenian copy review remain documented limitations. A hung upload retains the composer until the existing request timeout. The wider 0.8.2 release remains outside this Community acceptance pass.
