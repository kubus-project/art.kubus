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

## Ownership and live association probe

The checked-in app-domain transport is `web/` in this repository. The reusable
web artifact workflow builds Flutter into `build/web` and includes hidden
files, so the repository-owned association path is
`web/.well-known/assetlinks.json`. The production workflow deploys the complete
immutable `build/web` artifact from protected `master`; it has no single-file
association deployment path. No file is authored or deployed because the
production certificate set is not fully proven and the safe deployment path
would promote the full web artifact.

Direct HTTPS probe of
`https://app.kubus.site/.well-known/assetlinks.json` on 2026-09-25 returned:

- HTTP `404 Not Found`
- `Content-Type: text/html`
- no redirect / no `Location` header
- `Cache-Control: private`
- LiteSpeed origin response

The live host therefore does not currently publish a usable Digital Asset
Links statement. No production file was changed. The current app source
contains no `.well-known/assetlinks.json` file.

## Package and signing evidence

The Android Gradle configuration declares namespace and application ID
`com.art.kubus`, target SDK 36, and `MainActivity` is exported with
`launchMode="singleTop"`. The protected `android-release` workflow signs its
GitHub release APK and AAB artifacts. The public GitHub release APK
`v0.7.4` (source `4bd9387b4b16daeb641d36f0a1dd32848a78fda3`) was downloaded,
verified with Android `apksigner`, and its published SHA-256 checksum matched.
Its APK signer certificate SHA-256 is
`426842ad10cbaf2f45315bea6936253ec32d42b44d25f6935a1d2b9ce3b1c8a3`.
This proves the direct GitHub APK release signer only.

**Google Play App Signing: UNVERIFIED.** The repository workflow does not
establish whether the AAB was uploaded to a Play track or whether Play re-signs
installed APKs. No Play Console evidence is available, so the direct-release
fingerprint is not asserted as the complete production certificate set and is
not copied into `assetlinks.json`. Human action required: Google Play Console
→ Setup / App integrity → App signing → App signing key certificate → SHA-256
certificate fingerprint (wording can vary). No private signing material was
read or emitted.

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
and OS domain-verification behavior are not verified in this run.

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

## Completion level and remaining verification

- Below Level A: manifest/parser/test code is present, but functional lifecycle
  launch could not be tested because the environment blocked `adb shell am start`.
- Direct GitHub APK signer is proven; Play App Signing certificate remains
  unknown. No production `assetlinks.json` source was authored.
- No live App Links verification or deployment; the endpoint still returns 404.
- Cold/warm/foreground intent launches, Back-stack, and native launch captures
  remain unverified because the activity launch command was blocked.
- Genuine 200% browser zoom remains HUMAN VERIFICATION REQUIRED; CSS viewport
  simulation is not counted.
- No iOS Universal Links implementation.
- No index, canonical, artwork/marker ownership, database, or public-page
  changes.
