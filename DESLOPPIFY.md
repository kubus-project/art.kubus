# DESLOPPIFY.md

## Purpose

This document is the working audit and cleanup backlog for the art.kubus "desloppify" pass. It is grounded in the current Flutter client, Node/Express backend, repo-local `AGENTS.md` guidance, `backend/art.kubus-threat-model.md`, and the OpenAI harness-engineering lens: https://openai.com/index/harness-engineering/.

The goal is to reduce security risk, architectural drift, brittle state flow, UI/accessibility rough edges, and agent-hostile repo entropy without speculative rewrites.

## Audit summary

- Repos touched: one Git repo at `G:\WorkingDATA\art.kubus\art.kubus`.
- Branch created: `chore/desloppify-audit`.
- Audit mode file scope: only this `DESLOPPIFY.md` file was created.
- Current stack: Flutter client, Node/Express backend, HA/deployment docs, Solana/Rust program under `programs/fee-splitter`, Playwright QA scripts under `output/playwright`.
- Subagents used: Repo Cartographer, Architecture Reviewer, Security and Validation Reviewer, UI/UX and Accessibility Reviewer, API and State Flow Reviewer, Test and CI Reviewer, Harness Engineering Reviewer.
- Read-only validation run during audit:
  - `backend`: `npm run lint` passed.
  - Flutter: `C:\dev\flutter\bin\flutter.bat analyze` passed with no issues.
  - Flutter focused tests passed: storage config, map style, tutorial overlay host, map overlay blocker, map layers manager, desktop map tutorial bindings.
  - Backend targeted media/CORS/profile tests passed: 5 suites / 32 tests.
  - Bare `flutter analyze` failed in this shell because `flutter` is not on PATH; the documented absolute Flutter path works.

## Critical issues

### [CRIT-01] Upload folder metadata can escape the upload root

**Category:** Security / Validation / Storage  
**Location:** `backend/src/routes/upload.js`, `backend/src/services/storageService.js`, `backend/src/routes/profiles.js`, `backend/src/services/avatarAssetService.js`  
**Problem:** Client-controlled upload metadata can set `metadata.folder`, which becomes `metadata.uploadFolder`. `StorageService.uploadToHTTP()` trims slashes and then uses `path.join(this.httpStoragePath, uploadFolder)` without resolving and verifying the final directory stays under the upload root.  
**Why it matters:** Authenticated users may write files outside intended upload folders, risking overwrite, persistence, or public asset confusion.  
**Recommended change:** Reject client-provided folder paths or strictly allowlist server-selected folders. Add `path.resolve` containment checks before `mkdir` and `writeFile`; apply the same rule to all service callers that pass `uploadFolder`.  
**Safe to fix now:** Yes  
**Suggested task size:** Small  
**Recommended model:** GPT-5.5 high  
**Validation required:** Backend unit tests for `../`, backslashes, absolute paths, encoded traversal, and a valid nested upload folder; targeted upload tests.  
**Dependencies or blockers:** None  
**Status:** Completed  
**Completion notes:** Added upload-folder normalization and resolved-path containment in `StorageService`; stripped client-controlled folder metadata from `/api/upload`, `/api/upload/multiple`, and profile avatar uploads; kept server-selected upload folders for intended file types.  
**Validation run:** `npx jest --runInBand storageServiceUploadPath.test.js uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js` passed (39 tests); `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable; no UI change.  
**Follow-up:** Remaining upload validation/content-type hardening continues under [CRIT-06] and [CRIT-07].

### [CRIT-02] Unsigned wallet bootstrap can mint wallet-scoped JWTs

**Category:** Security / Auth / Validation  
**Location:** `backend/src/routes/auth.js` (`POST /api/auth/register`, `signTokenForUser`, `wallet_bootstrap`)  
**Problem:** Wallet registration accepts a `walletAddress` and can return a JWT with `wallet_bootstrap` authority without proving wallet ownership through the challenge/signature flow.  
**Why it matters:** An attacker can mint an account token for another wallet address if downstream routes accept this token for wallet-scoped operations. This can cause account corruption and privilege abuse.  
**Recommended change:** Require a valid wallet challenge/signature for wallet registration, or issue only a non-authoritative prelink token that cannot access wallet-owned writes.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Large  
**Recommended model:** GPT-5.5 xhigh  
**Validation required:** Auth route tests proving arbitrary wallet registration fails without a valid signature and the existing login challenge flow still passes.  
**Dependencies or blockers:** Requires careful frontend/backend auth-contract review.  
**Status:** Completed  
**Completion notes:** `POST /api/auth/register` now requires the existing wallet challenge/signature proof before any user/profile write or token issue. Successful registration and idempotent existing-wallet registration now emit `wallet_signature` / `wallet_signed` sessions instead of `wallet_bootstrap`.  
**Validation run:** `npx jest --runInBand authFallbackUuid.test.js authSecureAccount.test.js authChallengeLimits.test.js` passed (16 tests); `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable; no UI change.  
**Follow-up:** Old clients that post wallet-only registration must use the existing `/api/auth/challenge` + signed request flow. Adjacent account-linking authority issues remain tracked by [CRIT-03] and [CRIT-04].

### [CRIT-03] Email and Google onboarding can bind wallet-owned records without wallet proof

**Category:** Security / Auth / Profile  
**Location:** `backend/src/routes/auth.js` (`/register/email`, `/login/google`, `/bind-wallet`)  
**Problem:** Email and Google routes accept wallet identifiers and can bind or update wallet-associated rows without requiring wallet signature proof. `/bind-wallet` uses `verifyToken` but does not require a wallet signature.  
**Why it matters:** A user who controls an email/Google account may be able to attach to or mutate a wallet-associated identity record if the target wallet has no conflicting email.  
**Recommended change:** Make wallet binding a two-factor join: authenticated account plus wallet challenge signature. Never mutate an existing wallet user from email/Google routes without wallet proof.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Large  
**Recommended model:** GPT-5.5 xhigh  
**Validation required:** Tests for email, Google, and bind-wallet attempts using another user's wallet must return 403/409 and leave user/profile rows unchanged.  
**Dependencies or blockers:** Same auth contract review as [CRIT-02].  
**Status:** Completed  
**Completion notes:** Added a wallet-proof guard for account-linking flows. Email registration, Google ID/code login, and `/api/auth/bind-wallet` now require a signed wallet challenge when a request introduces a real wallet unless the session is already wallet-signed for that wallet. `/bind-wallet` fallback no longer upgrades account-linked sessions to wallet-signed authority.  
**Validation run:** `npx jest --runInBand authSecureAccount.test.js authGoogleWalletIdentity.test.js authBindWalletAccountLink.test.js` passed (28 tests); `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable; no UI change.  
**Follow-up:** Frontend onboarding must provide `signature`/`walletSignature` with wallet-bearing email, Google, or bind-wallet requests. Lower-assurance wallet-scoped mutations remain tracked by [CRIT-04].

### [CRIT-04] Wallet-sensitive mutations accept lower-assurance JWTs

**Category:** Security / AuthZ / API  
**Location:** `backend/src/middleware/auth.js`, `backend/src/routes/profiles.js`, `backend/src/routes/upload.js`, `backend/src/routes/messages.js`, DAO routes using `requireWalletSignedToken`  
**Problem:** `requireWalletSignedToken` exists and is used for some DAO routes, but many wallet-owned profile, upload, and messaging mutations use only `verifyToken`.  
**Why it matters:** If a lower-assurance token is minted through bootstrap or account-linking gaps, it can be used for broader write access, including profile deletion, media writes, or identity abuse.  
**Recommended change:** Classify routes by auth assurance level. Require wallet-signed authority for wallet-owned profile, artist, institution, DAO, upload, and ownership-sensitive writes where applicable.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Large  
**Recommended model:** GPT-5.5 xhigh  
**Validation required:** Route tests with `wallet_bootstrap`, email, Google, and wallet-signed tokens proving only intended auth levels can mutate wallet-owned state.  
**Dependencies or blockers:** Should follow [CRIT-02] and [CRIT-03].  
**Status:** Partially completed  
**Completion notes:** Added wallet-signed middleware enforcement to wallet-owned profile create/update, profile deletion, avatar upload, and generic upload/multiple upload writes. Added route coverage proving account-linked tokens are rejected before upload storage while wallet-signed tokens can proceed. Second pass added wallet-signed enforcement for marker create/update/delete and marker claim submit/review routes.
**Validation run:** `npx jest --runInBand uploadWalletSignedAuth.test.js uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js profilesMediaPersistence.test.js profilesRoleFlags.test.js` passed (34 tests); second pass `npx jest --runInBand artMarkersWriteAssurance.test.js artMarkersCreateIdempotency.test.js artMarkersUpdatePersistence.test.js artMarkersClaimsAuth.test.js markerOwnership.test.js` passed (25 tests); `npm run lint` passed in `backend/`.
**Screenshots:** Not applicable; no UI change.  
**Follow-up:** Messaging authorization still needs a route-by-route assurance matrix; deferred below rather than enforced blindly.

### [CRIT-05] Admin moderation updates bypass public sync

**Category:** Architecture / Backend / Public Sync  
**Location:** `backend/src/routes/adminModeration.js` (`updateWithAudit`, posts/artworks/collections/markers/events/exhibitions patch routes)  
**Problem:** Admin moderation uses a generic `updateWithAudit()` helper to mutate public entities, but the route does not import or call `publicSyncService`.  
**Why it matters:** Admin visibility/status changes can desynchronize Postgres from OrbitDB/public snapshots, which breaks the decentralized public data contract and outage fallback behavior.  
**Recommended change:** Add explicit post-commit sync hooks for each public entity type, best-effort and gated by existing sync behavior. Keep the database transaction source-of-truth unchanged.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 xhigh  
**Validation required:** Backend tests proving each admin moderation mutation calls the expected public sync hook when sync is enabled and remains safe when sync is off.  
**Dependencies or blockers:** Requires mapping each moderated entity to the correct public sync service method.  
**Status:** Partially completed  
**Completion notes:** Admin moderation `updateWithAudit()` now runs best-effort post-commit public sync for supported public entities: users/profiles, community posts, comments via parent post, artworks, collections, art markers, AR markers, and exhibitions. Added route-level tests covering each supported mapping and the failure-is-best-effort path.  
**Validation run:** `npx jest --runInBand adminModerationPublicSync.test.js adminModerationReportsTicketsRoutes.test.js adminModerationMediaFields.test.js` passed (30 tests); `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable; no UI change.  
**Follow-up:** Event status moderation still lacks a matching `publicSyncService` event hook or explicit snapshot refresh API; deferred below rather than wiring an unvalidated publication contract.

### [CRIT-06] Static upload validation can publish active or spoofed content

