import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/themeprovider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/tile_providers.dart';
import '../../providers/wallet_provider.dart';
import '../../models/artwork.dart';
import '../../models/art_marker.dart';
import '../../models/map_marker_subject.dart';
import '../../services/map_marker_service.dart';
import '../../services/ar_service.dart';
import '../../utils/map_marker_subject_loader.dart';
import '../../utils/map_search_suggestion.dart';
import '../../widgets/art_marker_cube.dart';
import '../../widgets/art_map_view.dart';
import '../../widgets/map_marker_dialog.dart';
import '../../utils/grid_utils.dart';
import '../../widgets/app_logo.dart';
import '../../utils/app_animations.dart';
import '../../utils/artwork_media_resolver.dart';
import 'components/desktop_widgets.dart';
import '../art/art_detail_screen.dart';
import 'community/desktop_user_profile_screen.dart';
import '../../services/search_service.dart';

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
  final MapMarkerService _mapMarkerService = MapMarkerService();

  Artwork? _selectedArtwork;
  ArtMarker? _activeMarker;
  bool _showFiltersPanel = false;
  String _selectedFilter = 'all';
  double _searchRadius = 5.0; // km
  LatLng? _pendingMarkerLocation;
  bool _mapReady = false;
  double _cameraZoom = 13.0;
  List<ArtMarker> _artMarkers = [];
  bool _isLoadingMarkers = false;
  MarkerSubjectLoader get _subjectLoader => MarkerSubjectLoader(context);
  LatLng? _userLocation;
  bool _autoFollow = true;
  bool _isLocating = false;
  final Distance _distance = const Distance();
  StreamSubscription<ArtMarker>? _markerStreamSub;
  Timer? _markerRefreshDebounce;
  LatLng _cameraCenter = const LatLng(46.0569, 14.5058);
  LatLng? _queuedCameraTarget;
  double? _queuedCameraZoom;
  LatLng? _lastMarkerFetchCenter;
  DateTime? _lastMarkerFetchTime;
  static const double _markerRefreshDistanceMeters = 1200;
  static const Duration _markerRefreshInterval = Duration(minutes: 5);

  final TextEditingController _searchController = TextEditingController();
  final LayerLink _searchFieldLink = LayerLink();
  Timer? _searchDebounce;
  List<MapSearchSuggestion> _searchSuggestions = [];
  bool _isFetchingSearch = false;
  String _searchQuery = '';
  bool _showSearchOverlay = false;
  final SearchService _searchService = SearchService();

  final List<String> _filterOptions = ['all', 'nearby', 'discovered', 'undiscovered', 'ar', 'favorites'];
  String _selectedSort = 'distance';

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
    _markerStreamSub = _mapMarkerService.onMarkerCreated.listen(_handleMarkerCreated);
    _cameraCenter = const LatLng(46.0569, 14.5058);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMarkers(force: true);
      _refreshUserLocation(animate: true);
      _prefetchMarkerSubjects();
    });
  }

  LatLng get _effectiveCenter => _mapReady ? _mapController.camera.center : _cameraCenter;
  double get _effectiveZoom => _mapReady ? _mapController.camera.zoom : _cameraZoom;

  void _handleMapReady() {
    setState(() {
      _mapReady = true;
      _cameraCenter = _mapController.camera.center;
      _cameraZoom = _mapController.camera.zoom;
    });
    if (_queuedCameraTarget != null && _queuedCameraZoom != null) {
      _mapController.move(_queuedCameraTarget!, _queuedCameraZoom!);
      _queuedCameraTarget = null;
      _queuedCameraZoom = null;
    }
  }

  void _moveCamera(LatLng target, double zoom) {
    _cameraCenter = target;
    _cameraZoom = zoom;
    if (_mapReady) {
      _mapController.move(target, zoom);
    } else {
      _queuedCameraTarget = target;
      _queuedCameraZoom = zoom;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _panelController.dispose();
    _searchDebounce?.cancel();
    _markerRefreshDebounce?.cancel();
    _markerStreamSub?.cancel();
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
        // TileProviders centralizes tile logic (tiles + optional grid overlay) just like mobile MapScreen
        final tileProviders = Provider.of<TileProviders?>(context, listen: false);
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final isRetina = devicePixelRatio >= 2.0;
        final markers = <Marker>[
          _buildUserLocationMarker(themeProvider),
          // Removed duplicate artwork circle markers - only show art marker pins
          ..._buildArtMarkerPins(themeProvider),
          if (_activeMarker != null)
            _buildMarkerOverlay(
              _activeMarker!,
              context.read<ArtworkProvider>().getArtworkById(_activeMarker!.artworkId ?? ''),
              themeProvider,
            ),
          if (_pendingMarkerLocation != null)
            _buildPendingMarker(_pendingMarkerLocation!, themeProvider),
        ];

        return ArtMapView(
          mapController: _mapController,
          initialCenter: _effectiveCenter,
          initialZoom: _cameraZoom,
          minZoom: 3.0,
          maxZoom: 18.0,
          isDarkMode: themeProvider.isDarkMode,
          isRetina: isRetina,
          tileProviders: tileProviders,
          markers: markers,
          onMapReady: _handleMapReady,
          onTap: (_, __) {
            setState(() {
              _selectedArtwork = null;
              _showFiltersPanel = false;
              _showSearchOverlay = false;
              _pendingMarkerLocation = null;
              _activeMarker = null;
            });
          },
          onLongPress: (_, point) {
            setState(() => _pendingMarkerLocation = point);
            _startMarkerCreationFlow(position: point);
          },
          onPositionChanged: (position, hasGesture) {
            final center = position.center;
            _cameraCenter = center;
            _cameraZoom = position.zoom;
            if (hasGesture && _autoFollow) {
              setState(() => _autoFollow = false);
            }
            if (hasGesture && _activeMarker != null) {
              setState(() => _activeMarker = null);
            }
            _queueMarkerRefresh(center, fromGesture: hasGesture);
          },
        );
      },
    );
  }

  Future<void> _refreshUserLocation({bool animate = false}) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _userLocation = current;
        if (_autoFollow) {
          _cameraCenter = current;
        }
      });
      if (animate || _autoFollow) {
        _moveCamera(current, math.max(_effectiveZoom, 15));
      }
    } catch (e) {
      debugPrint('DesktopMapScreen: location fetch failed: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Marker _buildUserLocationMarker(ThemeProvider themeProvider) {
    final accent = themeProvider.accentColor;
    final position = _userLocation ?? _cameraCenter;
    return Marker(
      point: position,
      width: 20,
      height: 20,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.3),
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
          unawaited(_selectArtwork(
            artwork,
            focusPosition: artwork.position,
          ));
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
                    hintText: 'Search artworks, artists, institutions',
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
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: _activeMarker?.metadata ?? artwork.metadata,
    );
    final distanceLabel = _formatDistanceToArtwork(artwork);

    return Container(
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: scheme.surface,
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeProvider.accentColor,
                              themeProvider.accentColor.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.white70, size: 40),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            themeProvider.accentColor,
                            themeProvider.accentColor.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_outlined, color: Colors.white70, size: 40),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
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
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildDetailStat(Icons.favorite, '${artwork.likesCount}'),
                      _buildDetailStat(Icons.visibility, '${artwork.viewsCount}'),
                      if (artwork.discoveryCount > 0)
                        _buildDetailStat(Icons.explore, '${artwork.discoveryCount} discoveries'),
                      if (artwork.actualRewards > 0)
                        _buildDetailStat(Icons.token, '${artwork.actualRewards} KUB8'),
                      if (distanceLabel != null) _buildDetailStat(Icons.location_on, distanceLabel),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final modelUrl = artwork.model3DURL ??
                                (artwork.model3DCID != null
                                    ? 'ipfs://${artwork.model3DCID}'
                                    : null);
                            if (modelUrl == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('No AR asset available for this artwork'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            unawaited(ARService().launchARViewer(
                              modelUrl: modelUrl,
                              title: artwork.title,
                            ));
                          },
                          icon: const Icon(Icons.view_in_ar, size: 20),
                          label: const Text('View in AR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          unawaited(Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArtDetailScreen(artworkId: artwork.id),
                            ),
                          ));
                        },
                        icon: const Icon(Icons.favorite_border, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          unawaited(Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArtDetailScreen(artworkId: artwork.id),
                            ),
                          ));
                        },
                        icon: const Icon(Icons.share, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          padding: const EdgeInsets.all(12),
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
                    onPressed: () async {
                      final uri = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${artwork.position.latitude},${artwork.position.longitude}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
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
                  _buildSortOption('Distance', _selectedSort == 'distance', Icons.near_me, themeProvider),
                  _buildSortOption('Popularity', _selectedSort == 'popularity', Icons.trending_up, themeProvider),
                  _buildSortOption('Newest', _selectedSort == 'newest', Icons.schedule, themeProvider),
                  _buildSortOption('Rating', _selectedSort == 'rating', Icons.star, themeProvider),
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
                      setState(() {
                        _searchRadius = 5.0;
                        _selectedFilter = 'all';
                        _selectedSort = 'distance';
                      });
                      _loadMarkers(force: true);
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
                      _loadMarkers(force: true);
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
        final normalized = label.toLowerCase();
        final filterKey =
            normalized.contains('ar') ? 'ar' : normalized.contains('all') ? 'all' : _selectedFilter;
        setState(() {
          _selectedFilter = filterKey;
        });
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
          onTap: () {
            setState(() {
              _selectedSort = label.toLowerCase();
            });
          },
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
                  final nextZoom = (_effectiveZoom + 1).clamp(3.0, 18.0);
                  _moveCamera(_effectiveCenter, nextZoom);
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
                  final nextZoom = (_effectiveZoom - 1).clamp(3.0, 18.0);
                  _moveCamera(_effectiveCenter, nextZoom);
                },
                icon: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Create marker from pending selection
        Material(
          color: Theme.of(context).colorScheme.primary,
          shape: const CircleBorder(),
          elevation: 4,
          child: IconButton(
            onPressed: () {
              final target = _pendingMarkerLocation ?? _effectiveCenter;
              _startMarkerCreationFlow(position: target);
            },
            icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
            tooltip: 'Create marker here',
          ),
        ),
        const SizedBox(height: 16),
        // My location button
        Container(
          decoration: BoxDecoration(
            color: _autoFollow
                ? themeProvider.accentColor.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surface,
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
              setState(() => _autoFollow = true);
              _refreshUserLocation(animate: true);
              if (_userLocation == null) {
                _moveCamera(const LatLng(46.0569, 14.5058), 15.0);
              }
            },
            icon: Icon(
              Icons.my_location,
              color: _autoFollow ? Colors.white : themeProvider.accentColor,
            ),
            color: _autoFollow ? themeProvider.accentColor : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfoBar(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final artworks = _getFilteredArtworks(artworkProvider.artworks);
        final displayArtworks = artworks.take(5).toList();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: themeProvider.accentColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Nearby Artworks',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (artworks.isNotEmpty)
                    IconButton(
                      tooltip: 'View all',
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      onPressed: () => _showArtworksList(context, artworks),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 16,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (displayArtworks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'No artworks loaded',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: displayArtworks.take(10).map((artwork) {
                    final cover = ArtworkMediaResolver.resolveCover(artwork: artwork);
                    final distance = _userLocation != null
                        ? _calculateDistance(_userLocation!, artwork.position)
                        : null;
                    final distanceText = distance != null ? _formatDistance(distance) : null;

                    return SizedBox(
                      width: (380 - 32 - 10) / 2, // Half panel width minus padding and spacing
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        elevation: 1,
                        child: InkWell(
                          onTap: () {
                            unawaited(_selectArtwork(
                              artwork,
                              focusPosition: artwork.position,
                            ));
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Thumbnail with AR badge
                                Stack(
                                  children: [
                                    _buildArtworkThumbnail(
                                      cover,
                                      width: double.infinity,
                                      height: 80,
                                      borderRadius: 6,
                                      iconSize: 28,
                                    ),
                                    if (artwork.arMarkerId != null)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: themeProvider.accentColor,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(
                                            Icons.view_in_ar,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Title
                                Text(
                                  artwork.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Artist
                                Text(
                                  artwork.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (distanceText != null) ...[
                                  const SizedBox(height: 4),
                                  // Distance badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      distanceText,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: themeProvider.accentColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showArtworksList(BuildContext context, List<Artwork> artworks) {
    if (artworks.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, controller) {
          return ListView.builder(
            controller: controller,
            itemCount: artworks.length,
            itemBuilder: (context, index) {
              final artwork = artworks[index];
              return ListTile(
                leading: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                title: Text(artwork.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text(artwork.artist, style: GoogleFonts.inter(fontSize: 12)),
                trailing: Text('${artwork.rewards} KUB8', style: GoogleFonts.inter(fontSize: 12)),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_selectArtwork(
                    artwork,
                    focusPosition: artwork.position,
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _selectArtwork(
    Artwork artwork, {
    LatLng? focusPosition,
    double minZoom = 15,
    bool skipFetch = false,
  }) async {
    setState(() {
      _selectedArtwork = artwork;
      _showFiltersPanel = false;
    });

    if (focusPosition != null || artwork.hasValidLocation) {
      _moveCamera(
        focusPosition ?? artwork.position,
        math.max(_effectiveZoom, minZoom),
      );
    }

    if (skipFetch) return;

    final hydrated = await _fetchArtworkDetails(artwork.id);
    if (mounted && hydrated != null) {
      setState(() {
        _selectedArtwork = hydrated;
      });
    }
  }

  Future<void> _selectArtworkById(
    String artworkId, {
    LatLng? focusPosition,
    bool openDetail = false,
  }) async {
    try {
      final artworkProvider = context.read<ArtworkProvider>();
      await artworkProvider.fetchArtworkIfNeeded(artworkId);
      final hydrated = artworkProvider.getArtworkById(artworkId);
      if (hydrated != null) {
        await _selectArtwork(
          hydrated,
          focusPosition: focusPosition ?? hydrated.position,
          skipFetch: true,
        );
        if (openDetail && mounted) {
          unawaited(Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArtDetailScreen(artworkId: hydrated.id),
            ),
          ));
        }
      }
    } catch (e) {
      debugPrint('DesktopMapScreen: failed to select artwork $artworkId: $e');
    }
  }

  Future<Artwork?> _fetchArtworkDetails(String artworkId) async {
    try {
      final artworkProvider = context.read<ArtworkProvider>();
      await artworkProvider.fetchArtworkIfNeeded(artworkId);
      return artworkProvider.getArtworkById(artworkId);
    } catch (e) {
      debugPrint('DesktopMapScreen: failed to hydrate artwork $artworkId: $e');
      return null;
    }
  }

  /// Calculate distance in meters between two points
  double _calculateDistance(LatLng from, LatLng to) {
    return _distance.as(LengthUnit.Meter, from, to);
  }

  /// Format distance in meters to human-readable string
  String _formatDistance(double meters, {bool includeAway = false}) {
    if (meters < 1) return 'Here';
    final suffix = includeAway ? ' away' : '';
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km$suffix';
    }
    return '${meters.round()} m$suffix';
  }

  String? _formatDistanceToArtwork(Artwork artwork) {
    if (_userLocation == null) return null;
    final meters = _calculateDistance(_userLocation!, artwork.position);
    return _formatDistance(meters, includeAway: true);
  }

  Artwork? _artworkFromMarkerMetadata(ArtMarker marker) {
    final metaArt = marker.metadata?['artwork'];
    if (metaArt is! Map) return null;
    final map = Map<String, dynamic>.from(metaArt.map((key, value) => MapEntry(key.toString(), value)));
    map['id'] ??= marker.artworkId ?? map['_id'] ?? map['artworkId'] ?? map['artwork_id'] ?? '';
    map['title'] ??= marker.name;
    map['artist'] ??= map['artistName'] ?? map['artist'] ?? map['creator'] ?? 'Unknown artist';
    map['description'] ??= marker.description;
    map['imageUrl'] ??= map['coverImage'] ?? map['cover_image'] ?? map['image'] ?? map['coverUrl'] ?? map['cover_url'];
    map['latitude'] ??= marker.position.latitude;
    map['longitude'] ??= marker.position.longitude;
    map['rarity'] ??= ArtworkRarity.common.name;
    map['status'] ??= ArtworkStatus.undiscovered.name;
    map['rewards'] ??= 0;
    map['model3DCID'] ??= map['modelCID'] ?? map['model_cid'];
    map['model3DURL'] ??= map['modelURL'] ?? map['model_url'];
    map['metadata'] = {
      ...?map['metadata'] as Map<String, dynamic>?,
      ...?marker.metadata,
      'linkedMarkerId': marker.id,
    };

    try {
      return Artwork.fromMap(map);
    } catch (_) {
      return null;
    }
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
        final suggestions = await _searchService.fetchSuggestions(
          context: context,
          query: trimmed,
          scope: SearchScope.map,
          limit: 8,
        );
        if (!mounted) return;
        setState(() {
          _searchSuggestions = suggestions.isNotEmpty
              ? suggestions
              : _buildLocalSearchSuggestions(trimmed);
          _isFetchingSearch = false;
          _showSearchOverlay = true;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchSuggestions = _buildLocalSearchSuggestions(trimmed);
          _isFetchingSearch = false;
        });
      }
    });
  }

  List<MapSearchSuggestion> _buildLocalSearchSuggestions(String query) {
    final normalized = query.toLowerCase();
    final artworkProvider = context.read<ArtworkProvider>();
    return artworkProvider.artworks
        .where((artwork) =>
            artwork.title.toLowerCase().contains(normalized) ||
            artwork.artist.toLowerCase().contains(normalized) ||
            artwork.category.toLowerCase().contains(normalized))
        .map((art) => MapSearchSuggestion(
              label: art.title,
              type: 'artwork',
              subtitle: art.artist,
              id: art.id,
              position: art.hasValidLocation ? art.position : null,
            ))
        .take(8)
        .toList();
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
      unawaited(_selectArtwork(
        filtered.first,
        focusPosition: filtered.first.position,
        minZoom: 14,
      ));
    }
  }

  void _handleSuggestionTap(MapSearchSuggestion suggestion) {
    setState(() {
      _searchQuery = suggestion.label;
      _searchController.text = suggestion.label;
      _showSearchOverlay = false;
      _searchSuggestions = [];
    });

    if (suggestion.position != null) {
      _moveCamera(
        suggestion.position!,
        math.max(_effectiveZoom, 15.0),
      );
    }

    if (suggestion.type == 'artwork' && suggestion.id != null) {
      unawaited(_selectArtworkById(
        suggestion.id!,
        focusPosition: suggestion.position,
        openDetail: true,
      ));
    } else if (suggestion.type == 'profile' && suggestion.id != null) {
      unawaited(Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: suggestion.id!),
        ),
      ));
    }
  }

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
            .where((artwork) => artwork.getDistanceFrom(basePosition) <= 1000)
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
      case 'popularity':
        filtered.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case 'newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'rating':
        filtered.sort((a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0));
        break;
      default:
        break;
    }
    return filtered;
  }

  double _scaleForZoom(double zoom) {
    const double minZoom = 3.0;
    const double maxZoom = 18.0;
    final double t = ((zoom - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
    return 0.38 + t * (1.25 - 0.38);
  }

  Color _resolveArtMarkerColor(ArtMarker marker, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final subjectType = (marker.metadata?['subjectType'] ?? marker.metadata?['subject_type'])
        ?.toString()
        .toLowerCase();
    if (subjectType != null && subjectType.isNotEmpty) {
      if (subjectType.contains('institution') || subjectType.contains('museum')) {
        return scheme.secondary;
      }
      if (subjectType.contains('event')) {
        return scheme.tertiary;
      }
      if (subjectType.contains('group') || subjectType.contains('dao') || subjectType.contains('collective')) {
        return scheme.primaryContainer;
      }
    }
    switch (marker.type) {
      case ArtMarkerType.artwork:
        return themeProvider.accentColor;
      case ArtMarkerType.institution:
        return scheme.secondary;
      case ArtMarkerType.event:
        return scheme.tertiary;
      case ArtMarkerType.residency:
        return scheme.primaryContainer;
      case ArtMarkerType.drop:
        return scheme.error;
      case ArtMarkerType.experience:
        return scheme.primary;
      case ArtMarkerType.other:
        return scheme.outline;
    }
  }

  IconData _resolveArtMarkerIcon(ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return Icons.auto_awesome;
      case ArtMarkerType.institution:
        return Icons.museum_outlined;
      case ArtMarkerType.event:
        return Icons.event_available;
      case ArtMarkerType.residency:
        return Icons.apartment;
      case ArtMarkerType.drop:
        return Icons.wallet_giftcard;
      case ArtMarkerType.experience:
        return Icons.view_in_ar;
      case ArtMarkerType.other:
        return Icons.location_on_outlined;
    }
  }

  Future<void> _loadMarkers({bool force = false}) async {
    if (_isLoadingMarkers) return;
    _isLoadingMarkers = true;
    try {
      final center = _userLocation ?? _effectiveCenter;
      final markers = await _mapMarkerService.loadMarkers(
        center: center,
        radiusKm: _searchRadius,
        forceRefresh: force,
      );
      final filtered =
          markers.where((marker) => marker.hasValidPosition).toList();
      await _hydrateMarkersWithArtworks(filtered);
      if (!mounted) return;
      setState(() {
        _artMarkers = filtered;
      });
      _lastMarkerFetchCenter = center;
      _lastMarkerFetchTime = DateTime.now();
    } finally {
      _isLoadingMarkers = false;
    }
  }

  void _queueMarkerRefresh(LatLng center, {required bool fromGesture}) {
    final lastFetch = _lastMarkerFetchTime;
    final lastCenter = _lastMarkerFetchCenter;
    final now = DateTime.now();

    final bool timeElapsed =
        lastFetch == null || now.difference(lastFetch) >= _markerRefreshInterval;
    final bool movedEnough = lastCenter == null ||
        _distance.as(LengthUnit.Meter, lastCenter, center) >= _markerRefreshDistanceMeters;

    if (!timeElapsed && !movedEnough && _artMarkers.isNotEmpty) {
      return;
    }

    _markerRefreshDebounce?.cancel();
    _markerRefreshDebounce = Timer(fromGesture ? const Duration(milliseconds: 350) : Duration.zero, () {
      _loadMarkers(force: timeElapsed || movedEnough);
    });
  }

  Future<void> _hydrateMarkersWithArtworks(List<ArtMarker> markers) async {
    final artworkProvider = context.read<ArtworkProvider>();

    final missingIds = <String>{};
    for (final marker in markers) {
      final artworkId = marker.artworkId;
      if (artworkId == null || artworkId.isEmpty) continue;
      if (artworkProvider.getArtworkById(artworkId) == null) {
        missingIds.add(artworkId);
      }
    }

    for (final artworkId in missingIds) {
      try {
        await artworkProvider.fetchArtworkIfNeeded(artworkId);
      } catch (e) {
        debugPrint('DesktopMapScreen: failed to hydrate artwork $artworkId: $e');
      }
    }

    // Backfill positions for artworks created without coordinates once a marker exists.
    for (final marker in markers) {
      final artworkId = marker.artworkId;
      if (artworkId == null || artworkId.isEmpty) continue;
      final artwork = artworkProvider.getArtworkById(artworkId);
      if (artwork != null && !artwork.hasValidLocation && marker.hasValidPosition) {
        artworkProvider.addOrUpdateArtwork(
          artwork.copyWith(
            position: marker.position,
            arMarkerId: marker.id,
            metadata: {
              ...?artwork.metadata,
              'linkedMarkerId': marker.id,
            },
          ),
        );
      }
    }
  }

  Marker _buildPendingMarker(LatLng point, ThemeProvider themeProvider) {
    return Marker(
      point: point,
      width: 42,
      height: 42,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: themeProvider.accentColor.withValues(alpha: 0.85),
          shape: BoxShape.rectangle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: themeProvider.accentColor.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.push_pin, color: Colors.white, size: 22),
      ),
    );
  }

  List<Marker> _buildArtMarkerPins(ThemeProvider themeProvider) {
    final zoom = _effectiveZoom;
    final bool useClustering = zoom < 12;
    final List<Marker> markers = [];

    if (!useClustering) {
      final scale = _scaleForZoom(zoom);
      return _artMarkers
          .map((marker) => _buildArtMarkerPin(marker, themeProvider, scaleOverride: scale))
          .toList();
    }

    final level = (GridUtils.resolvePrimaryGridLevel(zoom) - 2).clamp(3, 14);
    final Map<String, _ClusterBucket> buckets = {};
    for (final marker in _artMarkers) {
      final cell = GridUtils.gridCellForLevel(marker.position, level);
      final key = '${cell.gridLevel}:${cell.uIndex}:${cell.vIndex}';
      buckets.putIfAbsent(key, () => _ClusterBucket(cell, <ArtMarker>[]));
      buckets[key]!.markers.add(marker);
    }

    final baseScale = _scaleForZoom(zoom);
    for (final bucket in buckets.values) {
      if (bucket.markers.length == 1) {
        markers.add(_buildArtMarkerPin(bucket.markers.first, themeProvider, scaleOverride: baseScale));
      } else {
        markers.add(_buildClusterMarker(bucket, themeProvider, baseScale));
      }
    }
    return markers;
  }

  Marker _buildArtMarkerPin(ArtMarker marker, ThemeProvider themeProvider, {double? scaleOverride}) {
    final Color color = _resolveArtMarkerColor(marker, themeProvider);
    final IconData icon = _resolveArtMarkerIcon(marker.type);
    final double scale = scaleOverride ?? _scaleForZoom(_effectiveZoom);
    final double cubeSize = 46 * scale;
    final double markerWidth = 60 * scale;
    final double markerHeight = 72 * scale;

    return Marker(
      point: marker.position,
      width: markerWidth,
      height: markerHeight,
      child: GestureDetector(
        onTap: () {
          _moveCamera(marker.position, math.max(_effectiveZoom, 15));
          setState(() => _activeMarker = marker);
          _ensureLinkedArtworkLoaded(marker);
        },
        child: ArtMarkerCube(
          marker: marker,
          baseColor: color,
          icon: icon,
          size: cubeSize,
          glow: true,
        ),
      ),
    );
  }

  Marker _buildClusterMarker(_ClusterBucket bucket, ThemeProvider themeProvider, double scale) {
    final dominant = _resolveArtMarkerColor(bucket.markers.first, themeProvider);
    final count = bucket.markers.length;
    final size = (56 * scale) + (count > 9 ? 10 : 0);
    return Marker(
      point: bucket.cell.center,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _moveCamera(bucket.cell.center, math.min(18.0, _effectiveZoom + 2)),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                dominant.withValues(alpha: 0.92),
                dominant.withValues(alpha: 0.65),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: dominant.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: count > 9 ? 16 : 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleMarkerCreated(ArtMarker marker) {
    if (!marker.hasValidPosition) return;
    final withinRadius =
        _distance.as(LengthUnit.Kilometer, _cameraCenter, marker.position) <=
            (_searchRadius + 0.5);
    if (withinRadius) {
      setState(() {
        final existingIndex = _artMarkers.indexWhere((m) => m.id == marker.id);
        if (existingIndex >= 0) {
          _artMarkers[existingIndex] = marker;
        } else {
          _artMarkers = List<ArtMarker>.from(_artMarkers)..add(marker);
        }
      });
    } else {
      _mapMarkerService.clearCache();
    }
  }

  Marker _buildMarkerOverlay(
      ArtMarker marker, Artwork? artwork, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = _resolveArtMarkerColor(marker, themeProvider);
    final distanceText = _userLocation != null
        ? _formatDistance(_calculateDistance(_userLocation!, marker.position))
        : null;
    final imageUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: marker.metadata,
    );

    return Marker(
      point: marker.position,
      width: 260,
      height: 230,
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: const Offset(0, -115),
        child: GestureDetector(
          onTap: () => _openMarkerDetail(marker, artwork),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 240,
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: baseColor.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              marker.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (artwork != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                artwork.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _activeMarker = null),
                        borderRadius: BorderRadius.circular(4),
                        child: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 90,
                      width: double.infinity,
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _markerImageFallback(baseColor, scheme, marker),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: baseColor.withValues(alpha: 0.12),
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                            )
                          : _markerImageFallback(baseColor, scheme, marker),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    marker.description.isNotEmpty
                        ? marker.description
                        : (artwork?.description ?? 'No description available'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (distanceText != null)
                        _compactChip(scheme, Icons.near_me, distanceText, baseColor),
                      if (marker.category.isNotEmpty)
                        _compactChip(scheme, Icons.category_outlined, marker.category, baseColor),
                      if (marker.metadata?['subjectLabel'] != null || marker.metadata?['subject_type'] != null)
                        _compactChip(
                          scheme,
                          Icons.label_outline,
                          (marker.metadata!['subjectLabel'] ?? marker.metadata!['subject_type']).toString(),
                          baseColor,
                        ),
                      if (marker.metadata?['locationName'] != null || marker.metadata?['location'] != null)
                        _compactChip(
                          scheme,
                          Icons.place_outlined,
                          (marker.metadata!['locationName'] ?? marker.metadata!['location']).toString(),
                          baseColor,
                        ),
                      if (artwork != null)
                        _compactChip(scheme, Icons.card_giftcard, '${artwork.rewards} POAP', baseColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: baseColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _openMarkerDetail(marker, artwork),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: Text(
                        'More info',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Unified chip widget for displaying metadata with icon
  Widget _compactChip(
    ColorScheme scheme,
    IconData icon,
    String label,
    Color accent, {
    bool isLarge = false,
  }) {
    return Container(
      padding: isLarge
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isLarge ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(isLarge ? 10 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isLarge ? 14 : 11, color: accent),
          SizedBox(width: isLarge ? 6 : 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isLarge ? 11 : 10,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a thumbnail widget for artwork cover images with error fallback
  Widget _buildArtworkThumbnail(String? imageUrl, {
    required double width,
    required double height,
    required double borderRadius,
    double iconSize = 24,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.image,
        size: iconSize,
        color: scheme.onSurfaceVariant,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _markerImageFallback(Color baseColor, ColorScheme scheme, ArtMarker marker) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            baseColor.withValues(alpha: 0.25),
            baseColor.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        _resolveArtMarkerIcon(marker.type),
        color: scheme.onPrimary,
        size: 42,
      ),
    );
  }

  Future<void> _openMarkerDetail(ArtMarker marker, Artwork? artwork) async {
    setState(() {
      _activeMarker = marker;
      _selectedArtwork = artwork;
      _showFiltersPanel = false;
    });

    final resolvedArtwork = await _ensureLinkedArtworkLoaded(marker, initial: artwork);
    if (!mounted) return;

    setState(() {
      _selectedArtwork = resolvedArtwork;
    });

    if (resolvedArtwork == null) {
      await _showMarkerInfoFallback(marker);
    }
  }

  Future<Artwork?> _ensureLinkedArtworkLoaded(ArtMarker marker, {Artwork? initial}) async {
    Artwork? resolvedArtwork = initial;
    final artworkProvider = context.read<ArtworkProvider>();

    final artworkId = marker.artworkId;
    if (artworkId != null && artworkId.isNotEmpty) {
      resolvedArtwork ??= artworkProvider.getArtworkById(artworkId);

      if (resolvedArtwork == null) {
        try {
          await artworkProvider.fetchArtworkIfNeeded(artworkId);
          resolvedArtwork = artworkProvider.getArtworkById(artworkId);
          if (mounted && _activeMarker?.id == marker.id) {
            setState(() {});
          }
        } catch (e) {
          debugPrint('DesktopMapScreen: failed to fetch artwork $artworkId for marker ${marker.id}: $e');
        }
      }
    }

    resolvedArtwork ??= _artworkFromMarkerMetadata(marker);
    if (resolvedArtwork != null) {
      if (artworkProvider.getArtworkById(resolvedArtwork.id) == null) {
        artworkProvider.addOrUpdateArtwork(resolvedArtwork);
      }
      if (mounted && _activeMarker?.id == marker.id) {
        setState(() {
          if (_selectedArtwork == null || _selectedArtwork?.id == resolvedArtwork!.id) {
            _selectedArtwork = resolvedArtwork;
          }
        });
      }
    }

    return resolvedArtwork;
  }

  Future<void> _showMarkerInfoFallback(ArtMarker marker) async {
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = ArtworkMediaResolver.resolveCover(
      metadata: marker.metadata,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          marker.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverUrl != null && coverUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  coverUrl,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _markerImageFallback(_resolveArtMarkerColor(marker, context.read<ThemeProvider>()), scheme, marker),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              marker.description.isNotEmpty
                  ? marker.description
                  : 'No linked artwork found for this marker yet.',
              style: GoogleFonts.inter(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  MarkerSubjectData _snapshotMarkerSubjectData() => _subjectLoader.snapshot();

  Future<MarkerSubjectData?> _refreshMarkerSubjectData({bool force = false}) {
    return _subjectLoader.refresh(force: force);
  }

  Future<void> _prefetchMarkerSubjects() async {
    try {
      await _refreshMarkerSubjectData(force: true);
    } catch (e) {
      debugPrint('DesktopMapScreen: subject prefetch failed: $e');
    }
  }

  Future<void> _startMarkerCreationFlow({LatLng? position}) async {
    final targetPosition = position ?? _pendingMarkerLocation ?? _effectiveCenter;
    final subjectData = await _refreshMarkerSubjectData(force: true) ?? _snapshotMarkerSubjectData();
    if (!mounted) return;

    if (subjectData.artworks.isEmpty) {
      final wallet = context.read<WalletProvider>().currentWalletAddress;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wallet == null || wallet.isEmpty
                ? 'Connect your wallet and create an AR-enabled artwork to place a marker.'
                : 'No AR-enabled artworks found for your wallet. Create one first to place a marker.',
            style: GoogleFonts.inter(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final MapMarkerFormResult? result = await MapMarkerDialog.show(
      context: context,
      subjectData: subjectData,
      onRefreshSubjects: ({bool force = false}) => _refreshMarkerSubjectData(force: force),
      initialPosition: targetPosition,
      allowManualPosition: true,
      mapCenter: _effectiveCenter,
      onUseMapCenter: () {
        final center = _effectiveCenter;
        setState(() => _pendingMarkerLocation = center);
      },
      initialSubjectType: MarkerSubjectType.artwork,
    );

    if (!mounted || result == null) return;

    final selectedPosition = result.positionOverride ?? targetPosition;
    final success = await _createMarkerAtPosition(
      position: selectedPosition,
      form: result,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Marker created successfully!',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadMarkers(force: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create marker. Please try again.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _createMarkerAtPosition({
    required LatLng position,
    required MapMarkerFormResult form,
  }) async {
    try {
      final currentZoom = _effectiveZoom;
      final gridCell = GridUtils.gridCellForZoom(position, currentZoom);
      final tileProviders = Provider.of<TileProviders?>(context, listen: false);
      final LatLng snappedPosition = tileProviders?.snapToVisibleGrid(position, currentZoom) ??
          gridCell.center;

      final resolvedCategory = form.category.isNotEmpty
          ? form.category
          : form.subject?.type.defaultCategory ?? form.subjectType.defaultCategory;

      final marker = await _mapMarkerService.createMarker(
        location: snappedPosition,
        title: form.title,
        description: form.description,
        type: form.markerType,
        category: resolvedCategory,
        artworkId: form.linkedArtwork?.id,
        modelCID: form.linkedArtwork?.model3DCID,
        modelURL: form.linkedArtwork?.model3DURL,
        isPublic: form.isPublic,
        metadata: {
          'snapZoom': currentZoom,
          'gridAnchor': gridCell.anchorKey,
          'gridLevel': gridCell.gridLevel,
          'gridIndices': {
            'u': gridCell.uIndex,
            'v': gridCell.vIndex,
          },
          'createdFrom': 'desktop_map_screen',
          'subjectType': form.subjectType.name,
          'subjectLabel': form.subjectType.label,
          if (form.subject != null) ...{
            'subjectId': form.subject!.id,
            'subjectTitle': form.subject!.title,
            'subjectSubtitle': form.subject!.subtitle,
          },
          if (form.linkedArtwork != null) ...{
            'linkedArtworkId': form.linkedArtwork!.id,
            'linkedArtworkTitle': form.linkedArtwork!.title,
          },
          'visibility': form.isPublic ? 'public' : 'private',
          if (form.subject?.metadata != null) ...form.subject!.metadata!,
        },
      );

      if (marker != null) {
        setState(() {
          _pendingMarkerLocation = null;
          _artMarkers.add(marker);
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('DesktopMapScreen: error creating marker: $e');
      return false;
    }
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

class _ClusterBucket {
  _ClusterBucket(this.cell, this.markers);
  final GridCell cell;
  final List<ArtMarker> markers;
}

