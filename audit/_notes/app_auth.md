# App Auth Lifecycle Audit

## Summary
Reviewed auth lifecycle across providers, services, onboarding/sign-in, token storage, and app-lock/biometric flows. Re-auth prompts can surface before explicit sign-in when a wallet is cached, and token-expiry handling depends on app-lock settings in a way that can either over-prompt or silently fail. Evidence is cited with file paths and line numbers.

## Findings

- **AK-AUD-001 — Re-auth prompt can appear before explicit sign-in (wallet-only local account).**
  - **Severity:** P1
  - **Category:** Auth lifecycle / UX
  - **Evidence:**
    - Local account is considered present if *any* token, wallet, or user_id key exists in prefs (`hasLocalAccountSync`), not just a valid auth token: `lib/services/auth_gating_service.dart` lines 7–33.
    - Wallet creation/import/connect persist `wallet_address` and `has_wallet` even without auth token: `lib/providers/wallet_provider.dart` lines 1045–1056, 1098–1106, 1153–1156.
    - AppInitializer routes to main app if `has_wallet` is true, even when no auth token is present (`shouldShowSignIn` requires **no** wallet): `lib/core/app_initializer.dart` lines 196–205.
    - Backend API treats 401/403 as auth failures and invokes re-auth coordinator: `lib/services/backend_api_service.dart` lines 658–761.
    - Re-auth gating relies on `shouldPromptReauth()` (which uses `hasLocalAccount`), so a wallet-only state can still trigger token-expired lock: `lib/providers/security_gate_provider.dart` lines 332–357.
  - **Root cause:** `hasLocalAccountSync` treats cached wallet/user_id as “local account,” and `shouldShowSignIn` allows main UI when a wallet exists, so the first protected API 401 triggers token-expired reauth even if the user has never signed in.

- **AK-AUD-002 — Re-auth gating uses auto-lock setting even when app lock isn’t configured.**
  - **Severity:** P1
  - **Category:** Auth/session policy
  - **Evidence:**
    - Re-auth gating uses `hasAppLock = requirePin || (autoLockSeconds != 0 && autoLockSeconds > 0)`: `lib/providers/security_gate_provider.dart` lines 332–335.
    - Default settings set `autoLockSeconds` to 5 minutes while `requirePin` defaults to `false`: `lib/services/settings_service.dart` lines 237–252.
    - Auto-lock itself is only enforced when `requirePin` is true (`_shouldAutoLock`): `lib/providers/security_gate_provider.dart` lines 176–186.
  - **Root cause:** re-auth uses auto-lock as a proxy for app-lock readiness, but auto-lock defaults to enabled even when no PIN is set, so re-auth can trigger in states where the app lock is effectively not configured.

- **AK-AUD-003 — Token expiry may fail silently when app lock is disabled.**
  - **Severity:** P1
  - **Category:** Auth token lifecycle
  - **Evidence:**
    - If `!shouldPrompt || !hasAppLock`, re-auth returns `notEnabled` and does not reliably route to sign-in (only routes when `!shouldPrompt` and onboarding is not shown): `lib/providers/security_gate_provider.dart` lines 335–356.
    - Backend API will retry once only when re-auth is successful; otherwise it returns the original 401/403: `lib/services/backend_api_service.dart` lines 736–770.
  - **Root cause:** When users disable app lock (PIN off and auto-lock set to “Never”), token-expiry reauth is skipped and there is no guaranteed fallback prompt, leading to repeated 401s and a degraded experience without a clear recovery path.

## Top P0/P1
- **P1:** AK-AUD-001 — Re-auth prompt before explicit sign-in (wallet-only local account).
- **P1:** AK-AUD-002 — Re-auth gating uses auto-lock defaults even without PIN.
- **P1:** AK-AUD-003 — Token expiry can fail silently when app lock disabled.

## Files Reviewed
- `lib/main.dart`
- `lib/core/app_initializer.dart`
- `lib/services/auth_gating_service.dart`
- `lib/services/auth_session_coordinator.dart`
- `lib/services/backend_api_service.dart`
- `lib/services/settings_service.dart`
- `lib/providers/security_gate_provider.dart`
- `lib/providers/wallet_provider.dart`
- `lib/screens/auth/sign_in_screen.dart`
- `lib/screens/auth/security_setup_screen.dart`
- `lib/screens/auth/session_reauth_prompt.dart`
- `lib/widgets/security_gate_overlay.dart`
- `lib/screens/settings_screen.dart`
- `lib/services/security/pin_auth_service.dart`
- `lib/services/security/post_auth_security_setup_service.dart`
