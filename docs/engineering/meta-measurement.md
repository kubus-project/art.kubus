# Meta measurement (activation funnel)

This document describes the feature-flagged Meta browser pixel integration for
the guest → account activation funnel, and exactly what is needed to turn it
on.

> **Meta ad traffic no longer lands only on `/map`.** Paid campaigns now also
> link straight to `https://app.kubus.site/register`, which is a different
> acquisition path with its own funnel. First-party attribution for both — the
> UTM taxonomy, the two funnels, and how to inspect a campaign in admin — is
> documented in `backend/docs/CAMPAIGN_ATTRIBUTION.md`. That pipeline is
> independent of this pixel and works whether or not the pixel is ever enabled.

The integration ships **disabled**. With no pixel id configured, no third-party
script is added to the page, no request reaches Meta, and the adapter is an
inert no-op on every platform.

## What is emitted, and when

| Meta event | Fired when | Source |
| --- | --- | --- |
| `ViewContent` | A public artwork detail screen is opened. Carries `content_type: artwork` and the artwork id only. | `lib/screens/art/art_detail_screen.dart` |
| `CompleteRegistration` | **Only** once a usable authenticated account session exists for a new account. | `lib/services/post_auth_coordinator.dart` |

`CompleteRegistration` is deliberately **not** emitted when the backend merely
accepts a registration form. For email signup the backend returns no session
(`POST /api/auth/register/email` responds `requiresEmailVerification: true` with
no token), so a visitor who never opens the verification email has not
registered in any sense worth optimising a campaign against. The event fires
from `PostAuthCoordinator`, at the same point as the first-party
`account_session_created` event, gated on
`AuthOnboardingService.payloadIndicatesNewAccount(payload)`.

`PageView` is intentionally never auto-fired: the app is a single-page shell,
so a blanket page view would attribute every in-app route change as a landing.

## Deduplication with a server-side Conversions API sender

Every browser event carries a generated `eventID`. If a server-side CAPI sender
is added later, it must send the **same** `event_id` for the same conversion so
Meta collapses the pair. The browser event is emitted through one helper
(`window.__kubusMetaTrack`) precisely so this contract lives in a single place:

```js
window.fbq('track', name, params, { eventID: eventId });
```

No CAPI sender exists today. Nothing in this change contacts Meta from the
backend.

## Privacy and consent

- The adapter reads the same `enableAnalytics` preference that gates first-party
  telemetry. A visitor who turns analytics off is not measured by Meta either.
- It also respects the `analytics` build flag; with analytics off, the pixel
  never loads.
- Payloads carry a coarse content type, an entity id, an auth method and — for
  `CompleteRegistration` — the opaque `users.id` as `external_id`. No email
  address, name, wallet address, location or referrer is sent.
- Load failures (content blockers, offline) are swallowed: measurement never
  affects the funnel it measures.

## Environment variables

Both are Dart compile-time defines, supplied at web build time:

| Variable | Required | Purpose |
| --- | --- | --- |
| `META_PIXEL_ENABLED` | yes | Master switch. Defaults to `false`. |
| `META_PIXEL_ID` | yes | Numeric Meta pixel id. Validated against `^[0-9]{6,32}$` before it is interpolated into the loader, so a misconfigured value cannot become script injection. |

Example:

```bash
flutter build web --release \
  --dart-define=META_PIXEL_ENABLED=true \
  --dart-define=META_PIXEL_ID=1234567890123456
```

The id is not a secret (it is visible in any page that loads the pixel), but it
is still not committed: it is supplied per environment by the deploy workflow.

## Content Security Policy

**The pixel will not load until the CSP allows it.** `web/.htaccess` currently
lists no Meta host in `script-src`, so enabling the flags alone results in the
loader being blocked with no visible error — measurement silently stays at zero.

Before enabling, add **only** `https://connect.facebook.net` to `script-src`
(and `https://www.facebook.com` to `img-src` if you want the tracking pixel
fallback). Do not broaden the directive further.

`unsafe-eval` is already present in the policy, so the loader's `eval()` does
not force any CSP weakening. If a future hardening pass removes `unsafe-eval`,
rewrite `_installStubAndHelper` in `meta_pixel_bridge_web.dart` using
`js_interop` instead of `eval` rather than re-adding the directive.

## Production activation steps

1. Obtain the pixel id from Meta Events Manager for the `app.kubus.site` domain.
2. Add `META_PIXEL_ENABLED=true` and `META_PIXEL_ID=<id>` to the web deploy
   environment. Per `docs/engineering/branching-and-deployment.md`, composite
   actions cannot read `vars`/`secrets` directly — forward both as explicit
   inputs from the env-bound caller workflow.
3. Add `https://connect.facebook.net` to `script-src` in `web/.htaccess` (see
   above) — without it the pixel never loads.
4. Verify the domain in Events Manager and confirm `ViewContent` and
   `CompleteRegistration` arrive in the Test Events tab.
5. Confirm no event fires with analytics disabled in app settings.
6. If a CAPI sender is added afterwards, wire it to reuse the browser
   `eventID` and re-check deduplication in Events Manager.

## Files

- `lib/services/meta/meta_conversion_adapter.dart` — platform-agnostic API and
  the consent/flag gating.
- `lib/services/meta/meta_pixel_bridge_web.dart` — loader and `fbq` bridge.
- `lib/services/meta/meta_pixel_bridge_stub.dart` — hard no-op off web.
- `lib/config/config.dart` — `enableMetaPixel`, `metaPixelId`, and the
  `metaPixel` feature-flag case.
