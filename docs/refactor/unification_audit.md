# Unification Audit (Map + Search)

Date: 2026-02-05

Scope (per request):
1) Unify `lib/screens/map_screen.dart` + `lib/screens/desktop/desktop_map_screen.dart` into shared modules.
2) Unify **all search bars** (map, home, community, messages, etc.) into **one base widget** with parameters + thin wrappers.
3) Identify additional duplicated widgets for follow-up extraction.

This audit is research-only: it identifies duplication clusters, highlights existing shared building blocks already in the repo, and proposes extraction points that preserve behavior.

---

## Map Surface Area

### Primary map screens
- `lib/screens/map_screen.dart` (mobile)
- `lib/screens/desktop/desktop_map_screen.dart` (desktop)

### Other MapLibre surfaces (not the main target, but share patterns)
- `lib/screens/web3/artist/artwork_creator_screen.dart` (uses `ArtMapView` + `_handleMapStyleLoaded` + controller)
- `lib/screens/map_markers/marker_editor_view.dart` (uses `ArtMapView` + `_handleMapStyleLoaded` + controller)

### Existing shared map widgets/helpers (avoid duplicating these)
- Map view wrapper + web fallback style safety:
  - `lib/widgets/art_map_view.dart`
  - `lib/services/map_style_service.dart`
  - `lib/utils/maplibre_style_utils.dart`
- Pointer / platform-view interception overlays:
  - `lib/widgets/map_overlay_blocker.dart`
- Marker overlay presentation:
  - `lib/widgets/marker_overlay_card.dart`
- Hitbox / marker utilities already centralized:
  - `lib/utils/map_marker_helper.dart`
  - `lib/utils/map_marker_icon_ids.dart`
  - `lib/utils/map_marker_subject_loader.dart`
  - `lib/utils/map_tap_gating.dart`
  - `lib/utils/map_viewport_utils.dart`
  - `lib/utils/art_marker_list_diff.dart`

---

## Search Bars Surface Area

### Canonical desktop search component today
- `DesktopSearchBar` lives in `lib/screens/desktop/components/desktop_widgets.dart` (lines ~514–650)
  - Used by:
    - `lib/screens/desktop/desktop_map_screen.dart` (top bar, lines ~3030–3170)
    - `lib/screens/desktop/desktop_home_screen.dart` (header, lines ~600–700; floating header lines ~2520–2560)
    - `lib/screens/desktop/community/desktop_community_screen.dart` (header, lines ~1320–1370)
    - `lib/screens/desktop/web3/desktop_marketplace_screen.dart` (header, lines ~110–170)

### Mobile + mixed (TextField-based) search inputs (examples)
- Map mobile search card:
  - `lib/screens/map_screen.dart` `_buildSearchCard` (lines ~5952–6055)
  - plus suggestions sheet `_buildSuggestionSheet` (lines ~6103–6213)
- Community group directory search:
  - `lib/screens/community/community_screen.dart` `_buildGroupSearchField` (lines ~1640–1695)
- Share flow profile search:
  - `lib/widgets/share/share_message_sheet.dart` (search field around lines ~120–185, includes a debounce)
- Marker management search:
  - `lib/screens/map_markers/manage_markers_screen.dart` (search TextField around lines ~120–165)

### Desktop “search overlay” pattern duplicates
- Desktop map suggestions overlay:
  - `lib/screens/desktop/desktop_map_screen.dart` `_buildSearchOverlay` (lines ~3174–3313)
- Desktop community suggestions/results overlay:
  - `lib/screens/desktop/community/desktop_community_screen.dart` `_buildSearchOverlay` (lines ~1458+)

---

## Duplication Clusters

