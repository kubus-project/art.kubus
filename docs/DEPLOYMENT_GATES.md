# Deployment gates

The `Deploy` workflow promotes artifacts produced by a successful `CI` run. It
does not rebuild source after CI. Both deployment environments retain their
scoped secrets, but routine successful `master` CI must not require a reviewer
gate: promotion and alpha publishing are automatic.

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

Create a `production-web` environment with these secrets and variables. Do not
configure required reviewers or a wait timer: the workflow automatically uploads
the verified artifact and atomically promotes it after successful `master` CI.

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
atomically replaces the live symlink, and performs an HTTP smoke test. The smoke
request forces normal cache revalidation with HTTP headers instead of adding a
query parameter that hosting security filters can reject. A failed smoke restores
the exact previous symlink target. CI exercises the same promotion and rollback
script with `npm run verify:deploy`.

## Android release environment

Create a protected `android-release` environment with:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

CI compiles an unsigned release APK. After successful `master` CI, `Deploy`
derives `v<pubspec-version>-alpha`, signs that exact tested artifact, and creates
an immutable prerelease when neither the release nor tag exists. Later commits
at the same application version detect the existing release and skip signing
successfully; they never replace its APK or move its tag. Bump `pubspec.yaml`
before the next automatic alpha release.

Manual `Deploy` runs can still sign a selected successful CI artifact without
publishing it. Manual publication requires a new explicit tag and remains
immutable.

## CI build metadata

`version.json` and `pubspec.yaml` retain the manually selected `X.Y.Z` version.
Every CI workflow derives its own UTC build date and Android-safe build number
without committing generated version changes. The build number uses
`YYDDDNNNN`: the UTC two-digit year, day of year, and a one-to-10,000 sequence
derived from the GitHub workflow run number. It is monotonic across normal CI
runs, supports up to 10,000 runs per day, and stays below Android's
`versionCode` limit.

The generated metadata is passed to all Flutter web, Android, and iOS builds as
both Flutter build arguments and Dart defines. A semantic version bump remains
a deliberate source change and is the only event that creates the next alpha
release tag.

## Manual promotion

A manual run requires the successful CI run ID and its full 40-character commit
SHA. The workflow queries GitHub before downloading artifacts and fails if the
workflow name, conclusion, or commit does not match.
