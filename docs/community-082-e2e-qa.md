# Community 0.8.2 final isolated acceptance, 2026-10-09

This pass used the actual release Flutter web application, real browser file choosers, real first-party authentication, two Node/Express writers, disposable PostgreSQL and local HTTP storage. It did not use mock authentication for the browser publications. All four composer surfaces published successfully. No production migration, deployment, merge, tag, version change or production secret change was performed. The wider 0.8.2 release is not completed by this slice.

## A. Focused corrections

- Deployment notes now require migration 098 before updated writable backends and before explicit frontend activation.
- Clean bootstrap resets the PostgreSQL connection search path to public after loading the base snapshot. The snapshot's empty search path had caused migration 008 to fail in a new disposable database.
- Committed-but-unsaved-response conflicts carry `COMMUNITY_POST_ALREADY_COMMITTED`. The existing composer retains its draft, URLs and key, gives localized feedback and opens feed inspection in a separate tab.
- Upload/create errors remain visible inside all composer surfaces, including text-only create failures. Mobile idle draft closure requires explicit confirmation; publishing remains protected from close/back navigation.
- Clicking carousel arrows restores keyboard focus, so subsequent Left/Right keys navigate the carousel.
- Create-post HTTP 429 retains Retry-After in the existing structured exception and displays localized waiting feedback. Slovenian diacritics have a literal regression test.

No carousel rewrite, new authentication architecture, storage infrastructure or unrelated slice changes were made. Existing design tokens and controllers were retained.

Application source for both final artifacts: `cca7ae13d5f4aa66a4500f5d5b8007352285fd93`. Frontend correction commits: `665599233a4f1746625fcddb9155b7db7429d29c`, `47a448e7ea51a2830ff4127dda5374bacd2f3643`, `b722b9c6` and `cca7ae13`. Backend correction commit: `4abcc1bdb5bfefe60e293ced77f70f56a1a573f4`. The final frontend documentation/evidence commit is a descendant of the artifact source, and does not change application code. Exact pushed HEAD and CI status are recorded in PR #250.

## B. Real environment and authentication

No usable authorized deployed-staging credentials were available in the existing checkout. The existing backend, migration, storage and browser infrastructure supported isolated acceptance instead:

| Component | Actual setup |
| --- | --- |
| Flutter | Two independent JavaScript release web artifacts; explicit enabled/disabled Dart definitions |
| Browser | Project Playwright 1.61.1, Chromium 149.0.7827.55, Windows host, headless |
| Web | Existing `scripts/qa/dev_spa_proxy.mjs`, loopback 58080 enabled and 58081 disabled |
| Backend | Two `node src/server.js` entrypoints, loopback 53001/53002, shared disposable DB and JWT configuration |
| PostgreSQL | `postgis/postgis:15-3.4`, PostgreSQL 15.8, loopback 55482, database community082 |
| Storage | Existing HTTP provider, isolated local upload directory, real multipart requests and stored files |
| Email | Local Mailpit SMTP 51025/UI 58025, real verification messages |

Two disposable accounts registered through the real email API, received SMTP verification and signed in through the Flutter email UI. Email-only users encounter the existing wallet requirement for Community posting. That requirement was preserved. Posting used supported generated-wallet sessions and, after a backend restart, an ephemeral injected wallet provider which signed the actual Ed25519 challenge. The server verified signatures and issued real JWTs. The provider fixture implements the supported wallet interface; it is not a physical Phantom extension, mock JWT or authentication bypass. No production users/tokens were copied. External Google SSO was not exercised.

The loopback PostgreSQL host-trust configuration was confined to this disposable fixture. Wallet keys, recovery phrases, passwords, tokens and browser profiles are excluded from the committed evidence.

## Browser publications and database assertions

| Surface/case | HTTP and persisted result |
| --- | --- |
| Mobile ten mixed attachments | 10 ordered uploads; one 201 create; video type; post `5a75c042-6cee-416b-ad6a-ea710c8d4c16` |
| Mobile ten images | Reorder retained; ten uploads; one 201; image type; `16465809-f82d-464b-ad6c-ca8e89569777` |
| Mobile failed third upload | 200, 200, 400, then retry 200, 200, 200; completed first two not uploaded again; one post `1235d775-1d80-443f-adf4-565d79f6f8fe` |
| Desktop inline mixed | Reordered/removed media uploaded and preserved; manual retry after rejected create and committed 500; one post `de49425c-8ea6-48aa-acdf-79aa94b1ac11` |
| Desktop full dialog mixed | Three final uploads; real commit then connection reset; manual retry returned original 201; one post `3cb6dd3d-3125-45ce-b855-ea4c150e5da9` |
| Desktop inline video-only/image-only | Empty caption fallback; correct one-media types; 201 for both |
| Desktop full dialog video-only/image-only | Independently opened, selected and published; correct fallback/type; 201 for both |
| Group mixed | Member posting, three ordered media, pre-insert failure then manual retry; one group-linked post `5eb4773e-66e3-4a25-9f32-10adb093251c` |
| Disabled final artifact | Picker not multiple; one attachment; further picker disabled; one create `00853d5e-c7e2-47f0-9c56-114c50afc4f9` |

