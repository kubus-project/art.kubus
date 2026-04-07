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

Images live in [`docs/screenshots/`](docs/screenshots/) (see [`docs/SCREENSHOTS.md`](docs/SCREENSHOTS.md)).

<table>
  <tr>
    <td>
      <strong>Map (marker open)</strong><br />
      <img src="docs/screenshots/map.png" width="520" alt="Map with open marker" />
    </td>
    <td>
      <strong>Community</strong><br />
      <img src="docs/screenshots/community.png" width="520" alt="Community screen" />
    </td>
  </tr>
  <tr>
    <td>
      <strong>Artist Studio</strong><br />
      <img src="docs/screenshots/artist_studio.png" width="520" alt="Artist Studio screen" />
    </td>
    <td>
      <strong>Profile</strong><br />
      <img src="docs/screenshots/profile.png" width="520" alt="Profile screen" />
    </td>
  </tr>
  <tr>
    <td>
      <strong>Home</strong><br />
      <img src="docs/screenshots/home.png" width="520" alt="Home screen" />
    </td>
    <td>
      <strong>Onboarding</strong><br />
      <img src="docs/screenshots/onboarding.png" width="520" alt="Onboarding screen" />
    </td>
  </tr>
  <tr>
    <td>
      <strong>Institution Hub</strong><br />
      <img src="docs/screenshots/institution_hub.png" width="520" alt="Institution Hub screen" />
    </td>
    <td></td>
  </tr>
</table>

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
