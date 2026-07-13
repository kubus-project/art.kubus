# Deployment gates

The `Deploy` workflow promotes artifacts produced by a successful `CI` run. It
does not rebuild source after approval. Production environments must require
reviewers in GitHub before this workflow is enabled on `master`.

## Public build configuration

Configure these repository or environment variables for CI. They are compiled
into client applications and must never contain server credentials:

- `KUBUS_BACKEND_URL`
- `KUBUS_GOOGLE_CLIENT_ID`
- `KUBUS_GOOGLE_WEB_CLIENT_ID`
- `KUBUS_GOOGLE_IOS_CLIENT_ID`

`KUBUS_WALLETCONNECT_PROJECT_ID` is optional. When it is absent, compatible
injected Solana browser wallets (including Wallet Standard providers) remain
available, while the Reown QR/mobile fallback is disabled cleanly.

Pinata API and secret keys are backend-only and are rejected from client build
configuration by CI.

## Web promotion environment

Public entity route ownership, required backend variables, proxy prerequisites,
and coordinated rollback are documented in
[`seo-public-pages.md`](seo-public-pages.md). Enable the renderer and validate it
before promoting a web artifact whose `.htaccess` proxies localized public
routes.

Create a protected `production-web` environment with these secrets:

- `SFTP_SERVER`
- `SFTP_USERNAME`
- `SFTP_PRIVATE_KEY`
- `SFTP_HOST_FINGERPRINT`
- `SFTP_PRIVATE_KEY_PASSPHRASE` when the key is encrypted

Configure these environment variables:

- `SFTP_PORT` (defaults to `22`)
- `WEB_SERVER_DIR`: absolute path to the symlink served as the live web root;
  use `{SFTP_USERNAME}` when the protected username must not be exposed in a
  repository variable (for example `/home/{SFTP_USERNAME}/app.kubus.site`)
- `WEB_RELEASES_DIR`: optional absolute directory for immutable releases; the
  same `{SFTP_USERNAME}` placeholder is supported
- `WEB_SMOKE_URL`: public URL whose HTML loads the Flutter bootstrap

`WEB_SERVER_DIR` must be a symlink before the first automated promotion. If an
existing document root is a physical directory, migrate it once during an
approved maintenance window by manually dispatching `Deploy` with
`bootstrap_web_root=true`. The bootstrap requires the live directory to be a
direct child of the authenticated SFTP home, moves it beneath
`WEB_RELEASES_DIR/releases/`, and replaces it with a symlink. It is idempotent,
preserves the existing directory as the rollback target, and refuses symlinks
that point outside the immutable releases tree. Ordinary automatic promotions
never perform this migration.

Every promotion verifies both the downloaded artifact checksum and the
per-file checksum manifest, writes an immutable SHA-named release directory,
atomically replaces the live symlink, and performs an HTTP smoke test. A failed
smoke restores the exact previous symlink target. CI exercises the same
promotion and rollback script with `npm run verify:deploy`.

## Android release environment

Create a protected `android-release` environment with:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

CI compiles an unsigned release APK. Only a manual `Deploy` run can sign that
exact CI artifact. Publishing additionally requires a new explicit release tag;
ordinary pushes never create or update GitHub Releases.

## Manual promotion

A manual run requires the successful CI run ID and its full 40-character commit
SHA. The workflow queries GitHub before downloading artifacts and fails if the
workflow name, conclusion, or commit does not match.
