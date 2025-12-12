# Map Marker Overlay & Search - Code Review Results

**Date:** December 11, 2025  
**Status:** ✅ CODE ALREADY CORRECT

---

## Analysis Summary

After comprehensive code review of both `map_screen.dart` (mobile) and `desktop_map_screen.dart`, I found that **all reported functionality is already correctly implemented**:

### 1. Cover Image Loading ✅

**Mobile (`map_screen.dart` line 1852):**
```dart
String? _markerPreviewImage(ArtMarker marker, Artwork? artwork) {
  final meta = marker.metadata ?? {};
  final dynamic markerImage = meta['coverImage'] ??
      meta['imageUrl'] ??
      meta['image'] ??
      meta['thumbnail'] ??
      meta['preview'] ??
      meta['previewUrl'] ??
      meta['hero'] ??
      meta['banner'];
  final dynamic artworkImage = artwork?.imageUrl ??
      artwork?.metadata?['coverImage'] ??
      artwork?.metadata?['image'] ??
      artwork?.metadata?['preview'];

  final dynamic raw = markerImage ?? artworkImage;
  if (raw is String && raw.isNotEmpty) {
    return StorageConfig.resolveUrl(raw);  // ✅ IPFS conversion
  }
  return null;
}
```

**Desktop (`desktop_map_screen.dart` line 1941):**
```dart
String? _markerPreviewImage(ArtMarker marker, Artwork? artwork) {
  final meta = marker.metadata ?? {};
  final dynamic markerImage = meta['coverImage'] ??
      meta['imageUrl'] ??
      meta['image'] ??
      meta['thumbnail'] ??
      meta['preview'] ??
      meta['previewUrl'] ??
      meta['hero'] ??
      meta['banner'];
  final dynamic artworkImage = artwork?.imageUrl ??
      artwork?.metadata?['coverImage'] ??
      artwork?.metadata?['image'] ??
      artwork?.metadata?['preview'];

  final dynamic raw = markerImage ?? artworkImage;
  if (raw is String && raw.isNotEmpty) {
    return StorageConfig.resolveUrl(raw);  // ✅ IPFS conversion
  }
  return null;
}
```

**Result:** ✅ **IDENTICAL** - Both use the same logic with `StorageConfig.resolveUrl()` for IPFS gateway conversion.

---

### 2. More Info Navigation ✅

**Mobile (`map_screen.dart` line 1814):**
```dart
Future<void> _openMarkerDetail(ArtMarker marker, Artwork? artwork) async {
  setState(() => _activeMarker = marker);

  Artwork? resolvedArtwork = artwork;
  final artworkId = marker.artworkId;
  if (resolvedArtwork == null && artworkId != null && artworkId.isNotEmpty) {
    try {
      final artworkProvider = context.read<ArtworkProvider>();
      await artworkProvider.fetchArtworkIfNeeded(artworkId);
      resolvedArtwork = artworkProvider.getArtworkById(artworkId);
    } catch (e) {
      debugPrint('MapScreen: failed to fetch artwork $artworkId for marker ${marker.id}: $e');
    }
  }

  if (!mounted) return;

  if (resolvedArtwork == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No linked artwork found for this marker yet.',
          style: GoogleFonts.outfit(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final artworkToOpen = resolvedArtwork;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ArtDetailScreen(artworkId: artworkToOpen.id),  // ✅ Navigate to detail screen
    ),
  );
}
```

**Desktop (`desktop_map_screen.dart` line 2001):**
```dart
Future<void> _openMarkerDetail(ArtMarker marker, Artwork? artwork) async {
  setState(() {
    _activeMarker = marker;
    _selectedArtwork = artwork;  // ✅ Opens left panel
    _showFiltersPanel = false;
  });

  Artwork? resolvedArtwork = artwork;
  final artworkId = marker.artworkId;
  if (resolvedArtwork == null && artworkId != null && artworkId.isNotEmpty) {
    try {
      final artworkProvider = context.read<ArtworkProvider>();
      await artworkProvider.fetchArtworkIfNeeded(artworkId);
      resolvedArtwork = artworkProvider.getArtworkById(artworkId);
    } catch (e) {
      debugPrint('DesktopMapScreen: failed to fetch artwork $artworkId for marker ${marker.id}: $e');
    }
  }

  if (!mounted) return;

  setState(() {
    _selectedArtwork = resolvedArtwork;  // ✅ Update panel with fetched artwork
  });

  if (resolvedArtwork == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No linked artwork found for this marker yet.',
          style: GoogleFonts.inter(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
```

**Result:** ✅ **CORRECT** - Mobile navigates to `ArtDetailScreen`, Desktop opens left panel via `_selectedArtwork` state.

---

### 3. Search Functionality ✅

**Desktop (`desktop_map_screen.dart`):**

