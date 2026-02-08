# Architecture

This document describes the high-level architecture of the art.kubus Flutter application.

---

## Overview

art.kubus is a cross-platform Flutter application with:

- **Mobile** (Android/iOS) — Full features including AR
- **Desktop** (Windows/macOS/Linux) — Adapted layouts
- **Web** — Browser-based, AR redirects to mobile

The app follows a **provider-first** architecture with clear separation between UI, state management, and business logic.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Screens   │  │   Widgets   │  │  Desktop Screens    │  │
│  │ (mobile)    │  │ (shared)    │  │  (desktop layouts)  │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
└─────────┼────────────────┼─────────────────────┼────────────┘
          │                │                     │
          ▼                ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    State Management                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │               Providers (ChangeNotifier)            │    │
│  │  ProfileProvider, WalletProvider, MapProvider, etc. │    │
│  └────────────────────────┬────────────────────────────┘    │
└───────────────────────────┼─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Services   │  │   Helpers    │  │     Utilities    │   │
│  │ (API, AR,    │  │ (resolution, │  │  (formatting,    │   │
│  │  storage)    │  │  media)      │  │   colors)        │   │
│  └──────┬───────┘  └──────────────┘  └──────────────────┘   │
└─────────┼───────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │    Models    │  │  Storage     │  │   Backend API    │   │
│  │ (Artwork,    │  │ (local       │  │   (REST/WS)      │   │
│  │  User, etc.) │  │  persistence)│  │                  │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
lib/
├── config/              # App configuration and feature flags
│   └── app_config.dart  # Central configuration
│
├── core/                # Core initialization
│   └── app_initializer.dart  # Boot sequence
│
├── l10n/                # Localization
│   ├── app_en.arb       # English strings
│   └── app_sl.arb       # Slovenian strings
│
├── models/              # Data models
│   ├── artwork.dart
│   ├── user.dart
│   ├── art_marker.dart
│   └── ...
│
├── providers/           # State management
│   ├── profile_provider.dart
│   ├── wallet_provider.dart
│   ├── map_provider.dart
│   └── ...
│
├── screens/             # UI screens
│   ├── home_screen.dart
│   ├── map_screen.dart
│   ├── desktop/         # Desktop-specific layouts
│   ├── community/       # Community screens
│   ├── web3/            # Web3 screens
│   └── ...
│
├── services/            # Business logic
│   ├── backend_api_service.dart  # HTTP client
│   ├── ar_service.dart           # AR features
│   ├── solana_wallet_service.dart # Blockchain
│   └── ...
│
├── utils/               # Utilities
│   ├── media_url_resolver.dart
│   ├── category_accent_color.dart
│   └── ...
│
├── widgets/             # Reusable components
│   ├── avatar_widget.dart
│   ├── empty_state_card.dart
│   └── ...
│
└── main.dart            # Entry point
```

---

## Boot Sequence

The app initialization follows this sequence:

```
main.dart
    │
    ▼
MultiProvider (create providers)
    │
    ▼
AppInitializer
    ├── Load auth token
    ├── Initialize core providers
    ├── Check onboarding state
    │
    ▼
┌─────────────────────────────────────┐
│ Onboarding needed?                  │
│   YES → OnboardingScreen            │
│   NO  → MainApp                     │
└─────────────────────────────────────┘
    │
    ▼
AppBootstrapService.warmup()
    ├── Preload providers
    └── Cache essential data
    │
    ▼
Main UI renders with data
```

### Key Files

- `lib/main.dart` — Provider tree creation
- `lib/core/app_initializer.dart` — Boot logic and routing
- `lib/services/app_bootstrap_service.dart` — Data warmup

---

## State Management

The app uses **Provider** with `ChangeNotifier` for state management.

### Provider Rules

1. **Creation in main.dart** — All providers are created in the MultiProvider
2. **Idempotent initialization** — `initialize()` is safe to call multiple times
3. **No widget-level init** — Providers are never initialized in `initState` or constructors
4. **Cross-provider bindings** — Use `ChangeNotifierProxyProvider` for dependencies

### Example Provider Pattern

```dart
class ExampleProvider extends ChangeNotifier {
  bool _initialized = false;
  
  Future<void> initialize() async {
    if (_initialized) return; // Idempotent
    _initialized = true;
    
    // Load data
    await _loadData();
    notifyListeners();
  }
  
