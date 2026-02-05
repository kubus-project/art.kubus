## agents.md — Map Refactor Wave (Subagents)

### Mission
Reduce technical debt by extracting shared map logic (interaction, camera, data lifecycle) and reusable UI shells into dedicated modules. Maintain stable behavior across web/desktop/mobile.

### Constraints
- No automatic git commits.
- Preserve existing UX; refactor only.
- Each extraction lands in small verifiable steps with `flutter analyze` clean and tests passing.
- Shared map sources/layers remain centralized in `MapLayersManager`.

### Subagents and responsibilities

#### InventoryAgent
- Diff `map_screen.dart` and `desktop_map_screen.dart`.
- Rank duplication by LOC + risk + dependency complexity.
- Provide exact line ranges and proposed destination modules.

#### InteractionAgent
- Extract shared marker hit-testing + selection flow:
  - `_handleMapTap` + `_fallbackPickMarkerAtPoint` (+ any helpers).
- Implement `MapMarkerInteractionController` with injected callbacks.
- Ensure no duplicate listeners; no `BuildContext` dependencies unless unavoidable.

#### CameraAgent
- Implement `MapCameraController` that standardizes:
  - centering marker with overlay-safe composition offsets,
  - canceling auto-center on user interaction,
  - consistent zoom/tilt transitions (2D/3D parity).

#### FetchAndLifecycleAgent
- Build `MapDataCoordinator` to unify:
  - fetch triggers,
  - refresh cadence,
  - deduped reloading,
  - correct disposal of listeners/timers/subscriptions.

#### UIExtractAgent
- Extract reusable UI shells under `map_ui_shared/`:
  - square control buttons,
  - search bar shell (chrome),
  - small repeated rows/cards (task progress, discovery card, etc.).
- Keep them stateless and parameter-driven.

#### PerfAgent
- Identify and eliminate jank/leak sources:
  - repeated rebuild triggers,
  - redundant setStyle/setPaint calls,
  - duplicate event listeners,
  - excessive AnimatedSwitcher churn.
- Provide low-risk optimizations with instrumentation notes.

### Definition of Done
- Screens significantly reduced in size with clear separation:
  - shared logic → `lib/screens/map_core/`
  - shared UI → `lib/screens/map_ui_shared/`
  - platform-specific layout stays in screen files
- Analyzer clean, tests pass, and basic map flows verified on web + mobile.