Each browser create payload and PostgreSQL media array were inspected. Drafts clear after success. Publishing controls lock; rapid duplicate taps/clicks retain one logical key and one persisted post. The earlier desktop inline image-loss path was exercised through actual HTTP uploads, not inferred from shared-controller tests. Group membership was enforced through real routes: a second non-member received 403; replay of a previously completed key after membership removal also received 403.

Caption tests used short text, over 280 characters, Slovenian characters and emoji. A 2,201-code-point draft remained intact and could not submit. Exactly 2,200 code points published; PostgreSQL `char_length` verified the boundary. Existing-post editing and repost comments independently rejected 2,201 and accepted 2,200. No media editing was added.

### Controlled failures and retries

| Scenario | Actual evidence |
| --- | --- |
| Third of five uploads fails | Browser intercept returned controlled 400 only on third request; first two reached real storage, later files stayed pending; manual retry resumed at three; six requests total, one post |
| Create rejected before commit | Controlled browser 400, zero insertion for that attempt, composer open, uploaded URLs retained, retry made no additional uploads |
| HTTP 500 after commit | Browser `route.fetch()` obtained real committed 201, then returned 500 to Flutter; manual retry reused key and returned original post; no implicit replay to standby |
| Connection loss after commit | Real backend 201 obtained before browser connection reset; same-key manual retry returned original response; no duplicate insertion |
| Commit-to-response gap | Temporary disposable PG trigger rejected ledger response persistence after post commit; initial 500, retry 409 with explicit error code; original post exists, draft/key retained and feed inspection works. Trigger removed |
| Double submission | Actual rapid clicks/taps produced one create per logical attempt and one row per key |
| 429 Retry-After 45 | Upload window observed 83.296 seconds, create window 87.35 seconds; one request each, no automatic replay, localized 45-second feedback, intact draft |
| Two writable backends | Eight actual browser HTTP requests alternated writers with one key: five 201 with the same ID and three pending-response 409; later replay 201; exactly one post and one subject |
| Transaction rollback | Temporary isolated subject-insert trigger caused real 500; no post or ledger reservation survived; trigger removed |

The committed-gap Slovenian screenshot uses a controlled 409 response to verify the corrected translation. The database gap itself was reproduced separately against the real backend. Other controlled faults are explicitly browser transport simulations, not production incidents.

Two video-only posts were played in the actual feed. Both HTMLVideoElements decoded the short browser-compatible MP4; starting the second paused the first, leaving exactly one active player. Play/pause, mute/unmute and in-app navigation disposal (zero remaining video elements) were verified. Carousel swipe, counters/dots, arrows and keyboard keys worked. Media captions collapsed to four lines, text-only to eight; more/less retained carousel position and detail showed the full caption. Mixed reposts displayed one compact original-media preview, without duplicated outer media. Portrait and panorama borders remained visible; dimensions stayed stable.

## C. Visual review and evidence

[46 reviewed browser screenshots and sanitized JSON](../output/qa/community-082-e2e/README.md) are committed. Full generated evidence/logs/artifacts are outside the repository in `G:/WorkingDATA/art.kubus/_artifacts/community-082-e2e/`.

Actual browser viewports: 320x720, 390x844, 768x1024, 1440x1000 and a narrower 900x1000 desktop. Representative light/dark and English/Slovenian combinations were reviewed. Screenshots cover ten attachments, publishing, upload/create errors, both desktop surfaces, group compose, feeds, mixed media, video, expanded/detail captions, keyboard focus, discard confirmation and both capability modes. All selected screenshots were opened and visually inspected. Thumbnails were distinct and visible; controls/padding/alignment remained within the established design. Horizontal thumbnail strips intentionally scroll. No new layout regression required a redesign.

