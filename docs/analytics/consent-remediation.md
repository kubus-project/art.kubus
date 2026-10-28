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

Tests cover preference failures, missing/legacy values, consent-period changes, withdrawal, restart, persisted queue migration/expiry, actor transitions, concurrent flushes, delayed actual preference writes and guarded HTTP handoffs. SharedPreferences/native IO fault injection is synthetic evidence, not physical device or deployed browser acceptance. Browser cross-tab and family-domain cookies must be checked against the actual deployed origin configuration. The Vue website and Flutter app use distinct consent storage implementations; do not describe them as sharing one browser consent cookie without further integration evidence.

Rollback before deployment: revert the candidate code together with its consent authority/provider prerequisite. Do not interpret the old preference or a v2 queue as consent during a rollback. No live database migration or server retention change is included.
