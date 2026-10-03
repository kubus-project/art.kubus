# Wave 3 Android App Links

Status: implementation and CI evidence for the Wave 3 branch, refreshed
2026-09-25 against `dev` `bbc16d5a952d16dc4f3f5e1fe3aadd019a9a6daa`.
Updated branch includes that `dev` commit via merge
`0b713a0f96afa873073517ad7f9656a7b455089b`. This document does not claim live
domain verification or completed Android activity-launch acceptance.

## Route contract

`AndroidManifest.xml` declares HTTPS links for the current localized public
entity families on `app.kubus.site`:

| Entity | English prefix | Slovenian prefix |
| --- | --- | --- |
| Artwork | `/en/artworks/` | `/sl/umetnine/` |
| Profile (including artist/institution subtypes) | `/en/profiles/` | `/sl/profili/` |
| Event | `/en/events/` | `/sl/dogodki/` |
| Exhibition | `/en/exhibitions/` | `/sl/razstave/` |
| Post | `/en/posts/` | `/sl/objave/` |
| Collection | `/en/collections/` | `/sl/zbirke/` |
| Collectible | `/en/collectibles/` | `/sl/zbirateljski-predmeti/` |
| Map record | `/en/map/` | `/sl/zemljevid/` |

The filter remains limited to `https://app.kubus.site`, `VIEW`, `DEFAULT`, and
`BROWSABLE`. It does not claim the site root, assets, login callbacks, or
internal endpoints. Previously declared compact and long-form compatibility
prefixes are retained. The localized URL is the preferred sharing identity;
`ShareLinkBuilder` continues to emit HTTPS URLs for both locales and all eight
entity types.

`ShareDeepLinkParser` remains the sole URL interpreter. For the canonical
localized families it requires exactly locale, entity family, and one nonempty
ID segment. It takes locale from `/en/` or `/sl/` before considering a locale
query parameter, treats `Uri.pathSegments` as already decoded, and leaves query
and fragment available to the existing startup route preservation. An
unrecognized ID is still passed to the existing entity screen/provider, whose
normal missing-entity state owns the result; the parser does not fabricate
content.

## Ownership and association source

The checked-in app-domain transport is `web/` in this repository. Flutter
copies hidden files into `build/web`, so the repository-owned association path
is `web/.well-known/assetlinks.json` (package `com.art.kubus`, relation
`delegate_permission/common.handle_all_urls`). The production workflow deploys
the complete immutable `build/web` artifact from protected `master`; there is no
single-file association deployment path, and the atomic release script keeps any
host-owned `.well-known` content while the artifact's own files are retained.

`web/.well-known/assetlinks.json` is guarded by
`test/android_assetlinks_test.dart` (shape, package, fingerprint format, the
Android application id) and by the Apache routing contract
(`scripts/qa/web_routing_contract.mjs`), which requires the path to be a real
static file served as `application/json` with no redirect, never the app shell
or the 404 document.

Before this change `https://app.kubus.site/.well-known/assetlinks.json` returned
`404 Not Found` as `text/html` (re-probed 2026-10-03). The file only becomes live
when the web artifact containing it is deployed.

## Package and signing evidence

The Android Gradle configuration declares namespace and application ID
`com.art.kubus`, target SDK 36, and `MainActivity` is exported with
`launchMode="singleTop"`. The protected `android-release` workflow signs its
GitHub release APK and AAB artifacts. The public GitHub release APK `v0.7.4`
(source `4bd9387b4b16daeb641d36f0a1dd32848a78fda3`) was downloaded and verified
with Android `apksigner verify --print-certs` (re-verified 2026-10-03). Its
signer certificate SHA-256 is
`426842ad10cbaf2f45315bea6936253ec32d42b44d25f6935a1d2b9ce3b1c8a3`
(`CN=art.kubus Alpha Release`). The 0.8.0 APK is produced by the same protected
workflow and key, so this fingerprint is asserted in `assetlinks.json`. The final
0.8.0 release candidate must be re-verified against it before deployment.

**Google Play App Signing: UNVERIFIED, not asserted.** The repository workflow
does not establish whether the AAB is uploaded to a Play track or whether Play
re-signs installed APKs. If Play uses a separate app-signing certificate, its
SHA-256 must be added to `sha256_cert_fingerprints` as an additional entry
(Play Console, Setup, App integrity, App signing key certificate). Until then
verified App Links are guaranteed for the direct GitHub APK only. No private
signing material was read or emitted.

## Native navigation boundary

The parser has a collectible/NFT route type, but the existing app navigation
currently has no public collectible detail destination: its NFT navigation
branch is a no-op and startup routing treats it as wallet-required. Wave 1
reported no public production collectible records. This pass keeps the route
declared and parser-testable, but does not invent a detail screen or change the
wallet boundary without an existing public entity destination. Exact native
collectible opening remains a separate product blocker if a public collectible
is introduced.

For artwork, profile, event, exhibition, post, collection, and map records, the
existing `app_links` initial-link/runtime-link integration and existing entity
navigation remain authoritative. This branch adds no parallel router and does
not replace the map implementation: a map target feeds the existing
`MapDeepLinkProvider` and `MapTargetCoordinator`, so there is one selection
owner and one camera owner.

## Local Android verification

