# Secure Encrypted Wallet Backup Flow

## Goal
Allow email/Google users to keep a real Solana wallet from first sign-in while preserving recovery on a new device without turning `art.kubus` into a custodial wallet service.

## Non-negotiables
- The server must never store a raw mnemonic, private key, or decrypted signer.
- The client must verify that any recovered mnemonic derives the account wallet before activating it.
- The existing local secure-storage signer remains the primary same-device recovery path.
- Encrypted backup is a feature-gated recovery mechanism, not the normal signing path.

## Product model
- First sign-in with email/Google creates a real Solana wallet locally.
- The signer stays in OS secure storage for frictionless re-login on the same device.
- The user sees the existing wallet protection banner until an encrypted backup is configured.
- Cross-device recovery requires email/Google auth plus a recovery secret the server does not know.

## Threat model
- Server compromise must expose only ciphertext and KDF metadata.
- Session theft alone must not be enough to decrypt a wallet backup.
- A stolen encrypted backup should be expensive to brute-force offline.
- A mismatched or tampered backup must never be imported silently.

## Crypto design

### 1. Secrets and keys
- `mnemonic`: BIP-39 phrase already generated on-device.
- `DEK`: random 32-byte data-encryption key generated on-device.
- `recoverySecret`: user-provided recovery password, or a passkey-unlocked local secret if a passkey flow is added later.
- `KEK`: key-encryption key derived on-device from `recoverySecret` using `Argon2id`.

### 2. Encryption
- Encrypt the mnemonic with `AES-256-GCM` using the random `DEK`.
- Wrap the `DEK` with `AES-256-GCM` using the derived `KEK`.
- Use independent random nonces for mnemonic encryption and DEK wrapping.
- Bind both AEAD operations to additional authenticated data containing:
  - backup version
  - authenticated user id
  - wallet address

### 3. KDF parameters
- Preferred KDF: `Argon2id`.
- Store per-backup KDF metadata with the ciphertext:
  - `salt`
  - `memoryKiB`
  - `iterations`
  - `parallelism`
- KDF cost must be tuned per platform, but the target is memory-hard derivation on all supported clients.
- Do not use a server-known pepper to make the server part of decryption.

## Server-side storage contract
Server stores only an `EncryptedWalletBackupRecord`:

- `userId`
- `walletAddress`
- `version`
- `kdf`
- `salt`
- `wrappedDekNonce`
- `wrappedDekCiphertext`
- `mnemonicNonce`
- `mnemonicCiphertext`
- `createdAt`
- `updatedAt`
- `lastVerifiedAt`

The server must not store:
- raw mnemonic
- private key
- decrypted DEK
- recovery password
- any reversible server-only secret that can decrypt backups by itself

## API shape

### Create or replace backup
`PUT /api/wallet-backup`

Request body:
- `walletAddress`
- `version`
- `kdf`
- `salt`
- `wrappedDekNonce`
- `wrappedDekCiphertext`
- `mnemonicNonce`
- `mnemonicCiphertext`

Rules:
- `verifyToken` required
- `walletAddress` must equal the authenticated account wallet
- overwrite is allowed only for the same authenticated account wallet
- route-level rate limiting required

### Fetch backup metadata
`GET /api/wallet-backup`

Response:
- same encrypted fields as above
- no plaintext material

Rules:
- `verifyToken` required
- return only the backup belonging to the authenticated account wallet

### Delete backup
`DELETE /api/wallet-backup`

Rules:
- `verifyToken` required
- delete only the authenticated account wallet backup

## Client flows

### A. First-time email/Google sign-up
1. Create a real wallet locally.
2. Store signer locally in secure storage.
3. Bind wallet to the authenticated account.
4. Mark wallet backup as required.
5. Prompt for encrypted backup setup after sign-in or from the banner, not inline with account creation.

### B. Same-device sign-in
1. Authenticate with email/Google.
2. Recover signer from local secure storage.
3. Verify recovered signer address equals the account wallet.
4. Finish sign-in without asking for recovery secret.

### C. New device recovery
1. Authenticate with email/Google.
2. Detect that no local signer is available for the account wallet.
3. Fetch encrypted backup metadata from the server.
4. Ask for the recovery password.
5. Derive `KEK` locally with stored Argon2id parameters.
6. Unwrap `DEK`.
7. Decrypt mnemonic locally.
8. Derive the wallet address from the mnemonic.
9. Reject recovery if the derived address does not equal the account wallet.
10. Import signer locally and cache it in secure storage.

### D. Wallet-first sign-in
1. User connects or imports a wallet.
2. If an account already exists for that wallet, sign in to that account.
3. If no account exists, mark the wallet session as `isNewUser` and route to onboarding.
4. The encrypted backup flow is optional here because the user already brought their own phrase.

## UX rules
- The wallet-protection banner remains the primary persistent reminder.
- Backups should be described as encrypted recovery, not as server custody.
- Backup creation should require re-auth or local security gate confirmation before revealing or exporting anything.
- Recovery password reset cannot decrypt old backups; replacing it requires re-encrypting from an already unlocked signer.

## Abuse and failure handling
- If backup decryption fails, do not fall back to creating a new wallet silently.
- If the derived wallet mismatches the account wallet, block import and show a specific error.
- Log backup route events without ciphertext, salts, or recovery-secret derived values.
- Telemetry must continue redacting keys containing `mnemonic`, `secret`, `password`, or backup ciphertext fields.

## Feature flags
- Flutter: `AppConfig.isFeatureEnabled('encryptedWalletBackup')`
- Backend: dedicated flag, for example `ENABLE_ENCRYPTED_WALLET_BACKUP`

## Implementation slices

### Backend
- Add `wallet_backups` table with unique `wallet_address`.
- Add authenticated backup CRUD routes.
- Add route-level rate limiting and payload size validation.

### Flutter
- Add `EncryptedWalletBackupService` under `lib/services/`.
- Add a provider or banner action that drives setup state and last verification state.
- Use `WalletProvider.deriveWalletAddressFromMnemonic(...)` to verify recovered phrases before import.

## Explicitly rejected designs
- Raw mnemonic or signer stored on the server.
- Server-generated wallet keys for traditional auth users.
- Any fallback that creates a new wallet during recovery from an existing account.
