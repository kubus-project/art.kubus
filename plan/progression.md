# Map & Detail Redesign Progression Plan

Status legend: `[ ]` not started, `[-]` in progress, `[x]` completed

## Execution sequence (follow in order)

1. [x] Audit existing target files and identify minimum shared abstraction changes.
2. [x] Run subagent: marker overlay card architecture + hierarchy recommendations.
3. [x] Run subagent: desktop detail surfaces + shared shell redesign recommendations.
4. [x] Run subagent: responsive/accessibility/performance QA risks and checks.
5. [x] Refactor shared detail primitives and shell helpers to support unified content-first language.
6. [x] Implement marker overlay redesign (`kubus_marker_overlay_card*`, helpers).
7. [x] Implement desktop map side panel redesign (`desktop_map_screen.dart`, `kubus_detail_panel.dart`).
8. [x] Rework desktop artwork detail to content-first hierarchy (`desktop_artwork_detail_screen.dart`).
9. [x] Unify exhibition and event detail visual language (`exhibition_detail_screen.dart`, `event_detail_screen.dart`).
10. [x] Polish spacing, truncation, hover/focus feedback, and responsive behavior across touched screens.
11. [x] Run QA cleanup pass (dedupe, remove dead/inconsistent styling branches).
12. [x] Validate with tests/checks (focused + broader) and fix regressions (focused suite passed; broader suite still reports unrelated existing failures).
13. [x] Final handoff with files changed, hierarchy changes, tradeoffs/follow-ups.

## Non-negotiable checks per step

- Preserve marker stack paging, selection navigation, and primary target routing.
- Keep localization and existing actions/capabilities (share/save/like/directions/AR/attendance/POAP/collab/manage).
- Keep role-gated controls available while visually demoted for viewer-first reading.
- Keep glass/tokens/theme consistency; avoid hardcoded color literals.
- Keep desktop/mobile-safe sizing and avoid overflow/truncation.