  void bindToRefresh(AppRefreshProvider refreshProvider) {
    // Idempotent binding
    refreshProvider.addListener(_onRefresh);
  }
}
```

### Core Providers

| Provider | Purpose |
|----------|---------|
| `ProfileProvider` | Current user profile and preferences |
| `WalletProvider` | Wallet state and balance |
| `Web3Provider` | Web3 feature flags |
| `MapProvider` | Map state and markers |
| `CommunityHubProvider` | Social feed and posts |
| `ChatProvider` | Messaging |
| `NotificationProvider` | Push and in-app notifications |
| `ThemeProvider` | App theming |
| `ConfigProvider` | Runtime configuration |
| `PresenceProvider` | User online status |
| `StatsProvider` | Analytics data |

---

## Networking

### HTTP Client

All HTTP requests go through `BackendApiService`:

```dart
// In services/providers
final api = BackendApiService();
final response = await api.get('/api/artworks');
```

**Never** use `package:http` directly in screens or widgets.

### WebSocket

Real-time features use `SocketService`:

- Presence updates
- Chat messages
- Notifications
- Feed updates

### Backend Integration

- Base URL configured in `AppConfig`
- Auth token managed by `AuthService`
- Feature flags gate backend calls

---

## Media & Storage

### URL Resolution

Never hardcode IPFS gateways. Use resolution helpers:

| Use Case | Helper |
|----------|--------|
| General media | `MediaUrlResolver.resolve(url)` |
| Artwork covers | `ArtworkMediaResolver.resolveCover(...)` |
| User avatars | `UserService.safeAvatarUrl(...)` |
| Low-level | `StorageConfig.resolveUrl(url)` |

### Local Storage

- **SharedPreferences** — User preferences, flags
- **CollectiblesStorage** — NFT cache
- **InstitutionStorage** — Institution data
- **TileDiskCache** — Map tiles

---

## Platform Adaptation

### Desktop vs Mobile

The app adapts its UI based on platform:

```dart
// In DesktopShell or responsive widgets
if (isDesktop) {
  return DesktopLayout();
} else {
  return MobileLayout();
}
```

### Parity Rules

- Same providers and services
- Same data models
- Different UI layouts
- Feature-equivalent functionality

### Desktop Screens

All mobile screens have desktop counterparts in `lib/screens/desktop/`:

| Mobile | Desktop |
|--------|---------|
| `home_screen.dart` | `desktop_home_screen.dart` |
| `map_screen.dart` | `desktop_map_screen.dart` |
| `community/` | `desktop/community/` |
| `web3/` | `desktop/web3/` |

---

## Feature Flags

Features are gated using `AppConfig`:

```dart
if (AppConfig.isFeatureEnabled('presence')) {
  // Show presence indicator
}
```

### Build-time Flags

```bash
flutter build web -DANALYTICS_APP_ENABLED=true
```

### Runtime Flags

Stored in SharedPreferences and `ConfigProvider`.

---

## Localization

The app uses ARB-based localization:

```
lib/l10n/
├── app_en.arb    # English (source)
└── app_sl.arb    # Slovenian
```

### Usage

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Text(AppLocalizations.of(context)!.welcomeMessage)
```

### Adding Strings

1. Add key to `app_en.arb`
2. Add translation to `app_sl.arb`
3. Run `flutter gen-l10n`

---

## Theming

### Theme Provider

`ThemeProvider` manages:
- Light/dark mode
- Accent color customization
- System theme following

### Color Rules

1. Use `Theme.of(context).colorScheme.*` for colors
2. Use `themeProvider.accentColor` for accent
3. No hardcoded colors in widgets
4. No colors stored in models

### Color Utilities

| Purpose | Utility |
|---------|---------|
| Category colors | `CategoryAccentColor.get(category)` |
| Rarity colors | `RarityUI.getColor(rarity)` |
| Color transforms | `AppColorUtils.*` |

---

## Testing

### Unit Tests

```bash
flutter test
```

### Integration Tests

```bash
flutter test integration_test/
```

### Test Structure

```
test/
├── models/           # Model tests
├── providers/        # Provider tests
├── services/         # Service tests
└── widgets/          # Widget tests
```

---

## Error Handling

### BuildContext Safety

Never use `BuildContext` after `await` without guards:

```dart
// ❌ Bad
await someAsyncOperation();
Navigator.of(context).pop(); // Context may be invalid

// ✅ Good
final navigator = Navigator.of(context);
await someAsyncOperation();
if (!mounted) return;
navigator.pop();
```

### API Errors

Services return typed results; providers handle errors gracefully:

```dart
try {
  final result = await api.getData();
  // Handle success
} catch (e) {
  // Log and show user-friendly message
  _setError('Failed to load data');
}
```

---

## Security

### Sensitive Data

- No secrets in code
- API keys in environment
- Wallet mnemonics encrypted locally
- Biometric protection for sensitive actions

### Network

- HTTPS only for API calls
- Token-based authentication
- CSRF protection where applicable

---

## Performance

### Optimization Strategies

- Lazy loading of providers
- Image caching
- Map tile caching
- Debounced API calls
- Pagination for lists

### Memory Management

- Dispose providers properly
- Clear caches on logout
- Limit cached items
