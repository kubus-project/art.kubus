# Design Unification Notes - Creator/Manager Flows

## Overview

This pass unified the visual design, layout, component styling, spacing, typography, and micro-interactions across all creator and manager screens in Artist Studio and Institution Hub.

**Zero functional regressions**: all state management, validation, API calls, routing, and providers remain identical.

---

## Tokens Used

All styling is now derived from the centralized Kubus design token system defined in `lib/utils/design_tokens.dart`:

| Token Group | Source | Values Used |
|---|---|---|
| **Spacing** | `KubusSpacing` | `xxs` (2), `xs` (4), `sm` (8), `md` (16), `lg` (24), `xl` (32) |
| **Border Radius** | `KubusRadius` | `xs` (4), `sm` (8), `md` (12), `lg` (16), `xl` (24) |
| **Typography** | `KubusTextStyles` | `screenTitle`, `sectionTitle`, `detailScreenTitle`, `detailSectionTitle`, `detailCardTitle`, `detailBody`, `detailCaption`, `detailLabel`, `detailButton`, `actionTileTitle` |
| **Glass Effects** | `KubusGlassEffects` | `blurSigma` (12), `blurSigmaLight` (6) |
| **Colors** | `Theme.colorScheme` + `KubusColorRoles` | `web3ArtistStudioAccent`, `web3InstitutionAccent`, semantic scheme colors |

---

## Shared Components Introduced

**File**: `lib/widgets/creator/creator_kit.dart`

| Widget | Purpose |
|---|---|
| `CreatorScaffold` | Page shell with `AnimatedGradientBackground`, transparent scaffold, app bar, width centering on wide viewports |
| `CreatorSection` | Labelled `LiquidGlassCard` panel that groups related form fields with consistent padding |
| `CreatorFieldSpacing` | Standard `KubusSpacing.md` (16px) vertical gap between fields |
| `CreatorSectionSpacing` | Standard `KubusSpacing.lg` (24px) vertical gap between sections |
| `CreatorFooterActions` | Primary / secondary / destructive button row with consistent sizing, radius, and loading state |
| `CreatorTextField` | Above-label text field with token-based fill, border, and focus styling |
| `CreatorDropdown<T>` | Above-label dropdown with consistent container styling |
| `CreatorSwitchTile` | Toggle tile with title/subtitle in a bordered container |
| `CreatorCoverImagePicker` | Cover image upload with pick/change/remove controls and preview |
| `CreatorDateField` | Tappable date display with icon, label, and clear button |
| `CreatorTimeField` | Tappable time display mirroring `CreatorDateField` |
| `CreatorInfoBox` | Info/hint box with accent tint, icon, and description |
| `CreatorStatusBadge` | Small pill badge for status labels (Draft/Public/Private) |
| `CreatorProgressBar` | Multi-step progress indicator with active/inactive segments |

---

## Screens Updated

### 1. Collection Creator (`lib/screens/web3/artist/collection_creator.dart`)
- Wrapped in `CreatorScaffold` (replaces plain `Scaffold`)
- Form fields use `CreatorTextField`, `CreatorCoverImagePicker`, `CreatorSwitchTile`
- Footer uses `CreatorFooterActions`
- **NEW**: "Add Artworks" section with search/filter, artwork list with thumbnails, checkbox selection, and selected chips. Wired to existing `CollectionsProvider.addArtworks()` and `ArtworkProvider.loadArtworksForWallet()`.

### 2. Exhibition Creator (`lib/screens/events/exhibition_creator_screen.dart`)
- Wrapped in `CreatorScaffold` (replaces manual `AnimatedGradientBackground` + `Scaffold`)
- Sections use `CreatorSection`, fields use `CreatorTextField`, `CreatorDateField`
- Private `_DateRow` widget removed (replaced by `CreatorDateField`)
- Toggle uses `CreatorSwitchTile`, collab hint uses `CreatorInfoBox`
- Footer uses `CreatorFooterActions`

### 3. Event Creator (`lib/screens/web3/institution/event_creator.dart`)
- Retains 4-step wizard structure (not wrapped in `CreatorScaffold`)
- All `GoogleFonts.inter()` replaced with `KubusTextStyles` tokens
- All hardcoded spacing/padding/radius replaced with `KubusSpacing`/`KubusRadius` tokens
- Helper methods (`_buildTextField`, `_buildDropdown`, `_buildDateField`, etc.) styled to match creator kit patterns
- Navigation buttons match `CreatorFooterActions` styling
- Deprecated `activeColor` replaced with `activeTrackColor`

