# Getting Started with art.kubus

This guide walks you through setting up and running the art.kubus app.

## Prerequisites

### Required
- **Flutter SDK** 3.24+ ([installation guide](https://docs.flutter.dev/get-started/install))
- **Dart SDK** 3.5+ (included with Flutter)
- **Git** for version control

### Platform-Specific

#### Android Development
- Android Studio with Android SDK
- Android device or emulator (API 24+)
- ARCore-supported device for AR features

#### iOS Development
- Xcode 15+ (macOS only)
- iOS device (iOS 14+) or Simulator
- ARKit-supported device for AR features

#### Web Development
- Modern browser (Chrome, Firefox, Safari, Edge)
- AR features redirect to mobile app download

#### Desktop Development
- Platform-specific build tools:
  - Windows: Visual Studio 2019+ with C++ workload
  - macOS: Xcode command line tools
  - Linux: GTK 3.0+ development libraries

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd art.kubus
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Environment Configuration

Copy the example environment file and configure:

```bash
# The app uses AppConfig for runtime configuration
# No .env file needed for basic development
```

Key configuration lives in:
- `lib/config/app_config.dart` — Feature flags and API endpoints
- `lib/services/storage_config.dart` — Storage/IPFS configuration

## Running the App

### Development Mode

```bash
# Run on connected device/emulator (auto-detect)
flutter run --debug

# Run on specific platform
flutter run -d chrome          # Web
flutter run -d windows         # Windows desktop
flutter run -d macos           # macOS desktop
flutter run -d linux           # Linux desktop
flutter run -d <device-id>     # Specific device
```

### List Available Devices

```bash
flutter devices
```

### Hot Reload

While running in debug mode:
- Press `r` in terminal for hot reload
- Press `R` for hot restart (full rebuild)

## Building for Production

### Web

```bash
flutter build web

# With custom base href
flutter build web --base-href=/

# Using the helper script (recommended)
./scripts/build_web_release.ps1 -BaseHref '/' -Renderer canvaskit
```

### Android

```bash
# APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

### Desktop

```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## First Launch

When you first launch the app:

1. **Onboarding** — Welcome screens introduce key features
2. **Permissions** — Grant location (for map) and camera (for AR) access
3. **Sign In** — Create an account or continue as guest
4. **Persona Selection** — Choose your role (Explorer, Artist, Institution)

## Project Structure

```
lib/
├── config/          # App configuration
├── core/            # Core utilities and initialization
├── l10n/            # Localization (ARB files)
├── models/          # Data models
├── providers/       # State management (ChangeNotifier)
├── screens/         # UI screens
│   ├── desktop/     # Desktop-specific layouts
│   └── ...          # Mobile layouts
├── services/        # Business logic and API clients
├── utils/           # Helper utilities
└── widgets/         # Reusable UI components
```

## Troubleshooting

### Common Issues

**Flutter not found**
```bash
# Verify Flutter installation
flutter doctor
```

**Dependency issues**
```bash
flutter clean
flutter pub get
```

**Web build fails with CSP errors**
See the web deployment helper script for self-hosting Flutter web resources.

**AR features not working**
- Ensure device supports ARCore (Android) or ARKit (iOS)
- Grant camera permissions
- AR is not available on web/desktop

### Getting Help

- Check existing issues in the repository
- Review the feature flags in `AppConfig`
- Run `flutter analyze` to catch code issues

## Next Steps

- [App Screens](SCREENS.md) — Learn about all available screens
- [Features](FEATURES.md) — Deep dive into features
- [Architecture](ARCHITECTURE.md) — Understand the codebase structure