Verified defects corrected in this pass were inaccessible transient modal error feedback, ambiguous committed-conflict feedback, silent idle draft closure, lost keyboard focus after carousel arrow clicks, missing create-rate-limit wait feedback and corrupted diacritics in newly added Slovenian strings. Corresponding post-correction screenshots were reviewed.

Chromium page zoom 1.5x and 2x was exercised and recorded. This is not OS-level Flutter text scaling. The existing visual widget harness separately passed 1.5x/2x text-scale scenarios; those use mock fixtures and are not described as authenticated browser results. No physical mobile keyboard, OS safe-area, native playback or device acceptance claim is made.

Console and failed requests were captured. Retained observations include controlled 400/429 faults, expired-session 401s after the isolated JWT restart and navigation-aborted requests. A fresh final Community capture had no page errors or failed Community/media responses; optional DAO-review and wallet-backup fixture lookups returned 404. These unrelated missing optional resources were recorded, not refactored. See `network-final.json`; there is no claim of globally zero console errors.

## D. Fresh automated validation

Commands run in the matching worktree; use the installed Flutter SDK on PATH. Database URL below is only the disposable loopback fixture. Intentional flag-specific and environment/platform skips remain separately counted.

| Exact command | Final result |
| --- | --- |
| `flutter test` | 4,035 passed, 25 skipped, 0 failed |
| `flutter analyze` | No issues |
| `dart format --output=none --set-exit-if-changed <16 changed Dart paths from git diff baseline HEAD>` | 16 files, 0 changed |
| `flutter test --dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=true test/community test/widgets/community test/services/backend_api_service_write_failover_test.dart test/services/backend_api_upload_rate_limit_test.dart` | 148 passed, 10 skipped, 0 failed |
| `flutter test --dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=false test/community test/widgets/community` | 107 passed, 36 skipped, 0 failed |
| `KUBUS_RUN_VISUAL_QA=1 flutter test --dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=true test/qa/community_composer_visual_test.dart` | 8 passed, 0 skipped/failed |
| `flutter test test/services/spatial_upload_cancellation_test.dart` | 8 passed, 0 failed; investigated unrelated Windows cleanup lock |
| `node --test scripts/prepare_public_build_config.test.mjs` | 5 passed, 0 skipped/failed |
| `npm --prefix scripts/qa test` | 32 passed, 0 skipped/failed |
| `APP_URL=http://127.0.0.1:58080 QA_ARTIFACT_DIR=<external evidence>/web-smoke-final npm --prefix scripts/qa run qa:web` | Existing anonymous/stubbed smoke passed, 2 reviewed captures, exact source cca7ae13; separate from real-auth QA |
| `COMMUNITY_TEST_DATABASE_URL=postgresql://artkubus:isolated@127.0.0.1:55482/community082 npx jest --runInBand` | 209 suites passed, 5 skipped; 1,853 tests passed, 33 skipped, 0 failed; includes 17 real PG idempotency tests |
| `npm run lint` (backend) | Passed |
| `npm run schema:parity` (backend) | Zero table drift; migration filename policy passed |
| `npm run audit:ci` (backend) | Passed policy: 0 unexempted high/critical; 5 high packages in one existing documented unreachable upstream chain |
| `node src/db/migrate.js` against empty community082_clean_final | Full real clean bootstrap passed, including 098 |
| `node src/db/migrate.js migrations/098_community_post_submissions.sql` against reconstructed pre-098 database | Additive upgrade passed |

The first complete post-correction Flutter run had one Windows OS error 32 while deleting a temporary directory in an unrelated spatial cancellation test. Its assertions completed; the file rerun and fresh complete rerun both passed. No unrelated code was changed and no tests were disabled. Intermediate harness selector/fixture mistakes and compilation during changing sources were corrected before final runs; final results above are fresh measurements.

Both final builds ran `flutter build web --release --no-wasm-dry-run --dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=<true|false> --dart-define=BACKEND_BASE_URL=http://127.0.0.1:53001 --dart-define=BACKEND_STANDBY_BASE_URL=http://127.0.0.1:53002 --dart-define=APP_BASE_URL=http://127.0.0.1:<58080|58081>`. Enabled completed in 85.0 seconds; disabled in 80.5 seconds. Both metadata files record source cca7ae13 and the correct capability; 192 file hashes verified independently per artifact. Exact JS/manifest SHA256 values are in `artifact-builds.json`. Build-config tests verify the workflow environment input maps to the Dart definition and defaults false. These are isolated local release builds, not deployed production artifacts.

## E. Migration, budgets, activation and rollback

