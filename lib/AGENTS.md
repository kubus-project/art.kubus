# lib/ — Agent Notes (repo-grounded)

## Mission
Ship Flutter UI without breaking Kubus design tokens, theme roles, feature flags, provider initialization order, or desktop/mobile parity.

## Design tokens & Kubus colors (single source of truth)
- Tokens live in `lib/utils/design_tokens.dart`:
	- `KubusColors` (brand palette + semantic colors)
	- `KubusSpacing`, `KubusRadius`, `KubusTypography`, `KubusGradients`, `KubusGlassEffects`, `KubusLayout`
- Semantic role mapping lives in `lib/utils/kubus_color_roles.dart`:
	- “All UI color decisions should go through this extension or AppColorUtils.”
- Color helpers (use instead of ad‑hoc literals):
	- `lib/utils/app_color_utils.dart` (feature colors + marker colors)
	- `lib/utils/category_accent_color.dart` (category accent from theme primary)
	- `lib/utils/rarity_ui.dart` (rarity colors from theme primary)

## Theme system
- Theme source of truth: `lib/providers/themeprovider.dart`.
	- Uses `KubusColors` + `KubusTypography` and injects `KubusColorRoles` via `ThemeExtension`.
	- Accent colors are constrained in `ThemeProvider.availableAccentColors`.
- UI must use `Theme.of(context).colorScheme.*` or `ThemeProvider.accentColor`.

## Feature flags & config
- Feature flags live in `lib/config/config.dart` (`AppConfig.isFeatureEnabled(...)`).
- Map style assets are configured via `AppConfig.mapStyleLightAsset`/`mapStyleDarkAsset`.
- Telemetry toggles are `AppConfig.enableAnalytics` + `AppConfig.enablePerformanceMonitoring`.

## App init order & providers
- App entry + provider wiring is in `lib/main.dart`.
- Startup sequence and gating is in `lib/core/app_initializer.dart`.
- Provider warm‑up is centralized in `lib/services/app_bootstrap_service.dart`.
- Providers must remain idempotent; do not initialize inside widgets.

## Navigation & localization
- Navigation metadata is centralized in `lib/providers/navigation_provider.dart` (`screenDefinitions`).
- App routes + deep link handling live in `lib/main.dart` and `lib/core/app_initializer.dart`.
- Localization delegates + supported locales are wired in `lib/main.dart` via `AppLocalizations`.

## Media resolution (never hardcode gateways)
- Use `MediaUrlResolver.resolve(...)` (`lib/utils/media_url_resolver.dart`).
- Use `ArtworkMediaResolver.resolveCover(...)` (`lib/utils/artwork_media_resolver.dart`).
- Use `StorageConfig.resolveUrl(...)` (`lib/services/storage_config.dart`).

## Non‑negotiables
- No widget‑level provider initialization; use `AppInitializer` + `AppBootstrapService`.
- Keep desktop/mobile parity (`lib/screens/**` ↔ `lib/screens/desktop/**`).
- Avoid `dart:html`; web-only logic must be in `*_web.dart` with conditional imports.

## Evidence (direct quotes with line references)
- `lib/utils/design_tokens.dart` (lines 4–5):
	- “/// Central source of truth for all Kubus design tokens.”
	- “/// This file defines the palette, spacing, radii, and typography to be used across the app.”
- `lib/utils/kubus_color_roles.dart` (lines 4–5):
	- “/// Centralized color roles for the art.kubus app.”
	- “/// All UI color decisions should go through this extension or AppColorUtils.”
- `lib/providers/themeprovider.dart` (line 59; lines 242/337):
	- “static const List<Color> availableAccentColors = [”
	- “extensions: const <ThemeExtension<dynamic>>[”
- `lib/config/config.dart` (lines 268–269):
	- “/// Check if feature is enabled”
	- “static bool isFeatureEnabled(String feature) {”
- `lib/core/app_initializer.dart` (lines 128, 138):
	- “// Initialize ConfigProvider first”
	- “// Initialize WalletProvider early to restore cached wallet (safe for fresh starts).”
- `lib/services/app_bootstrap_service.dart` (line 29):
	- “/// Centralized bootstrapper that preloads the core providers before the user reaches the main UI.”
- `lib/providers/navigation_provider.dart` (line 58):
	- “static const Map<String, ScreenDefinition> screenDefinitions = {”
