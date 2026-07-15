# Public entry access policy

Public content is public everywhere. Authentication gates an action that needs
identity; it does not gate viewing an eligible entity.

This contract applies to web handoffs from the server-rendered public pages,
compact share links, native deep links, QR codes, and ordinary in-app
navigation. Backend eligibility and mutation authorization remain
authoritative.

## Destination policy

| Destination or action | Policy | Signed-out behavior |
| --- | --- | --- |
| Artwork, public artist/profile, institution profile, event, exhibition, collection, post, marker/place | `publicRead` | Open the entity read-only |
| Follow, save, like, comment, message, contribution, edit, or management entry | `authenticated` | Explain why sign-in is needed and return to the entity |
| Collectible/NFT wallet surface, DAO action, claim, transfer, or transaction | `walletRequired` | Require the appropriate account and fresh wallet confirmation |
| Verify-email, password recovery, and other auth-purpose links | Dedicated auth route | Preserve the token-purpose flow |

An exhibition handoff containing claim proof remains a `publicRead`
destination. The exhibition opens first; claiming is a separate protected
action and is never submitted automatically.

## Material startup states

| Visitor/session state | Public entity entry | Ordinary root | Protected action |
| --- | --- | --- | --- |
| Fresh or returning anonymous visitor | Open anonymously | Existing guest/onboarding policy | Contextual sign-in |
| Valid account session | Open with authenticated capabilities | Existing signed-in startup | Continue |
| Expired token, refresh-only state, or stale local account metadata | Attempt non-destructive restoration, then open anonymously | Existing returning-account sign-in policy may apply | Contextual sign-in |
| Stored wallet without a valid account session | Open anonymously | Existing wallet-shell policy | Account sign-in; wallet authority when required |
| First launch or incomplete onboarding | Open entity before onboarding | Show or resume onboarding | Sign-in/onboarding as required by the action |
| Pending auth onboarding or active account-link guard | Open entity and retain the continuation | Resume the guarded flow | Resume the guarded flow |

Failed restoration must not delete stale account state, create a fake guest
account, or redirect a `publicRead` destination to sign-in.

## Onboarding and locale

- A public cold start wins over first-run and pending onboarding.
- The existing deferred-onboarding provider retains the pending step and may
  present it after the initial entity has opened and the visitor chooses to
  continue into an onboarding-relevant workflow.
- EN and SL handoffs carry locale context separately from the stable entity ID.
- Canonical localized entity paths remain visible during progressive web
  takeover. Compact paths (`/a/:id`, `/u/:id`, and peers) remain internal route
  abstractions and explicit compatibility entry points.
- Benign campaign and locale query parameters may pass through initialization,
  but query parameters never grant access.

## Contextual authentication and replay

Contextual authentication keeps the exact canonical browser route as its return
route when entry began on a canonical public document; other entry surfaces use
their compact internal route. Cancelling sign-in returns to that entity rather
than a generic shell.

No mutation is replayed automatically by the generic gate. Follow, save, like,
comment, and message actions require the visitor to confirm the action again
after authentication. Wallet transactions, claims, financial operations,
destructive changes, DAO actions, and privileged management always require a
fresh action-specific confirmation.

## Platform expectations

Desktop web, mobile web, and native entry share the same access classification.
Their shell composition may differ, but stale account data, onboarding state,
or platform must not change a public read into an authenticated destination.

## Regression requirements

Tests must cover anonymous and stale-session public entry, valid sessions,
first-launch deferral, EN/SL locale retention, stable profile UUID resolution,
sign-in success and cancellation, redirect-loop prevention, and continued
authorization of protected mutations.
