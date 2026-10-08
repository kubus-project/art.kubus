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

Two repositories ship this slice. Apply the additive migration before deploying the updated backend; only enable the matching frontend after acceptance.

1. Verify backup/restore readiness and the migration plan for the intended database.
2. Apply migration 098 with the existing runner (`node src/db/migrate.js`) using authorized environment configuration.
3. Verify `community_post_submissions` exists, its wallet/operation/key primary key and post foreign key are correct, and schema parity passes. Migration 098 only adds a ledger table and its constraints: old backend code does not query it and remains compatible during rolling deployment.
4. Deploy backend PR #79 (`art.kubus-backend`, target `master`) to every writable instance.
5. Verify backend readiness, writable-role health and migration compatibility on every instance.
6. Run authenticated staging acceptance for mobile, desktop inline, desktop dialog and group composers using the intended API topology and real picker/uploads.
7. Enable the matching frontend artifact explicitly. `scripts/prepare_public_build_config.mjs` accepts `KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED=true|false`, validates it, and emits `COMMUNITY_MULTI_MEDIA_ENABLED`. The default is false. Reusable, development and production workflow inputs remain default-disabled, including push-triggered development builds.
8. Verify the enabled artifact's `kubus-community-build.json` source SHA and capability, checksum integrity and actual behavior; monitor errors, uploads and duplicate submissions.

No production migration or deployment is authorized by this QA pass.

PowerShell local build commands (supply the existing required public build variables first):

```powershell
$env:KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED = 'true'
node scripts/prepare_public_build_config.mjs --web
flutter build web --release --dart-define-from-file=.dart_tool/public-build-defines.json
```

For an authorized workflow activation after backend deployment and acceptance:

```text
gh workflow run deploy-development.yml --ref dev -f community_multi_media_enabled=true
gh workflow run release-production.yml --ref master -f community_multi_media_enabled=true
```

Rollback commands rebuild with the switch disabled; they do not delete stored media or revert the migration:

```powershell
$env:KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED = 'false'
node scripts/prepare_public_build_config.mjs --web
flutter build web --release --dart-define-from-file=.dart_tool/public-build-defines.json
```

```text
gh workflow run release-production.yml --ref master -f community_multi_media_enabled=false
```

The equivalent direct local flag is `flutter build web --release --dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=true|false`. Omit the switch only when the intended result is the default-disabled release. Existing protected deployment gates still apply to workflow dispatch. These commands were documented, not dispatched in this pass.

When the switch is off, composers accept one attachment, a photo or a video,
as before. Other composer behaviour is unchanged. The flag is read once at
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

## Verification

Fresh local correction-pass results:

- Full Flutter suite: **4,027 passed, 22 skipped, zero failures**. `flutter analyze`: no issues. Changed Dart files pass the format check.
- Enabled focused Community, creation failover and upload Retry-After tests: **140 passed, 7 skipped**. Disabled Community/widget configuration: **102 passed, 32 skipped**. Intentional skips select the opposite flag mode and mobile-only dismissal cases.
- Full backend Jest suite with the new PostgreSQL contract enabled: **209 passed suites, 5 skipped suites; 1,853 passed tests, 33 skipped tests, zero failures**. ESLint is clean. Both schema snapshots bootstrap with 95 migrations and matching 134-table catalogs; schema parity has zero drift.
- Real PostgreSQL route/service idempotency contract: **17 passed**. Covers normal Community/group creation, completed replay, eight concurrent requests, separate keys/users/operations, validation/auth/group permission rejection, legacy callers, transaction rollback, HTTP 500 and connection loss after committed success, side effects once, and failure before response persistence.
- Public-build configuration executable tests: **5 passed** (default, disabled, enabled, uppercase boolean normalization, invalid input). Existing web runtime/locale contracts: **32 passed**. Local release web builds succeed with `COMMUNITY_MULTI_MEDIA_ENABLED=true` and `false`. Existing wasm dry-run compatibility warnings remain; these were JavaScript release builds.
- Mock-authenticated real composer flows cover **mobile, desktop inline, desktop full dialog and group feed** using existing profile/token seams, fake picker and mock HTTP client. All four cover ten photos, limit enforcement, ordered mixed image/video submission (`postType: video` when a video is present), visible reordering/removal, empty-caption fallback, publishing lock, upload/create failure retention, manual retry with the same key and reused uploads, double-tap prevention, and controlled 429/45-second Retry-After retention without implicit retry. The intentional mobile dismissal contract remains unchanged.
- Thumbnail visual QA: **8 scenarios passed**. Valid distinct numbered 160x120 PNG fixtures replace indistinguishable swatches. The harness waits for actual asynchronous image codec completion and asserts that decoded `RawImage` frames reach `Image.memory` before capture. `XFile.fromData` and preview byte loading work; missing pictures were a capture/decoder scheduling issue. Captures now scroll the entire thumbnail strip into view. Reviewed evidence includes 390x844 light, 320px dark Slovenian, increased 1.5x text, 1440x1000 desktop light/dark, and 320px tray at 2x text. Mixed videos are distinct placeholders, and reordered/removed images match their items. Square previews use `BoxFit.cover`, without stretching. Ten items remain horizontally scrollable.
- Broader QA reproduced and corrected two compact-layout regressions: the desktop inline action row now wraps instead of overflowing, and 72px tiles have bounded icon-button sizes and video-placeholder padding. No composer redesign was performed.

Reproduce visual evidence:

```powershell
$env:KUBUS_RUN_VISUAL_QA = '1'
flutter test --dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=true test/qa/community_composer_visual_test.dart
```

Generated screenshots are in `output/qa/community-composer/`; selected reviewed captures are checked in under [evidence/community-082-final](evidence/community-082-final/README.md). CI runs the enabled and disabled Community contracts, and the backend database job runs the real PostgreSQL creation contract.

## Remaining acceptance gates

Real authenticated browser QA was **not performed**. Mock-authenticated widget tests do not establish real session, picker, upload or multi-backend browser acceptance. Before production activation, merge under owner control, migrate/deploy all writable backends, run real staging acceptance on all composer surfaces, verify the new exact frontend artifact and its capability metadata, then explicitly enable the production flag. No merge, tag, version bump, production deployment or production secret change occurred here.

The previously documented extensionless IPFS-only video limitation, native platform video constraints, per-process upload budgets and owner/native Slovenian copy review remain unchanged. A hung upload still holds the composer until the existing request timeout.
