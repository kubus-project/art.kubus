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
  `ipfs://...`). No database migration is needed; `community_posts.content` is
  already unbounded text.
- Repost comments and post edits that were valid before remain valid.
- Group posts now store the full ordered media set in `media_urls`.
- The old `UPLOAD_RATE_LIMIT` setting is no longer read. Deployment
  environments should use `UPLOAD_RATE_LIMIT_IP_PER_HOUR` (default 600) and,
  optionally, `UPLOAD_USER_RATE_LIMIT_PER_MINUTE` (20) and
  `UPLOAD_USER_RATE_LIMIT_PER_HOUR` (120).

## Rollout

Two repositories ship this slice. The backend must be live first.

1. **Deploy backend PR #79** (`art.kubus-backend`, target `master`). It
   accepts the ordered `mediaUrls` set, the 2,200-character limit and the
   per-file upload budget.
2. **Build the frontend with the multi-media switch on.** The switch is
   `--dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=true`. Release builds default to
   off, so a release built without it keeps the single-attachment composer and
   shows only the first item of any multi-item post.
3. **Rollback** needs no source change: rebuild the frontend with
   `COMMUNITY_MULTI_MEDIA_ENABLED=false`. Stored media is untouched. Multi-item
   posts simply show their first item.

When the switch is off, composers accept one attachment, a photo or a video,
as before. Other composer behaviour is unchanged. The flag is read once at
build time, through `AppConfig.isFeatureEnabled('communityMultiMedia')`.

## Known limitations

- **Video playback** uses the platform video player. It works on web, Android,
  iOS and macOS. On Windows and Linux desktop builds a video shows a clear
  "cannot be played here" message instead of playing.
- **No server-side transcoding.** Videos are stored as uploaded and must be in
  a format the reader's browser or device can play.
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

## Verification

Results at the commit that carries this note:

- **Backend (`art.kubus-backend`, feature branch on `master`):** full Jest run
  passed, 208 suites, 1,833 tests, 33 skipped, 0 failed. The upload quota tests
  exercise the real router chain: per-file batch accounting, refusals that
  spend nothing, shared single and batch budgets, the 120-file hour window with
  its retry delay, per-user isolation on a shared IP, a file-counted IP ledger,
  concurrent batches, and unmetered GET retrievals. ESLint is clean on the
  changed files.
- **Frontend (`art.kubus`, feature branch merged with `dev`):** full
  `flutter test` passed, 3,994 tests, 14 skipped, 0 failed. The Community
  directories also pass with the switch on and with the switch off
  (`--dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=false|true`, 105 tests each).
  `flutter analyze` on the whole project reports no issues, and the format
  check on changed files reports no changes.

Not verified in this pass:

- **Authenticated browser QA.** No authorized staging account was used. The
  composer is gated for guests, so the publish journey, the failed-upload and
  retry scenario, and the desktop and group composers were not exercised in a
  browser. Coverage here is unit and widget tests.
- **A rate-limit mutation check.** An attempt to show that the batch test fails
  without settlement was blocked by a permission policy, and the working tree was
  restored at once. The claim rests on reading the test assertions, not on a run.
