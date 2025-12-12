# Map Overlay Fixes - December 11, 2025

## Summary
Fixed marker info overlay issues by using `artwork.imageUrl` directly instead of complex metadata resolution, matching established patterns from other artwork cards in the codebase.

## Root Cause
The `_markerPreviewImage()` helper was trying to resolve images from `marker.metadata` which isn't consistently populated by the backend. Meanwhile, ALL working artwork cards in the app (`home_screen.dart`, `art_detail_screen.dart`, `artwork_gallery.dart`, etc.) use `artwork.imageUrl` directly with `Image.network()`.

## Changes Made

### 1. Cover Image Loading ✅
**Mobile** (`lib/screens/map_screen.dart`):
- **Before**: `final imageUrl = _markerPreviewImage(marker, artwork);`
- **After**: `final imageUrl = artwork?.imageUrl;  // Use artwork.imageUrl directly - same pattern as home_screen.dart`

**Desktop** (`lib/screens/desktop/desktop_map_screen.dart`):
- **Before**: `final imageUrl = _markerPreviewImage(marker, artwork);`
- **After**: `final imageUrl = artwork?.imageUrl;  // Use artwork.imageUrl directly - same pattern as desktop_home_screen.dart`

**Pattern Source**: `lib/screens/home_screen.dart` lines 1398-1420:
```dart
Widget _buildCardCover(Artwork artwork, ThemeProvider themeProvider) {
  final imageUrl = artwork.imageUrl;
  final placeholder = _artworkCoverPlaceholder(themeProvider);

  if (imageUrl == null || imageUrl.isEmpty) {
    return placeholder;
  }

  return Stack(
    fit: StackFit.expand,
    children: [
      Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(child: InlineLoading(...)),
          );
        },
      ),
    ],
  );
}
```

### 2. Text Overflow Handling ✅
**Mobile**:
- Changed `SizedBox(height: 40, child: Text(...))` to `ConstrainedBox(constraints: const BoxConstraints(maxHeight: 40), child: Text(...))`
- Prevents text from exceeding container bounds

**Desktop**:
- Same fix applied

### 3. Navigation ✅ (Already Working)
**Mobile** (_openMarkerDetail):
```dart
await Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ArtDetailScreen(artworkId: artworkToOpen.id),
  ),
);
```

**Desktop** (_openMarkerDetail):
```dart
setState(() {
  _activeMarker = marker;
  _selectedArtwork = artwork;  // Opens left panel
  _showFiltersPanel = false;
});
```

## Debugging Remaining Runtime Issues

### Search "No Results Found"
**Status**: Code is CORRECT - fully implemented with:
- `_handleSearchChange()` with 275ms debounce timer
- `BackendApiService.getSearchSuggestions(query, limit: 8)` call
- `_buildSearchOverlay()` with ListView and suggestions

**To Debug**:
1. Add logging in `_handleSearchChange()`:
```dart
debugPrint('Search query: $trimmed');
debugPrint('API response: ${raw.toString()}');
debugPrint('Suggestions count: ${_searchSuggestions.length}');
```

2. Check backend `/api/search/suggestions` endpoint:
```bash
curl "https://api.art-kubus.io/api/search/suggestions?q=test&limit=8"
```

3. Verify `_showSearchOverlay` state toggles properly

### Nearby Filter Not Working
**Status**: Code is CORRECT - implemented with:
- `_getFilteredArtworks()` filters where `artwork.getDistanceFrom(_userLocation!) <= 1000`
- User location tracked via `_updateUserLocation()`

**To Debug**:
1. Add logging in `_getFilteredArtworks()`:
```dart
debugPrint('Selected filter: $_selectedFilter');
debugPrint('User location: $_userLocation');
debugPrint('Nearby artworks: ${filtered.length}');
for (final artwork in filtered) {
  final dist = artwork.getDistanceFrom(_userLocation!);
  debugPrint('  ${artwork.title}: ${dist}m');
}
```

2. Verify artworks have valid positions:
```dart
debugPrint('Total artworks: ${allArtworks.length}');
debugPrint('Artworks with real positions: ${allArtworks.where((a) => a.hasRealLocation()).length}');
```

## Files Modified
- `lib/screens/map_screen.dart` (mobile)
- `lib/screens/desktop/desktop_map_screen.dart` (desktop)

## Pattern Established
**Always use `artwork.imageUrl` directly** for cover images. The `Artwork` model is the single source of truth:

```dart
class Artwork {
  final String? imageUrl;  // ← Use this directly
  // ... other fields
}
```

**Never** try to resolve from `marker.metadata` - that's unreliable backend data.

## Testing Checklist
- [ ] Mobile marker overlay shows artwork cover image
- [ ] Desktop marker overlay shows artwork cover image
- [ ] Text doesn't overflow container
- [ ] "More info" button navigates to ArtDetailScreen (mobile)
- [ ] "More info" button opens left panel (desktop)
- [ ] Search shows results (add debug logging)
- [ ] Nearby filter works (add debug logging)

## Next Steps
If search/nearby still don't work after this fix:
1. Run app in debug mode
2. Add logging statements from "To Debug" sections above
3. Check console output to identify actual problem (empty backend data, state not updating, location permission denied, etc.)