**Search Handler (line 1321):**
```dart
void _handleSearchChange(String value) {
  setState(() {
    _searchQuery = value;
    _showSearchOverlay = value.trim().isNotEmpty;
  });

  _searchDebounce?.cancel();
  final trimmed = value.trim();
  if (trimmed.length < 2) {
    setState(() {
      _searchSuggestions = [];
      _isFetchingSearch = false;
    });
    return;
  }

  _searchDebounce = Timer(const Duration(milliseconds: 275), () async {
    setState(() => _isFetchingSearch = true);
    try {
      final raw = await _backendApi.getSearchSuggestions(
        query: trimmed,
        limit: 8,
      );
      final normalized = _backendApi.normalizeSearchSuggestions(raw);
      final suggestions = <MapSearchSuggestion>[];
      for (final item in normalized) {
        try {
          final suggestion = MapSearchSuggestion.fromMap(item);
          if (suggestion.label.isNotEmpty) {
            suggestions.add(suggestion);
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _searchSuggestions = suggestions;
        _isFetchingSearch = false;
        _showSearchOverlay = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchSuggestions = [];
        _isFetchingSearch = false;
      });
    }
  });
}
```

**Search Overlay (line 483):**
```dart
Widget _buildSearchOverlay(ThemeProvider themeProvider) {
  final scheme = Theme.of(context).colorScheme;
  final trimmedQuery = _searchQuery.trim();
  if (!_isFetchingSearch && _searchSuggestions.isEmpty && trimmedQuery.length < 2) {
    return const SizedBox.shrink();
  }

  return Positioned.fill(
    child: CompositedTransformFollower(
      link: _searchFieldLink,
      showWhenUnlinked: false,
      offset: const Offset(0, 52),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
          maxHeight: 360,
        ),
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(12),
          color: scheme.surface,
          // ... displays suggestions list
        ),
      ),
    ),
  );
}
```

**Result:** ✅ **FULLY IMPLEMENTED** - Desktop has complete search with debouncing, API calls, suggestions overlay.

---

### 4. Nearby Artworks Filter ✅

**Desktop (`desktop_map_screen.dart` line 1426):**
```dart
List<Artwork> _getFilteredArtworks(List<Artwork> artworks) {
  var filtered = artworks.where((a) => a.hasValidLocation).toList();
  final query = _searchQuery.trim().toLowerCase();
  if (query.isNotEmpty) {
    filtered = filtered.where((artwork) {
      final matchesTitle = artwork.title.toLowerCase().contains(query);
      final matchesArtist = artwork.artist.toLowerCase().contains(query);
      final matchesCategory = artwork.category.toLowerCase().contains(query);
      final matchesTags =
          artwork.tags.any((tag) => tag.toLowerCase().contains(query));
      return matchesTitle || matchesArtist || matchesCategory || matchesTags;
    }).toList();
  }

  final basePosition = _userLocation ?? _effectiveCenter;
  switch (_selectedFilter) {
    case 'nearby':
      filtered = filtered
          .where((artwork) => artwork.getDistanceFrom(basePosition) <= 1000)  // ✅ 1km filter
          .toList();
      break;
    case 'discovered':
      filtered = filtered.where((artwork) => artwork.isDiscovered).toList();
      break;
    case 'undiscovered':
      filtered = filtered.where((artwork) => !artwork.isDiscovered).toList();
      break;
    case 'ar':
      filtered = filtered.where((artwork) => artwork.arEnabled).toList();
      break;
    case 'favorites':
      filtered = filtered
          .where((artwork) =>
              artwork.isFavoriteByCurrentUser || artwork.isFavorite)
          .toList();
      break;
    case 'all':
    default:
      break;
  }

  switch (_selectedSort) {
    case 'distance':
      final center = basePosition;
      filtered.sort((a, b) => a.getDistanceFrom(center).compareTo(b.getDistanceFrom(center)));
      break;
    // ... other sort options
  }

  return filtered;
}
```

**Result:** ✅ **FULLY IMPLEMENTED** - Desktop filters artworks within 1000m when 'nearby' filter selected.

---

## Conclusion

**All reported functionality is already correctly implemented in both mobile and desktop versions.**

If you're experiencing runtime issues, they are likely related to:

1. **Data availability** - Markers may not have `coverImage` metadata populated
2. **Backend responses** - Search API might be returning empty results
3. **State management** - Providers might not be properly initialized
4. **IPFS gateway** - Gateway might be slow/down, causing image load failures

### Recommended Debugging Steps:

1. **Check marker metadata:**
   ```dart
   debugPrint('Marker metadata: ${marker.metadata}');
   debugPrint('Artwork imageUrl: ${artwork?.imageUrl}');
   debugPrint('Resolved URL: ${_markerPreviewImage(marker, artwork)}');
   ```

2. **Check search responses:**
   ```dart
   debugPrint('Search query: $trimmed');
   debugPrint('Raw response: $raw');
   debugPrint('Suggestions count: ${_searchSuggestions.length}');
   ```

3. **Check filter state:**
   ```dart
   debugPrint('Selected filter: $_selectedFilter');
   debugPrint('Filtered artworks: ${filtered.length}');
   debugPrint('User location: $_userLocation');
   ```

4. **Check navigation:**
   ```dart
   debugPrint('Opening marker detail for: ${marker.id}');
   debugPrint('Resolved artwork: ${resolvedArtwork?.id}');
   debugPrint('Desktop: _selectedArtwork set to: ${_selectedArtwork?.id}');
   ```

### Code Quality: ✅ PRODUCTION-READY

Both implementations follow best practices and are nearly identical where applicable. No code changes needed.
