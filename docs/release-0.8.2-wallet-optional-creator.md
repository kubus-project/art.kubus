# art.kubus 0.8.2: wallet-optional creator participation

Status: **for review, not released.** Stacked on #254
(`feat/0.8.2-creator-capability-discovery`); no version file is touched here.
Backend counterpart: `art.kubus-backend` branch
`claude/wallet-optional-architecture-r79bes`, whose
`docs/WALLET_OPTIONAL_ACCOUNT_ARCHITECTURE.md` holds the data model, the
authorization matrix, the migration and the monograph matrix.

## What changes for people

An ordinary account (email or Google) with a public name can now, without
creating or connecting a wallet:

* apply as an artist, and separately as an institution, and see the status;
* use Artist Studio once granted: create artworks with a cover image and
  gallery, save drafts, create collections, publish and unpublish, see its own
  portfolio (drafts included);
* document public art on the map: marker, cover photo and attribution;
* use Institution Hub once granted (events and exhibitions were already
  account-authorised).

The wallet appears only where a signature is genuinely needed: digital
editions / minting, promotion payments, governance votes, token operations.
It is never offered as a prerequisite of applying, uploading, publishing or
mapping.

Not changed: sign-in, wallet login, existing wallet accounts, direct
`/artist-studio` and `/institution-hub` links, guest discovery, the dual-role
workspaces, the platform-native navigation.

## Gating: the app never outruns the backend

`GET /health` now carries `contracts.walletOptionalCreator`. The app reads it
(`BackendApiService.ensureWalletOptionalCreatorKnown`, cached 10 min when
positive and 1 min otherwise) and:

| Backend | Behaviour |
| --- | --- |
| advertises the contract | account applications, wallet-free publish, markers and portfolio |
| does not advertise it, or is unreachable | exactly the #254 behaviour, including the *Create or link a wallet to apply* step |

So this build can ship before or after the backend without exposing a workflow
the backend would reject. Release order is still backend first (see the
backend document).

## Changes

* `BackendApiService`: contract discovery, `submitAccountDAOReview`
  (`POST /api/dao/reviews/account`), `getMyCreatorStatus`
  (`GET /api/dao/reviews/mine`), `getMyArtworks`/`getMyCollections`
  (`?mine=true`). `createArtworkRecord` omits `walletAddress` when empty.
* `DAOProvider`: `submitReview` uses the account endpoint when advertised
  (no envelope, no local signer); per-role `myReviewFor`, `hasServerCapability`
  and the bounded `lastApplicationErrorCode` (`PROFILE_INCOMPLETE` gets its own
  message).
* `resolveCreatorWorkspaceStage(accountApplications:)`: a missing wallet is no
  longer a stage when the backend accepts accounts. The enum value stays for
  older backends.
* `ArtistStudio` / `InstitutionHub`: status read by account; a review for the
  other role no longer blocks a workspace (each role has its own review);
  server-granted capability opens the workspace; wallet and signer checks run
  only against an older backend.
* `ArtworkDraftsProvider.submitDraft`, `artwork_creator_screen`: publish needs
  a session, not a wallet. Authorship stays explicit; the submitter is never
  filled in as artist.
* `PortfolioProvider`, `ArtistPortfolioScreen`: account-scoped portfolio.
* Map marker creation (mobile, desktop and the shared coordinator): no wallet
  gate when advertised. Street-art attribution fields (author, licence) remain
  mandatory.
* Telemetry: `creator_capability_viewed`, `creator_application_submitted`
  (allowlisted on the backend first). No wallet-setup stage is counted as
  activation and a submission is not counted as an approval. `wallet_link_completed`
  is allowlisted in the backend but **not emitted yet**.
* Strings: `creatorApplicationProfileIncompleteToast` (EN/SL).

## Completion pass (public content, attribution, session restore)

Stacked on the backend's migrations 099-102 (`WALLET_OPTIONAL_ACCOUNT_ARCHITECTURE.md`
section 13 there).

* **Attribution is shown apart.** The artwork parser keeps the backend's
  `contributor` (the responsible account) and `verifiedArtist` (an explicit claim)
  in metadata. The byline stays the *recorded* artist ("Unknown artist" when
  unknown); a verified claim links that name to the artist's profile; a new
  `ArtworkContributorLine` shows "Documented by <account>" (EN/SL) on the mobile
  and desktop detail screens and is hidden when the contributor *is* the verified
  artist. Uploading or documenting never credits anyone as the artist.