**Category:** Security / Uploads / Validation  
**Location:** `backend/src/routes/upload.js`, `backend/src/routes/profiles.js`, `backend/src/services/storageService.js`, `backend/src/server.js` static `/uploads` serving  
**Problem:** Upload filtering accepts a file when MIME type OR extension matches. Stored filenames preserve extension, static uploads are served from `/uploads`, and avatar uploads allow SVG.  
**Why it matters:** Spoofed content or active SVG content can be published from trusted app/API origins, creating XSS/content-sniffing risk.  
**Recommended change:** Require extension and magic-byte/MIME agreement for risky types, sanitize or rasterize SVG only, force safe content types, ensure `nosniff` on uploads, and avoid serving user uploads from the app origin where possible.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Tests for `.html` with image MIME, SVG script payloads, mismatched magic bytes, and safe image uploads.  
**Dependencies or blockers:** May affect valid existing SVG/avatar workflows.  
**Status:** Completed  
**Completion notes:** Added a shared upload validation boundary requiring extension/MIME agreement and magic-byte/content checks for generic uploads and avatar uploads. Generic uploads now reject spoofed extensions, mismatched MIME declarations, and image bytes that do not match their declared type before storage. SVG avatars are accepted only as safe rasterization input, active SVG markup is rejected, and SVG avatar uploads now publish only the generated PNG variant. Static upload responses explicitly set `X-Content-Type-Options: nosniff`.  
**Validation run:** `npx jest --runInBand uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js uploadStaticCors.test.js storageServiceUploadPath.test.js` passed (50 tests); `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable; no UI change.  
**Follow-up:** Artwork-specific multipart upload filtering still has the older MIME-or-extension pattern and should be handled in a separate isolated task because it affects artwork create/update contracts.

### [CRIT-07] Message multipart endpoints lack file limits and filters

**Category:** Security / Validation / Performance  
**Location:** `backend/src/routes/messages.js` (`multer({ storage: multer.memoryStorage() })`, `upload.any()`, conversation avatar upload)  
**Problem:** Message multipart handling uses memory storage without explicit file size/count/type limits.  
**Why it matters:** Authenticated conversation members can trigger memory/disk pressure or upload unexpected media types.  
**Recommended change:** Reuse shared upload validation with explicit file size, file count, field limits, allowed MIME/extensions, and fail-before-storage behavior.  
**Safe to fix now:** Yes  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Multipart tests over size/count/type limits returning 413/400 and no storage writes.  
**Dependencies or blockers:** None  
**Status:** Completed  
**Completion notes:** Added explicit multipart limits for message attachments and conversation avatars, moved conversation membership/write checks before attachment buffering, reused shared upload validation for extension/MIME/content checks, rejected invalid multipart requests before storage, and routed conversation avatar uploads through `avatarAssetService` so SVG input follows PNG-only raster handling.  
**Validation run:** `npx jest --runInBand messagesRoutesAuth.test.js` passed (26 tests); `npx jest --runInBand messagesRoutesAuth.test.js uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js` passed (50 tests); `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable; no UI change.  
**Follow-up:** None.

## Medium cleanup items

### [MED-01] Client-side Pinata secret upload path

**Category:** Security / Storage / Frontend  
**Location:** `lib/config/api_keys.dart`, `lib/services/storage_config.dart`, `lib/services/ar_content_service.dart`  
**Problem:** Flutter code references `KUBUS_PINATA_SECRET_KEY` and can send `pinata_secret_api_key` from the client.  
**Why it matters:** Any real secret built into web/mobile artifacts is extractable and can be abused for storage costs or content abuse.  
**Recommended change:** Remove client-side Pinata secret support and route uploads through authenticated backend storage endpoints or scoped temporary upload tokens.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Static scan proving no Pinata secret env is referenced by Flutter code; AR upload flow uses backend path.  
**Dependencies or blockers:** Requires confirming current AR upload product path.  
**Status:** Completed  
**Completion notes:** Removed Flutter `KUBUS_PINATA_API_KEY`/`KUBUS_PINATA_SECRET_KEY` config and `pinata_secret_api_key` multipart upload code. AR uploads now route through authenticated backend upload storage via `ArtContentService.uploadMedia` and can request `http`/`ipfs`/`hybrid` target storage through `BackendApiService.uploadFile`. Added an architecture test preventing client Pinata credential tokens from returning. Intentional contract change: `ARContentService.uploadContent()` no longer produces a client-pinned CID from Flutter; it returns the backend upload URL immediately while backend storage owns IPFS pinning.  
**Validation run:** `rg -n "KUBUS_PINATA_SECRET_KEY|pinata_secret_api_key|pinataSecretKey|KUBUS_PINATA_API_KEY|pinata_api_key|pinataApiKey" lib` returned no matches; `flutter test test/architecture/client_pinata_secret_guard_test.dart test/services/backend_api_upload_compression_test.dart` passed; scoped `flutter analyze` on touched files passed; `npm run guard:architecture` passed. Full `flutter analyze` still fails on pre-existing `lib/screens/map_screen.dart:5298 deprecated_member_use` unrelated to this task.  
**Screenshots:** Not applicable.  
**Follow-up:** If backend async IPFS pinning needs a client-visible CID, expose a backend status/result contract instead of restoring client Pinata credentials.

### [MED-02] Media proxy allowlist defaults open

