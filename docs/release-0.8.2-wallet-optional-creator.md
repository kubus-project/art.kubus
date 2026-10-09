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

## Verification

* `flutter analyze` — no issues.
* `dart format --set-exit-if-changed` on every changed file — clean.
* New `test/screens/wallet_optional_creator_test.dart` (21 tests) drives the
  providers and the Artist Studio / Institution Hub widgets against a fake HTTP
  backend: the request actually sent (no envelope, no wallet, bounded error
  code), old-backend fallback, wallet-free publish, account-scoped portfolio,
  and a regression for a reload loop found while writing them
  (`didChangeDependencies` re-triggered the status load on every provider
  notification).
* Existing creator, telemetry and activation suites pass; see the PR for the
  full-suite result.

### Not verified here

* No browser run against a live backend: the backend needs PostgreSQL with
  PostGIS, which this sandbox lacks. The wire contract is covered by the
  backend's own route tests and the fake-backend tests above, **not** by a
  combined end-to-end run. The release owner should run the smoke below on a
  staging stack.
* No visual QA screenshots (narrow screens, EN/SL, dark/light, text scale, back
  navigation) were produced. The changes reuse existing widgets and only remove
  or change which step is shown; the layouts are unchanged but unreviewed.
* Android release compilation and the Flutter web release build are left to CI.

### Staging smoke (release owner)

1. Backend with migration `099`. 2. Email account, add a public name.
3. Artist Studio → *Apply* (no wallet prompt) → status *In review*.
4. Map → add a street-art marker with cover, author and licence (no wallet
   prompt). 5. Artist Studio → create artwork as draft → publish → unpublish.
6. Create a collection. 7. Reload; deep link `/artist-studio`. 8. Against a
   backend without `099` the wallet step is back.

## Known limitations

* Wallet **unlink** is not implemented (see the backend document).
* Wallet-free **profiles** are not replicated to OrbitDB; their artworks and
  markers are.
* A public page for a wallet-free collection does not exist; the owner sees it.
* Other wallet-keyed read surfaces (a public profile's artworks by wallet,
  marker-subject loading, community feeds) still key on wallet and will not
  list a wallet-free account's work there yet.
* Decision notifications for wallet-free applicants are not delivered
  in-app; the Studio shows the status.
