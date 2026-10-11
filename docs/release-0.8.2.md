# art.kubus 0.8.2: community media

Status: **draft, not released.** This document describes the Community media
slice that is part of the 0.8.2 release. Version files (`version.json`,
`pubspec.yaml`, `package.json` and the app version constant) are bumped in the
release-preparation commit, as in 0.8.1, not in this feature change.

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