* **Wallet-free profiles are reachable.** A public profile opened by profile id
  lists the account's contributions, collections and public counters (the
  backend resolves the id). Nothing in the app needed a wallet for this.
* **Session restore without a wallet.** `ProfileProvider.initialize()` only
  hydrated a profile for a persisted wallet, so after a reload or deep link a
  wallet-free account's profile was missing and Artist Studio asked for a public
  name the account already had. It now restores the account profile from the
  session token (3 tests; found by driving the real app against the real
  backend).
* `KubusSheetHeader` allows four subtitle lines (the artist-application sheet
  clipped its explanation on a 390 px phone).

## Verification

Run on this branch (head recorded in the PR description):

* `flutter analyze` - no issues; `dart run custom_lint` - no issues.
* Full `flutter test` - see the PR description for the executed counts.
* `flutter build web --release` against the real backend (below).
* New/changed tests: `test/screens/wallet_optional_creator_test.dart` (28:
  provider/HTTP-contract tests incl. session restore) and
  `test/widgets/artwork_contributor_line_test.dart` (5).

### Real full-stack run (this pass)

Flutter web release build served locally, driven by Chromium/Playwright against
the real backend on PostgreSQL 16 + PostGIS (disposable DB, migrations 099-102):

* Guest and signed-out viewers: public profile by profile id (wallet-free
  contributor), documented artwork ("by Unknown muralist" + "Documented by Ana
  Documenter"), verified-claim artwork ("by Ana Documenter"), public collection,
  map list - at 320, 390, 768, 1024 and 1440 px, English and Slovenian, light
  and dark; no horizontal overflow at any size. A private draft is not
  retrievable (the app shows its generic load-error state; see limitations).
* Email sign-in with no wallet; reload at `/artist-studio`; *Apply for governance
  review* (no wallet step) -> `POST /api/dao/reviews/account` -> *Pending*;
  reviewer decision (wallet-signed, outside the app) -> *Approved* with the
  reviewer's note and an open workspace; `/api/saved`, `/api/messages`,
  `/api/notifications` answer `200` for the wallet-free account (they were
  `401`/`400` before this pass).
* Backend side of the same journey (publish, drafts, collections, markers,
  claims, rename, wallet link, saved items, notifications, archival identity,
  negative tests): `scripts/e2e/` in the backend repository.

### Not verified here

* Creating an artwork **through the browser UI**: the cover picker uses the
  browser's file dialog, which the headless automation could not drive (the app
  reported a generic error). The publish contract is covered by the backend
  journey and by the fake-HTTP tests above; it is **not** covered by a combined
  UI + backend run. The release owner should include it in the staging smoke.
* Text-scale and keyboard focus states were not exercised in the browser (Flutter
  web does not follow the OS text-size setting under automation). The new line
  has a 32 px minimum touch target and a semantic link label; widget tests cover
  its text and visibility.
* Android compilation: left to CI (see the PR description).

### Staging smoke (release owner)

1. Backend with migration `099`. 2. Email account, add a public name.
3. Artist Studio → *Apply* (no wallet prompt) → status *In review*.
4. Map → add a street-art marker with cover, author and licence (no wallet
   prompt). 5. Artist Studio → create artwork as draft → publish → unpublish.
6. Create a collection. 7. Reload; deep link `/artist-studio`. 8. Against a
   backend without `099` the wallet step is back.

## Known limitations

* Wallet **unlink is blocked** and has no UI (see the backend inventory:
  `WALLET_COLUMN_INVENTORY.md`).
* Wallet-free **profiles** are published to IPFS and the registry under their
  profile id but not mirrored to OrbitDB; their artworks and markers are.
* Community posts, direct messages (empty inbox), achievements and presence are
  still wallet-keyed on the backend; a wallet-free account cannot yet author a
  post or message.
* A private or unavailable artwork shows the generic "failed to load" state with
  *Retry* instead of an "unavailable" message.
* Decision notifications for wallet-free applicants are stored against the
  account and listed in-app; there is no realtime push for them.
