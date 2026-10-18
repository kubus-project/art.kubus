# Deployment gates

The canonical branch and release model is documented in [`engineering/branching-and-deployment.md`](engineering/branching-and-deployment.md). This file records the operational gates used by the workflows.

## Trust boundaries

- `pr-validation.yml` runs unprivileged validation for PRs into `dev` and release-candidate PRs into `master`. It never references web deployment, Basic Auth, or mobile-signing secrets.
- `deploy-development.yml` accepts only the exact current `dev` SHA and enters `development-web`.
- `release-production.yml` accepts only the exact current `master` SHA and enters protected `production-web`.
- `mobile-release.yml` accepts a `v*` tag push, or a manual run dispatched from `master` that names an existing `v*` tag; either way it builds that tag's commit, which must be contained by `master`. Signing occurs only inside `android-release` or `ios-release`.
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

The development web build refuses to run against production data. The client reads its API origin from `BACKEND_BASE_URL` (failover: `BACKEND_STANDBY_BASE_URL`), both defaulting to `https://api.kubus.site`, so `deploy-development.yml` additionally requires the repository variable `KUBUS_DEVELOPMENT_BACKEND_URL`: the public HTTPS origin of a dedicated staging backend (no path, not `api.kubus.site` or `bapi.kubus.site`, not a local or private address). `scripts/prepare_public_build_config.mjs` fails the build when it is missing or unsafe and otherwise sets both the primary and the failover origin to it. A staging backend must run migration 105 and pass the Support API checks before an app build that includes the Support client is deployed to it. Production builds ignore this variable.

`development-web` additionally requires `HTTP_BASIC_USERNAME` and `HTTP_BASIC_PASSWORD`. Restrict it to `dev`. Restrict `production-web` to `master` and require explicit approval. Repository-scoped deployment credentials must be migrated into `production-web`, independently provisioned for staging, and then removed from repository scope; do not copy production values blindly.

The live path must be a symlink to an immutable release directory. An approved manual run may set `bootstrap_web_root=true` once to preserve a physical document root below the release tree and replace it with the symlink. Normal pushes never bootstrap.

Before upload, the workflow verifies the selected branch still points to the exact built SHA. It validates the expected hostname, safe absolute paths, SSH fingerprint, and remote availability of SSH commands, SHA-256, tar, symlinks, and atomic rename. It then uploads a checksum-protected archive, promotes through `atomic_web_release.sh`, runs environment-specific smoke, and rolls back on post-promotion failure. Finalization removes temporary upload data and retains a controlled number of previous SHA releases.

Development smoke verifies Basic Auth, `/app`, localized routes, the exact revision, staging `X-Robots-Tag`, deny-all `robots.txt`, and the absence of staging canonicals or sitemaps. Production smoke verifies direct application entry (`/`, `/en`, `/sl` and the `/app` compatibility entry all return `200` and boot the Flutter shell — see decision log D-11), production robots/sitemap behavior, real 404s, revision identity (via `/kubus-web-revision.txt`), compact aliases and deep-entity semantic HTML, Flutter takeover, and the production SEO contract.

## Mobile environments

`android-release` contains `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`, and `ANDROID_KEY_PASSWORD`. It builds and verifies signed APK and AAB packages.

`ios-release` contains the secrets `IOS_DISTRIBUTION_CERTIFICATE_BASE64` (base64 of the Apple Distribution `.p12`), `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` and `IOS_PROVISIONING_PROFILE_BASE64` (base64 of the explicit-App-ID `.mobileprovision`). The variables `IOS_TEAM_ID`, `IOS_BUNDLE_ID` (`com.art.kubus`, matching `ios/Flutter/Release.xcconfig`) and optional `IOS_EXPORT_METHOD` (default `app-store`) may live in the environment or the repository.

`IOS_RELEASE_ENABLED=true` must be a **repository** variable: it decides whether a tag push runs the iOS job, and a job-level `if` cannot read environment-scoped variables, so a copy inside `ios-release` is ignored. A manual run with `targets` `ios` or `both` runs the iOS job without it, which is how signing is proven before tag builds include iOS.

Before installing the toolchain the job names every missing setting, imports the certificate into an ephemeral keychain, and checks with `scripts/deploy/inspect_ios_profile.mjs` that the profile is for `IOS_TEAM_ID.IOS_BUNDLE_ID` (no wildcard), is unexpired, contains the imported certificate, belongs to the same team, and matches the export method (App Store, ad hoc, development or enterprise). The certificate must fit the profile: Apple Development for `development`/`debugging`, Apple Distribution for every other method. Xcode is pointed at that certificate by its exact common name. After the build it verifies the bundle ID, version and build number against the tagged source, the code signature and team, the embedded profile UUID, the signed application identifier and, for distribution, `get-task-allow` false, then records the tag, commit and version in `<name>.ios-build.json` beside the IPA. An always-run cleanup step deletes the keychain, the installed profile and every decoded file, also after a failure. The signing scripts run from the workflow's own revision, so rebuilding an older tag still runs the current checks.

For testing without an Apple Developer Program membership, `ios-unsigned-build.yml` (manual, from `master`) builds an **unsigned** IPA of a `v*` tag, `dev` or `master` and keeps it as a 14-day workflow artifact. It uses no secrets and no signing environment, never publishes a release, and checks the bundle ID, version and build number. A sideloading tool such as Sideloadly or AltStore re-signs it on install with the tester's own Apple ID (with a free Apple ID the install expires after 7 days). It is a test build, not a distributable one.

GitHub Release publication uses immutable tags and artifacts and is separate from all web deployments. A tag push publishes; a manual run publishes only with `publish_github_release=true`, and the run is refused before building when a release for that tag already exists. The release carries one combined `SHA256SUMS`. No mobile signing or publication occurs for pull requests; pull requests compile iOS without code signing (`flutter build ios --release --no-codesign`), which proves compilation only and never produces a distributable IPA. Nothing is uploaded to App Store Connect or TestFlight.

## Recovery

An upload or checksum failure occurs before promotion and cannot change the live symlink. A smoke failure after promotion invokes rollback to the exact previous target. If rollback itself fails, stop and inspect the release-specific state; do not delete it blindly or start a second promotion. Production deployment or environment approval always requires explicit human authorization.
