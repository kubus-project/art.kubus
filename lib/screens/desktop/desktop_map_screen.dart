import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/tile_providers.dart';
import '../../models/artwork.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/app_logo.dart';
import '../../utils/app_animations.dart';
import 'components/desktop_widgets.dart';
import '../art/art_detail_screen.dart';
import 'community/desktop_user_profile_screen.dart';

/// Desktop map screen with Google Maps-style presentation
/// Features side panel for artwork details and filters
class DesktopMapScreen extends StatefulWidget {
  const DesktopMapScreen({super.key});

  @override
  State<DesktopMapScreen> createState() => _DesktopMapScreenState();
}

class _DesktopMapScreenState extends State<DesktopMapScreen>
    with TickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;
  late AnimationController _panelController;

  Artwork? _selectedArtwork;
  bool _showFiltersPanel = false;
  String _selectedFilter = 'all';
  double _searchRadius = 5.0; // km

  final TextEditingController _searchController = TextEditingController();
  final LayerLink _searchFieldLink = LayerLink();
  Timer? _searchDebounce;
  List<_SearchSuggestion> _searchSuggestions = [];
  bool _isFetchingSearch = false;
  String _searchQuery = '';
  bool _showSearchOverlay = false;

  final List<String> _filterOptions = ['all', 'nearby', 'discovered', 'undiscovered', 'ar', 'favorites'];
  final BackendApiService _backendApi = BackendApiService();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _panelController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Map layer
          _buildMapLayer(themeProvider),

          // Top bar
          _buildTopBar(themeProvider, animationTheme),

          // Search suggestions overlay
          if (_showSearchOverlay) _buildSearchOverlay(themeProvider),

          // Left side panel (artwork details or filters)
          AnimatedPositioned(
            duration: animationTheme.medium,
            curve: animationTheme.defaultCurve,
            left: _selectedArtwork != null || _showFiltersPanel ? 0 : -400,
            top: 80,
            bottom: 24,
            width: 380,
            child: _selectedArtwork != null
                ? _buildArtworkDetailPanel(themeProvider, animationTheme)
                : _buildFiltersPanel(themeProvider),
          ),

          // Right side controls
          Positioned(
            right: 24,
            bottom: 100,
            child: _buildMapControls(themeProvider),
          ),

          // Bottom info bar
          Positioned(
            left: _selectedArtwork != null ? 400 : 24,
            right: 24,
            bottom: 24,
            child: _buildBottomInfoBar(themeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLayer(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final artworks = _getFilteredArtworks(artworkProvider.artworks);
        final tileProviders = Provider.of<TileProviders?>(context, listen: false);
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final isRetina = devicePixelRatio >= 2.0;

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(46.0569, 14.5058), // Ljubljana default
            initialZoom: 13.0,
            minZoom: 3.0,
            maxZoom: 18.0,
            onTap: (_, __) {
              setState(() {
                _selectedArtwork = null;
                _showFiltersPanel = false;
                _showSearchOverlay = false;
              });
            },
          ),
          children: [
            if (tileProviders != null)
              (isRetina
                  ? tileProviders.getTileLayer()
                  : tileProviders.getNonRetinaTileLayer())
            else
              TileLayer(
                urlTemplate: themeProvider.isDarkMode
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.kubus.art',
              ),
            MarkerLayer(
              markers: [
                // User location marker
                _buildUserLocationMarker(),
                // Artwork markers
                ...artworks.map((artwork) => _buildArtworkMarker(artwork, themeProvider)),
              ],
            ),
          ],
        );
      },
    );
  }

  Marker _buildUserLocationMarker() {
    // Default user location marker at Ljubljana
    return Marker(
      point: const LatLng(46.0569, 14.5058),
      width: 20,
      height: 20,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildArtworkMarker(Artwork artwork, ThemeProvider themeProvider) {
    final isSelected = _selectedArtwork?.id == artwork.id;
    final hasAR = artwork.arEnabled;

    return Marker(
      point: artwork.position,
      width: isSelected ? 56 : 44,
      height: isSelected ? 56 : 44,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedArtwork = artwork;
            _showFiltersPanel = false;
          });
          // Animate map to artwork
          _mapController.move(
            artwork.position,
            15.0,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? themeProvider.accentColor
                : (hasAR ? const Color(0xFF4ECDC4) : themeProvider.accentColor.withValues(alpha: 0.8)),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 4 : 3,
            ),
            boxShadow: [
              BoxShadow(
                color: themeProvider.accentColor.withValues(alpha: 0.3),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Icon(
            hasAR ? Icons.view_in_ar : Icons.location_on,
            color: Colors.white,
            size: isSelected ? 28 : 22,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0),
            ],
          ),
        ),
        child: Row(
          children: [
            // Logo and title
            Row(
              children: [
                const AppLogo(width: 36, height: 36),
                const SizedBox(width: 12),
                Text(
                  'Discover',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 48),

            // Search bar
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                child: CompositedTransformTarget(
                  link: _searchFieldLink,
                  child: DesktopSearchBar(
                    controller: _searchController,
                    hintText: 'Search artworks, locations...',
                    onChanged: _handleSearchChange,
                    onSubmitted: _handleSearchSubmit,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Filter chips
            Row(
              children: _filterOptions.map((filter) {
                final isActive = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(_getFilterLabel(filter)),
                    selected: isActive,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = filter);
                    },
                    selectedColor: themeProvider.accentColor,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(width: 16),

            // Filters button
            IconButton(
              onPressed: () {
                setState(() {
                  _showFiltersPanel = !_showFiltersPanel;
                  _selectedArtwork = null;
                });
              },
              icon: Icon(
                _showFiltersPanel ? Icons.close : Icons.tune,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            shadowColor: themeProvider.accentColor.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Builder(
                builder: (context) {
                  if (trimmedQuery.length < 2) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Type at least 2 characters to search',
                        style: GoogleFonts.inter(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }

                  if (_isFetchingSearch) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (_searchSuggestions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_off,
                            color: scheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'No results found',
                            style: GoogleFonts.inter(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchSuggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: scheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = _searchSuggestions[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: themeProvider.accentColor.withValues(alpha: 0.1),
                          child: Icon(
                            suggestion.icon,
                            color: themeProvider.accentColor,
                          ),
                        ),
                        title: Text(
                          suggestion.label,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: suggestion.subtitle == null
                            ? null
                            : Text(
                                suggestion.subtitle!,
                                style: GoogleFonts.inter(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                        onTap: () => _handleSuggestionTap(suggestion),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkDetailPanel(ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final artwork = _selectedArtwork!;

    return Container(
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header image
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeProvider.accentColor,
                  themeProvider.accentColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.view_in_ar,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                // Close button
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: () {
                      setState(() => _selectedArtwork = null);
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                // AR badge
                if (artwork.arEnabled)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_in_ar,
                            size: 16,
                            color: themeProvider.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AR Ready',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artwork.title,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'by ${artwork.artist}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: themeProvider.accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (artwork.description.isNotEmpty) ...[
                    Text(
                      artwork.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Stats row
                  Row(
                    children: [
                      _buildDetailStat(Icons.favorite, '${artwork.likesCount}'),
                      const SizedBox(width: 24),
                      _buildDetailStat(Icons.visibility, '${artwork.viewsCount}'),
                      const SizedBox(width: 24),
                      _buildDetailStat(Icons.location_on, '0.5 km'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Launch AR
                          },
                          icon: const Icon(Icons.view_in_ar),
                          label: const Text('View in AR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          // Like artwork
                        },
                        icon: const Icon(Icons.favorite_border),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          // Share artwork
                        },
                        icon: const Icon(Icons.share),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Directions button
                  OutlinedButton.icon(
                    onPressed: () {
                      // Get directions
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: themeProvider.accentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _showFiltersPanel = false);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Filter options
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search radius
                  Text(
                    'Search Radius',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _searchRadius,
                          min: 1,
                          max: 50,
                          divisions: 49,
                          onChanged: (value) {
                            setState(() => _searchRadius = value);
                          },
                          activeColor: themeProvider.accentColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_searchRadius.toInt()} km',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Artwork types
                  Text(
                    'Artwork Type',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('All', true, themeProvider),
                      _buildFilterChip('AR Art', false, themeProvider),
                      _buildFilterChip('NFTs', false, themeProvider),
                      _buildFilterChip('3D Models', false, themeProvider),
                      _buildFilterChip('Sculptures', false, themeProvider),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sort by
                  Text(
                    'Sort By',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSortOption('Distance', true, Icons.near_me, themeProvider),
                  _buildSortOption('Popularity', false, Icons.trending_up, themeProvider),
                  _buildSortOption('Newest', false, Icons.schedule, themeProvider),
                  _buildSortOption('Rating', false, Icons.star, themeProvider),
                ],
              ),
            ),
          ),

          // Apply button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Reset filters
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _showFiltersPanel = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, ThemeProvider themeProvider) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // Handle filter selection
      },
      selectedColor: themeProvider.accentColor.withValues(alpha: 0.2),
      checkmarkColor: themeProvider.accentColor,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        color: isSelected ? themeProvider.accentColor : Theme.of(context).colorScheme.onSurface,
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      side: BorderSide(
        color: isSelected ? themeProvider.accentColor : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildSortOption(String label, bool isSelected, IconData icon, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? themeProvider.accentColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? themeProvider.accentColor
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: themeProvider.accentColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls(ThemeProvider themeProvider) {
    return Column(
      children: [
        // Zoom controls
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              IconButton(
                onPressed: () {
                  _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  );
                },
                icon: const Icon(Icons.add),
              ),
              Container(
                height: 1,
                width: 32,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
              IconButton(
                onPressed: () {
                  _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  );
                },
                icon: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // My location button
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              // Center on default location (Ljubljana)
              _mapController.move(
                const LatLng(46.0569, 14.5058),
                15.0,
              );
            },
            icon: Icon(
              Icons.my_location,
              color: themeProvider.accentColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfoBar(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final artworks = _getFilteredArtworks(artworkProvider.artworks);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.explore,
                color: themeProvider.accentColor,
              ),
              const SizedBox(width: 12),
              Text(
                '${artworks.length} artworks',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'within ${_searchRadius.toInt()} km',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // Show list view
                },
                icon: const Icon(Icons.list, size: 18),
                label: const Text('List View'),
              ),
            ],
          ),
        );
      },
    );
  }

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
        final suggestions = <_SearchSuggestion>[];
        for (final item in normalized) {
          try {
            final suggestion = _SearchSuggestion.fromMap(item);
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

  void _handleSearchSubmit(String value) {
    final trimmed = value.trim();
    setState(() {
      _searchQuery = trimmed;
      _showSearchOverlay = false;
      _searchSuggestions = [];
      _isFetchingSearch = false;
    });
    if (trimmed.isEmpty) return;

    final artworkProvider = context.read<ArtworkProvider>();
    final filtered = _getFilteredArtworks(artworkProvider.artworks);
    if (filtered.isNotEmpty) {
      setState(() => _selectedArtwork = filtered.first);
      _mapController.move(
        filtered.first.position,
        math.max(_mapController.camera.zoom, 14),
      );
    }
  }

  void _handleSuggestionTap(_SearchSuggestion suggestion) {
    setState(() {
      _searchQuery = suggestion.label;
      _searchController.text = suggestion.label;
      _showSearchOverlay = false;
      _searchSuggestions = [];
    });

    if (suggestion.position != null) {
      _mapController.move(
        suggestion.position!,
        math.max(_mapController.camera.zoom, 15.0),
      );
    }

    final artworkProvider = context.read<ArtworkProvider>();
    if (suggestion.type == 'artwork' && suggestion.id != null) {
      final match = artworkProvider.getArtworkById(suggestion.id!);
      if (match != null) {
        setState(() => _selectedArtwork = match);
        unawaited(Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtDetailScreen(artworkId: match.id),
          ),
        ));
      }
    } else if (suggestion.type == 'profile' && suggestion.id != null) {
      unawaited(Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: suggestion.id!),
        ),
      ));
    }
  }

  List<Artwork> _getFilteredArtworks(List<Artwork> artworks) {
    var filtered = List<Artwork>.from(artworks);
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

    switch (_selectedFilter) {
      case 'nearby':
        final center = _mapController.camera.center;
        filtered = filtered
            .where((artwork) => artwork.getDistanceFrom(center) <= 1000)
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
    return filtered;
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'nearby':
        return 'Nearby';
      case 'discovered':
        return 'Discovered';
      case 'undiscovered':
        return 'Undiscovered';
      case 'ar':
        return 'AR';
      case 'favorites':
        return 'Favorites';
      default:
        return filter;
    }
  }
}

class _SearchSuggestion {
  final String label;
  final String type;
  final String? subtitle;
  final String? id;
  final LatLng? position;

  const _SearchSuggestion({
    required this.label,
    required this.type,
    this.subtitle,
    this.id,
    this.position,
  });

  IconData get icon {
    switch (type) {
      case 'profile':
        return Icons.account_circle_outlined;
      case 'institution':
        return Icons.museum_outlined;
      case 'event':
        return Icons.event_available;
      case 'marker':
        return Icons.location_on_outlined;
      case 'artwork':
      default:
        return Icons.auto_awesome;
    }
  }

  factory _SearchSuggestion.fromMap(Map<String, dynamic> map) {
    final lat = map['lat'] ?? map['latitude'];
    final lng = map['lng'] ?? map['longitude'];
    LatLng? position;
    if (lat is num && lng is num) {
      position = LatLng(lat.toDouble(), lng.toDouble());
    }

    String? subtitle = map['subtitle']?.toString();
    if ((subtitle == null || subtitle.isEmpty)) {
      final username = (map['username'] ?? map['handle'])?.toString();
      final wallet = (map['wallet'] ?? map['walletAddress'] ?? map['wallet_address'])?.toString();
      if (username != null && username.isNotEmpty) {
        subtitle = '@$username';
      } else if (wallet != null && wallet.isNotEmpty) {
        subtitle = wallet.length > 10 ? '${wallet.substring(0,4)}...${wallet.substring(wallet.length-4)}' : wallet;
      }
    }

    return _SearchSuggestion(
      label: (map['label'] ?? map['displayName'] ?? map['display_name'] ?? map['title'] ?? '').toString(),
      type: map['type']?.toString() ?? 'artwork',
      subtitle: subtitle,
      id: map['id']?.toString() ?? (map['wallet']?.toString()),
      position: position,
    );
  }
}
