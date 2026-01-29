# lib/screens/desktop/ — Agent Notes (repo-grounded)

## Mission
Maintain feature parity with mobile screens while adapting layout for desktop.

## Parity rules
- Reuse the same providers/services/models as mobile (`lib/screens/**`).
- Match feature flags from `AppConfig.isFeatureEnabled(...)` (see `lib/config/config.dart`).

## Desktop map specifics (from `lib/screens/desktop/desktop_map_screen.dart`)
- Uses the same `MapMarkerService` and travel/isometric flags as mobile.
- Desktop UX places nearby list in the right “functions” sidebar:
	- `DesktopShellScope.openFunctionsPanel(...)`.
- Uses glass UI tokens: `KubusGlassEffects`, `KubusSpacing`, `KubusRadius`.

## Theme + tokens
- Use `ThemeProvider` + `Theme.of(context).colorScheme`.
- Use tokens from `lib/utils/design_tokens.dart` (spacing, glass, layout).

## Evidence (direct quotes with line references)
- `lib/screens/desktop/desktop_map_screen.dart` (lines 245–246, 116):
	- “// Desktop UX: show the nearby list in the functions sidebar (right panel)”
	- “// instead of rendering a "nearby" card overlay on the map.”
	- “// Travel mode is viewport-based (bounds query), not huge-radius.”
