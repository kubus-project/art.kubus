# art.kubus 0.8.5: public entry, SSR WORLD HANDOFF and keyless basemap

Status: **RELEASED** on 2026-10-29. Tag `v0.8.5` is on `master` `d5c5164378f447f9ede2d7d821b5eef156471704`
(`d5c51643`, the `dev` to `master` merge commit, [#380](https://github.com/kubus-project/art.kubus/pull/380)); the
[GitHub Release](https://github.com/kubus-project/art.kubus/releases/tag/v0.8.5) is published (not a prerelease), and
production web is live at the same commit. Statuses are kept separate: **implemented**, **tested**, **reviewed**,
**merged**, **deployed** and **released** are never inferred from one another. Maturity stays 0.8.x-alpha.

0.8.5 follows 0.8.4 (tag `v0.8.4`, `master` `8c2c571f`). It adds no Web2.5 features. Walletless
community work remains deferred to 0.9 (see "Deferred").

## Backend (art.kubus-backend): merged and deployed

`master` `e0d2a0e1` (package version 0.8.5, [#144](https://github.com/kubus-project/art.kubus-backend/pull/144)).
**Deployed** to Oracle on 2026-10-29 at 13:25:20Z: only the backend container was recreated, no migrations,
`/health/ready` true, `X-Kubus-Backend-Revision: e0d2a0e1…`. Rollback image:
`artkubus-backend:rollback-pre-e0d2a0e1` (the previous `da6ee5be` image). The compose invocation was proven by
config hash first. The backend repository is not tagged per release; the deployed SHA is the record.

| Area | PRs |
| --- | --- |
| Account and admin security | #123 suspension enforced on every surface, #125 / #127 moderators cannot grant or alter admin roles, #126 pricing and hard delete are admin-only, #128 whitelist entries need an explicit role, #119 tokens of deleted accounts refused, #140 / #149 dependency advisories |
| Public-read and SEO limits | #137, #138, #142 rate-limit scope, media-proxy IP cap |
| SSR entity pages | #129 localized takeover status contract, #146 inline loading section with Retry and Go to app, #147 / #148 WORLD HANDOFF section, #151 whole-photo hero, #150 responsive Wikimedia Commons hero variants, #152 / #153 fallback fonts with `font-display: optional` (CLS 0 over a 28-cell matrix), #139 AA contrast |
| Markers and institutions | #120 hidden-artwork markers are not public, #133 legacy-grant read path, #134 / #135 / #136 institution import review and attribution |
| Health and admin | #124 readiness stays HTTP-only, #145 editorial decisions do not wait for the IPFS publish |

## Web: production hotfix train (already live) and the 0.8.5 app

Between `v0.8.4` and this release `master` received the narrow production SSR release as hotfixes:
#371 (WORLD HANDOFF web files, locale-exact readiness, engine start after first paint), #372 (failed state when
the Flutter engine cannot start), #373 (Firefox and Safari start failures), #374 (controller locale from the
canonical path) and #376 (reproducible sealed artifact: Flutter writes a random service-worker version into
`flutter_bootstrap.js` and `index.html`; it is now derived from the commit before the manifest is sealed).
These were **deployed** as web `0f1081db` on 2026-10-29 (run 40877920117, approved through `production-web`).
[#377](https://github.com/kubus-project/art.kubus/pull/377) merges `master` back into `dev`.

App changes on `dev` since 0.8.4:

| Area | PRs |
| --- | --- |
| Public entry and auth | #354 canonical profile/post takeover and auth return, #355, #356 canonical entry history, #357 session ends when the account is suspended, #358 integration |
| Institutions and accessibility | #360 email-only accounts browse institutions without wallet onboarding, #361 password visibility toggles named from state, #350 icon tooltips and localized strings, #349 staged avatar kept when profile save fails |
| Map | #364 center-on-me coordinator, Artist Studio portfolio, #365 basemap moved from CARTO to keyless OpenFreeMap |
| Web handoff | #366 inline loading section with Retry and Go to app, #368 / #369 / #370 WORLD HANDOFF design in the PHP gateway with a pinned parity test, #367 web smoke tolerates only cancelled OpenFreeMap tiles |
| API | #353 a write is never replayed on another backend when it may have committed |

## Released artifacts and deployment

- **Web deployed:** `release-production.yml` run 40909894439 on `d5c51643`, approved through `production-web`.
  `app.kubus.site/kubus-web-revision.txt` reports `d5c51643`, `version.json` reports 0.8.5, the post-promotion
  production smoke passed, and entity pages report `X-Kubus-Backend-Revision: e0d2a0e1`. Re-read independently on
  2026-10-30 from a live entity page: `X-Kubus-Web-Revision: d5c5164378f447f9ede2d7d821b5eef156471704` and
  `X-Kubus-Backend-Revision: e0d2a0e15c74ac3ec484b57443ee396898b37abd`.
- **Mobile:** `Mobile release` run 40909878532 (tag `v0.8.5`), build number 263020014, published the release with
  `SHA256SUMS` and `release-manifest.json` (every file verified against the checksums).
  - **Android** APK and AAB are signed with the release keystore. The APK certificate SHA-256
    `42:68:42:AD:10:CB:AF:2F:45:31:5B:EA:69:36:25:3E:C3:2D:42:B4:4D:25:F6:93:5A:1D:2B:9C:E3:B1:C8:A3`
    matches the fingerprint in the live `/.well-known/assetlinks.json`.
  - **iOS** is an **unsigned** IPA for re-signing (`signed: false`, `distributable: false`): the `ios-release`
    environment has no Apple signing secrets and `IOS_RELEASE_ENABLED` is unset.
- **Acceptance before the promotion:** local Docker run of the `dev` web build against backend `e0d2a0e1`:
  server-rendered pages 164 + 56 + 56 cases with no regression, real engine on Chromium, Firefox and WebKit 0 findings,
  axe 0 section violations. The remaining harness findings (entity API outage hands over to the app by design, a cold
  first hero lookup) are identical to the previous accepted run.
- **Review:** Codex review was unavailable (usage limit); an independent release-level review found no blocker. Its
  build-number concern does not apply: mobile build numbers come from the CI date and run number.

## Known limitations (open, not passes)

- Flutter engine startup is about 53 s at 4x CPU on slow 4G; the server-rendered page carries the first paint.
- INP stays above 200 ms (320-360 ms measured, equal to the 0.8.4 build within noise).
- Browser Back from a taken-over entity page stays on the entity URL.
- With `font-display: optional` the first uncached view of an SSR page uses the metric-matched system font.
- The home standby backend is stale (v0.8.1) with no database; it answers SSR pages with 503 and is not a working failover.
- As last recorded on 2026-10-24: IPFS cluster pinning wedged and the DNSLink pointer stale; HA replication unhealthy.
- Not verified on a physical Android device; installed-native App Links for 0.8.5 are unverified.
- The iOS artifact is unsigned and not distributable until Apple signing is configured (see "iOS signing" below).
- GitGuardian reports one fake-JWT test fixture on #380 (`test/services/backend_api_diagnostics_post_test.dart`; its
  signature decodes to the text "signature"). It is not a required check and the token never was a credential.
  A `.gitguardian.yaml` does not suppress the hosted integration, so it needs dismissing as a test credential in the
  GitGuardian workspace.
  Checked 2026-10-30 without reproducing the value: HS256 header, claims `sub` and `role` only (no `exp`), signature
  is the nine literal bytes `signature` (a real HS256 signature is 32 bytes), so no secret can verify it against any
  environment. The hosted finding's status cannot be queried from here: dismissal is a **manual action** for a
  GitGuardian workspace operator (mark as test credential / false positive). The check passes on PRs that do not
  contain the file (for example #383). Secret scanning stays enabled.
- The `backend` gitlink was stale at `ee3b880` (2026-09-11) when 0.8.5 was released; `dev` pins the deployed
  `e0d2a0e1` from [#383](https://github.com/kubus-project/art.kubus/pull/383). The tag and `master` keep the old pin
  (history is not rewritten). The pin is a CI reference and records what is deployed; it deploys nothing.

## iOS signing (operational follow-up)

The `v0.8.5` iOS IPA is the unsigned output of the build, published for re-signing only. Producing a signed,
distributable build is a separate operational task, not part of this release: configure the `ios-release` environment
with the secrets `IOS_DISTRIBUTION_CERTIFICATE_BASE64`, `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` and
`IOS_PROVISIONING_PROFILE_BASE64`, the variables `IOS_TEAM_ID`, `IOS_BUNDLE_ID` and `IOS_EXPORT_METHOD`, and set
`IOS_RELEASE_ENABLED=true`. The workflow then verifies the bundle identifier, team and embedded profile before it
publishes. A signed build is published as a new release; the `v0.8.5` tag and its assets are not replaced.

## Deferred to 0.9

Walletless account posting and direct messages (backend #104 / #105 / #106, app #340 / #341), the wallet-optional
creator work (app #254 / #256 / #280, backend #81 / #82 / #88) and the spatial viewer bundles (app #258, backend #83).

## Release procedure (as executed)

`dev` to `master` by a **merge commit** (no squash or rebase), tag `v0.8.5` on the resulting `master` commit,
the `Mobile release` workflow builds and signs the Android APK/AAB and the iOS IPA from the tag, then the
`release-production.yml` web deployment is approved through `production-web`. Rollback: the previous atomic web
release (automatic on a failed post-promotion smoke), the backend rollback image above, `SEO_HERO_VARIANTS=0`
and the takeover flag.
