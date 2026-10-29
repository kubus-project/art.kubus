# art.kubus 0.8.5: public entry, SSR WORLD HANDOFF and keyless basemap

Status: **PREPARED** (2026-10-29). This record is updated to **RELEASED** in a follow-up commit once
the tag, the signed artifacts and the production web deployment exist. Statuses are kept separate:
**implemented**, **tested**, **reviewed**, **merged**, **deployed** and **released** are never
inferred from one another. Maturity stays 0.8.x-alpha. Version 0.8.5 is already set on `dev`
(`pubspec.yaml`, `package.json`, `version.json`); the build number and date come from CI.

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

## Known limitations (open, not passes)

- Flutter engine startup is about 53 s at 4x CPU on slow 4G; the server-rendered page carries the first paint.
- INP stays above 200 ms (320-360 ms measured, equal to the 0.8.4 build within noise).
- Browser Back from a taken-over entity page stays on the entity URL.
- With `font-display: optional` the first uncached view of an SSR page uses the metric-matched system font.
- The home standby backend is stale (v0.8.1) with no database; it answers SSR pages with 503 and is not a working failover.
- As last recorded on 2026-10-24: IPFS cluster pinning wedged and the DNSLink pointer stale; HA replication unhealthy.
- Not verified on a physical Android device; installed-native App Links for 0.8.5 are unverified.

## Deferred to 0.9

Walletless account posting and direct messages (backend #104 / #105 / #106, app #340 / #341), the wallet-optional
creator work (app #254 / #256 / #280, backend #81 / #82 / #88) and the spatial viewer bundles (app #258, backend #83).

## Release procedure

`dev` to `master` by a **merge commit** (no squash or rebase), tag `v0.8.5` on the resulting `master` commit,
the `Mobile release` workflow builds and signs the Android APK/AAB and the iOS IPA from the tag, then the
`release-production.yml` web deployment is approved through `production-web`. Rollback: the previous atomic web
release (automatic on a failed post-promotion smoke), the backend rollback image above, `SEO_HERO_VARIANTS=0`
and the takeover flag.
