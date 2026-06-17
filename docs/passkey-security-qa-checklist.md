# Passkey and Security Hub QA Checklist

Run this checklist against a backend configured with:

- `PASSKEY_RP_ID=kubus.site`
- `PASSKEY_ALLOWED_ORIGINS=https://app.kubus.site,https://art.kubus.site`
- shared challenge storage available in multi-instance or production deployments

## Account Passkey Flow

- Create a passkey from the account/wallet security screen.
- Log out.
- Log in with the newly created passkey.
- Add a second passkey from a different browser profile or device.
- Revoke one registered passkey.
- Confirm the revoked passkey can no longer log in.
- Retry creating a passkey on the same device/browser and confirm the UI shows a duplicate credential message, not a generic failure.
- Cancel the browser passkey prompt and confirm the UI says the prompt was cancelled/blocked/timed out.
- Let a passkey prompt expire and confirm the UI asks for a fresh challenge.

## Wallet Recovery Flow

- Create or update the encrypted wallet backup.
- Add passkey protection when PRF is supported.
- Confirm wallet recovery reports PRF support only after the ceremony result includes PRF output.
- On a browser/device without PRF support, confirm account passkey sign-in can still succeed and wallet recovery falls back to recovery password or recovery phrase.

## Security Hub Layout

- Mobile width: confirm a compact single-column flow with status cards above the action panel.
- Desktop width: confirm a two-column layout with the colored status panel and action panel side by side.
- Confirm status rows render for PIN/local lock, passkey sign-in, wallet recovery, backup phrase, and registered passkeys.
- Confirm green, blue, amber, and red states appear for secured, available, recommended, and failed states.

## Browser Matrix

- Desktop Chrome: create passkey, log out, log in with passkey, add second passkey, revoke passkey, retry duplicate device.
- Desktop Firefox: create passkey, log out, log in with passkey, revoke passkey, verify duplicate/error messaging.
- Mobile Safari: create/login with passkey where supported, cancel prompt, verify fallback paths.
- Mobile Chrome: create/login with passkey where supported, cancel prompt, verify fallback paths.
