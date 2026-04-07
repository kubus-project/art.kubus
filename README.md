<p align="center">
  <img src="assets/images/logo.png" width="160" alt="art.kubus logo" />
</p>

# art.kubus

[![Flutter](https://img.shields.io/badge/Flutter-app-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![License: Apache-2.0 (client)](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

A cross-platform Flutter app for discovering public and street art on a map — community-first, with optional AR and wallet-connected experiences.

- Map-first discovery (MapLibre) with search and nearby browsing
- Community features: profiles, posts, follows, and reporting
- Mobile AR viewer for 3D artworks on supported devices
- Institutions and events surfaces (feature-flagged; backend-dependent)
- Optional wallet / Web3 features (Solana), gated behind feature flags

Project site: https://art.kubus.site
App site: https://app.kubus.site

## Platforms

- Android / iOS
- Web
- Windows / macOS / Linux

> AR experiences are mobile-focused; web/desktop builds prioritize discovery and community workflows.

## What this repository contains

- `lib/`, `assets/`, `android/`, `ios/`, `web/`, `windows/`, … — the Flutter client (Apache-2.0)
- `docs/` — client documentation and the open-platform boundary (start at [`docs/README.md`](docs/README.md))
- `backend/` — platform backend for local development / reference (not Apache-2.0; see [`backend/README.md`](backend/README.md))

## Quick start

Prereqs: Flutter (Dart >= 3.6).

```bash
flutter pub get
flutter run
```

Build (examples):

```bash
flutter build web
flutter build apk --release
```

### Point the app at a backend

The client reads its API base URL from build-time defines (see `lib/config/config.dart`):

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:3000
```

For deeper setup (platform prerequisites, troubleshooting, backend setup), use [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).

## Documentation

- Docs index: [`docs/README.md`](docs/README.md)
- Getting started: [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md)
- Features: [`docs/FEATURES.md`](docs/FEATURES.md)
- Screens: [`docs/SCREENS.md`](docs/SCREENS.md)
- Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- Open platform scope: [`docs/OPEN_PLATFORM.md`](docs/OPEN_PLATFORM.md)

## Screenshots

Screenshots live under `docs/screenshots/` (file list: [`docs/SCREENSHOTS.md`](docs/SCREENSHOTS.md)).

### Map (marker open)

![Map with open marker](docs/screenshots/map.png)

Map-first discovery with nearby browsing and filters.

- Search across artworks, artists, and institutions.
- Toggle discovery filters (e.g. nearby, discovered/undiscovered).
- Open a marker to view the artwork card, then save/share or jump to details.

### Community

![Community screen](docs/screenshots/community.png)

Social feed + discovery for posts, people, and topics.

- Browse the community feed with sorting modes (e.g. recent/top).
- Search posts, users, and tags.
- Follow creators and start conversations (messages).

### Artist Studio

![Artist Studio screen](docs/screenshots/artist_studio.png)

Creator workspace for publishing and managing your presence.

- Create artworks, collections, and exhibitions.
- Manage markers (create, publish, edit) used for map discovery.
- Handle invites and (where enabled) promotion requests.

### Profile

![Profile screen](docs/screenshots/profile.png)

Public identity: bio, activity, and portfolio surface.

- Showcase artworks and collections.
- Track posts, followers/following, and earned progress.
- Follow or message creators directly from their profile.

### Home

![Home screen](docs/screenshots/home.png)

Dashboard that keeps your next actions close.

- Quick actions for common flows (e.g. studio, map, AR where enabled).
- Recent activity and lightweight stats panels.
- Discovery shortcuts to trending art and creators.

### Onboarding

![Onboarding screen](docs/screenshots/onboarding.png)

Guided setup for new accounts.

- Create an account or sign in.
- Choose your role and complete profile basics.
- Optionally connect a wallet and enable extra features (feature-flagged).

### Institution Hub

![Institution Hub screen](docs/screenshots/institution_hub.png)

Workspace for institutions hosting exhibitions and events.

- Create and manage exhibitions/events (availability depends on backend + flags).
- Coordinate collaboration invites and visibility requests.
- Track basic institution-level stats (where enabled).

## Project status

Active development. Expect rapid iteration and occasional breaking changes while the client and platform harden.

## Contributing, support, and policies

- Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Support: [`SUPPORT.md`](SUPPORT.md)
- Security: [`SECURITY.md`](SECURITY.md)
- Governance: [`GOVERNANCE.md`](GOVERNANCE.md)

Licensing notes:

- Client code: [`LICENSE`](LICENSE) (Apache-2.0) + [`NOTICE`](NOTICE)
- Trademarks/branding: [`TRADEMARK.md`](TRADEMARK.md)
- Assets/content: [`LICENSE_ASSETS.md`](LICENSE_ASSETS.md)