### 4. Artwork Creator (`lib/screens/web3/artist/artwork_creator_screen.dart`)
- Retains 5-step Stepper structure
- All typography converted to `KubusTextStyles`
- All spacing/radius converted to `KubusSpacing`/`KubusRadius`
- Custom `_kubusInputDecoration()` helper provides consistent TextFormField styling
- ElevatedButton styling unified

### 5. Marker Editor View (`lib/screens/map_markers/marker_editor_view.dart`)
- Form fields grouped into `CreatorSection` widgets: Subject, Details, Location, Settings
- Toggles use `CreatorSwitchTile`
- Save/Delete buttons replaced with `CreatorFooterActions`
- TextFormField decoration unified via `_creatorInputDecoration()` helper
- All spacing/typography converted to tokens

### 6. Manage Markers Screen (`lib/screens/map_markers/manage_markers_screen.dart`)
- Status badges use `CreatorStatusBadge`
- Typography uses `KubusTextStyles`
- Search field styling unified
- All spacing uses `KubusSpacing` tokens

### 7. Event Manager (`lib/screens/web3/institution/event_manager.dart`)
- Event cards use `LiquidGlassCard`
- Status badges use `CreatorStatusBadge`
- Typography uses `KubusTextStyles`
- All spacing/radius uses tokens

---

## Edge Cases Handled

- **Artwork Creator stepper**: The `Stepper` widget imposes its own layout constraints. Rather than wrapping in `CreatorScaffold`, design tokens were applied directly to all inner styling.
- **Event Creator wizard**: Uses custom animated transitions. Kept the existing animation wrapper; unification applied to inner spacing, typography, and form elements.
- **Marker Editor embedded mode**: `MarkerEditorView` is used both standalone (via `MarkerEditorScreen`) and embedded in `ManageMarkersScreen`. The `CreatorSection` groups and `CreatorFooterActions` work correctly in both contexts.
- **Glass capability detection**: `CreatorScaffold` uses `AnimatedGradientBackground` which adapts to device capabilities via `GlassCapabilitiesProvider`.
- **Feature-flag gated UI**: Exhibition creator's `collabInvites` feature flag check is preserved using `CreatorInfoBox` wrapper.

---

## Localization

New l10n keys added for Collection Creator artwork selection:
- `collectionCreatorAddArtworksTitle` (EN: "Add Artworks", SL: "Dodaj umetnine")
- `collectionCreatorSearchArtworksLabel` (EN: "Search", SL: "Iskanje")
- `collectionCreatorSearchArtworksHint` (EN: "Search your artworks...", SL: "Iskanje umetnin...")
- `collectionCreatorNoArtworksAvailable` (EN: "No artworks available", SL: "Ni razpoložljivih umetnin")

---

## Verification Checklist

### Desktop (width >= 720px)
- [ ] **Collection Creator**: Opens with animated gradient background, glass sections, artwork list with search. Create with and without selected artworks.
- [ ] **Exhibition Creator**: Glass sections for basics, schedule, and cover. Date pickers work. Published toggle works. Create button submits.
- [ ] **Event Creator**: 4-step wizard with consistent field styling. Step navigation works. Create/edit event flows complete.
- [ ] **Artwork Creator**: 5-step stepper with consistent field areas. Map interaction works. Complete publish flow.
- [ ] **Marker Editor**: Section grouping (Subject, Details, Location, Settings). Map positioning works. Save/Delete buttons work.
- [ ] **Manage Markers**: Two-pane layout at >= 980px. Search, filter, status badges. Marker selection opens editor in right pane.
- [ ] **Event Manager**: Glass-styled event cards, status badges, filter chips. Edit/Delete/Share actions work.

### Mobile (width < 720px)
- [ ] **Collection Creator**: Single column, full-width sections. Artwork list scrolls within constrained height.
- [ ] **Exhibition Creator**: Single column, all sections stack vertically.
- [ ] **Event Creator**: Full-width wizard, buttons at bottom.
- [ ] **Artwork Creator**: Full-width stepper steps.
- [ ] **Marker Editor**: Full-width form with map at top.
- [ ] **Manage Markers**: Single-pane list. Tap marker navigates to editor screen.
- [ ] **Event Manager**: Full-width event cards stack.

### Functional Regression Tests
- [ ] Create a new collection (with and without artworks)
- [ ] Create a new exhibition with cover image and dates
- [ ] Create a new event through all 4 steps
- [ ] Create a new artwork through all 5 steps
- [ ] Create a new marker with location and subject
- [ ] Edit an existing marker
- [ ] Delete a marker
- [ ] Edit an existing event
- [ ] Filter events in Event Manager
- [ ] Search markers in Manage Markers