| Cluster | Files | Identical / near-identical | Key differences | Extraction suggestion |
|---|---|---|---|---|
| Map search input + clear/filter affordances | `map_screen.dart` `_buildSearchCard` (~5952+) vs desktop top bar using `DesktopSearchBar` (~3098+) | Prefix icon, clear button logic, semantics label `map_search_input`, mouse cursor text | Mobile packs “filters toggle” into suffix when query empty; desktop has separate Filters icon button; glass tint/alpha differs | Extract **base** `KubusSearchBar` and build `MapSearchBar` wrapper with parameters (suffix slots for filter toggle / clear), used by both screens |
| Search suggestions overlays | `map_screen.dart` `_buildSuggestionSheet` (~6103+) vs `desktop_map_screen.dart` `_buildSearchOverlay` (~3174+) vs `desktop_community_screen.dart` `_buildSearchOverlay` (~1458+) | Min-length gating (≥2), empty/loading/no-results states, list tiles with icon + label + optional subtitle | Mobile is positioned `top:` + glass container; desktop is `CompositedTransformFollower` anchored to field; different max sizes | Extract `KubusSearchSuggestionsOverlay` (builder/slot for item rendering + anchoring mode) and reuse in map + desktop community (keep data fetching outside) |
| DesktopSearchBar vs other search fields | `desktop_widgets.dart` `DesktopSearchBar` vs many `TextField` search inputs (community, share sheet, manage markers) | Controller+focus, prefix search icon, optional clear icon, hintText | Some are filled surfaces, some are glass; some debounce externally; some enable/disable states | Make `DesktopSearchBar` a thin wrapper over `KubusSearchBar` (preserving public API), and gradually migrate TextFields to `KubusSearchBar` with the right style variant |
| Map glass icon buttons / chips | Mobile: `_glassIconButton` / `_glassChip` in `map_screen.dart` (~5462+ / ~5512+) vs Desktop: `_buildGlassIconButton` / `_buildGlassChip` in `desktop_map_screen.dart` (~2887+ / ~2944+) | Same conceptual component (glass button/chip with border + tint + hover/click cursor) | Desktop uses `animationTheme`, larger sizes, different alpha, and supports active state; mobile uses InkWell + fixed 36px | Extract `KubusGlassIconButton` + `KubusGlassChip` with a `spec` object (`size`, `radius`, `blurSigma`, `alpha`) and keep call-sites specifying their current values |
| Map marker rendering pipeline | Both map screens define: style init, image preregistration, hitbox layer, marker source/layer IDs, cluster logic, `_syncMapMarkersSafe`, `_syncMapMarkers`, `_preregisterMarkerIcons`, `_markerFeatureFor`, `_clusterFeatureFor` | Large identical sections around marker layer IDs, epochs, registered images, cluster bucket logic | Desktop also has pending marker layer; desktop overlay modes differ | Extract non-UI engine to `lib/widgets/map/core/map_marker_render_engine.dart` (stateful helper owned by each screen) + platform adapter for extras (pending marker) |
| Map travel/isometric toggles | Both map screens have prefs load + toggle methods and same flags `mapTravelMode` / `mapIsometricView` | Preferences keys, cache invalidation on toggle, refresh markers | Desktop uses `_moveCamera` and has different UI placement | Extract helper `MapViewPreferencesController` (pure Dart helper) used by both screens; keep UI placement in shells |

---

## Proposed File Outputs

These are proposed; we’ll implement incrementally with compile checks after each step.

### Search system (required)
- `lib/widgets/search/kubus_search_bar.dart` — base reusable search input (controller/focus, clear button, leading/trailing slots, theming + accessibility).
- `lib/widgets/search/kubus_search_bar_styles.dart` — style specs (glass vs filled vs minimal) to preserve existing visuals.
- `lib/widgets/search/kubus_search_overlay.dart` — reusable suggestions/results overlay scaffold (anchored or positioned; content via builder).
- `lib/widgets/search/presets/map_search_bar.dart` — thin wrapper preset for map screens.
- `lib/widgets/search/presets/community_search_bar.dart` — thin wrapper preset for community screens.

### Map unification (required)
- `lib/widgets/map/adapters/map_platform_adapter.dart` — platform behavior knobs (hover enablement, cursor/pointer intercept).
- `lib/widgets/map/layout/map_layout_spec.dart` — sizes/paddings used by the shared widgets.
- `lib/widgets/map/core/map_marker_render_engine.dart` — shared marker layer/source setup + sync functions.
- `lib/widgets/map/ui/map_search_host.dart` — shared map search UI host (search bar + overlay hook).
- `lib/widgets/map/ui/map_filters_panel.dart` — shared panel shell, with chip builders passed in.

### “Nice to have” (follow-up)
- `lib/widgets/glass/kubus_glass_icon_button.dart`
- `lib/widgets/glass/kubus_glass_chip.dart`

---

## Risks / Gotchas (keep behavior identical)

- **Pointer interception on web**: map overlays must keep blocking platform-view touch-through (use `MapOverlayBlocker` consistently).
- **Async + context safety**: current screens correctly avoid using deactivated contexts; extracted widgets must not capture context-backed loaders.
- **Theme discipline**: no hardcoded colors; use `Theme.of(context).colorScheme.*`, `ThemeProvider.accentColor`, `KubusColorRoles`.
- **Provider init order**: do not move provider initialization into widgets.
- **Desktop/mobile parity**: any extraction used by one map must be applied to the other.

---

## Next steps (implementation order)

1) Build `KubusSearchBar` + rewire `DesktopSearchBar` to use it (no call-site changes needed, minimal risk).
2) Replace map search input(s) to use `KubusSearchBar`.
3) Introduce reusable search overlay scaffold and migrate desktop map + desktop community overlays.
4) Start map unification by extracting the marker rendering pipeline into a shared engine (largest debt win).