**Category:** Security / API / SSRF  
**Location:** `backend/src/routes/mediaProxy.js`  
**Problem:** Empty `MEDIA_PROXY_ALLOWED_HOSTS` allows all public hosts. Private IP filtering exists, but the public proxy remains broader than necessary.  
**Why it matters:** SSRF risk is reduced but still unnecessarily high, especially around DNS rebinding and redirects.  
**Recommended change:** Require an explicit production allowlist, pin DNS resolution to validated addresses or use a hardened fetch agent, and preserve redirect validation.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Tests for localhost/private ranges, disallowed public hosts, allowed hosts, redirects, and DNS edge cases.  
**Dependencies or blockers:** Need approved media host allowlist.  
**Status:** Completed  
**Completion notes:** Changed `backend/src/routes/mediaProxy.js` so production (`NODE_ENV=production`) requires an explicit `MEDIA_PROXY_ALLOWED_HOSTS` value instead of defaulting to all public hosts. Non-production/dev behavior remains permissive for local media QA. Added regression tests for missing production allowlist, allowed hosts, disallowed public hosts, private DNS resolution, and redirects to unapproved hosts.  
**Validation run:** `npx jest --runInBand mediaProxyRoutes.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** Deployment must set the approved production `MEDIA_PROXY_ALLOWED_HOSTS` list; this change intentionally does not guess product-approved media domains.

### [MED-03] Institution provider parses backend events into a legacy model

**Category:** State / API / Architecture  
**Location:** `lib/providers/institution_provider.dart`, `lib/models/institution.dart`, `lib/models/event.dart`, `backend/src/services/eventsService.js`  
**Problem:** `InstitutionProvider` parses backend event responses into legacy `Event.fromJson`, while newer app flows use `KubusEvent.fromJson` and backend fields differ.  
**Why it matters:** Backend event loads can throw or be swallowed, leaving stale local institution/event data and inconsistent mobile/desktop institution hubs.  
**Recommended change:** Make `InstitutionProvider` depend on `EventsProvider`/`KubusEvent`, or add a deliberate adapter with regression tests. Do not keep two event models long term.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Unit-test real `/api/events` shaped payloads through `InstitutionProvider.initialize`; smoke mobile and desktop institution hub.  
**Dependencies or blockers:** Requires event-domain ownership decision.  
**Status:** Completed  
**Completion notes:** Added a deliberate `KubusEvent`/backend-payload adapter for legacy institution `Event` and changed only `InstitutionProvider` backend loading to use it. The provider now accepts snake_case `/api/events` fields, hydrates the related institution when possible, and leaves local storage/local-only event mutation behavior unchanged.  
**Validation run:** `flutter test test/models/institution_event_adapter_test.dart test/providers/institution_provider_backend_events_test.dart` passed; `flutter test test/services/storage_config_test.dart test/models/institution_event_adapter_test.dart test/providers/institution_provider_backend_events_test.dart` passed; scoped `flutter analyze` on touched files passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Longer-term ownership decision remains: collapse institution event state onto `EventsProvider`/`KubusEvent` instead of keeping a legacy UI model plus adapter.

### [MED-04] Saved/bookmark mutations have duplicate write paths

**Category:** State / API / Cleanup  
**Location:** `lib/providers/artwork_provider.dart`, `lib/providers/saved_items_provider.dart`, `backend/src/routes/artworks.js`, `backend/src/routes/saved.js`  
**Problem:** Artwork saved toggles write through `SavedItemsProvider`, then call artwork bookmark/unbookmark endpoints. Backend artwork bookmark endpoints also maintain saved-items compatibility snapshots while `/api/saved` has its own CRUD route.  
**Why it matters:** One UI action can issue two writes and two offline/outbox paths, increasing rollback and stale-state risk.  
**Recommended change:** Choose `SavedItemsProvider` plus `/api/saved` as the source of truth. Make artwork bookmark endpoints thin aliases only if still needed.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Online/offline bookmark toggle produces one saved state, one pending mutation, and one DB row.  
**Dependencies or blockers:** Requires caller inventory for artwork bookmark endpoints.  
**Status:** Completed  
**Completion notes:** Made `ArtworkProvider.toggleArtworkSaved` rely on the bound `SavedItemsProvider` as the only write path, removed the Flutter `ArtworkBackendApi.bookmarkArtwork`/`unbookmarkArtwork` methods and `BackendApiService` implementations, and added a focused provider regression test that save/unsave state changes go through the saved-items repository only. Backend artwork bookmark routes remain in place as route-level aliases for now, but no Flutter production caller uses them.  
**Validation run:** `rg -n "bookmarkArtwork\(|unbookmarkArtwork\(" lib test --glob "*.dart"` returned no matches; `flutter test test/providers/artwork_provider_saved_items_source_test.dart test/providers/saved_items_provider_all_types_test.dart test/providers/artwork_provider_inflight_dedupe_test.dart test/art/art_detail_comments_test.dart test/art/art_detail_attendance_confirm_test.dart` passed; scoped `flutter analyze` on touched files passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Decide whether to keep, deprecate, or remove backend `/api/artworks/:id/bookmark` aliases after confirming external pre-launch clients do not call them.

### [MED-05] Marker owner identity remains ambiguous

**Category:** State / API / Backend  
**Location:** `backend/src/utils/markerOwnership.js`, `backend/src/routes/artMarkers.js`, `lib/models/art_marker.dart`  
**Problem:** Marker ownership can mean wallet, user id, alias, or `system`; frontend exposes `createdBy` only. Route code still contains legacy owner fallbacks and backfills.  
**Why it matters:** Edit/delete/claim checks, achievements, sockets, and OrbitDB docs can disagree on who owns a marker.  
**Recommended change:** Introduce canonical `ownerWalletAddress` in backend payload/model/public doc and keep `createdBy` only as display/audit until removed.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Large  
**Recommended model:** GPT-5.5 xhigh  
**Validation required:** Create/update/delete/claim marker tests with wallet auth, email auth, missing wallet, and legacy marker JSON.  
**Dependencies or blockers:** May require schema and public snapshot changes; update both schema snapshots if DB changes.  
**Status:** Completed  
**Completion notes:** Added canonical JSON/API/public-doc ownership fields for markers without changing DB schema: backend marker ownership helpers now resolve/write `ownerWalletAddress` and `ownerUserId` separately from legacy `createdBy`/`created_by`; marker create/update responses, Orbit/public sync docs, and public object registry ownership prefer the canonical wallet field; claim submission stores owner wallet/user id in the correct columns; claim approval transfers ownership to claimant wallet first. Flutter `ArtMarker`, HTTP marker parsing, socket marker parsing, and map ownership affordances now consume `ownerWalletAddress`.  
**Validation run:** `npx jest --runInBand markerOwnership.test.js artMarkersCreateIdempotency.test.js artMarkersUpdatePersistence.test.js artMarkersClaimsAuth.test.js publicSyncService.test.js publicObjectRegistryService.test.js` passed; `npm run lint` passed in `backend/`; `flutter test test/models/art_marker_owner_wallet_test.dart test/features/map/shared/map_marker_owner_helper_test.dart test/models/art_marker_type_parsing_test.dart test/services/backend_api_service_marker_update_test.dart` passed; scoped `flutter analyze` on touched Dart files passed; `npm run guard:architecture` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** A later schema pass can add indexed first-class owner columns if needed; legacy rows with only ambiguous `createdBy` values remain readable, but non-wallet legacy aliases are no longer promoted as public owner wallet addresses.

### [MED-06] Community mutations bypass provider-owned state

**Category:** State / UI / API  
**Location:** `lib/screens/community/community_screen.dart`, desktop community screen, `lib/providers/community_interactions_provider.dart`  
**Problem:** Community post creation and repost create/delete call `BackendApiService` directly from screen logic instead of provider methods that own cache invalidation.  
**Why it matters:** Feed, detail, group, interaction, and profile-package caches can diverge after create/repost/delete.  
**Recommended change:** Add provider methods for post/repost mutations and centralize invalidation/ProfilePackageMutationTracker calls there for mobile and desktop.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Create/repost/delete from mobile and desktop community surfaces; verify feed, profile, detail, and interaction states refresh.  
**Dependencies or blockers:** UI screenshots required for community flows.  
**Status:** Completed  
**Completion notes:** Added provider-owned mutation methods to `CommunityInteractionsProvider` for non-group post creation, repost creation, repost deletion, and post deletion. Mobile and desktop community screens now call those methods instead of direct `BackendApiService` mutation calls, while keeping screen-local feed list updates local. Group post creation remains owned by `CommunityHubProvider.submitGroupPost`. Profile package mutation tracking, repost analytics, and hydrated post state updates now live in the provider mutation path.  
**Validation run:** `flutter test test/providers/community_interactions_provider_test.dart` passed; `flutter test test/providers/community_interactions_provider_test.dart test/community/community_post_achievement_result_test.dart test/community/community_post_subject_parsing_test.dart test/services/community_startup_request_contract_test.dart` passed; scoped `flutter analyze` on touched files passed; `npm run guard:architecture` passed; static scan for direct screen `createCommunityPost`/`createRepost`/`deleteRepost`/`deleteCommunityPost` calls returned no matches outside provider calls.  
**Screenshots:** Not applicable; no visual/layout changes were made.  
**Follow-up:** Run an auth-backed manual smoke for mobile and desktop create/repost/unrepost/delete flows when a local backend/session is available; no screenshot baseline was captured because the task changed state routing only.

### [MED-07] Profile preferences persist optimistically without visible failure state

**Category:** State / UX / API  
**Location:** `lib/providers/profile_provider.dart`  
**Problem:** `updatePreferences()` updates local state and prefs before best-effort backend persistence, then swallows backend failure.  
**Why it matters:** UI can show settings as saved even when backend rejected or failed them; another device/session may revert.  
**Recommended change:** Add dirty/error state plus retry, or make preference save transactional from the UI's point of view. Guard noisy logs in the same area.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Force `/api/profiles` failure and verify pending/failed or rollback behavior.  
**Dependencies or blockers:** Product decision on optimistic vs transactional settings UX.  
**Status:** Completed  
**Completion notes:** Added explicit preference sync state to `ProfileProvider` (`isSavingPreferences`, `hasUnsyncedPreferences`, `preferencesSaveError`, `hasPendingPreferenceSync`) and a `retryPreferenceSync()` hook. `updatePreferences()` still preserves existing optimistic local behavior, but backend failure now leaves a retryable dirty/error state instead of being silently swallowed. The mobile privacy settings save path now shows a failure snackbar with retry when backend preference sync fails.  
**Validation run:** `flutter test test/providers/profile_provider_media_test.dart` passed with a forced `updateProfile` failure/retry regression; `flutter test test/privacy/privacy_settings_parity_test.dart` passed; scoped `flutter analyze lib/providers/profile_provider.dart lib/screens/settings_screen.dart test/providers/profile_provider_media_test.dart` passed; `npm run guard:architecture` passed.  
**Screenshots:** Not applicable; no layout, styling, route, or control structure changed.  
**Follow-up:** Desktop privacy toggles can now consume provider sync state, but a broader inline sync-status treatment should be handled as a UI task with screenshots if product wants persistent on-page status instead of snackbar/error state.

### [MED-08] Domain models and providers bypass transport boundaries

**Category:** Architecture / API / Cleanup  
**Location:** `lib/models/user_profile.dart`, `lib/services/art_content_service.dart`, `lib/providers/profile_provider.dart`  
**Problem:** `UserProfile` imports `BackendApiService`; `ArtContentService` and `ProfileProvider` use direct HTTP for backend stats/probes.  
**Why it matters:** Auth, retry, base URL, telemetry, and test behavior become inconsistent with the `BackendApiService` contract.  
**Recommended change:** Move avatar URL fallback to a config/media resolver, wrap backend stats/probes in dedicated service methods, and add static guard coverage for direct HTTP in providers/models/screens.  
**Safe to fix now:** Yes  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Unit tests for profile/avatar parsing without constructing API service; static search guard.  
**Dependencies or blockers:** None  
**Status:** Completed  
**Completion notes:** Removed `BackendApiService` from the `UserProfile` domain model sample-avatar helper, moved storage stats and avatar URL probes behind `BackendApiService` methods, and changed `ProfileProvider`/`ArtContentService` to use those service boundaries instead of raw `package:http`. Tightened `scripts/architecture_guard.mjs` so raw HTTP imports in models/providers/screens/widgets and `BackendApiService` imports in models now fail mechanically.  
**Validation run:** `flutter test test/services/backend_api_service_media_probe_test.dart test/models/user_profile_transport_boundary_test.dart test/providers/profile_provider_media_test.dart test/community/profile_edit_media_sync_test.dart test/art/art_detail_comments_test.dart test/presence/presence_provider_test.dart` passed; scoped `flutter analyze` on touched Dart files passed; `npm run guard:architecture` passed; `npx jest --runInBand architectureGuardScript.test.js` passed in `backend/`; static scans for raw HTTP imports in `lib/models`, `lib/providers`, `lib/screens`, and `lib/widgets`, and for `backend_api_service.dart` imports in `lib/models`, returned no matches.  
**Screenshots:** Not applicable; no UI changes.  
**Follow-up:** `ProfileProvider.uploadProfileCoverBytes()` still has a concrete `BackendApiService` fallback for non-default test APIs; converting cover upload to an explicit profile API contract can be handled in a later provider-injection cleanup.

### [MED-09] Sticky API-unavailable flags hide backend recovery

**Category:** API / State / Resilience  
**Location:** `lib/services/backend_api_service.dart` (`listEvents`, event/exhibition availability flags)  
**Problem:** Some availability booleans can permanently pin the session to empty local/snapshot data after a transient 404/400 or staged backend deploy.  
**Why it matters:** Users can see stale/empty data until restart even after the backend recovers.  
**Recommended change:** Replace sticky booleans with TTL-backed circuit breakers or explicit feature/config availability.  
**Safe to fix now:** Yes  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Simulate first request 404 then second request 200; provider should recover without app restart.  
**Dependencies or blockers:** None  
**Status:** Completed  
**Completion notes:** Removed permanent short-circuiting for provisional institutions/events endpoints and changed provisional events/exhibitions unavailable markings to `null` so the next request can retry and a later 200 can restore `eventsApiAvailable`/`exhibitionsApiAvailable` to `true`. Added provider-level regression coverage for events and exhibitions recovering after a first 404 without restarting the singleton.  
**Validation run:** `flutter test test/providers/backend_api_availability_recovery_test.dart` passed; `flutter test test/providers/backend_api_availability_recovery_test.dart test/providers/institution_provider_backend_events_test.dart test/services/backend_api_service_media_probe_test.dart` passed; scoped `flutter analyze lib/services/backend_api_service.dart test/providers/backend_api_availability_recovery_test.dart` passed; `npm run guard:architecture` passed.  
**Screenshots:** Not applicable; no UI changes.  
**Follow-up:** The map open flows still read availability getters, but provisional failures now resolve to `null` rather than sticky `false`; any visible map affordance change should be handled as a screenshot-backed map UI task.

### [MED-10] API error contracts are inconsistent

**Category:** API / State / Validation  
**Location:** `lib/services/backend_api_service.dart` (`getMyProfile`, `listEvents`, `createArtworkRecord`, related methods)  
**Problem:** Some methods return `{success:false}`, some return `[]`, some return `null`, and mutations may swallow failures.  
**Why it matters:** Providers cannot reliably distinguish empty data from failed requests, which weakens retry and stale UI behavior.  
**Recommended change:** Define per-method result policy: public reads may snapshot fallback; mutations throw typed `BackendApiRequestException`; optional reads return empty only on proven empty.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Large  
**Recommended model:** GPT-5.5 high  
**Validation required:** Table tests for 200, 401, 404, 500, timeout, and offline fallback for representative methods.  
**Dependencies or blockers:** Requires compatibility plan for existing providers.  
**Status:** Deferred  
**Deferral reason:** This is a cross-cutting API contract change. Existing providers and screens currently depend on mixed return conventions (`[]`, `null`, `{success:false}`, and thrown exceptions); changing representative methods without a compatibility matrix would risk turning recoverable empty states into user-facing failures or swallowing real mutation failures in a different place.  
**Safest next action:** Write a method-by-method compatibility matrix for `getMyProfile`, `listEvents`, `listExhibitions`, `createArtworkRecord`, and one mutation path, then implement one contract family at a time with table tests for 200, 401, 404, 500, timeout, and snapshot fallback.  
**Validation needed later:** Table-driven backend API service tests plus provider regression tests for each changed method family.

### [MED-11] Map screens still own lifecycle and business logic

**Category:** Architecture / UI / State  
**Location:** `lib/screens/map_screen.dart`, `lib/screens/desktop/desktop_map_screen.dart`, `lib/features/map/**`  
**Problem:** The map architecture docs say screens are layout-only, but both map screens still own MapLibre controllers, streams, timers, marker loading/sync/create, and overlay routing.  
**Why it matters:** Mobile/desktop parity and resource cleanup are harder to preserve; future map changes are regression-prone.  
**Recommended change:** Continue extracting marker load/sync/create/location lifecycle into `KubusMapController` and smaller coordinators; leave screens as composition shells.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Large  
**Recommended model:** GPT-5.5 xhigh  
**Validation required:** `flutter analyze`, map-focused tests, mobile/desktop map smoke screenshots for marker select/create/delete.  
**Dependencies or blockers:** UI screenshots required.  
**Status:** Deferred  
**Deferral reason:** This is a large map architecture refactor with required mobile and desktop map screenshots. It should run as a dedicated map-isolation task with baseline screenshots before touching `map_screen.dart`/`desktop_map_screen.dart`; doing it in this mixed cleanup branch would raise regression and review risk.  
**Safest next action:** Create a focused map-controller extraction task, capture baseline mobile/desktop map screenshots, then move one lifecycle responsibility at a time into `KubusMapController` with map-focused tests.  
**Validation needed later:** `flutter analyze`, map controller tests, mobile/desktop route smoke screenshots for marker select/create/delete and fallback flows.

### [MED-12] Large route/service/screen monoliths slow review and increase regression risk

**Category:** Architecture / Cleanup / Harness  
**Location:** `lib/services/backend_api_service.dart`, `backend/src/routes/auth.js`, `lib/screens/community/community_screen.dart`, `lib/screens/desktop/community/desktop_community_screen.dart`, `lib/screens/onboarding/onboarding_flow_screen.dart`, `backend/src/services/promotionService.js`  
**Problem:** Multiple core files are thousands of lines and mix transport, parsing, UI composition, state orchestration, and domain behavior.  
**Why it matters:** Changes are hard to review, tests are hard to localize, and future agents are more likely to make broad accidental changes.  
**Recommended change:** Extract by stable domain seams while keeping public APIs stable. Prioritize auth services, backend domain clients, community feed/composer widgets/controllers, and onboarding step controllers.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Large  
**Recommended model:** GPT-5.5 high  
**Validation required:** Existing tests for each domain plus focused regression tests around extracted units.  
**Dependencies or blockers:** Should be broken into separate goals.  
**Status:** Deferred  
**Deferral reason:** The item intentionally spans several monoliths across Flutter and backend. It is too broad for a single safe cleanup task and should be split by domain ownership (`BackendApiService`, auth routes, community screens, onboarding, promotion service).  
**Safest next action:** Create one extraction task per domain with before/after tests for the affected behavior and no cross-domain edits.  
**Validation needed later:** Existing domain tests plus focused regression tests for each extracted unit.

### [MED-13] Reusable services depend on `BuildContext`

**Category:** Architecture / State / Cleanup  
**Location:** `lib/services/search_service.dart`, `lib/services/post_auth_coordinator.dart`, `lib/services/wallet_session_sync_service.dart`, `lib/services/share/share_service.dart`  
**Problem:** Reusable services read providers or navigate through `BuildContext`, which blurs widget/service boundaries.  
**Why it matters:** Services are harder to test without widget harnesses and can accidentally use context after async gaps.  
**Recommended change:** Pass typed dependencies into constructors or method parameters; keep context capture in widgets/controllers only.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Service unit tests without widget harness plus `flutter analyze`.  
**Dependencies or blockers:** None  
**Status:** Partially completed  
**Completion notes:** `SearchService` no longer captures providers, localization, or `BuildContext`; it now consumes explicit snapshot data, while `KubusSearchController` owns the widget-layer provider/localization capture.  
**Validation run:** `flutter test test/services/search_service_test.dart test/widgets/search/kubus_general_search_test.dart test/widgets/search/kubus_search_bar_map_glass_test.dart test/widgets/search/kubus_search_results_overlay_interaction_test.dart` passed; scoped `flutter analyze` for touched search files/tests passed; `npm run guard:architecture` passed; `rg` confirmed no `BuildContext`/provider/localization usage remains in `lib/services/search_service.dart`.  
**Screenshots:** Not applicable; no visual or layout changes.  
**Follow-up:** `lib/services/post_auth_coordinator.dart`, `lib/services/wallet_session_sync_service.dart`, and `lib/services/share/share_service.dart` still require isolated context-removal work because they touch onboarding, wallet session, navigation, and share modal flows.

### [MED-14] Legacy API shims remain despite pre-launch no-legacy policy

**Category:** API / Cleanup  
**Location:** `backend/src/server.js`, `backend/src/routes/users.js`, callers referencing `/api/users`  
**Problem:** Backend registers `/api/users` as a compatibility shim for older clients while repo guidance says not to preserve legacy paths unless explicitly requested.  
**Why it matters:** Extra route surface and duplicated profile/user contracts increase maintenance and security review load.  
**Recommended change:** Inventory callers, move them to `/api/profiles`, and remove the shim when tests confirm no references remain.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Static scan for `/api/users|usersRouter`, backend route tests, Flutter profile tests.  
**Dependencies or blockers:** Must confirm no external pre-launch clients rely on it.  
**Status:** Completed  
**Completion notes:** Moved authenticated email-preference GET/PATCH endpoints from `/api/users/me/preferences` to `/api/profiles/me/preferences`, updated the Flutter API client, removed the unused `/api/users/:id` client method, unmounted `/api/users`, deleted `backend/src/routes/users.js`, and updated route/leak regression tests.  
**Validation run:** `rg -n '/api/users|usersRouter|routes/users|getUserProfile\(' backend/src backend/__tests__ lib test -g '*.js' -g '*.dart'` returned no matches; `npx jest --runInBand userPreferencesRoutes.test.js publicWalletLeakRoutes.test.js` passed; `npm run lint` passed in `backend/`; scoped Flutter settings tests and `flutter analyze` passed; `npm run guard:architecture` passed.  
**Screenshots:** Not applicable; no UI changes.  
**Follow-up:** If any external pre-launch client still calls `/api/users/*`, migrate it to `/api/profiles/*`; no local callers remain.

## Nice-to-have polish

### [POLISH-01] Map accessibility labels expose internal keys

**Category:** UI / Accessibility  
**Location:** `lib/screens/map_screen.dart`, `lib/screens/desktop/desktop_map_screen.dart`, `lib/widgets/map/controls/kubus_map_primary_controls.dart`, `lib/widgets/map/nearby/kubus_nearby_art_panel_header.dart`  
**Problem:** Semantics labels such as `map_search_input`, `map_zoom_in`, and `nearby_art_handle` are developer IDs instead of user-facing labels.  
**Why it matters:** Screen readers announce internal keys, which makes map controls less usable.  
**Recommended change:** Use localized tooltip strings as semantics labels and add toggled/selected state where relevant.  
**Safe to fix now:** Yes  
**Suggested task size:** Small  
**Recommended model:** GPT-5.4 mini medium  
**Validation required:** Semantics/widget tests; no screenshots required unless visual focus states change.  
**Dependencies or blockers:** None  
**Status:** Completed  
**Completion notes:** Replaced internal map semantics labels with user-facing/localized labels for mobile/desktop search fields, primary controls, desktop info/sidebar panels, and discovery idle card. Marked active controls with selected state. Removed the decorative nearby bottom-sheet drag handle from the semantics tree.  
**Validation run:** `flutter test test/features/map/map_overlay_stack_interaction_test.dart test/widgets/map/nearby/kubus_nearby_art_panel_interaction_test.dart` passed; static scan for the old internal labels in touched map files returned no matches; scoped `flutter analyze --no-fatal-infos` on touched files passed with the known unrelated `lib/screens/map_screen.dart:5298` `axisAlignment` info.  
**Screenshots:** Not applicable; semantics-only change with no visual focus/layout changes.  
**Follow-up:** None for these map labels.

### [POLISH-02] Repeated tappable cards lack consistent keyboard and focus semantics

**Category:** UI / Accessibility  
**Location:** Profile showcase cards, shared detail media cards, gallery thumbnails  
**Problem:** Several repeated cards use raw `GestureDetector` without keyboard activation, button semantics, labels, selected state, or visible focus.  
**Why it matters:** Keyboard and assistive-technology users may not be able to reach or understand repeated card actions.  
**Recommended change:** Add a reusable accessible card wrapper using `Semantics`, `FocusableActionDetector`, `ActivateIntent`, and focus styling.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Widget semantics tests and before/after focus screenshots.  
**Dependencies or blockers:** UI screenshot capture required.  
**Status:** Partially completed
**Completion notes:** `SharedShowcaseCard` now owns button semantics, default semantic labels, keyboard activation through Enter/Space `ActivateIntent`, and visible hover/focus styling for tappable showcase cards. Mobile self-profile saved/showcase cards and public-profile showcase cards now pass their existing navigation callbacks into the shared card instead of wrapping it in raw `GestureDetector`s; desktop profile surfaces already used the shared `onTap` path. The same validation pass fixed adjacent profile UX debt discovered by tests: likes-sheet layout now respects the modal route height cap, likes rows do not trigger fallback avatar network fetches, social repost identity data preserves explicit user ids separately from wallet seeds, hyphenated usernames remain stable, and avatar shimmer tickers run only while actually loading.
**Validation run:** `flutter test test/widgets/detail/shared_showcase_card_test.dart` passed; `flutter test test/widgets/profile_identity_summary_test.dart` passed after the adjacent likes-sheet/identity fixes; `flutter test test/widgets/detail/shared_showcase_card_test.dart test/widgets/profile_public_package_loading_test.dart test/widgets/profile_identity_summary_test.dart test/widgets/profile_achievements_badges_sections_test.dart` passed (26 tests); scoped `flutter analyze --no-fatal-infos` on touched files passed; `npm run guard:architecture` passed; `npm run verify:all` passed with the known nonfatal `lib/screens/map_screen.dart:5298` `axisAlignment` info.
**Screenshots:** Baseline: `output/playwright/desloppify-polish02-before-desktop-root.png`, `output/playwright/desloppify-polish02-before-mobile-root.png`; after: `output/playwright/desloppify-polish02-after-desktop-root.png`, `output/playwright/desloppify-polish02-after-mobile-root.png`. These are root-route smoke screenshots because local auth/profile seed data was not available for a live profile route; widget/profile tests validate the card behavior directly.
**Follow-up:** Gallery thumbnails, detail media cards, and any remaining non-showcase repeated card families still need adoption with route-specific focus screenshots.

### [POLISH-03] Onboarding topbar icon is pointer-only

**Category:** UI / Accessibility  
**Location:** `lib/widgets/onboarding_topbar_icon.dart`  
**Problem:** Topbar icons use `GestureDetector`, optional tooltip, and an approximately 42px hit area without keyboard/semantic activation.  
**Why it matters:** It misses the 44px baseline and is weak for keyboard/screen-reader users.  
**Recommended change:** Replace with `IconButton` or a shared icon-button primitive with explicit semantic label and 44px minimum.  
**Safe to fix now:** Yes  
**Suggested task size:** Small  
**Recommended model:** GPT-5.4 mini medium  
**Validation required:** Widget tests; no screenshots unless visual dimensions change.  
**Dependencies or blockers:** None  
**Status:** Completed  
**Completion notes:** Updated `OnboardingTopbarIcon` with explicit semantic-label support, a debug assertion requiring either `semanticLabel` or `tooltip`, keyboard activation through `FocusableActionDetector`, and a 44px minimum hit area while preserving the icon-only/no-fill visual treatment.  
**Validation run:** `flutter test test/widgets/onboarding_topbar_icon_test.dart` passed; scoped `flutter analyze --no-fatal-infos lib/widgets/onboarding_topbar_icon.dart test/widgets/onboarding_topbar_icon_test.dart` passed.  
**Screenshots:** Not captured; the widget currently has no `lib/` callsite/route to smoke, and validation is isolated widget-level.  
**Follow-up:** Future onboarding callers should provide `semanticLabel` or a non-empty `tooltip`.

### [POLISH-04] Media/gallery image semantics are incomplete

**Category:** UI / Accessibility  
**Location:** `lib/widgets/common/kubus_cached_image.dart`, `lib/widgets/artwork_gallery_view.dart`, artwork detail cover widgets  
**Problem:** Shared cached images do not pass semantic labels, and gallery thumbnails do not expose selected/index state.  
**Why it matters:** Media-heavy art flows are visually clear but not equally clear to assistive tech.  
**Recommended change:** Add semantic-label plumbing and expose labels like "image 2 of 5, selected" for thumbnails.  
**Safe to fix now:** Yes  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Widget semantics tests and gallery/lightbox screenshots.  
**Dependencies or blockers:** UI screenshots required.  
**Status:** Partially completed
**Completion notes:** Added semantic-label plumbing to `KubusCachedImage` and `DiskCachedArtworkImage`, including loading/error/fallback states. `ArtworkGalleryView` now exposes actionable main-image labels, mobile selected-index announcements, desktop thumbnail index/selected semantics, semantic tap actions, keyboard-friendly `InkWell` thumbnail activation, lightbox current-image labels, and guarded prefetch failures. Mobile and desktop artwork detail routes pass artwork-title context into gallery labels.
**Validation run:** `flutter test test/widgets/common/kubus_cached_image_test.dart test/widgets/artwork_gallery_view_test.dart` passed; scoped `flutter analyze --no-fatal-infos` on touched gallery/image files and tests passed; `npm run verify:all` passed with the known nonfatal `lib/screens/map_screen.dart:5298` `axisAlignment` info.
**Screenshots:** Not captured for this slice. The change is semantics-only at idle and no seeded local artwork-detail route with gallery/lightbox media was available for meaningful before/after screenshots.
**Follow-up:** Add route-level gallery/lightbox screenshots once a seeded artwork media harness exists, then decide whether to mark the screenshot requirement fully satisfied.

### [POLISH-05] Purple and hardcoded status/social colors bypass color roles

**Category:** UI / Theme  
**Location:** `lib/screens/onboarding/onboarding_flow_screen.dart`, `lib/screens/desktop/desktop_home_screen.dart`, `lib/utils/app_color_utils.dart`, profile social chips, artwork archive status UI  
**Problem:** Purple and raw status/social brand colors appear outside documented AI/system exceptions and token roles.  
**Why it matters:** Theme consistency and contrast behavior can drift from the design system.  
**Recommended change:** Map these to theme/role colors or document narrow approved exceptions in a central color-role helper.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Light/dark screenshots for affected screens and color-role unit tests where applicable.  
**Dependencies or blockers:** UI screenshots required.  
**Status:** Deferred  
**Reason:** Color-role cleanup spans onboarding, desktop home, profile chips, and artwork archive/status UI. It needs product/design confirmation for approved purple/social-color exceptions plus light/dark screenshots.  
**Safest next action:** Create a color-role matrix for the cited screens, approve exceptions centrally, then update one screen family per isolated pass.  
**Validation needed later:** Light/dark screenshots for each affected screen and targeted color-role helper tests.

### [POLISH-06] Loading and empty states are not announced consistently

**Category:** UI / Accessibility  
**Location:** `lib/widgets/map/nearby/kubus_nearby_art_panel_states.dart`, `lib/widgets/search/kubus_general_search.dart`, `lib/widgets/empty_state_card.dart`  
**Problem:** Loading indicators and empty-state cards are visually present but lack live-region or semantic wrappers.  
**Why it matters:** Async state changes may be silent to screen-reader users.  
**Recommended change:** Add localized `Semantics(label: ..., liveRegion: true)` around shared loading/error/empty state primitives.  
**Safe to fix now:** Yes  
**Suggested task size:** Small  
**Recommended model:** GPT-5.4 mini medium  
**Validation required:** Semantics tests; screenshots optional.  
**Dependencies or blockers:** None  
**Status:** Completed  
**Completion notes:** Added live-region semantic wrappers to the shared `EmptyStateCard`, nearby art loading/empty states, and search dropdown loading/no-results states. The search empty row now keeps the visible text decorative under a single live announcement node to avoid duplicate screen-reader output.  
**Validation run:** `flutter test test/widgets/empty_state_card_test.dart test/widgets/map/nearby/kubus_nearby_art_panel_interaction_test.dart test/widgets/search/kubus_general_search_test.dart` passed; scoped `flutter analyze --no-fatal-infos` on touched widgets/tests passed with no issues.  
**Screenshots:** Not applicable; semantics-only change with no visual layout changes.  
**Follow-up:** Continue broader accessibility coverage for focusable cards and media/gallery semantics in isolated passes.

### [POLISH-07] Debug logging remains noisy in selected Flutter paths

**Category:** Cleanup / Logging  
**Location:** Many direct `debugPrint` calls in `lib/**`, including map/profile/community/service paths  
**Problem:** Some logs are direct `debugPrint` calls instead of `AppConfig.debugPrint` or `kDebugMode` guards.  
**Why it matters:** Release polish and diagnostic signal can degrade, and the repo rule is easy for future agents to miss because violations remain.  
**Recommended change:** Add a mechanical guard first, then clean direct logs in focused domains.  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.4 mini medium  
**Validation required:** Static guard and `flutter analyze`.  
**Dependencies or blockers:** Should follow [HARNESS-01].  
**Status:** Partially completed  
**Completion notes:** Added `AK-GUARD-008` to `scripts/architecture_guard.mjs` to enforce the current unqualified `debugPrint` debt ceiling. Second pass removed the no-value `NotificationProvider` constructor log, removed noisy avatar/profile payload logs, centralized selected glass/wallet/profile-package/Solana logs behind `AppConfig.debugPrint`, suppressed routine glass diagnostics under Flutter test bindings, and lowered the direct `debugPrint` budget from `814` to `790`. Third pass removed backend API achievement fetch-start chatter, removed normal profile payload key dumps, replaced full profile-save payload logging with a field-name-only message, centralized selected backend API diagnostics, and lowered the budget to `778`.
**Validation run:** `node --check scripts/architecture_guard.mjs`, `npm run guard:architecture`, and `npm run verify:architecture` passed in the first pass. Second pass `npm run guard:architecture` passed at `790/790`, scoped `flutter analyze --no-fatal-infos` on touched logging files passed, and `npm run verify:all` passed with the known nonfatal `lib/screens/map_screen.dart:5298` `axisAlignment` info. Third pass `npm run guard:architecture` passed at `778/778`, scoped `flutter analyze --no-fatal-infos lib/services/backend_api_service.dart lib/services/backend_api_service_profile_helpers.dart` passed, and `npm run verify:all` passed with the same known analyzer info.
**Screenshots:** Not applicable.  
**Follow-up:** The actual conversion of remaining direct logs remains deferred to isolated domain passes. Current verify output still includes centralized debug output from wallet/Solana test fallbacks, profile-package telemetry, debug-token issuance, and secure-storage timeouts; lower `directDebugPrintBudget` after each cleanup.

## Harness engineering alignment

### What the repo does well

- Strong repo-local intent: root and layer `AGENTS.md` files define feature flags, provider-first state, theme roles, storage/IPFS helpers, OrbitDB sync, no-legacy policy, and HA deployment contracts.
- Real validation exists: Flutter analyze/test/build, backend lint/Jest, focused map/security/profile tests, and CI workflows.
- Security baseline exists: `backend/art.kubus-threat-model.md` is concise and operational.
- UI docs and screenshots exist under `docs/`, and map architecture has dedicated refactor notes and tests.
- Backend has meaningful boundary tests for CORS, auth, uploads, public sync, and HA/writable routes.

### Gaps and weaknesses

- Architecture and taste rules are mostly prose rather than mechanical gates.
- Validation is not exposed through one stable root command; local docs hardcode machine-specific Flutter paths.
- Some docs are stale or misleading (`npm run test:coverage`, `flutter test integration_test/`, screenshot placeholders).
- Playwright/browser QA exists but lives under `output/playwright` rather than a first-class harness path.
- The backend submodule/checkout contract is ambiguous in CI; backend checks can be skipped when backend sources are absent.
- Root and layer `AGENTS.md` files are useful but large and partly duplicative.

### Top 5 changes for better agent-first engineering outcomes

1. Add root `verify:flutter`, `verify:backend`, `verify:all`, and `qa:web` commands that future agents can run without reading multiple docs.
2. Add repo-local architecture guard scripts/tests for forbidden direct HTTP in UI/provider layers, direct `debugPrint`, hardcoded gateway URLs, TODO/FIXME, map-screen controller/timer ownership, and public mutations without sync hooks.
3. Move Playwright/browser QA from `output/playwright` into `scripts/qa` with README, package scripts, and CI artifacts for screenshots/videos.
4. Convert root `AGENTS.md` into a shorter map plus hard non-negotiables, with deeper rules indexed in docs and checked by a docs freshness script.
5. Clarify backend submodule validation in docs and CI so agents know whether backend tests actually ran or were intentionally skipped.

### [HARNESS-01] Add mechanical architecture guard checks

**Alignment area:** Architecture enforcement / Validation / Entropy control  
**Location:** Missing root guard script/test; `analysis_options.yaml`; `backend/.eslintrc.cjs`; existing `test/architecture/**`  
**Current state:** Guardrails prohibit many patterns, but lints are mostly stock and existing violations still pass.  
**Gap:** Future agents can add direct HTTP, noisy logs, hardcoded gateways, map-screen lifecycle logic, or unsynced public mutations without a fast failing check.  
**Why it matters for agents:** Mechanical checks preserve product intent better than prose alone.  
**Recommended change:** Add a repo-local guard script and/or tests for the most important `AGENTS.md` contracts.  
**Priority:** Critical  
**Safe to fix now:** Yes  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** New guard command passes and fails against known seeded examples in tests.  
**Status:** Completed  
**Completion notes:** Added root `npm run guard:architecture` backed by `scripts/architecture_guard.mjs`. The guard currently enforces no `dart:html` imports, no direct `package:http` imports from screens/widgets, no retired `cloudflare-ipfs.com` runtime config drift, no `debugPrint('DEBUG: ...')` logs, no direct MapLibre layer mutations from canonical map screens, and explicit limits on `multer.memoryStorage()` route uploads. Added seeded backend Jest coverage for passing and failing fixtures.  
**Validation run:** `npm run guard:architecture` passed; `npx jest --runInBand architectureGuardScript.test.js` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Broader route CORS, map lifecycle, public-sync, and general debug logging guards remain deferred until existing violations are cleaned or explicitly allowlisted.

### [HARNESS-02] Add stable root verification commands

**Alignment area:** Feedback loops / Reproducible workflows  
**Location:** `package.json`, `docs/LOCAL_VERIFICATION.md`, `run_tests.bat`, `backend/package.json`  
**Current state:** Root package only exposes version scripts; docs contain absolute local Flutter paths; backend default `npm test` writes coverage.  
**Gap:** Agents must infer command sets and local path assumptions.  
**Why it matters for agents:** Reliable, single-command feedback reduces failed validation and inconsistent handoffs.  
**Recommended change:** Add root `verify:flutter`, `verify:backend`, `verify:all`, and targeted variants; update docs to reference those commands.  
**Priority:** Medium  
**Safe to fix now:** Yes  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.4 mini medium  
**Validation required:** Run each new script locally.  
**Status:** Completed  
**Completion notes:** Added `scripts/verify.mjs`, root `verify:*` npm scripts, and a root-relative `run_tests.bat` wrapper. Updated `docs/LOCAL_VERIFICATION.md` to use stable root commands and `FLUTTER_BIN` instead of machine-specific Flutter paths. The default root commands run architecture guard, Flutter analyze with `--no-fatal-infos`, curated Flutter smoke tests, backend lint, and backend smoke tests without coverage writes.  
**Validation run:** `node ./scripts/verify.mjs help`, `npm run verify:architecture`, `npm run verify:flutter:analyze`, `npm run verify:flutter:smoke`, `npm run verify:backend:lint`, `npm run verify:backend:smoke`, and `npm run verify:all` passed. Direct full-suite exploratory runs of `flutter test` and `npx jest --runInBand` failed on existing unrelated suites, so they are documented as non-default investigative commands until stabilized.  
**Screenshots:** Not applicable.  
**Follow-up:** Clean existing full-suite failures and the `map_screen.dart` `axisAlignment` info if CI-strict `flutter analyze` should become the default local gate.

### [HARNESS-03] Promote Playwright QA into a first-class harness

**Alignment area:** UI validation / Reviewability / Feedback loops  
**Location:** `output/playwright/**`, missing `scripts/qa` README/script, `.github/workflows/ci.yml`  
**Current state:** Playwright scripts and diagnostics exist under `output/playwright`, which reads as generated output rather than maintained QA.  
**Gap:** Visual/runtime browser checks are ad hoc and not part of the main harness.  
**Why it matters for agents:** UI changes need repeatable screenshots and smoke checks.  
**Recommended change:** Move or copy maintained QA scripts to `scripts/qa`, add package scripts, and upload screenshots/videos as CI artifacts when run.  
**Priority:** Medium  
**Safe to fix now:** Needs isolation  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.5 high  
**Validation required:** Run browser smoke locally and verify artifact paths.  
**Status:** Completed  
**Completion notes:** Added first-class Playwright QA under `scripts/qa/`, root `qa:web`, `qa:web:proxy`, and `qa:web:install` scripts, artifact ignore rules, and local verification docs. The smoke starts a repo-local SPA proxy, stubs the Google Identity script to avoid third-party script flake, captures desktop/mobile screenshots and JSON diagnostics, and fails on missing Flutter runtime markers or page errors. Fixed `web/index.html` build-version bootstrap so Flutter's service-worker deprecation replacement no longer breaks inline JavaScript after `flutter build web`.  
**Validation run:** `npm run qa:web:install` passed; `node --check scripts/qa/dev_spa_proxy.mjs`, `node --check scripts/qa/web_runtime_smoke.mjs`, `node --check build/web/flutter_bootstrap.js`, `node --check build/web/main.dart.js`, and `node --check build/web/local/maplibre-gl/maplibre-gl-csp.js` passed; `C:\dev\flutter\bin\flutter.bat build web --release` passed with existing Wasm dry-run dependency warnings; `npm run qa:web` passed; `npm run verify:all` passed with the known `lib/screens/map_screen.dart:5298` analyzer info.  
**Screenshots:** `output/playwright/artifacts/web-smoke/desktop-home.png`, `output/playwright/artifacts/web-smoke/mobile-home.png`; diagnostics in adjacent JSON files.  
**Follow-up:** Add CI artifact upload once a CI workflow policy is selected.

### [HARNESS-04] Add docs and AGENTS freshness checks

**Alignment area:** Repo knowledge / Documentation freshness / Entropy control  
**Location:** `AGENTS.md`, `lib/**/AGENTS.md`, `backend/**/AGENTS.md`, `docs/**`, `backend/README.md`  
**Current state:** Docs are useful but stale commands and duplicated guidance exist.  
**Gap:** No recurring check catches stale commands, duplicate instruction drift, mojibake, or placeholder text.  
**Why it matters for agents:** Stale docs mislead agents and create expensive false starts.  
**Recommended change:** Add `docs:doctor` or `repo:doctor` to check stale command references, missing docs indexes, temp files, AGENTS drift, and broken links.  
**Priority:** Medium  
**Safe to fix now:** Yes  
**Suggested task size:** Medium  
**Recommended model:** GPT-5.4 mini medium  
**Validation required:** New doctor command passes and is documented.  
**Status:** Completed  
**Completion notes:** Added `scripts/docs_doctor.mjs`, root `docs:doctor` and `verify:docs` scripts, and included docs freshness in `verify:all`. The doctor verifies required root/lib/backend `AGENTS.md` files, local verification docs, key cross-file guidance, generated Playwright artifact hygiene, and local Markdown links in the docs index. Updated `docs/LOCAL_VERIFICATION.md` and `docs/README.md` so the command is discoverable.  
**Validation run:** `node --check scripts/docs_doctor.mjs`, `node --check scripts/verify.mjs`, `npm run docs:doctor`, `npm run verify:docs`, and `npm run verify:all` passed. `verify:all` still reports the known `lib/screens/map_screen.dart:5298` analyzer info.  
**Screenshots:** Not applicable.  
**Follow-up:** Expand the doctor after additional docs cleanup to cover broader docs, stale command examples, and AGENTS drift rules.

### [HARNESS-05] Clarify backend submodule and CI skip contract

**Alignment area:** Task isolation / CI / Validation boundaries  
**Location:** `.gitmodules`, `.github/workflows/ci.yml`, `docs/LOCAL_VERIFICATION.md`, `backend/README.md`  
**Current state:** Backend appears as a submodule; CI checks out with `submodules: false` and skips backend checks if `backend/package.json` is absent.  
**Gap:** Full-stack agents may assume backend tests ran when CI skipped them.  
**Why it matters for agents:** Accurate validation reporting prevents false confidence.  
**Recommended change:** Document the root/backend contract and add a root CI/status check that reports backend presence, SHA/status, and skipped validation explicitly.  
**Priority:** Medium  
**Safe to fix now:** Yes  
**Suggested task size:** Small  
**Recommended model:** GPT-5.4 mini medium  
**Validation required:** CI dry-read and local script output.  
**Status:** Completed  
**Completion notes:** Added `scripts/backend_status.mjs`, root `backend:status` and `verify:backend-status` scripts, and wired backend status into `verify:backend` before lint/tests. Updated CI to use the same script for backend presence detection and to print the skip reason plus submodule status when backend validation is skipped. Updated local verification docs and docs doctor script to include the backend status contract.  
**Validation run:** `node --check scripts/backend_status.mjs`, `node --check scripts/docs_doctor.mjs`, `node --check scripts/verify.mjs`, `npm run backend:status`, `npm run docs:doctor`, `npm run verify:backend-status`, and `npm run verify:all` passed. Local status reported backend package present, HEAD `1a2e1b9`, and dirty worktree from this cleanup branch.  
**Screenshots:** Not applicable.  
**Follow-up:** If CI should run backend checks from the parent repo without a pre-populated submodule, change checkout policy to initialize the backend submodule instead of only reporting a skip.

## Suggested cleanup sequence

1. [CRIT-01] Upload folder metadata can escape the upload root
2. [CRIT-02] Unsigned wallet bootstrap can mint wallet-scoped JWTs
3. [CRIT-03] Email and Google onboarding can bind wallet-owned records without wallet proof
4. [CRIT-04] Wallet-sensitive mutations accept lower-assurance JWTs
5. [CRIT-05] Admin moderation updates bypass public sync
6. [CRIT-06] Static upload validation can publish active or spoofed content
7. [CRIT-07] Message multipart endpoints lack file limits and filters
8. [HARNESS-01] Add mechanical architecture guard checks
9. [MED-01] Client-side Pinata secret upload path
10. [MED-02] Media proxy allowlist defaults open
11. [MED-03] Institution provider parses backend events into a legacy model
12. [MED-04] Saved/bookmark mutations have duplicate write paths
13. [MED-05] Marker owner identity remains ambiguous
14. [MED-06] Community mutations bypass provider-owned state
15. [MED-07] Profile preferences persist optimistically without visible failure state
16. [MED-08] Domain models and providers bypass transport boundaries
17. [MED-09] Sticky API-unavailable flags hide backend recovery
18. [MED-10] API error contracts are inconsistent
19. [MED-11] Map screens still own lifecycle and business logic
20. [MED-12] Large route/service/screen monoliths slow review and increase regression risk
21. [MED-13] Reusable services depend on `BuildContext`
22. [MED-14] Legacy API shims remain despite pre-launch no-legacy policy
23. [HARNESS-02] Add stable root verification commands
24. [HARNESS-03] Promote Playwright QA into a first-class harness
25. [HARNESS-04] Add docs and AGENTS freshness checks
26. [HARNESS-05] Clarify backend submodule and CI skip contract
27. [POLISH-01] Map accessibility labels expose internal keys
28. [POLISH-02] Repeated tappable cards lack consistent keyboard and focus semantics
29. [POLISH-03] Onboarding topbar icon is pointer-only
30. [POLISH-04] Media/gallery image semantics are incomplete
31. [POLISH-05] Purple and hardcoded status/social colors bypass color roles
32. [POLISH-06] Loading and empty states are not announced consistently
33. [POLISH-07] Debug logging remains noisy in selected Flutter paths

## Execution protocol

For each selected task:

1. Re-read this file and the selected task.
2. Inspect only relevant files.
3. Produce a brief task plan with files, risk, validation, and screenshot needs.
4. Make minimal changes only for the selected task.
5. Run the smallest relevant validation first, then broader checks as needed.
6. Capture baseline and after screenshots for any UI-visible change.
7. Update the selected item status with completion notes, validation run, screenshots, and follow-up.
8. Add the completed item to `## Completed tasks`.
9. Run `git status` and `git diff --stat` after each meaningful task.

## Completed tasks

### [AUDIT-01] Desloppify audit

**Status:** Completed  
**Completion notes:** Full read-only audit completed with required reviewer slices and this backlog created.  
**Validation run:** Backend lint passed; Flutter analyze passed via `C:\dev\flutter\bin\flutter.bat`; focused Flutter map/tutorial tests passed; targeted backend media/CORS/profile tests passed.  
**Screenshots:** Not applicable; no UI code changed during audit.  
**Follow-up:** Begin execution at [CRIT-01].

### [CRIT-01] Upload folder metadata can escape the upload root

**Status:** Completed  
**Completion notes:** Hardened `StorageService.uploadToHTTP()` against traversal, absolute paths, encoded dot segments, and final-path escape; removed client control over upload destination folders in single upload, multiple upload, and profile avatar upload routes.  
**Validation run:** `npx jest --runInBand storageServiceUploadPath.test.js uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** Continue with auth-contract isolation for [CRIT-02].

### [CRIT-02] Unsigned wallet bootstrap can mint wallet-scoped JWTs

**Status:** Completed  
**Completion notes:** Required wallet challenge/signature proof on `POST /api/auth/register` before persistence or token creation, and changed successful register responses from `wallet_bootstrap` to `wallet_signature`.  
**Validation run:** `npx jest --runInBand authFallbackUuid.test.js authSecureAccount.test.js authChallengeLimits.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** Address `/bind-wallet` and account-linked wallet authority under [CRIT-03]/[CRIT-04].

### [CRIT-03] Email and Google onboarding can bind wallet-owned records without wallet proof

**Status:** Completed  
**Completion notes:** Required signed wallet challenges for wallet-bearing email registration, Google login/code login, and bind-wallet requests; preserved already wallet-signed same-wallet sessions; kept returned bind-wallet tokens at their original account auth level instead of silently minting wallet-signed authority.  
**Validation run:** `npx jest --runInBand authSecureAccount.test.js authGoogleWalletIdentity.test.js authBindWalletAccountLink.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** Continue with route-level authorization hardening in [CRIT-04].

### [CRIT-04A] Wallet-signed enforcement for profile and upload writes

**Status:** Completed  
**Completion notes:** Required wallet-signed tokens for profile create/update, profile deletion, profile avatar upload, and generic upload writes.  
**Validation run:** `npx jest --runInBand uploadWalletSignedAuth.test.js uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js profilesMediaPersistence.test.js profilesRoleFlags.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** Remaining [CRIT-04] marker and messaging authorization policy continued under [CRIT-04B].

### [CRIT-04B] Marker write assurance policy

**Status:** Partially completed
**Completion notes:** Required wallet-signed tokens for marker create/update/delete and marker claim submit/review routes. Read routes, optional view/interact routes, and messaging routes were not changed.
**Validation run:** `npx jest --runInBand artMarkersWriteAssurance.test.js` passed (6 tests); `npx jest --runInBand artMarkersWriteAssurance.test.js artMarkersCreateIdempotency.test.js artMarkersUpdatePersistence.test.js artMarkersClaimsAuth.test.js markerOwnership.test.js` passed (25 tests); `npm run lint` passed in `backend/`.
**Screenshots:** Not applicable.
**Follow-up:** Messaging write assurance remains deferred until the route matrix defines which chat/collaboration flows require wallet-signed authority versus account-level authentication.

### [CRIT-05A] Admin moderation public sync hooks

**Status:** Completed  
**Completion notes:** Added focused coverage for post-commit admin moderation sync hooks and mocked public sync in adjacent admin moderation route tests to keep validation deterministic. Supported mappings now cover profiles, community posts, parent posts after comment moderation, artworks, collections, markers, AR markers, and exhibitions.  
**Validation run:** `npx jest --runInBand adminModerationPublicSync.test.js adminModerationReportsTicketsRoutes.test.js adminModerationMediaFields.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** Remaining event moderation publication/snapshot contract deferred below.

### [CRIT-06] Static upload validation can publish active or spoofed content

**Status:** Completed  
**Completion notes:** Introduced `backend/src/utils/uploadFileValidation.js`, hardened generic upload and avatar upload routes to require extension/MIME/content agreement, made SVG avatar handling PNG-only with active SVG rejection, and added explicit `nosniff` headers to static upload responses.  
**Validation run:** `npx jest --runInBand uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js uploadStaticCors.test.js storageServiceUploadPath.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** Review `backend/src/routes/artworks.js` multipart upload validation separately under [CRIT-06B].

### [CRIT-07] Message multipart endpoints lack file limits and filters

**Status:** Completed  
**Completion notes:** Added size/count/field/part limits to message multipart parsing, added reject-before-storage checks for unsupported attachment types and bad content signatures, and moved conversation avatar storage to the shared avatar rasterization flow.  
**Validation run:** `npx jest --runInBand messagesRoutesAuth.test.js` passed; `npx jest --runInBand messagesRoutesAuth.test.js uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** None.

### [CRIT-06B] Artwork multipart upload validation still uses MIME-or-extension checks

**Status:** Completed
**Completion notes:** Replaced artwork route-local MIME-or-extension filtering with shared artwork-specific declaration and magic-byte validation for cover images and GLB/glTF/USDZ models. Artwork storage metadata now uses the validated MIME type and extension.
**Validation run:** `npx jest --runInBand artworksUploadValidation.test.js` passed; `npx jest --runInBand artworksUploadValidation.test.js uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js uploadStaticCors.test.js storageServiceUploadPath.test.js messagesRoutesAuth.test.js` passed (84 tests); `npx jest --runInBand artworksUploadValidation.test.js artworksCreateGalleryMetaJson.test.js` passed; `npm run lint` passed in `backend/`.
**Screenshots:** Not applicable; backend validation-only change.
**Follow-up:** None for artwork multipart media validation.

### [HARNESS-01] Mechanical architecture guard checks

**Status:** Completed  
**Completion notes:** Added `scripts/architecture_guard.mjs`, root `npm run guard:architecture`, and `backend/__tests__/architectureGuardScript.test.js` seeded pass/fail coverage. The first guard set catches deprecated web imports, screen/widget HTTP drift, retired IPFS gateway runtime drift, noisy `DEBUG` debugPrints, direct MapLibre layer mutations in map screens, and unbounded memory multipart routes.  
**Validation run:** `npm run guard:architecture` passed; `npx jest --runInBand architectureGuardScript.test.js` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Add more guard rules after existing CORS wildcard, map lifecycle, public sync, and broad logging debt is cleaned or allowlisted.

### [MED-01] Client-side Pinata secret upload path

**Status:** Completed  
**Completion notes:** Removed Flutter Pinata API/secret configuration and direct Pinata multipart upload. AR model uploads now use backend-managed upload storage with a normalized target storage field, and architecture coverage guards against reintroducing client-side Pinata credential tokens. `ARContentService.uploadContent()` now returns a backend URL immediately and leaves `cid` null unless a future backend result contract exposes one.  
**Validation run:** Pinata credential token scan across `lib/` returned no matches; `flutter test test/architecture/client_pinata_secret_guard_test.dart test/services/backend_api_upload_compression_test.dart` passed; scoped touched-file `flutter analyze` passed; `npm run guard:architecture` passed. Full `flutter analyze` remains blocked by unrelated `lib/screens/map_screen.dart:5298 deprecated_member_use`.  
**Screenshots:** Not applicable.  
**Follow-up:** Define a backend-visible IPFS pin result/status flow if AR screens need to display CIDs after async pinning.

### [MED-02] Media proxy allowlist defaults open

**Status:** Completed  
**Completion notes:** Required explicit `MEDIA_PROXY_ALLOWED_HOSTS` in production and preserved dev/test permissiveness. Added media proxy regression coverage for production misconfiguration, allowed hosts, disallowed hosts, private DNS results, and redirect revalidation.  
**Validation run:** `npx jest --runInBand mediaProxyRoutes.test.js` passed; `npm run lint` passed in `backend/`.  
**Screenshots:** Not applicable.  
**Follow-up:** Set the final production host allowlist in deployment environment config.

### [MED-03] Institution provider parses backend events into a legacy model

**Status:** Completed  
**Completion notes:** Added `Event.fromBackendJson`/`Event.fromKubusEvent` adapter logic and switched `InstitutionProvider` backend event refresh to that adapter. Backend-shaped `/api/events` payloads now parse without throwing on snake_case fields or missing legacy-only fields.  
**Validation run:** `flutter test test/models/institution_event_adapter_test.dart test/providers/institution_provider_backend_events_test.dart` passed; combined smoke with `test/services/storage_config_test.dart` passed; scoped touched-file `flutter analyze` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Retire the legacy institution `Event` model in a later event-domain ownership pass.

### [MED-04] Saved/bookmark mutations have duplicate write paths

**Status:** Completed  
**Completion notes:** Collapsed frontend artwork saved toggles onto `SavedItemsProvider`/`/api/saved`, removed the old Flutter artwork bookmark API methods, and added a regression test proving artwork save/unsave uses the saved-items repository path.  
**Validation run:** `rg -n "bookmarkArtwork\(|unbookmarkArtwork\(" lib test --glob "*.dart"` returned no matches; `flutter test test/providers/artwork_provider_saved_items_source_test.dart test/providers/saved_items_provider_all_types_test.dart test/providers/artwork_provider_inflight_dedupe_test.dart test/art/art_detail_comments_test.dart test/art/art_detail_attendance_confirm_test.dart` passed; scoped touched-file `flutter analyze` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Backend `/api/artworks/:id/bookmark` aliases still need an external-caller decision before removal.

### [MED-05] Marker owner identity remains ambiguous

**Status:** Completed  
**Completion notes:** Added additive canonical marker owner wallet/user fields in backend JSON, API responses, public sync docs, public registry selection, Flutter marker parsing, and map ownership helpers. Claim submission now stores owner wallet/user id separately, and claim approval transfers to the claimant wallet before falling back to claimant user id.  
**Validation run:** `npx jest --runInBand markerOwnership.test.js artMarkersCreateIdempotency.test.js artMarkersUpdatePersistence.test.js artMarkersClaimsAuth.test.js publicSyncService.test.js publicObjectRegistryService.test.js` passed; `npm run lint` passed in `backend/`; `flutter test test/models/art_marker_owner_wallet_test.dart test/features/map/shared/map_marker_owner_helper_test.dart test/models/art_marker_type_parsing_test.dart test/services/backend_api_service_marker_update_test.dart` passed; scoped touched-file `flutter analyze` passed; `npm run guard:architecture` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** First-class indexed marker owner columns remain a later schema decision; no schema snapshots were changed in this task.

### [MED-06] Community mutations bypass provider-owned state

**Status:** Completed  
**Completion notes:** Centralized non-group post creation, repost create/delete, and post delete through `CommunityInteractionsProvider`; mobile and desktop screens no longer call those backend mutation endpoints directly.  
**Validation run:** Provider mutation tests, adjacent community regression tests, scoped touched-file `flutter analyze`, and `npm run guard:architecture` passed.  
**Screenshots:** Not applicable; no visual/layout changes were made.  
**Follow-up:** Manual auth-backed mobile/desktop community mutation smoke remains useful when a local backend session is available.

### [MED-07] Profile preferences persist optimistically without visible failure state

**Status:** Completed  
**Completion notes:** Added retryable profile preference sync state to `ProfileProvider`, guarded stale preference-save completions, and made the mobile privacy dialog report backend sync failure with a retry action instead of always showing the success toast.  
**Validation run:** `flutter test test/providers/profile_provider_media_test.dart`; `flutter test test/privacy/privacy_settings_parity_test.dart`; scoped `flutter analyze lib/providers/profile_provider.dart lib/screens/settings_screen.dart test/providers/profile_provider_media_test.dart`; `npm run guard:architecture` all passed.  
**Screenshots:** Not applicable; no visual layout changes.  
**Follow-up:** Consider a desktop inline sync-status affordance as a separate screenshot-backed UI polish task.

### [MED-08] Domain models and providers bypass transport boundaries

**Status:** Completed  
**Completion notes:** Centralized storage stats and avatar URL verification in `BackendApiService`, removed raw HTTP imports from profile/provider/model hotspots, removed `BackendApiService` from `UserProfile`, and extended the architecture guard for model/provider transport boundaries.  
**Validation run:** New media-probe/model boundary tests plus affected provider tests passed; scoped touched-file `flutter analyze` passed; `npm run guard:architecture` passed; backend architecture guard Jest fixture passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Consider making cover upload part of `ProfileBackendApi` to remove the remaining concrete fallback in `ProfileProvider.uploadProfileCoverBytes()`.

### [MED-09] Sticky API-unavailable flags hide backend recovery

**Status:** Completed  
**Completion notes:** Provisional events/institutions/exhibitions failures no longer pin the app to `false`; later requests retry normally and successful responses restore the availability getter to `true`.  
**Validation run:** Provider recovery tests for events and exhibitions passed, adjacent institution event refresh and media probe tests passed, scoped analysis passed, and `npm run guard:architecture` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Keep any future feature-disable behavior behind explicit config flags rather than inferred transient 404/400 responses.

### [MED-13A] Search service context boundary

**Status:** Completed  
**Completion notes:** Moved search provider/localization capture out of `SearchService` and into `KubusSearchController`; search service local fallback now consumes explicit snapshot lists instead of reading providers through `BuildContext`.  
**Validation run:** `flutter test test/services/search_service_test.dart test/widgets/search/kubus_general_search_test.dart test/widgets/search/kubus_search_bar_map_glass_test.dart test/widgets/search/kubus_search_results_overlay_interaction_test.dart` passed; scoped `flutter analyze` for touched search files/tests passed; `npm run guard:architecture` passed.  
**Screenshots:** Not applicable; no visual or layout changes.  
**Follow-up:** Complete [MED-13B] for auth/wallet/share context removal in isolated tasks.

### [MED-14] Legacy API shims remain despite pre-launch no-legacy policy

**Status:** Completed  
**Completion notes:** Migrated email preferences to `/api/profiles/me/preferences`, updated the Flutter client, removed the unused `/api/users/:id` client method, unmounted `/api/users`, and deleted the legacy `backend/src/routes/users.js` router.  
**Validation run:** Static `/api/users|usersRouter|routes/users|getUserProfile(` scan across backend source/tests and Flutter code returned no matches; `npx jest --runInBand userPreferencesRoutes.test.js publicWalletLeakRoutes.test.js` passed; `npm run lint` passed in `backend/`; scoped Flutter settings tests/analyze passed; `npm run guard:architecture` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** None for local code; external pre-launch clients, if any, must use `/api/profiles/*`.

### [HARNESS-02] Stable root verification commands

**Status:** Completed  
**Completion notes:** Added `scripts/verify.mjs`, root `verify`, `verify:all`, `verify:flutter`, `verify:backend`, smoke/analyze/lint variants, and converted `run_tests.bat` to a root-relative `npm run verify:all` wrapper. Updated `docs/LOCAL_VERIFICATION.md` to document stable root commands, `FLUTTER_BIN`, smoke scope, and full-suite caveats.  
**Validation run:** `node ./scripts/verify.mjs help`, `npm run verify:architecture`, `npm run verify:flutter:analyze`, `npm run verify:flutter:smoke`, `npm run verify:backend:lint`, `npm run verify:backend:smoke`, and `npm run verify:all` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Full direct `flutter test` and `npx jest --runInBand` remain unstable on existing unrelated failures and should be stabilized before being promoted to default root gates.

### [HARNESS-03] Promote Playwright QA into a first-class harness

**Status:** Completed  
**Completion notes:** Added maintained Playwright QA package/scripts under `scripts/qa`, root `qa:web*` scripts, artifact ignore rules, and local verification docs. The harness serves `build/web`, stubs Google Identity for deterministic browser smoke, captures desktop/mobile screenshots plus JSON diagnostics, and gates on Flutter runtime markers/page errors. Fixed `web/index.html` service-worker version interpolation so generated web builds no longer produce `Unexpected identifier 's'` parse errors.  
**Validation run:** `npm run qa:web:install` passed; JS syntax checks passed for the QA scripts and built web JS; `C:\dev\flutter\bin\flutter.bat build web --release` passed with existing Wasm dry-run warnings; `npm run qa:web` passed; `npm run verify:all` passed with the known `axisAlignment` analyzer info.  
**Screenshots:** `output/playwright/artifacts/web-smoke/desktop-home.png`, `output/playwright/artifacts/web-smoke/mobile-home.png`.  
**Follow-up:** Wire QA artifacts into CI under a separate CI policy task.

### [HARNESS-04] Add docs and AGENTS freshness checks

**Status:** Completed  
**Completion notes:** Added `scripts/docs_doctor.mjs`, root `docs:doctor` and `verify:docs` scripts, and wired docs checks into `verify:all`. Updated local verification docs and docs index so the command is easy to find.  
**Validation run:** `node --check scripts/docs_doctor.mjs`, `node --check scripts/verify.mjs`, `npm run docs:doctor`, `npm run verify:docs`, and `npm run verify:all` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Broaden the doctor to more docs once stale examples are cleaned or intentionally allowlisted.

### [HARNESS-05] Clarify backend submodule and CI skip contract

**Status:** Completed  
**Completion notes:** Added root backend status reporting through `scripts/backend_status.mjs`, exposed it as `backend:status` and `verify:backend-status`, and made `verify:backend` print backend availability/SHA/dirty state before lint/tests. CI now uses the same script to decide whether backend checks can run and logs the explicit skip reason plus submodule status.  
**Validation run:** `node --check scripts/backend_status.mjs`, `node --check scripts/docs_doctor.mjs`, `node --check scripts/verify.mjs`, `npm run backend:status`, `npm run docs:doctor`, `npm run verify:backend-status`, and `npm run verify:all` passed.  
**Screenshots:** Not applicable.  
**Follow-up:** Initialize backend submodules in CI if skipped backend validation should become impossible.

### [POLISH-01] Map accessibility labels expose internal keys

**Status:** Completed  
**Completion notes:** Replaced internal map semantics labels with user-facing/localized labels for search, primary controls, desktop map panels, and discovery idle card. Excluded the decorative nearby-sheet handle from semantics and added focused semantics regression coverage.  
**Validation run:** Focused map/nearby widget tests passed; old-label static scan in touched map files returned no matches; scoped `flutter analyze --no-fatal-infos` passed with the known `axisAlignment` analyzer info.  
**Screenshots:** Not applicable.  
**Follow-up:** Continue broader accessibility work under the remaining polish items.

### [POLISH-02] Repeated tappable cards lack consistent keyboard and focus semantics

**Status:** Partially completed
**Completion notes:** Added shared button semantics, Enter/Space keyboard activation, and hover/focus styling to tappable `SharedShowcaseCard`s. Routed mobile profile saved/showcase and public-profile showcase cards through that shared `onTap` path. Fixed adjacent profile UX issues found during validation: likes-sheet modal height overflow, unnecessary likes-row fallback avatar fetches, social identity user-id/wallet confusion, hyphenated username preservation, and idle avatar shimmer tickers.
**Validation run:** `flutter test test/widgets/detail/shared_showcase_card_test.dart` passed; `flutter test test/widgets/profile_identity_summary_test.dart` passed; combined `flutter test test/widgets/detail/shared_showcase_card_test.dart test/widgets/profile_public_package_loading_test.dart test/widgets/profile_identity_summary_test.dart test/widgets/profile_achievements_badges_sections_test.dart` passed (26 tests); scoped touched-file `flutter analyze --no-fatal-infos` passed; `npm run guard:architecture` passed; `npm run verify:all` passed with the known nonfatal `lib/screens/map_screen.dart:5298` analyzer info.
**Screenshots:** `output/playwright/desloppify-polish02-before-desktop-root.png`, `output/playwright/desloppify-polish02-before-mobile-root.png`, `output/playwright/desloppify-polish02-after-desktop-root.png`, `output/playwright/desloppify-polish02-after-mobile-root.png`. Root-route smoke only; no seeded live profile route was available.
**Follow-up:** Gallery/media/detail card families still need a dedicated adoption pass with route-specific before/after focus screenshots.

### [POLISH-03] Onboarding topbar icon is pointer-only

**Status:** Completed  
**Completion notes:** Added semantic-label support, keyboard activation, and a 44px minimum hit area to `OnboardingTopbarIcon` while preserving the existing icon-only visual styling.  
**Validation run:** `flutter test test/widgets/onboarding_topbar_icon_test.dart` passed; scoped `flutter analyze --no-fatal-infos` on the widget and test passed.  
**Screenshots:** Not captured; this isolated widget has no current app route/callsite in `lib/`.  
**Follow-up:** None beyond requiring labels for future callers.

### [POLISH-06] Loading and empty states are not announced consistently

**Status:** Completed  
**Completion notes:** Added localized live-region announcements for shared empty, nearby loading/empty, and search loading/no-results states. Added semantics tests that assert the live-region flag with Flutter's current `flagsCollection` API.  
**Validation run:** `flutter test test/widgets/empty_state_card_test.dart test/widgets/map/nearby/kubus_nearby_art_panel_interaction_test.dart test/widgets/search/kubus_general_search_test.dart` passed; scoped `flutter analyze --no-fatal-infos` on touched widgets/tests passed with no issues.  
**Screenshots:** Not applicable.  
**Follow-up:** None for this scoped primitive pass.

### [POLISH-07] Debug logging remains noisy in selected Flutter paths

**Status:** Partially completed  
**Completion notes:** Added a CI-facing architecture guard budget for unqualified `debugPrint` calls so the existing logging debt cannot grow during future agent work. Second pass removed the no-value notification constructor log and noisy avatar/profile diagnostics, centralized selected glass/wallet/profile-package/Solana logs, suppressed routine glass diagnostics under Flutter test bindings, and lowered the budget from `814/814` to `790/790`. Third pass removed achievement fetch-start logs and profile key dumps from `BackendApiService`, replaced full profile-save payload logging with key-only diagnostics, centralized selected backend API debug logs, and lowered the budget to `778/778`.
**Validation run:** `node --check scripts/architecture_guard.mjs`, `npm run guard:architecture`, and `npm run verify:architecture` passed in the first pass; second pass `npm run guard:architecture` passed at `790/790`, scoped touched-file `flutter analyze --no-fatal-infos` passed, and `npm run verify:all` passed with the known nonfatal `lib/screens/map_screen.dart:5298` analyzer info. Third pass `npm run guard:architecture` passed at `778/778`, scoped `flutter analyze --no-fatal-infos lib/services/backend_api_service.dart lib/services/backend_api_service_profile_helpers.dart` passed, and `npm run verify:all` passed with the same known analyzer info.
**Screenshots:** Not applicable.  
**Follow-up:** Continue with focused wallet/Solana/profile-package logging passes. Full verifier output is still not silent, but remaining Flutter logs are centralized or outside this small slice.

### [POLISH-04] Media/gallery image semantics are incomplete

**Status:** Partially completed
**Completion notes:** Added shared image semantic-label support and adopted it in `ArtworkGalleryView` plus mobile/desktop artwork detail callsites. Gallery thumbnails now expose index and selected state, main media frames expose semantic tap actions, mobile page indicators announce the selected index, and lightbox media exposes the current image context.
**Validation run:** `flutter test test/widgets/common/kubus_cached_image_test.dart test/widgets/artwork_gallery_view_test.dart` passed; scoped touched-file `flutter analyze --no-fatal-infos` passed; `npm run verify:all` passed with the known nonfatal `lib/screens/map_screen.dart:5298` analyzer info.
**Screenshots:** Not captured; no seeded gallery/lightbox route was available locally and the implementation is semantics-only for idle visual state.
**Follow-up:** Capture before/after artwork gallery and lightbox screenshots when the local QA harness can seed a representative artwork detail route.

### [POLISH-05] Purple and hardcoded status/social colors bypass color roles

**Status:** Deferred  
**Reason:** Requires design/product decisions on approved exceptions plus light/dark screenshots for several unrelated screens.  
**Safest next action:** Build a color-role matrix, approve exceptions, then update one screen family at a time.  
**Validation needed later:** Light/dark screenshots and targeted color-role tests.

### [MED-10] API error contracts are inconsistent

**Status:** Deferred  
**Reason:** Requires a compatibility plan across providers before changing return/throw contracts. A partial change in this pass could make existing empty-state handling or mutation error handling less reliable.  
**Safest next action:** Build a route/method policy matrix, then implement one method family per isolated task with table tests and provider regressions.  
**Validation needed later:** 200/401/404/500/timeout/snapshot-fallback tests for each representative method plus affected provider tests.

### [MED-11] Map screens still own lifecycle and business logic

**Status:** Deferred  
**Reason:** Requires a dedicated map refactor and mandatory mobile/desktop screenshots for marker select/create/delete.  
**Safest next action:** Start a map-only task with screenshot baselines, then extract one lifecycle responsibility at a time into `KubusMapController`.  
**Validation needed later:** Map-focused tests, `flutter analyze`, and before/after screenshots for mobile and desktop map flows.

### [MED-12] Large route/service/screen monoliths slow review and increase regression risk

**Status:** Deferred  
**Reason:** This is a multi-domain extraction program, not one reviewable cleanup task.  
**Safest next action:** Split into separate domain goals for backend API service, backend auth routes, community screens, onboarding, and promotion service.  
**Validation needed later:** Existing tests plus focused regression tests for each extracted unit.

## Deferred items

### [CRIT-04B] Messaging and marker write assurance policy

**Status:** Partially completed
**Completion notes:** Marker ownership-affecting writes now require wallet-signed authority for `POST /api/art-markers`, `PUT /api/art-markers/:id`, `DELETE /api/art-markers/:id`, `POST /api/art-markers/:id/claims`, and `PATCH /api/art-markers/:id/claims/:claimId`. Messaging routes remain deferred because account-linked chat/session behavior needs an explicit route matrix before enforcement.
**Validation run:** `npx jest --runInBand artMarkersWriteAssurance.test.js` passed (6 tests); `npx jest --runInBand artMarkersWriteAssurance.test.js artMarkersCreateIdempotency.test.js artMarkersUpdatePersistence.test.js artMarkersClaimsAuth.test.js markerOwnership.test.js` passed (25 tests); `npm run lint` passed in `backend/`.
**Reason remaining:** Some messaging flows may be legitimate for email/Google account-linked sessions, while attachment and conversation mutation routes may need stronger assurance depending on product policy. Applying one rule blindly would risk breaking valid non-wallet collaboration flows.
**Safest next action:** Define a route matrix for `backend/src/routes/messages.js`, then add focused tests for account-linked and wallet-signed tokens before changing middleware.
**Validation needed later:** Route tests for conversation creation, message sending, attachment upload, conversation membership changes, and conversation avatar upload under account-linked and wallet-signed sessions.

### [CRIT-05B] Event moderation public publication contract

**Status:** Deferred  
**Reason:** `backend/src/routes/adminModeration.js` can moderate `events`, but `backend/src/services/publicSyncService.js` exposes no `syncEventById`/`syncEventRow` method. Events are currently included in DNSLink/IPFS public snapshots through `publicSnapshotService`, which has scheduled/manual publish behavior but no narrow post-commit event refresh API. Adding a new event publication contract inside CRIT-05 would be a broader public-data design change.  
**Safest next action:** Define whether events should become first-class `publicSyncService` entities, snapshot-only entities with a refresh queue, or exhibition-linked records only; then add tests for event create/update/moderation/delete sync semantics.  
**Validation needed later:** Public sync or snapshot tests covering `events` status changes and public fallback output.

### [CRIT-06B] Artwork multipart upload validation still uses MIME-or-extension checks

**Status:** Completed
**Completion notes:** Added artwork upload route tests for spoofed image/model uploads, mismatched bytes, valid PNG covers, and valid GLB/glTF/USDZ model signatures. Reused `backend/src/utils/uploadFileValidation.js` from `backend/src/routes/artworks.js` for both Multer declaration filtering and pre-storage content validation.
**Validation run:** `npx jest --runInBand artworksUploadValidation.test.js` passed; `npx jest --runInBand artworksUploadValidation.test.js uploadRouteDeprecation.test.js avatarProfileUploadRoutes.test.js uploadStaticCors.test.js storageServiceUploadPath.test.js messagesRoutesAuth.test.js` passed (84 tests); `npx jest --runInBand artworksUploadValidation.test.js artworksCreateGalleryMetaJson.test.js` passed; `npm run lint` passed in `backend/`.
**Screenshots:** Not applicable.
**Follow-up:** None.

### [HARNESS-01B] Broader architecture guards need debt cleanup first

**Status:** Deferred  
**Reason:** Several valuable guard candidates would fail against current known debt: route-level wildcard CORS still appears in `backend/src/routes/mediaProxy.js` and `backend/src/routes/presence.js`; canonical map screens still own timers, listeners, and subscriptions; broad `debugPrint` usage is widespread; and public-sync coverage requires route-specific ownership decisions.  
**Safest next action:** Convert each category into a cleanup task with focused tests, then extend `scripts/architecture_guard.mjs` once the repo can pass the invariant without broad allowlists.  
**Validation needed later:** `npm run guard:architecture`, focused route tests, Flutter analyze, and map/UI smoke checks for map lifecycle rules.

### [MED-13B] Auth, wallet, and share services still depend on `BuildContext`

**Status:** Deferred  
**Reason:** Removing context from `PostAuthCoordinator`, `WalletSessionSyncService`, and `ShareService` would cross login/onboarding, wallet binding, app bootstrap, navigation, snackbar, and modal share flows. That is too broad to change safely as the remainder of [MED-13] without dedicated flow tests and screenshots where share UI is affected.  
**Safest next action:** Split into separate tasks: auth coordinator dependency bundle, wallet session sync typed provider dependencies, and share sheet UI/controller extraction. Keep existing behavior stable and validate each flow independently.  
**Validation needed later:** Post-auth widget tests, wallet session sync service tests without widget provider harnesses where feasible, share sheet widget tests, scoped `flutter analyze`, and screenshots for share modal UI if the modal composition changes.

## Notes for future audits

- Re-run all `AGENTS.md` preflight reads before code changes.
- Re-check `backend/art.kubus-threat-model.md` before security-affecting backend work.
- Avoid stale watchlist findings: `/api/orbitdb/artworks` currently has explicit size/depth limits and a route limiter.
- Treat auth contract fixes as isolated tasks with route-level tests before broad route assurance changes.
- Treat UI tasks as screenshot-required when visual focus, layout, colors, or major controls change.