Migration 098 creates the additive ledger. Direct SQL verified the authenticated wallet/operation/key primary key and post FK with ON DELETE SET NULL. Old requests without a key still create legacy single-media posts after migration. The pre-098 schema was reconstructed by excluding only the new ledger from a schema-only snapshot; it was not a deployed prior-backend binary rehearsal. Full clean bootstrap was independently performed in another empty database.

Real HTTP batch quota acceptance: two ten-file batches produced twenty storage writes; the next batch returned standard 429 with Retry-After and `UPLOAD_RATE_LIMITED`, producing zero storage writes. Eleven files returned Multer 400 `UPLOAD_FILE_COUNT_REJECTED`, producing zero writes. Per-user 20/minute, 120/hour and default 600/hour/IP limits and file-count charging are also covered by fresh route tests. No elapsed-hour HTTP simulation is claimed. Per-process budget behavior remains a documented limitation.

Required controlled activation sequence:

1. Verify backup/restore readiness and the intended migration plan.
2. Apply migration 098 to the intended database.
3. Inspect ledger existence and constraints.
4. Deploy the updated backend to every writable instance.
5. Verify readiness and schema compatibility.
6. Run authenticated deployed-staging acceptance with its real auth/storage topology.
7. Explicitly enable the matching frontend artifact.
8. Verify its source SHA, capability metadata and checksums; monitor uploads/errors/duplicates.

Migration-first is compatible with old backend writers during a rolling deployment. Multi-media must wait for every writable backend to be updated. Rollback first disables the frontend capability or restores the previously approved artifact, then restores the prior backend if necessary while retaining the additive ledger, stored posts and media. Do not drop the ledger during rollback. Backup/restore execution in the intended deployment environment remains an owner gate; this task did not approve or execute it.

Remaining limits: no deployed-staging or production coverage; Google SSO/real wallet extension/physical-device/OS text-scale acceptance not performed; extensionless IPFS-only video and Windows/Linux native playback remain unchanged; no transcoding or durable side-effect outbox; upload quotas remain per process. Production audit's existing unreachable upstream advisory remains documented.

## F. Existing PRs and integration

Frontend [PR #250](https://github.com/kubus-project/art.kubus/pull/250), branch feat/0.8.2-community-media, target dev. Backend [PR #79](https://github.com/kubus-project/art.kubus-backend/pull/79), branch feat/0.8.2-community-media-backend, target master. No new PR was created and no force-push was used. Final live review/check/mergeability state is recorded in the updated PR descriptions and final handoff; local checks alone are not a merge gate.

## G. Acceptance verdict and owner actions

Community development and isolated authenticated browser acceptance are complete for the tested scope. All four composer surfaces, real storage, real PG persistence, durable keyed retries, group permissions and both artifacts were exercised. Production activation is not approved. Controlled staging integration is prepared, subject to owner-controlled merges, backup/restore verification, migration-first deployment to every writer and deployed authenticated acceptance. Those deployment actions and later explicit production authorization remain with the owner. Green CI does not substitute for browser evidence or deployed staging acceptance.

## Exact changed application/documentation files

Frontend corrections relative to supplied baseline:

- `docs/release-0.8.2.md`
- `lib/community/community_composer_media.dart`
- `lib/community/community_upload_feedback.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_sl.dart`
- `lib/l10n/app_sl.arb`
- `lib/screens/community/community_screen_parts/community_screen_p3.dart`
- `lib/screens/community/group_feed_screen.dart`
- `lib/screens/desktop/community/desktop_community_screen_parts/desktop_community_screen_p4.dart`
- `lib/services/backend_api_service.dart`
- `lib/widgets/community/community_composer_media_tray.dart`
- `lib/widgets/community/community_post_media_carousel.dart`
- `test/community/community_composer_flow_test.dart`
- `test/community/community_composer_publish_test.dart`
- `test/community/community_post_text_limits_test.dart`
- `test/services/backend_api_service_write_failover_test.dart`
- `test/widgets/community/community_post_media_carousel_test.dart`

New frontend evidence: `docs/community-082-e2e-qa.md` and the 46 PNGs, 5 sanitized JSONs and README enumerated in `output/qa/community-082-e2e/README.md`.

Backend corrections relative to supplied baseline:

- `__tests__/communityPostIdempotency.postgres.test.js`
- `docs/COMMUNITY_POST_SUBMISSIONS.md`
- `src/db/migrate.js`
- `src/routes/community.js`
- `src/routes/groups.js`
- `src/services/communityPostService.js`
