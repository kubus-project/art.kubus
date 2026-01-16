# art.kubus Documentation

Welcome to the art.kubus app documentation. This guide covers the app's features, screens, and how to get started.

## What is art.kubus?

art.kubus is a cross-platform (mobile + desktop) application for discovering, creating, and experiencing art through augmented reality. It combines:

- **Interactive AR Map** — Discover art installations and exhibitions near you
- **Community Platform** — Connect with artists, collectors, and art enthusiasts
- **Artist Studio** — Create and showcase your artwork portfolio
- **Web3 Integration** — Optional wallet, marketplace, and DAO governance features

## Documentation Index

| Document | Description |
|----------|-------------|
| [Getting Started](GETTING_STARTED.md) | Installation, setup, and first steps |
| [App Screens](SCREENS.md) | Overview of all app screens and navigation |
| [Features](FEATURES.md) | Detailed feature documentation |
| [Architecture](ARCHITECTURE.md) | High-level architecture and patterns |

## Quick Start

```bash
# Clone and setup
git clone <repo-url>
cd art.kubus
flutter pub get

# Run in development
flutter run --debug

# Build for web
flutter build web
```

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Supported | ARCore required for AR features |
| iOS | ✅ Supported | ARKit required for AR features |
| Web | ✅ Supported | AR features require mobile app |
| Windows | ✅ Supported | Desktop layout |
| macOS | ✅ Supported | Desktop layout |
| Linux | ✅ Supported | Desktop layout |

## Feature Highlights

### 🗺️ Interactive Map
Explore art installations, exhibitions, and markers on an interactive map with real-time presence indicators.

### 🎨 AR Experience
Scan markers to view 3D art installations in augmented reality (mobile only).

### 👥 Community
Follow artists, join groups, share posts, and participate in discussions.

### 🏛️ Institutions
Discover museums, galleries, and cultural venues with their events and exhibitions.

### 💼 Web3 (Optional)
Connect your Solana wallet to access the marketplace, DAO governance, and collect digital art.

## Contributing

See the project root `AGENTS.md` for development guidelines and coding standards.

## License

See `LICENSE` in the project root.
