# art.kubus 0.8.2: community media

Status: **released.** `v0.8.2` was published on 2026-10-15 and the hotfix
`v0.8.2.1` (Support Center web refresh and auth-return routing, #296) the same
day; production is `master` at `4181b4d2`. The sections up to and including
"Final integration state" are the development record as it stood while the
release was assembled. Their "remaining", "not merged" and "not deployed"
statements describe that moment, not the shipped state. The shipped contract is
in "Release outcome" at the end of this document, and the next release is
described in [release-0.8.3.md](release-0.8.3.md).

This document describes the Community media slice that is part of the 0.8.2
release. Version files (`version.json`, `pubspec.yaml`, `package.json` and the
app version constant) are bumped in the release-preparation commit, as in 0.8.1,
not in this feature change.

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
- **Videos play.** A video plays on tap, with sound, at the volume you last
  chose; muting or lowering it carries to the next clip. If a browser refuses
  sound, the clip plays muted and shows it as muted. The player is exactly the
  shape of the video: the seek bar and controls sit inside the picture, never
  across the empty part of the stage. Its player loads on first play and is
  released when you scroll away. Only one video plays at a time.
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

No merge, tag, version bump, production migration/deployment or production secret change occurred. Owner-controlled integration must still verify backups, apply migration 098 before updated writable backends, run deployed authenticated staging acceptance, verify the exact matching frontend artifact and explicitly enable it. Isolated browser QA does not establish deployed staging, Google SSO, physical-device or OS-level text-scale acceptance. Browser page zoom and separately identified widget text-scale tests were exercised.

Extensionless IPFS-only video, native platform playback limits, per-process upload budgets and owner/native Slovenian copy review remain documented limitations. A hung upload retains the composer until the existing request timeout. The wider 0.8.2 release remains outside this Community acceptance pass.

## UI integration candidate

One reviewable branch carries the open 0.8.2 UI work, so the protected base is validated once instead of after every merge. It is built from `dev` at `ba9f3613` (which already holds #257, #263 and #251) and merges, without squashing or rewriting, the head commits of nine pull requests: #264 map chrome, #267 focus visibility, #259 analytics scales, #262 Community guest gating, #268 single titles, #260 shared media resolution, #269 institution navigation, #265 institution search rows and #270 video posters with muted autoplay. Each source branch and its review history is unchanged.

Conflicts were resolved by hand, not by taking a side: #267's shared focus ring wraps #264's flat map search field and #264's own chrome button replaces the removed variant button; the Community action buttons keep #267's ring, #262's focus node and 48 px targets; #268's single-title app bar keeps the bottom-bar comment composer already on `dev`; #260's storage import stays in the marker card test. Localization was regenerated and the locale guard re-applied.

Corrections made on top of the merged work:

- **Muted autoplay.** While a clip plays silently only because autoplay started it, its volume control shows Unmute and a volume of 0. A tap on the clip, the button, the slider or the M key takes the sound on the same player. The viewer's remembered sound choice is still never written by autoplay.
- **Video-first posts.** The art feed card, both repost sheets and the raw search-row mapping use the post's poster through one shared rule (`communityMediaPreviewStill`) instead of the first media reference.
- **Quick-card focus.** One key press reached the activation tracker twice (key down, then its release), and the overlay re-places the card once its anchor resolves. The re-placed card took the second event as a new open and recorded whatever held focus as its opener, which had just been disposed, so Escape and Close landed in the search field. A card that sees an activation with no opener of its own inside the activation window now joins the running session, and focus returns to the Nearby row that opened it.
- **Fullscreen control.** At desktop widths each control in the video strip is its own focusable button with its own semantics node. The earlier failure came from the acceptance harness: at 1440 x 900 the player's strip lies below the fold, so the harness clicked a wrapper. A regression test now asserts separate nodes, Tab reach and Enter activation.

The Support Center client (#261) is deliberately **not** in the branch proposed for `dev`. It needs backend #80 and migration 105. A separate branch, `int/0.8.2-ui-integration-support`, adds it on top for staging with the matching backend. The backend counterpart is `int/0.8.2-backend-staging` (#84, #85 and #80 merged without squashing; `backend-ci.yml` keeps every database-contract step).

Gates before this reaches users: merge into `dev` after the required checks pass, then deploy the matching backend candidate before the Support client, and keep the Community multi-media switch tied to backend #79 as described above. Nothing here changes versions, tags or production configuration.

## Development release candidate (state 2026-10-11; superseded by "Final integration state" below)

Implemented, merged, deployed and tested are different things; each row says which.

| Part | Revision | Implemented | Merged | Deployed | Tested |
| --- | --- | --- | --- | --- | --- |
| App UI integration (#271, nine PRs, merge commit) | `dev` `90884947` | yes | yes, into `dev` | development web, workflow run 38157484073 | CI 11/11; acceptance harness on the byte-identical artifact |
| Support Center (#261 on current `dev`) | art.kubus#272, branch `int/0.8.2-ui-integration-support` | yes | no (open PR) | no | analyze, unit and widget tests; real-backend browser QA (below) |
| Backend integration (#84, #85, #80) | art.kubus-backend#86, `int/0.8.2-backend-staging` | yes | no (needs owner approval) | no; production backend is `ce11d5f` | CI green; disposable-database migration rehearsal |
| Admin Support console | admin.kubus#13 (`71c2f48`) | yes | no | no | CI; 107/107 browser checks against the real Support API |

### Development deployment
- `Deploy development web` built `90884947`, verified `SHA256SUMS`, `kubus-web-revision.txt` and the deployment metadata, and passed the password-aware development smoke and the revision smoke. No production release workflow ran.
- `dev.kubus.site` is behind HTTP basic auth, so browser acceptance ran on the downloaded artifact served locally (identical bytes). That is not a direct live-site check.
- **Shared API (temporary owner decision).** Development and production frontends use `https://api.kubus.site` (standby `https://bapi.kubus.site`) until a separate staging backend exists. `deploy-development.yml` sets `require_staging_backend: false`; the staging-capable logic stays in `web-artifact.yml` and `scripts/prepare_public_build_config.mjs`. QA against the shared API is read-only; write flows used the disposable rig.

### Acceptance results (browser harness; exact revisions)
- **Development artifact `90884947`** (served locally, byte-identical to the deployed bundle). Map: 1440 light and dark 14/14; the 390, 820 and 320 widths show the same two narrow-width failures as the earlier accepted baseline (marker rendering at the fixture centre, tab order to Nearby artworks); keyboard-focus suite 13/13 at 1440, 820 and 390. Video: Chromium 1440 21/21, 390 reduced motion 7/7, Firefox 390 19/21 (the two baseline Firefox items). No horizontal overflow in 24 page/width/theme combinations. Community, Chromium and Firefox: IPFS cover fallback, institution rows, video poster and muted autoplay, comment draft restoration, compose and chat continuation all pass; guest Like with sign-in continuation passes (Firefox 1440 2/2), with the reload duplicate noted below.
- **Support Center** on `717ce1ce` (the build with the two review fixes), against the 0.8.2 backend candidate with real sign-in, ticket creation, admin reply and closure: Chromium 390 EN 26/26, Firefox 1440 SL 26/26, guest-to-sign-in-to-send 1/1, cold `/support` deep link at 390 EN 3/4 (the failing check is the sign-in confirmation step of the harness; the cold load, My requests and send checks pass), Chromium 820 SL dark 24/26. On the build before the review fixes (same lifecycle code): Chromium 1440 EN dark 26/26, Chromium 320 SL 26/26, Firefox 390 EN 26/26. The 6th ticket in an hour returned 429 with `Retry-After` as designed, which also limited how often one account could be reused. At 820 SL dark the reply typed by the harness reaches the backend without its first character (the other 2 of the 26 checks; three runs, that configuration only). The Slovenian gate sign-in variants of the cold-link and Like scripts could not be exercised: the script does not find the gate's sign-in link in Slovenian, on the previous build as well.
- **Admin console** (admin.kubus#13 `71c2f48`): 107/107 browser checks against the real Support API; the Support routes it uses are unchanged in the integration candidate.
- **Analytics**: 1440 x 900 trend panel with normal, spiky, single-point and empty series, light and dark, with hover, as widget tests (13 in the file). The authenticated 1440 browser flow could not reach the profile (see limitations).
- **Review findings fixed before this state.** Codex found two P1 privacy issues on #272, both fixed and covered by tests: the Support provider kept the previous account's requests after a logout or account switch (data is now bound to the signed-in account and late responses are dropped), and a draft refused for account A could be restored into account B (drafts now carry their account).

### Support Center switch
Public CI builds pass `SUPPORT_TICKETS_ENABLED` from the repository variable `KUBUS_SUPPORT_TICKETS_ENABLED` and **fail closed**: unset means the Support Center shows the FAQ and an unavailability notice and makes no ticket calls. Local builds default to enabled. Set the variable to `true` and redeploy only after the Support API is live (below). Community switches are unchanged: `COMMUNITY_MULTI_MEDIA_ENABLED`, `COMMUNITY_VIDEO_AUTOPLAY_ENABLED`, `COMMUNITY_VIDEO_POSTERS_ENABLED`.

### Backend 0.8.2 (art.kubus-backend#86, not deployed)
- **Migration 105** (`support_tickets.kind`, index, `support_ticket_messages`) is the only schema change. It is additive. On a database built from `master` (95 migrations) with three legacy tickets seeded, the candidate runner applied exactly 105; a second run applied nothing; rows, admin notes and assignees were unchanged; every legacy ticket reads `kind = 'support'`; an INSERT in the previous application's shape still works; the check constraint rejects unknown kinds. Fresh bootstrap of `schema.sql` and `schema_complete.sql` (96 migrations) matches. The runner records applied files by name, so the 099-104 numbers (on #81/#82) can land later.
- **Institutions.** `GET /api/institutions` returns 0 on production: institutions are profiles with `is_institution = true`. Search and suggestions return them with `source: "profile"` and the profile wallet as `id`, which the app already opens as a profile. No institution id is invented.
- **Authorship, media, sitemap** (#84) and **degraded kinds** (#85) are covered by their own suites; the combined candidate passes the support, search, SEO and authorship suites (265 tests).
- **Rollback.** Roll the application back and keep the additive schema: `master` code ignores the new column and table. Do not drop populated Support tables.

### Required before production, in this order (owner approval needed for 2-5)
1. Take a production database backup and restore it into an isolated database; compare table counts. (Not done by the agent: access to the production host was not available to this session.)
2. Apply migration 105 on the writable primary, then deploy the backend to primary and standby; confirm `/health/writable` and `x-kubus-backend-revision`.
3. Verify the Support API: unauthenticated 401, owner-only reads (another account gets 404), reply 409 on a closed ticket, 429 limits (5 tickets and 30 replies per hour per account), no `admin_note` or `assigned_to` in requester responses.
4. Merge and deploy admin.kubus#13; check an administrator and a viewer account.
5. Merge art.kubus#272, set `KUBUS_SUPPORT_TICKETS_ENABLED=true`, redeploy development, then repeat the Support lifecycle on the live host.
6. Then, and only then: version bump, `dev` to `master`, tag, signed Android and iOS builds, and the physical-device checks that browser QA cannot replace (Android and iOS back navigation, native video, OS text scale, Google sign-in).

### Known limitations (P2, not blocking development review)
- Like continuation: after a reload, a duplicate like request is sent in about one of three Chromium runs, and in Firefox the like intermittently shows as not liked. Pending-action completion is stored by design, so the cause is a race between the replay check and the interactions state; not yet fixed.
- Desktop focus after a sign-in-continued Like lands on the page body.
- The desktop sidebar keeps its Sign in tile for an email session that continued without a wallet, so the profile (and its analytics) is not reachable on desktop for such a session; 1440 px analytics layout is covered by widget tests (normal, spiky, single-point and empty series, light and dark, with hover), not by an authenticated browser flow.
- Historical videos without posters use the fallback state; reduced-motion disables autoplay by design.
- Support QA at 820 px Slovenian lost the first typed character of a reply in the harness twice (the reply reached the backend as "ser follow-up"); it did not happen at the other widths. Probably typing before the field takes focus; not investigated further and not seen by a person.
- art.kubus#266 (an older release-state draft) is superseded by this document and should be closed unmerged.

## Final UI corrections

Corrections after owner testing of the development build. Each root cause was reproduced before it was changed.

**Post deletion.** Reproduced on an isolated backend with a real signed-in session: `DELETE /api/community/posts/:id` returned 200 and the post was gone, yet the feed showed "Failed to delete post." and kept the dialog open. The cause was client-side. `getCommunityPosts` returns `toList(growable: false)`, the feed assigned that list directly, and `_removePostFromLocalFeeds` called `removeWhere` on it, which throws on a fixed-length list *after* the server had deleted. Post detail did not touch those lists, which is why it worked. All four surfaces (feed, desktop feed, group feed, post detail) now share `confirmAndDeleteCommunityPost`: one provider call, 404 treated as already deleted, status-aware messages (401, 403, 409, network, 5xx), a blocking pending state, and local cleanup isolated so it can never turn a completed deletion into a failure. Feed lists are copied on assignment and replaced, never mutated.

**Marker continuity.** Recorded frame by frame while easing z3.5 to z9.5: past the overview exit zoom (8.0) the marker source was emptied until the camera settled and the detailed fetch landed, then markers faded up from opacity 0. The overview is now held as a hand-off and drawn until the detailed markers replace it, which then ease in softly. Blank run before: about 1.4 s (default motion) and the whole settle (reduced motion); after: none.

**Dialogs.** `KubusAlertDialog` had no width contract. It now takes a `KubusDialogSize` (compact 420, standard 520, wide 720, from `KubusSizes.dialogWidth*`), defaults to standard, stacks its actions when they do not fit, and scrolls its content under fixed title and actions. 53 text-only confirmations are compact. Raw `AlertDialog` surfaces were moved to `showKubusDialog`. Large surfaces (fullscreen media, editors, the marker editor, the claims table, onboarding) are deliberately unchanged.

**Actions.** `KubusIconActionButton` is the one icon-only action in the control geometry (rounded rectangle, `KubusRadius.control`, 48 px). It replaces the circular Send controls in direct messages, post detail, the feed and desktop inline comment composers and artwork comments. The app theme gives text, filled, outlined and icon buttons the same control shape. Avatars, radios, progress indicators, map markers, pills that are chips or badges and the glass map controls stay circular or pill by design.

**Video.** A post with one video takes the clip's own shape: 16:9 until known, then the poster's shape, then the loaded clip's, bounded to 4:5 at the tallest and 32:9 at the shallowest, never below 112 px. Posts with several media keep the stable 4:3 stage. A clip with no poster that has not played yet is still 16:9 (its shape is unknown without downloading it).

**Map chrome.** The basemap credit is spelled out on arrival and then collapses to the compact info button beside the control cluster; the full credit stays reachable by tap, tooltip and semantics label. The Discovery Path card takes exactly the width of the control cluster.

**Art discovery.** The Art tab is one ranked feed (`ArtDiscoveryRanker`): follows and saves, proximity, recency and genuine engagement, with per-author and per-kind damping and one post per artwork. Sources are art-feed posts (radius widening 3, 15, 60, 250 km only while sparse), recent public posts, public artworks and published exhibitions. Location is the chosen area, then the map's area, then the device (never prompted unless the visitor asks), then the last used area; without any it is public discovery. Only entries within 25 km are labelled nearby. `GET /api/community/art-feed?includeGeneral=true` (backend PR, additive, group posts excluded) lets ordinary located posts qualify; servers without it simply return art categories only.

Not done here: a UI to pick a named city (the map's area serves as the chosen area), and no migration, deployment, tag or version change.

## Final integration state (2026-10-12)

Statuses are separate: **implemented**, **merged**, **deployed**, **tested**, **owner accepted**, **released**. The last two are never inferred. Revisions in this table are the ones recorded when the section was written; the release checkpoint in the PR descriptions is authoritative for later changes.

| Part | PR / revision | Implemented | Merged | Deployed | Tested |
| --- | --- | --- | --- | --- | --- |
| Backend 0.8.2 (#86, migration 105) | `master` `32fb3160` | yes | yes | Oracle primary, running image tagged `candidate-32fb316`, rollback `rollback-pre-32fb316` | CI; running container reports the revision |
| Admin Support console (#13) | `master` `438bde04` | yes | yes | Netcup `~/admin.kubus.site/httpdocs` | CI; browser checks against the real Support API |
| Flutter 0.8.2 with Support (#272) | `dev` `c57232f6` | yes | yes | development web, run 38182460291, `KUBUS_SUPPORT_TICKETS_ENABLED=true` | CI; acceptance harness |
| Art feed bounding box + index (backend #87, migration 106) | `master` `e0fa367c` (merge commit) | yes | yes | Oracle 2026-10-12: backend recreated from `e0fa367c` (running `GIT_COMMIT` verified, `/health/ready` and `/health/writable` primary, replica streaming), migration 106 applied (97 recorded, index present), rollback tag `rollback-pre-e0fa367` | CI; unit and route tests; disposable PostGIS: schema parity, clean bootstrap, plan and equivalence evidence; public `art-feed` answers 200 (400 for latitude 123), `/api/support/tickets` still 401 unauthenticated |
| Admin reply/save/refresh keep unsaved edits (admin #14) | `master` `53a14e87` (merge commit) | yes | yes | Netcup `~/admin.kubus.site/httpdocs` 2026-10-12: built from `53a14e87` (Node 22.15.0, npm 11.7.0, `VITE_API_BASE_URL=https://api.kubus.site`), backup `~/backups/admin.kubus.site-pre-53a14e8-20261012T103352Z.tar.gz`, live `index.html` and main bundle byte-identical to the build, server `.htaccess` and `.well-known` untouched | `npm run verify` (302 tests); CI; authenticated checks not run (no credentials available to this session) |
| Final UI corrections (#273) and desktop wallet shell (#276) | integration PR #279, merged heads `ba3e556b` and `4c719168`, plus review fixes `ec692ee1` | yes | pending until #279 merges | no | focused and combined Flutter tests (1849 before the last review fixes; the affected suites re-run), analyzer, docs doctor, browser Art-tab acceptance |

### What the final integration adds over #272
- Art tab: search is applied to the whole ranked feed before paging (a lower-ranked match used to be unreachable and Load more vanished); a search with no match says so; captionless posts with different media are kept apart while real duplicates are still suppressed.
- Map overview: held hand-off dots bridge a zoom crossing only; a per-artwork filter (search, favourites, AR) drops them at once, so a failed detailed fetch cannot leave unfiltered dots on screen.
- Wallet: the recovery phrase reveal opens inside the desktop shell like the backup screen that hosts it; mobile and no-shell hosts keep the route. Cryptography and persistence are untouched.
- Admin: Refresh and Save keep unsaved status, priority, assignee, note and reason; Refresh is disabled while a reply or save is in flight.
- Backend: the art-feed geographic scan is bounded by an indexable box (antimeridian split, pole handling, latitude validation) ahead of the exact radius check, with a partial index. On 300k posts the plan went from a sequential scan (6384 buffers, 75 ms) to an index scan (10 buffers, 0.03 ms); boxed and exact id sets are identical for seven test centres.

### Evidence types
- **Browser acceptance of the integrated build** (exact local release build of the merge of `ba3e556b` and `4c719168`, served locally; the API is the disposable integration backend, and the public-posts endpoint is answered by a 30-post fixture so a match can sit beyond the first page): Art tab at 1440 light/English and 1440 dark/Slovenian pass populated feed, Show more, search for a lower-ranked match, no-match message and restoring the feed (7/7 each); at 390 the populated feed and Show more pass, and the header search is not covered by the script. Evidence under `C:/kubus-build/evidence/final-int/shots/`.
- **Wallet nested navigation** is verified by a widget test against a shell stand-in that, like the real shell, shows only the top screen (open backup, Show phrase, close). It is not a browser run: the harness has no signed-in wallet fixture.
- **Map filter behaviour** is verified by controller tests; the unfiltered zoom hand-off keeps its earlier frame-sequence evidence (`C:/kubus-build/evidence/ui-fix/lod`).
- A "Review" chip on a post card stays English in the Slovenian UI. It predates this work and is not changed here.

### Operational state (read-only checks, 2026-10-12)
- Oracle backend healthy, `GIT_COMMIT` equals `32fb3160`; `/health/writable` reports primary with one streaming replica and no synchronous standby. The home replication slot is active with no retained WAL (earlier growth was while the standby was offline); WAL directory 1104 MB against a 4096 MB slot cap.
- `ipfs-cluster` runs at about 97% of its 768 MiB memory limit, with `context deadline exceeded` on repo stat and API 500s; the backend snapshot publisher logs `IPFS upload failed` about once a minute. Kubo itself is healthy. Raising the cluster memory limit needs an owner decision (compose change and container recreate).
- Docker reclaimable space on Oracle is about 8.9 GB (images and build cache); host free space was not measurable from docker alone.

### Remaining before production (unchanged order, owner decisions)
Merge #279 and redeploy development, then repeat the Support lifecycle on the live host with an authorised test account (admin reply with unsaved edits, status and assignment, requester-visible updates, user reply, closure, account switch), then version bump, `dev` to `master`, tag, signed builds and physical-device checks. Nothing in this section authorises a production release.

## Release outcome

Recorded 2026-10-16 from the repository and its tags. Statuses stay separate:
implemented, merged, tested, deployed and released are not inferred from one
another.

- **Released:** `v0.8.2` and `v0.8.2.1` (GitHub releases dated 2026-10-15).
  Production web is `master` `4181b4d2`, a merge-commit release, and `dev` contains
  `master` (no commits only on `master`).
- **Not part of 0.8.2:** the wallet-optional participation stack (#254, #256, #280
  and backend #81, #82, #88) and the progressive spatial viewer (#258). They are
  tracked for 0.9 and stay isolated; see [release-0.8.3.md](release-0.8.3.md).
- **Superseded documentation:** PR #266 carried a 2026-10-10 snapshot of this file
  with every package listed as open. Its tables are obsolete. The two sections
  below are the parts of it that remain true contracts, carried over unchanged
  from that snapshot (written against app #260 `2d8679c1` and backend #84
  `d27bf9b`); re-check the resolver code before relying on a detail.

### Cross-repo media contract

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

### Invariants kept

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
