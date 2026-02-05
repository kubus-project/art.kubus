# Widget Extraction Backlog (Desktop + Mobile Parity)

Date: 2026-02-05

This backlog lists duplicated UI patterns that should be extracted into reusable widgets/modules after the Map + Search unification work.

Scoring:
- Complexity: S/M/L (effort)
- Risk: low/med/high (chance of behavior regression)

---

## P0 — High value / low-to-med risk (do soon)

1) **Unified Search Overlay Scaffold**
- Suggestion: `KubusSearchOverlay`
- Where duplicated:
  - `lib/screens/desktop/desktop_map_screen.dart` `_buildSearchOverlay` (~3174+)
  - `lib/screens/desktop/community/desktop_community_screen.dart` `_buildSearchOverlay` (~1458+)
  - Mobile map suggestions sheet: `lib/screens/map_screen.dart` `_buildSuggestionSheet` (~6103+)
- Complexity: M
- Risk: med (anchoring + pointer handling)
- Plan: extract overlay container + states (min chars/loading/empty); keep fetching outside.

2) **Glass Icon Button + Glass Chip**
- Suggestion: `KubusGlassIconButton`, `KubusGlassChip`
- Where duplicated:
  - Mobile map: `lib/screens/map_screen.dart` `_glassIconButton` / `_glassChip` (~5462+, ~5512+)
  - Desktop map: `lib/screens/desktop/desktop_map_screen.dart` `_buildGlassIconButton` / `_buildGlassChip` (~2887+, ~2944+)
- Complexity: M
- Risk: low–med
- Plan: extract base widgets with a `spec` for sizing/alpha; keep exact current visuals via params.

3) **Empty-state cards and list empty placeholders**
- Existing shared widget: `lib/widgets/empty_state_card.dart` (already good)
- Duplications remain in how empty states are wrapped/padded.
- Complexity: S
- Risk: low
- Plan: standardize wrapper widget `KubusEmptyStateSection` with consistent padding + optional action.

---

## P1 — Medium value / medium risk

4) **Map marker selection overlay host**
- Suggestion: `MapMarkerOverlayHost`
- Where:
  - Mobile map anchored overlay build logic in `lib/screens/map_screen.dart` `_buildAnchoredMarkerOverlay` (large block)
  - Desktop map anchored overlay build logic in `lib/screens/desktop/desktop_map_screen.dart` marker overlay layer builders
- Complexity: L
- Risk: high (anchor math, selection stack paging, layout differences)
- Plan: extract shell with slots: card builder, anchor provider, paging controls.

5) **Map controls stack (zoom, travel, isometric, center-on-me, add marker)**
- Suggestion: `MapControlsColumn`
- Where:
  - Mobile map: `_buildPrimaryControls` (~6610+)
  - Desktop map: `_buildMapControls` (later in file)
- Complexity: M
- Risk: med
- Plan: extract common button list; keep placement + desktop-only actions in shells.

---

## P2 — Lower value / higher churn

6) **Desktop side panels vs mobile bottom sheets containers**
- Suggestion: `KubusPanelScaffold`
- Complexity: L
- Risk: high
- Plan: only after Map core is stabilized; avoid UI redesign.

---

## Notes

- Do not create duplicate domain models; keep UI-only helpers under `lib/widgets/*` or `lib/widgets/map/*`.
- Always preserve feature flags via `AppConfig.isFeatureEnabled(...)`.
- Keep pointer interception rules intact on web (`MapOverlayBlocker`).
