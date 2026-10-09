# art.kubus 0.8.2: creator capabilities

> **Update:** the wallet requirements below describe the backend as of this
> slice. They are superseded, behind a backend contract check, by
> [`release-0.8.2-wallet-optional-creator.md`](release-0.8.2-wallet-optional-creator.md).

Status: **draft, not released.** This slice belongs to 0.8.2. Version files
are bumped in the release-preparation commit, not here.

## What changes for people

- **Artist Studio and Institution Hub are always discoverable.** Home lists
  them in their own *Create and organize* section for everyone, guests
  included. Before, the home strip showed Artist Studio only to approved
  artists and Institution Hub only to approved institutions, and the desktop
  sidebar offered guests a single *Infrastructure* entry that opened wallet
  setup.
- **Opening a workspace never asks for a wallet.** A visitor without an
  account sees what the workspace is for and how it opens: account, public
  profile, application, governance review. One button starts that journey.
- **One step at a time, back to the workspace.** The workspace offers only the
  next missing step: an account, then a public name, then a wallet to sign the
  application, then the application. Each step returns to the workspace,
  including after email verification, a page refresh or a shared link
  (`/artist-studio`, `/institution-hub`).
- **No dead end without a wallet.** A signed-in account without a wallet used
  to see a disabled *Connect a wallet to apply* button. It is now an active
  step that opens wallet setup and returns to the workspace.
- **Both roles keep both workspaces.** Holding the institution role no longer
  hides *Create* on desktop, and holding the artist role no longer hides
  *Organize*. A role granted on the server opens its workspace even when the
  wallet's single review concerns the other role. The app no longer clears a
  server-granted role from its cached profile.
- **kubus Node is discoverable on its own.** Node leads the *Network and
  infrastructure* section on home and is a desktop destination for guests
  when its rollout flag is on. Pairing asks for an account at the pairing
  step, never a wallet.
- **Wallet, governance and digital editions stay together** under *Network and
  infrastructure* and keep the wallet lock. Home now has a Wallet card; the
  section is no longer titled *Wallet and Web3 access*.
- **Publishing an artwork no longer needs a local signer.** Publish and
  unpublish are account operations on the backend. The app reports *Saved*
  only once the backend returns the updated artwork, and an error otherwise.

## Capability matrix

| Viewer | Artist Studio / Institution Hub | Wallet asked for |
| --- | --- | --- |
| Guest | Opens; discovery panel; *Start* opens the account sheet | Never |
| Account, no public name | Opens; next step *Add your public name* | No |
| Account with name, no wallet | Opens; next step *Create or link a wallet to apply* | Only at this step: applications are wallet-signed |
| Account with wallet | Opens; *Apply for governance review* | Signer check when submitting (existing) |
| Application pending / declined | Opens; true status, resubmit when declined | No |
| Approved, or role granted on the server | Workspace tools open | Only for wallet operations inside |
| Both roles | Both workspaces open | As above |
| Other role's review pending or approved, no role here | Existing cross-role notice | No |

## Backend dependencies (unchanged, documented)

Verified against the deployed backend (`art.kubus-backend` master `ce11d5f`):

| Operation | Backend authority |
| --- | --- |
| Artist / institution application (`POST /api/dao/reviews`) | Wallet-signed token and signed envelope |
| Review approval | Sets `is_artist` **or** `is_institution` (one role per review) |
| Create artwork (`POST /api/artworks`), collections | Wallet address in the session token |
| Uploads (`POST /api/upload`), map markers | Wallet-signed token |
| Publish / unpublish artwork | Account: owner wallet in token or collaborator user id |
| Create exhibition / event | Account (canonical user id), collaborator roles |
| Node account routes (`/api/availability/account/*`) | Account session |

The first four rows are why a wallet is still needed to become a creator and
to publish media. They are deliberate security decisions, and this slice does
not change them. Making artist and institution applications, artwork creation
and uploads account-authorized needs owner-keyed (`user_id`) ownership on
artworks, collections and reviews, a schema migration, matching
`publicSyncService` mappers and an owner decision on upload abuse controls. It
is not a small change.

## Measurement

No new event types. The creator journey is measured with existing,
allowlisted events:

| Step | Event |
| --- | --- |
| Workspace opened | `screen_view` for `/artist-studio`, `/institution-hub` (desktop: `DesktopArtistStudio`, `DesktopInstitutionHub`) |
| Next step requested | `protected_action_clicked` with `action_type=contribute`, `source_screen=artist_studio` or `institution_hub` |
| Account sheet shown / dismissed | `auth_gate_viewed`, `auth_gate_dismissed` (same dimensions) |
| Method chosen | `auth_method_selected` |
| Account session | `account_session_created` |
| Profile step done | `onboarding_complete` |
| First contribution | `contribution_started`, `contribution_submitted` |

Gap: opening a workspace as an *eligible* creator cannot be told apart from a
visitor's discovery view without a new event type. A new `event_type` must be
allowlisted in the backend before any app build emits it, so it waits for the
next backend deployment.

## Known limitations

- A wallet is still required to apply and to publish artworks (see above).
- The cross-role rule stays: a wallet whose single review is for one role
  sees the existing notice in the other workspace unless the server already
  grants that role.
- The desktop Node destination is in-shell state, not a URL, so a refresh on
  desktop returns to the shell's default destination.
- Slovenian copy for the new strings is a first translation.
