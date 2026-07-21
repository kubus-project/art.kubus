# Deployment gates

The canonical branch and release model is documented in [`engineering/branching-and-deployment.md`](engineering/branching-and-deployment.md). This file records the operational gates used by the workflows.

## Trust boundaries

- `pr-validation.yml` runs unprivileged validation for PRs into `dev` and release-candidate PRs into `master`. It never references web deployment, Basic Auth, or mobile-signing secrets.
- `deploy-development.yml` accepts only the exact current `dev` SHA and enters `development-web`.
- `release-production.yml` accepts only the exact current `master` SHA and enters protected `production-web`.
- `mobile-release.yml` accepts a `v*` tag or explicit manual run whose exact commit is contained by `master`; signing occurs only inside `android-release` or `ios-release`.
- `scheduled-quality.yml` runs expensive trusted-source validation weekly or manually.

Build and privileged deployment are separate jobs. A web artifact is named `flutter-web-<development|production>-<sha>`, contains `kubus-web-revision.txt`, `kubus-deployment-metadata.json`, and `SHA256SUMS`, and is consumed only when all three identities agree.

## Public build configuration

The following repository variables are compiled into client applications and must never contain server credentials:

- `KUBUS_BACKEND_URL`
- `KUBUS_GOOGLE_CLIENT_ID`
- `KUBUS_GOOGLE_WEB_CLIENT_ID`
- `KUBUS_GOOGLE_IOS_CLIENT_ID`
- optional `KUBUS_WALLETCONNECT_PROJECT_ID`

Client-side Pinata credentials are forbidden and rejected by CI.

## Web environments

Create `development-web` and `production-web` with independent values. Both require environment variables `SFTP_PORT`, `WEB_SERVER_DIR`, `WEB_RELEASES_DIR`, `WEB_SMOKE_URL`, `ENVIRONMENT_NAME`, and `EXPECTED_DEPLOYMENT_HOST`. Both require environment secrets `SFTP_SERVER`, `SFTP_USERNAME`, `SFTP_PRIVATE_KEY`, `SFTP_PRIVATE_KEY_PASSPHRASE` when encrypted, and `SFTP_HOST_FINGERPRINT`.

`development-web` additionally requires `HTTP_BASIC_USERNAME` and `HTTP_BASIC_PASSWORD`. Restrict it to `dev`. Restrict `production-web` to `master` and require explicit approval. Repository-scoped deployment credentials must be migrated into `production-web`, independently provisioned for staging, and then removed from repository scope; do not copy production values blindly.

The live path must be a symlink to an immutable release directory. An approved manual run may set `bootstrap_web_root=true` once to preserve a physical document root below the release tree and replace it with the symlink. Normal pushes never bootstrap.

Before upload, the workflow verifies the selected branch still points to the exact built SHA. It validates the expected hostname, safe absolute paths, SSH fingerprint, and remote availability of SSH commands, SHA-256, tar, symlinks, and atomic rename. It then uploads a checksum-protected archive, promotes through `atomic_web_release.sh`, runs environment-specific smoke, and rolls back on post-promotion failure. Finalization removes temporary upload data and retains a controlled number of previous SHA releases.

Development smoke verifies Basic Auth, `/app`, localized routes, the exact revision, staging `X-Robots-Tag`, deny-all `robots.txt`, and the absence of staging canonicals or sitemaps. Production smoke preserves root canonicalization, `/app`, localized semantic HTML, production robots/sitemap behavior, real 404s, revision identity, compact aliases, Flutter takeover, and the production SEO contract.

## Mobile environments

`android-release` contains `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`, and `ANDROID_KEY_PASSWORD`. It builds and verifies signed APK and AAB packages.

When `IOS_RELEASE_ENABLED=true`, `ios-release` contains `IOS_DISTRIBUTION_CERTIFICATE_BASE64`, `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`, and `IOS_PROVISIONING_PROFILE_BASE64`, plus `IOS_TEAM_ID`, `IOS_BUNDLE_ID`, and optional `IOS_EXPORT_METHOD`. The workflow validates the profile identity, uses an ephemeral keychain, verifies the signed IPA, and removes signing material in an always-run cleanup step.

GitHub Release publication uses immutable tags and artifacts and is separate from all web deployments. No mobile signing or publication occurs for pull requests.

## Recovery

An upload or checksum failure occurs before promotion and cannot change the live symlink. A smoke failure after promotion invokes rollback to the exact previous target. If rollback itself fails, stop and inspect the release-specific state; do not delete it blindly or start a second promotion. Production deployment or environment approval always requires explicit human authorization.