- A debug APK built from updated branch commit
  `0b713a0f96afa873073517ad7f9656a7b455089b` and installed on the
  `sdk_gphone64_x86_64` Android API 34 emulator. Its signing class is local
  debug/test signing, not the production release signer. The old emulator app
  was uninstalled because there was insufficient free space for an in-place
  update; the new APK then installed successfully.
- The current manifest regression test passes and covers all 16 localized
  prefixes plus the retained compatibility prefixes. On the updated emulator
  install, `cmd package query-activities` matched `MainActivity` for all 16
  localized URL prefixes. This is resolver evidence only, not activity launch,
  ownership, or production signing evidence.
- `pm verify-app-links --re-verify com.art.kubus` followed by
  `pm get-app-links com.art.kubus` reports `app.kubus.site: 1024` for this
  debug-signed installation. Android ownership is not verified.
- The command policy rejected the authorized direct `adb shell am start` HTTPS
  VIEW/BROWSABLE intent before execution. Cold-start, warm/background,
  foreground re-entry, Back-stack, and launch screenshot evidence therefore
  remain unverified. No launch proof is inferred from resolver matching or
  parser/unit tests.
- The first direct `flutter build apk --release --no-pub` attempt used stale
  generated plugin metadata and failed to resolve the
  `flutter_native_splash` and `integration_test` Android classes. The
  repository-prescribed `npm run verify:flutter:android` then re-resolved
  dependencies and passed both the debug build and unsigned release APK build.
  No release signing identity was inferred from that compile check.

Focused manifest, startup routing, parser, and HTTPS share-link tests pass
(28 tests); the full Flutter suite passes (3,049 passed, 5 skipped), and
`flutter analyze` reports no issues. The local release web build and `qa:web`
smoke also pass. The repository Android debug and unsigned release APK builds
pass. Updated PR CI status, including its device-test APK verification and iOS
no-codesign lane, is reported on #181.

The retained UI/browser matrix in PR #178 uses a synthetic public-only fixture,
not a production entity. Its genuine 200% zoom item remains open: the available
Playwright browser accepted a keyboard shortcut but reported no change in
`innerWidth`, device-pixel ratio, or `visualViewport.scale`. The separate narrow
CSS viewport simulation is not counted as browser zoom.

## Lifecycle verification (API 34 emulator, 2026-10-03)

Run on the `kubus_test_api34` emulator (Android 14, host GPU) with a release
build of this branch signed with the local debug key, domain approval forced
with `pm set-app-links --package com.art.kubus 2 app.kubus.site`. Links were
launched with `am start -W -a android.intent.action.VIEW -c
android.intent.category.BROWSABLE -d <https url>` (no explicit package, so the
OS resolver chose the app) and the visible screen was read from the
accessibility tree. Entities are real production records.

| Scenario | Result |
| --- | --- |
| Cold: stopped app, `/en/artworks/<id>` | Exact artwork, no onboarding, one task |
| Cold: `/en/profiles/<id>` | Exact profile |
| Warm: Home pressed, `/en/artworks/<other id>` | `LaunchState: HOT`, exact new artwork |
| Warm: Home pressed, `/sl/zbirke/<id>` | Exact collection, Slovenian UI |
| Foreground: `/sl/umetnine/<id>` while an entity is open | Intent delivered to the running top instance; exact new artwork |
| Repeated: same URL twice | Consumed once; same screen, no extra task or activity |
| Sequential different URLs (three artworks) | Each exact entity; one task throughout |
| Back from a link-opened entity | Returns to the discovery shell; further Back shows the exit hint; no onboarding, duplicate shell or loop |
| Event, exhibition, post (EN and SL) | Route to the matching screen (no public event or exhibition records exist in production, so the screens show their unknown or unavailable states) |
| `/en/map/<markerId>` cold, alternating two markers ×5 | The requested marker is selected each time |

Resolver check, `pm query-activities` against the HTTPS URL, returns no match
for `/`, `/api/...`, `/assets/...`, `/reset-password`, `/verify-email`, `/en/`
and `/en/settings`: the app does not claim the site root, assets, internal
endpoints or auth callbacks.

Defect found and fixed by this run. A cold map link starts at a world-scale
viewport that does not contain its target. `resolveBestMarkerCandidate` treats
the exact marker id as a hint and falls back to the lowest-id loaded marker, so
the coordinator selected an unrelated marker ("Stations of the Cross…", the
lowest id in view) and never fetched the requested one. This reproduced on the
merged Wave 5B build with the pre-existing `/m/<id>` link, so it was not caused
by the new prefixes. `MapTargetCoordinator` now requires the exact marker when
the intent carries no artwork or subject relation; two regression tests fail
without the change.

## Completion level and remaining verification

- Level reached: emulator lifecycle (cold, warm, foreground, repeated,
  sequential, Back) verified with launched intents on API 34. This is
  **emulator evidence, not a physical-device claim**.
- A resolver match is not a verified App Link. `pm get-app-links` reports
  `approved` only because approval was forced for this debug-signed install.
  OS-level verification against the live host requires the deployed
  `assetlinks.json` and the release-signed APK; that final check belongs to the
  release candidate.
- The direct-release signer is proven and asserted; the Google Play App Signing
  certificate is unknown and may need an additional fingerprint entry.
- On a cold map link the Android camera stays at the world-scale view while the
  correct marker is selected. This is recorded for the release-hardening pass.
- No iOS Universal Links implementation.
- No index, canonical, artwork/marker ownership, database, or public-page
  changes.
