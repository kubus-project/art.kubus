# Wave 3 Android App Links

Status: implementation evidence for the stacked Wave 3 branch. This document
does not claim live domain verification, production signing verification, or
device acceptance.

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

## Ownership and live association probe

The checked-in app-domain transport is `web/` in this repository. The reusable
web artifact workflow builds Flutter into `build/web`, applies the
`production-web` artifact policy, and deploys that artifact to the app host.
Accordingly, a future repository-managed association file belongs at
`web/.well-known/assetlinks.json` and should be checked into that static web
artifact. No file is added in this pass because the production signing identity
has not been established.

Direct HTTPS probe of
`https://app.kubus.site/.well-known/assetlinks.json` on 2026-09-24 returned:

- HTTP `404 Not Found`
- `Content-Type: text/html`
- no redirect / no `Location` header
- `Cache-Control: private`
- LiteSpeed origin response

The live host therefore does not currently publish a usable Digital Asset
Links statement. No production file was changed.

## Package and signing evidence

The Android Gradle configuration declares namespace and application ID
`com.art.kubus`, target SDK 36, and `MainActivity` is exported with
`launchMode="singleTop"`. The mobile release workflow obtains the release
keystore and aliases from the protected `android-release` GitHub Environment
and signs both APK and AAB outputs with that configured key. The inspected
workflow builds artifacts and can publish a GitHub Release; it does not record
whether Play App Signing is enabled or identify the certificate on APKs
delivered by Google Play.

**Production signing fingerprint: UNVERIFIED.** No fingerprint is guessed or
written here. The deployable APK signer, any upload certificate, and the Play
App Signing certificate must be distinguished from authoritative distribution
records before an association statement is authored. Private signing material
was not read or emitted.

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
not change the map implementation. Cold, warm, foreground, Android Back-stack,
and OS domain-verification behavior were not fully verified in this run.

## Local Android verification

- A debug APK built and installed on the `kubus_test_api34` Android emulator
  (Android API 34). The install used `adb install -r -d` to allow the local
  debug version code to replace the newer emulator copy; existing emulator app
  data was preserved.
- `cmd package query-activities` resolved an English artwork canonical URL and
  a Slovenian event canonical URL to `com.art.kubus/.MainActivity` (Chrome was
  also a resolver). This verifies manifest matching, not Android domain
  ownership or a successful activity launch.
- `pm verify-app-links --re-verify com.art.kubus` was issued, then the result
  was checked after about 110 seconds. `pm get-app-links` reported
  `app.kubus.site: 1024` on API 34. Android documents `verified` as the success
  state and values at or above 1024 as verifier-specific errors; this result
  is therefore **not verified** and is consistent with the live association
  URL returning 404.
- The local command review blocked `adb shell am start` for the canonical URL.
  Consequently cold-start, warm/background, foreground re-entry, Back-stack,
  and screenshot/video launch evidence could not be completed. No launch proof
  is inferred from resolver matching or parser/unit tests.
- The first direct `flutter build apk --release --no-pub` attempt used stale
  generated plugin metadata and failed to resolve the
  `flutter_native_splash` and `integration_test` Android classes. The
  repository-prescribed `npm run verify:flutter:android` then re-resolved
  dependencies and passed both the debug build and unsigned release APK build.
  No release signing identity was inferred from that compile check.

The retained UI/browser matrix in PR #178 uses a synthetic public-only fixture,
not a production entity. Its genuine 200% zoom item remains open: the available
Playwright browser accepted a keyboard shortcut but reported no change in
`innerWidth`, device-pixel ratio, or `visualViewport.scale`. The separate narrow
CSS viewport simulation is not counted as browser zoom.

## Explicitly not completed here

- No `assetlinks.json` source: production signing fingerprint is unverified.
- No live App Links verification or deployment.
- No Play App Signing or direct-distribution signer claim.
- Cold/warm/foreground intent launches, Back-stack, and native launch captures
  remain unverified because the activity launch command was blocked.
- Genuine 200% browser zoom for the Wave 2B acceptance remains unverified.
- No iOS Universal Links implementation.
- No index, canonical, artwork/marker ownership, database, or public-page
  changes.
