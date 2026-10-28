# Optional analytics: local release candidate

This implementation is not a statement about deployed app bundles. Production activation, policy text and browser/native acceptance remain separate gates.

## Authority and migration

OptionalAnalyticsConsent is the sole permission authority. Missing, corrupted, legacy boolean and failed preference reads do not grant optional measurement. A granted choice takes effect after a successful durable receipt write. The receipt includes a per-choice revision. Withdrawal denies immediately in memory before storage IO; a failed denial cannot be undone by refreshing an older stored grant within the same process. Complete device-storage failure cannot guarantee that the denial survives a process restart.

ConfigProvider exposes this authority. Build flags only make analytics available; they do not grant permission. Existing enableAnalytics values are not automatically migrated into grants. The optional Meta adapter remains unavailable until recipient-specific disclosure, activation and consent requirements have been reviewed and implemented.

## Data boundaries

The app does not construct optional telemetry events until permission is established. Consent/account transitions invalidate outstanding work, discard unsent events and campaign state, and rotate measurement sessions. Persisted queues bind their actor and receipt, expire after 24 hours, reject future timestamps and retain at most 500 events. Legacy v2 queues are discarded. Session identifiers, timestamps and deduplication keys use one atomic, serialized record scoped to actor and consent revision. Old session keys are removed on cleanup.

The transport rechecks permission, consent generation, authentication epoch and event actor before the HTTP handoff. It does not use authenticated request replay or fallback retries. An HTTP request already handed to the network cannot be recalled. Campaign parameters present before a valid choice are discarded rather than replayed after acceptance. Functional guest/intent navigation remains available independently of optional measurement.

Security/operational diagnostics are a separate processing path. This patch removes response-body previews; it does not suppress necessary security logging when optional measurement is refused. Diagnostic activation, legal basis, recipients and server retention require their own verification.

## Verification and rollout

Tests cover preference failures, missing/legacy values, consent-period changes, withdrawal, restart, persisted queue migration/expiry, actor transitions, concurrent flushes, delayed actual preference writes and guarded HTTP handoffs. SharedPreferences/native IO fault injection is synthetic evidence, not physical device or deployed browser acceptance. Browser cross-tab and family-domain cookies must be checked against the actual deployed origin configuration. The Vue websites and Flutter app keep distinct positive choices. A browser app choice is bound to the observed family consent cookie/revision context. A later family-context change invalidates that earlier app receipt, and website acceptance alone never grants app measurement. Native choices remain device-specific. Actual family-domain cookie routing still requires coordinated deployment acceptance.

Rollback before deployment: revert the candidate code together with its consent authority/provider prerequisite. Do not interpret the old preference or a v2 queue as consent during a rollback. No live database migration or server retention change is included.


## Browser follow-up

The browser permission getter and optional request-context headers check the family cookie context synchronously; a 500 ms observer plus focus/visibility checks triggers queue cleanup. Network handoff refreshes permission again. The app does not write the website consent cookie or silently grant website analytics. An explicit new app choice applies to the app only and binds to the then-current family context. Receipt revisions use a JavaScript-safe random-number bound; the synthetic release-browser harness caught and corrected the native-only bit-shift bound.

Measurement intentionally drops unsent guest/account backlog and campaign state on an actor transition. A campaign's pre-account stages are not retrospectively relabelled as account events; reports must not assume one continuous measurement session across account creation/sign-out. This affects funnel continuity but does not prevent account creation, artwork contribution or other product actions.

Both HTTP diagnostics paths now omit response-body previews. The diagnostics path still has its own activation, metadata and server-retention requirements; refusing analytics is not a promise to suppress operational security records.
