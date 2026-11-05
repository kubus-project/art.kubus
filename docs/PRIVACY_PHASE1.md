# Phase 1: credential persistence and private attachment client

Local correction of F01/F04 and the client contract for B01, based on `origin/dev` `d1125941901dc701d64d4a41055ab39cca83ba0a`. The deployed web app still identifies older master `8c2c571feec2258cc1e766cc4c516da5e60a8825`; these changes have not been deployed.

## Credential strategy and deliberate behavior changes

`AuthCredentialStore` is the central persistence policy used by `BackendApiService`. Native credentials use FlutterSecureStorage; new JWT/refresh values are never duplicated into SharedPreferences. Native legacy preference sessions are migrated to secure storage before ordinary preference copies are removed. Secure-store errors fail closed, and preference-only account hints do not establish authentication. The direct helper write bypass is removed.

The browser uses memory-only credentials. A browser reload/new application context requires sign-in again. Existing persistent browser token/preferences and known secure-plugin token keys are cleaned, not adopted as a browser session. This is an explicit functional change: browser secure-storage encryption with a script-accessible key is not native secret storage or an HttpOnly cookie. Memory-only tokens still exist in the running application and are not immunity from XSS. A future persistent browser session needs a separately designed backend session/CSRF/refresh protocol; it must not silently restore localStorage credentials.

Secret IO is serialized through actual completion, not treated as cancelled by a timeout. Caller timeouts bound UI waiting while cleanup remains queued. Each credential session has a generation; access/refresh response pairs commit together. Auth-producing requests carry their request-start epoch. Stale responses, reads, writes and failures cannot intentionally restore an ended session or clear a newer one. Direct refresh writes identify their access token; wallet linking and profile-token continuations respect relevant session guards. `authSessionEpoch` now advances on credential commits as well as logout; callers must not assume it only changes on logout.

Logout clears memory/identity immediately, independently attempts all legacy preference and secure keys, and starts a non-secret persistent revocation marker before waiting for outstanding secret IO. That marker blocks restart restoration after failed secret deletion. If both marker persistence and secret deletion fail, durable erasure/restoration prevention cannot be guaranteed; the implementation reports incomplete cleanup to debug diagnostics without credential values. This is local session termination, not new server-side revocation of previously copied bearer tokens. The backend has no general refresh transport or newly implemented logout denylist. Existing account suspension/deletion checks remain authoritative on requests.

`setRefreshToken` now requires `forAccessToken`. `persistAuthTokensFromResponse` can receive `sessionEpoch` captured before the request. Auth response transports use this guard. Preference-only `evaluateStoredSession` no longer returns valid/refreshRequired; explicitly supplied access tokens or the central restored session are required. Existing tests have been updated to preserve the new contract rather than expect plaintext copies.

## Attachment delivery

Both phone and wide conversation surfaces share `ConversationScreen`. New private routes use `fetchPrivateMessageAttachment`, which accepts only the configured backend origin and exact attachment path, sends the bearer through the central client, refuses redirects and discards bytes if the session changes during download. Private bytes never go through public image proxies or token-in-query URLs.

The shared attachment widget displays an in-memory image and uses an explicit download/share action for files/video. The action fetches again so permissions are rechecked rather than exporting an old preview. On an account change it hides the content and evicts its memory image. The user's explicit download/share may create OS-managed temporary files or recipient copies; this is not a guarantee of forensic memory erasure or deletion of previously downloaded material. Native OS share behavior and actual deployed web download fallback still need device/browser acceptance.

## Verification boundaries and rollout

Unit/service tests use synthetic credentials, mocked secure storage and HTTP; widget evidence covers EN/SL, 390/1280 widths and light/dark with local product fonts. Native keychain/keystore and real device restart require separate acceptance. The Windows Flutter Chrome test attempt encountered CanvasKit 404s in the test server and did not complete; a root-level browser test remains available for a functioning browser runner. It must not be reported as a passing real-browser credential test.

Coordinate app and backend rollout; old clients cannot display Bearer-only attachment URLs automatically. No dependency/lockfile version change, server session migration, live token purge or production deployment is part of this change. Preserve unrelated local work. Do not enable Phase 2 analytics claims: consent defaults/queues/Meta/attribution remain a separate unimplemented phase.

Rollback should use a forward correction preserving secure-only persistence and private delivery, not restore preference token duplication or public attachment URLs. Preserve native secure sessions and the logout marker; browser users can sign in explicitly. Exact tests, results, unresolved gates and the policy handoff are recorded in the cumulative remediation evidence directory.
