# Guest-first entry contract (PRODUCT)

The canonical contract for how app.kubus.site and the native apps open, and how
a visitor becomes an account. Wave 5A-E implements it; this page is what later
work (including the Android App Links work in #181) has to preserve.

## The contract

| Concern | Rule |
| --- | --- |
| Default anonymous entry | **Public discovery.** A fresh visitor on `/`, `/en`, `/sl`, `/main`, `/map` or a native cold start opens the map. No modal, no alpha notice, no welcome tour, no role picker, no permission prompt, no sign-in wall. |
| Public entity entry | **The exact public entity** (artwork, event, exhibition, profile, institution, post, map record). From there the visitor can go Back, open the map, switch tab, search and open another entity with no onboarding appearing. "Show the entity, then force onboarding on the next navigation" is retired. |
| Auth | **Contextual, at the protected-action boundary.** `ContextualAuthGate.ensureAuthenticated` is the only place a guest is asked for an account. |
| Account | **Not role onboarding.** Account-only actions stop once the account exists and return to the exact origin. |
| Role / profile | **Progressive capability.** Asked for only by an action that needs it (a public identity, a creator surface) or chosen voluntarily from settings. |
| Wallet | **Explicit capability only.** Never for discovery, never for an account-only action. |
| DAO | **Explicit capability only.** Entry needs a wallet; eligibility and role are enforced by the DAO screens and the backend. Votes and proposals are never replayed. |
| Permissions | **Contextual, never startup.** Notifications: the settings toggle or an explicit opt-in. Location: "My location" / Nearby. Camera: opening AR or the scanner. |
| Onboarding | **A capability/continuation system, not a first-run gate.** It exists to finish an account journey the visitor started, a profile/creator/wallet capability an action asked for, or a voluntary profile completion. |

Explicit auth intent is not ignored: `/register`, `/sign-in`, an email
verification callback, a password reset, an interrupted account journey and an
active wallet-link journey all still open their own flow. Guest-first means auth
is not *forced*, not that it is unavailable.

## Cold-start decision

`resolveColdStartEntry` (`lib/core/app_initializer_helper.dart`) is the single
decision for a start with no explicit intent:

| State | Lands on |
| --- | --- |
| No valid server session (fresh, or lapsed) | `/map` (`/community` if that was the preferred shell route) |
| Valid session | the preferred shell route, `/main` by default |
| Degraded startup or watchdog fallback | public discovery, never onboarding or sign-in |

A lapsed server session is not an app lock; the local security gate (PIN /
biometric) is a separate overlay owned by `SecurityGateProvider`.
`decideStartupRoute` handles only explicit continuations: a pending email
verification, a pending structured journey, an active Google-registration or
account-link guard.

## Capability matrix (from the call sites)

`ProtectedActionRequirements` is a UX model, not authorization. The backend
remains the authority for every mutation.

| Scope | Actions (call sites) | Asks for |
| --- | --- | --- |
| `accountOnly` (the gate default) | **Save** (map marker overlay, AR, artwork, collection, event, exhibition, post, group feed, community, desktop variants); **Like** (artwork, post, marker overlay, group feed, community); **Follow** (profile, desktop profile, desktop community); **Comment** (artwork detail, post detail, artwork engagement) | An account. Then return to origin. |
| `participant` | **Compose** (community, desktop community); **DM** (profile, desktop profile); **Group create** (group feed, desktop community); **Marker create** (map, desktop map); **Marker claim** (map, desktop map) | An account and a usable profile (display name). No role, no wallet. |
| `creator` | Defined and resolver-tested (`role` then `profile`). **No direct call site today:** Artist Studio, Institution Hub and the DAO entry are Home cards that are wallet-locked, so they currently route through the wallet scope. Artwork create/edit have no gate call; they are reachable from signed-in owner surfaces, check `isSignedIn` locally, and the backend authorizes. | Role then profile, never a wallet. |
| `wallet` | Home/desktop wallet cards; every `WalletActionGuard.ensureSignerAccess` caller: marketplace (list, buy, offer), artist studio, artist portfolio, institution hub, governance hub, send token, swap, NFT gallery | An account, then wallet setup. The attempted financial operation is deliberately **not** captured: it must be started again. |
| `dao` | Governance hub entry (via `WalletActionGuard`, so wallet scope) | Wallet. Vote/proposal are never auto-replayed. |

Not found in this branch: a client gate for **Promotion** (only the
`promotion.dart` model exists) and a separate **claim/takeover** gate beyond
marker claim above.

Findings kept, not fixed here: the creator scope is not yet wired to a call
site, and the artwork edit publication toggle shows an auth toast instead of the
contextual gate (owner-only surface). Both are follow-ups, not entry blockers.

## Pending actions

```
guest attempts Save/Follow/Like/Comment
  -> PendingActionIntent captured (safe internal route, TTL, account-bound)
  -> contextual activation sheet (value first)
  -> account created or verified (account-only scope ends here)
  -> return to the exact origin (OnboardingCompletionNavigation.returnToOrigin)
  -> explicit confirmation of the pending action
  -> mutation exactly once, then the intent is cleared
```

An *interrupted* account journey (for example a pending email verification)
that is still armed when the visitor taps a protected action is resumed **after**
the gate has captured the action and its return route, never before. The journey
opens above the entity they are viewing, keeps the wider of its own scope and the
action's, and completing it returns to that exact entity for the explicit
confirmation. (Resuming first used to replace the entity and lose the action.)

**One usable-profile rule.** "This account already has the profile the action
needs" means a hydrated profile with a display name
(`isUsablePublicProfile`, `ProfileProvider.hasUsablePublicProfile`). The gate,
the post-auth resolver, interrupted-journey recovery and pending-action return
all use it, so a hydrated profile with an empty display name cannot bypass a
participant or creator action; an account-only action never asks for it.

**Degraded startup** (initialisation failure or the 20s watchdog) looks for an
interrupted journey under the unscoped key and every user/wallet scope
(`OnboardingStateService.hasAnyPendingAuthOnboardingSync`); stale markers fall
through to public discovery.

Wallet transactions, DAO votes/proposals, claims, financial and privileged
mutations capture **no** replayable intent (`privileged actions capture no
replayable intent`). Dismissing the gate runs no mutation.

## Telemetry

First-party only. The funnel event map, including `map_engaged`, is in
[`analytics/campaign-activation-contract.md`](analytics/campaign-activation-contract.md).

## Relationship to #181 (Android App Links)

#181 changes how native entry URLs arrive; it must not change what happens
after. Any rebase of #181 must preserve: guest-first launch, public entity
direct entry, **no navigation-triggered onboarding**, explicit auth callbacks
(verify-email, password reset, wallet link), contextual protected actions and a
correct Back stack (no canonical -> compact -> `/app` history hops). The
regression tests are `test/architecture/guest_first_startup_contract_test.dart`
and `test/core/app_initializer_helper_test.dart`.
