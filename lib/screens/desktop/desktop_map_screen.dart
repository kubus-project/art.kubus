import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../providers/themeprovider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/marker_management_provider.dart';
import '../../providers/presence_provider.dart';
import '../../providers/tile_providers.dart';
import '../../providers/wallet_provider.dart';
import '../../models/artwork.dart';
import '../../models/art_marker.dart';
import '../../models/exhibition.dart';
import '../../models/map_marker_subject.dart';
import '../../config/config.dart';
import '../../services/map_style_service.dart';
import '../../services/backend_api_service.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../services/map_marker_service.dart';
import '../../services/ar_service.dart';
import '../../utils/map_marker_subject_loader.dart';
import '../../utils/map_marker_helper.dart';
import '../../utils/art_marker_list_diff.dart';
import '../../utils/debouncer.dart';
import '../../utils/map_search_suggestion.dart';
import '../../utils/presence_marker_visit.dart';
import '../../utils/map_viewport_utils.dart';
import '../../utils/geo_bounds.dart';
import '../../widgets/art_marker_cube.dart';
import '../../widgets/artwork_creator_byline.dart';
import '../../widgets/art_map_view.dart';
import '../../widgets/map_marker_dialog.dart';
import '../../utils/grid_utils.dart';
import '../../widgets/app_logo.dart';
import '../../utils/app_animations.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/media_url_resolver.dart';
import 'components/desktop_widgets.dart';
import 'desktop_shell.dart';
import 'art/desktop_artwork_detail_screen.dart';
import '../events/exhibition_detail_screen.dart';
import 'community/desktop_user_profile_screen.dart';
import '../../services/search_service.dart';
import '../../services/task_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/category_accent_color.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/maplibre_style_utils.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/tutorial/interactive_tutorial_overlay.dart';
import '../../widgets/inline_progress.dart';
import '../../providers/task_provider.dart';
import '../../models/task.dart';
 

/// Desktop map screen with Google Maps-style presentation
/// Features side panel for artwork details and filters
enum _MarkerOverlayMode {
  anchored,
  centered,
}

class DesktopMapScreen extends StatefulWidget {
  final LatLng? initialCenter;
  final double? initialZoom;
  final bool autoFollow;
  final String? initialMarkerId;

  const DesktopMapScreen({
    super.key,
    this.initialCenter,
    this.initialZoom,
    this.autoFollow = true,
    this.initialMarkerId,
  });

  @override
  State<DesktopMapScreen> createState() => _DesktopMapScreenState();
}

class _DesktopMapScreenState extends State<DesktopMapScreen>
    with TickerProviderStateMixin {
  ml.MapLibreMapController? _mapController;
  late AnimationController _animationController;
  late AnimationController _panelController;
  final MapMarkerService _mapMarkerService = MapMarkerService();

  Artwork? _selectedArtwork;
  Exhibition? _selectedExhibition;
  ArtMarker? _activeMarker;
  bool _markerOverlayExpanded = false;
  _MarkerOverlayMode _markerOverlayMode = _MarkerOverlayMode.anchored;
  bool _didOpenInitialMarker = false;
  bool _showFiltersPanel = false;
  bool _isDiscoveryExpanded = false;
  String _selectedFilter = 'nearby';
  double _searchRadius = 5.0; // km
  bool _travelModeEnabled = false;
  bool _isometricViewEnabled = false;

  // Travel mode is viewport-based (bounds query), not huge-radius.
  double get _effectiveSearchRadiusKm => _searchRadius;

  // Interactive onboarding tutorial (coach marks)
  final GlobalKey _tutorialMapKey = GlobalKey();
  final GlobalKey _tutorialSearchKey = GlobalKey();
  final GlobalKey _tutorialFilterChipsKey = GlobalKey();
  final GlobalKey _tutorialFiltersButtonKey = GlobalKey();
  final GlobalKey _tutorialNearbyButtonKey = GlobalKey();
  final GlobalKey _tutorialTravelButtonKey = GlobalKey();

  bool _showMapTutorial = false;
  int _mapTutorialIndex = 0;
  LatLng? _pendingMarkerLocation;
  bool _mapReady = false;
  double _cameraZoom = 13.0;
  int _renderZoomBucket = MapViewportUtils.zoomBucket(13.0);
  List<ArtMarker> _artMarkers = [];
  bool _isLoadingMarkers = false; // Tracks the latest marker request
  int _markerRequestId = 0;
  MarkerSubjectLoader get _subjectLoader => MarkerSubjectLoader(context);
  LatLng? _userLocation;
  bool _autoFollow = true;
  bool _isLocating = false;
  bool _isNearbyPanelOpen = false;
  String? _nearbySidebarSignature;
  final Distance _distance = const Distance();
  StreamSubscription<ArtMarker>? _markerStreamSub;
  StreamSubscription<String>? _markerDeletedSub;
  final Debouncer _markerRefreshDebouncer = Debouncer();
  LatLng _cameraCenter = const LatLng(46.0569, 14.5058);
  LatLng? _queuedCameraTarget;
  double? _queuedCameraZoom;
  LatLng? _lastMarkerFetchCenter;
  DateTime? _lastMarkerFetchTime;
  GeoBounds? _loadedTravelBounds;
  int? _loadedTravelZoomBucket;
  bool _programmaticCameraMove = false;
  double _lastBearing = 0.0;
  bool _mapStyleReady = false;
  bool _styleInitializationInProgress = false;
  final Set<String> _registeredMapImages = <String>{};
  final LayerLink _markerOverlayLink = LayerLink();
  final Debouncer _overlayAnchorDebouncer = Debouncer();
  Offset? _activeMarkerAnchor;
  static const String _markerSourceId = 'kubus_markers';
  static const String _markerLayerId = 'kubus_marker_layer';
  static const String _locationSourceId = 'kubus_user_location';
  static const String _locationLayerId = 'kubus_user_location_layer';
  static const String _pendingSourceId = 'kubus_pending_marker';
  static const String _pendingLayerId = 'kubus_pending_marker_layer';
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

  final List<String> _filterOptions = [
    'all',
    'nearby',
    'discovered',
    'undiscovered',
    'ar',
    'favorites'
  ];
  String _selectedSort = 'distance';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
    _markerStreamSub =
        _mapMarkerService.onMarkerCreated.listen(_handleMarkerCreated);
    _markerDeletedSub =
        _mapMarkerService.onMarkerDeleted.listen(_handleMarkerDeleted);

    _autoFollow = widget.autoFollow;
    _cameraCenter = widget.initialCenter ?? const LatLng(46.0569, 14.5058);
    _cameraZoom = widget.initialZoom ?? _cameraZoom;

    unawaited(_loadMapTravelPrefs());
    unawaited(_loadMapIsometricPrefs());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load markers after the first layout. If travel mode is enabled we will
      // force a bounds refresh once the map reports ready.
      unawaited(_loadMarkersForCurrentView(force: true).then((_) => _maybeOpenInitialMarker()));

      // Only animate camera to user location when we're not deep-linking to a target.
      // When initialCenter is provided (e.g. "Open on Map"), keep the camera focused on that target.
      final bool shouldAnimateToUser =
          widget.initialCenter == null && widget.autoFollow;
      _refreshUserLocation(animate: shouldAnimateToUser);
      _prefetchMarkerSubjects();

      // Desktop UX: show the nearby list in the functions sidebar (right panel)
      // instead of rendering a "nearby" card overlay on the map.
      _openNearbyArtPanel();

      unawaited(_maybeShowInteractiveMapTutorial());
    });
  }

  Future<void> _loadMapTravelPrefs() async {
    if (!AppConfig.isFeatureEnabled('mapTravelMode')) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(PreferenceKeys.mapTravelModeEnabledV1) ?? false;
      if (!mounted) return;
      setState(() {
        _travelModeEnabled = enabled;
      });
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _loadMapIsometricPrefs() async {
    if (!AppConfig.isFeatureEnabled('mapIsometricView')) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(PreferenceKeys.mapIsometricViewEnabledV1) ?? false;
      if (!mounted) return;
      setState(() {
        _isometricViewEnabled = enabled;
      });
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _setTravelModeEnabled(bool enabled) async {
    if (!AppConfig.isFeatureEnabled('mapTravelMode')) return;
    if (!mounted) return;

    setState(() {
      _travelModeEnabled = enabled;
    });

    // Switching query strategy (radius vs bounds) should invalidate caches.
    _mapMarkerService.clearCache();
    _loadedTravelBounds = null;
    _loadedTravelZoomBucket = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PreferenceKeys.mapTravelModeEnabledV1, enabled);
    } catch (_) {
      // Best-effort.
    }

    unawaited(_loadMarkersForCurrentView(force: true));
  }

  Future<void> _setIsometricViewEnabled(bool enabled) async {
    if (!AppConfig.isFeatureEnabled('mapIsometricView')) return;
    if (!mounted) return;

    setState(() {
      _isometricViewEnabled = enabled;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PreferenceKeys.mapIsometricViewEnabledV1, enabled);
    } catch (_) {
      // Best-effort.
    }

    unawaited(_applyIsometricCamera(enabled: enabled, adjustZoomForScale: true));
  }

  Future<void> _maybeShowInteractiveMapTutorial() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(PreferenceKeys.mapOnboardingDesktopSeenV2) ?? false;
      if (seen) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _showMapTutorial = true;
          _mapTutorialIndex = 0;
        });
      });
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _setMapTutorialSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PreferenceKeys.mapOnboardingDesktopSeenV2, true);
    } catch (_) {
      // Best-effort.
    }
  }

  void _dismissMapTutorial() {
    if (!mounted) return;
    setState(() => _showMapTutorial = false);
    unawaited(_setMapTutorialSeen());
  }

  void _tutorialNext() {
    if (!mounted) return;
    final steps = _buildMapTutorialSteps(AppLocalizations.of(context)!);
    if (_mapTutorialIndex >= steps.length - 1) {
      _dismissMapTutorial();
      return;
    }
    setState(() => _mapTutorialIndex += 1);
  }

  void _tutorialBack() {
    if (!mounted) return;
    if (_mapTutorialIndex <= 0) return;
    setState(() => _mapTutorialIndex -= 1);
  }

  List<TutorialStepDefinition> _buildMapTutorialSteps(AppLocalizations l10n) {
    final steps = <TutorialStepDefinition>[
      TutorialStepDefinition(
        targetKey: _tutorialMapKey,
        icon: Icons.map_outlined,
        title: l10n.mapTutorialStepMapTitle,
        body: l10n.mapTutorialStepMapBody,
      ),
      TutorialStepDefinition(
        targetKey: _tutorialMapKey,
        icon: Icons.place_outlined,
        title: l10n.mapTutorialStepMarkersTitle,
        body: l10n.mapTutorialStepMarkersBody,
      ),
      TutorialStepDefinition(
        targetKey: _tutorialNearbyButtonKey,
        icon: Icons.view_list,
        title: l10n.mapTutorialStepNearbyTitle,
        body: l10n.mapTutorialStepNearbyDesktopBody,
        onTargetTap: _openNearbyArtPanel,
      ),
      TutorialStepDefinition(
        targetKey: _tutorialFilterChipsKey,
        icon: Icons.auto_awesome,
        title: l10n.mapTutorialStepTypesTitle,
        body: l10n.mapTutorialStepTypesDesktopBody,
      ),
      TutorialStepDefinition(
        targetKey: _tutorialFiltersButtonKey,
        icon: Icons.tune,
        title: l10n.mapTutorialStepFiltersTitle,
        body: l10n.mapTutorialStepFiltersDesktopBody,
        tooltipAlignToTargetRightEdge: true,
        onTargetTap: () {
          if (!mounted) return;
          setState(() => _showFiltersPanel = true);
        },
      ),
    ];

    if (AppConfig.isFeatureEnabled('mapTravelMode')) {
      steps.add(
        TutorialStepDefinition(
          targetKey: _tutorialTravelButtonKey,
          icon: Icons.travel_explore,
          title: l10n.mapTutorialStepTravelTitle,
          body: l10n.mapTutorialStepTravelBody,
          onTargetTap: () => unawaited(_setTravelModeEnabled(true)),
        ),
      );
    }

    steps.add(
      TutorialStepDefinition(
        targetKey: _tutorialSearchKey,
        icon: Icons.search,
        title: l10n.mapTutorialStepSearchTitle,
        body: l10n.mapTutorialStepSearchBody,
      ),
    );

    return steps;
  }

  void _openNearbyArtPanel() {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope == null) return;

    setState(() {
      _isNearbyPanelOpen = true;
      _nearbySidebarSignature = null;
      _selectedArtwork = null;
      _selectedExhibition = null;
      _showFiltersPanel = false;
    });

    shellScope.openFunctionsPanel(DesktopFunctionsPanel.exploreNearby);
  }

  void _closeNearbyArtPanel() {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope == null) return;
    setState(() => _isNearbyPanelOpen = false);
    _nearbySidebarSignature = null;
    shellScope.closeFunctionsPanel();
  }

  void _syncNearbySidebarIfNeeded(
      ThemeProvider themeProvider, List<Artwork> filteredArtworks) {
    if (!_isNearbyPanelOpen) return;
    final shellScope = DesktopShellScope.of(context);
    if (shellScope == null) return;

    // Build a compact signature so we only push sidebar updates when something
    // meaningful changes (avoids setState->build feedback loops).
    final base = _userLocation ?? _effectiveCenter;
    final ids = filteredArtworks
        .take(30)
        .map((a) => a.id)
        .join(',');
    final modeSig = _travelModeEnabled ? 'travel' : _effectiveSearchRadiusKm.toStringAsFixed(1);
    final sig = '$modeSig|'
        '${base.latitude.toStringAsFixed(4)},${base.longitude.toStringAsFixed(4)}|'
        '${filteredArtworks.length}|$ids';
    if (_nearbySidebarSignature == sig) return;
    _nearbySidebarSignature = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      shellScope.setFunctionsPanelContent(
        _buildNearbyArtSidebar(themeProvider, filteredArtworks),
      );
    });
  }

  Future<void> _maybeOpenInitialMarker() async {
    if (_didOpenInitialMarker) return;
    final markerId = widget.initialMarkerId?.trim() ?? '';
    if (markerId.isEmpty) return;

    _didOpenInitialMarker = true;

    final existing = _artMarkers.where((m) => m.id == markerId).toList(growable: false);
    if (existing.isNotEmpty) {
      _moveCamera(existing.first.position, math.max(_effectiveZoom, 15));
      _handleMarkerTap(existing.first, overlayMode: _MarkerOverlayMode.centered);
      return;
    }

    try {
      final marker = await BackendApiService().getArtMarker(markerId);
      if (!mounted) return;
      if (marker == null || !marker.hasValidPosition) return;

      setState(() {
        _artMarkers.removeWhere((m) => m.id == marker.id);
        _artMarkers.add(marker);
      });
      _moveCamera(marker.position, math.max(_effectiveZoom, 15));
      _handleMarkerTap(marker, overlayMode: _MarkerOverlayMode.centered);
    } catch (_) {
      // Best-effort: keep user on map if marker fetch fails.
    }
  }

  LatLng get _effectiveCenter => _cameraCenter;
  double get _effectiveZoom => _cameraZoom;

  void _handleMapReady() {
    setState(() => _mapReady = true);
    if (_queuedCameraTarget != null && _queuedCameraZoom != null) {
      unawaited(_moveCamera(_queuedCameraTarget!, _queuedCameraZoom!));
      _queuedCameraTarget = null;
      _queuedCameraZoom = null;
    }

    // Travel mode needs a bounds-based fetch once the viewport exists.
    if (_travelModeEnabled) {
      unawaited(_loadMarkersForCurrentView(force: true));
    } else if (_artMarkers.isEmpty && !_isLoadingMarkers) {
      unawaited(_loadMarkersForCurrentView(force: true));
    }
  }

  void _handleMapCreated(ml.MapLibreMapController controller) {
    _mapController = controller;
    _mapStyleReady = false;
    _registeredMapImages.clear();
  }

  String _hexRgb(Color color) {
    return MapLibreStyleUtils.hexRgb(color);
  }

  Future<void> _handleMapStyleLoaded(ThemeProvider themeProvider) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!mounted) return;
    if (_styleInitializationInProgress) return;

    final scheme = Theme.of(context).colorScheme;
    _styleInitializationInProgress = true;
    _mapStyleReady = false;
    _registeredMapImages.clear();

    try {
      final Set<String> existingLayerIds = <String>{};
      try {
        final raw = await controller.getLayerIds();
        for (final id in raw) {
          if (id is String) existingLayerIds.add(id);
        }
      } catch (_) {}

      // Clear any previous layer/source ids (e.g. style swap).
      for (final id in <String>[
        _markerLayerId,
        _locationLayerId,
        _pendingLayerId
      ]) {
        if (!existingLayerIds.contains(id)) continue;
        try {
          await controller.removeLayer(id);
        } catch (_) {}
        existingLayerIds.remove(id);
      }
      for (final id in <String>[
        _markerSourceId,
        _locationSourceId,
        _pendingSourceId
      ]) {
        try {
          await controller.removeSource(id);
        } catch (_) {}
      }

      await controller.addGeoJsonSource(
        _markerSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[]
        },
        promoteId: 'id',
      );
      await controller.addSymbolLayer(
        _markerSourceId,
        _markerLayerId,
        ml.SymbolLayerProperties(
          iconImage: <dynamic>['get', 'icon'],
          iconSize: <dynamic>[
            'interpolate',
            ['linear'],
            ['zoom'],
            3,
            0.5,
            15,
            1.0,
            24,
            1.5,
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          iconPitchAlignment: 'map',
          iconRotationAlignment: 'map',
        ),
      );

      await controller.addGeoJsonSource(
        _locationSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[]
        },
        promoteId: 'id',
      );
      await controller.addCircleLayer(
        _locationSourceId,
        _locationLayerId,
        ml.CircleLayerProperties(
          circleRadius: 6,
          circleColor: _hexRgb(scheme.secondary),
          circleOpacity: 1.0,
          circleStrokeWidth: 2,
          circleStrokeColor: _hexRgb(scheme.surface),
        ),
      );

      await controller.addGeoJsonSource(
        _pendingSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[]
        },
        promoteId: 'id',
      );
      await controller.addCircleLayer(
        _pendingSourceId,
        _pendingLayerId,
        ml.CircleLayerProperties(
          circleRadius: 7,
          circleColor: _hexRgb(scheme.primary),
          circleOpacity: 0.92,
          circleStrokeWidth: 2,
          circleStrokeColor: _hexRgb(scheme.surface),
        ),
      );

      if (!mounted) return;
      _mapStyleReady = true;

      await _applyIsometricCamera(enabled: _isometricViewEnabled);
      await _syncUserLocation(themeProvider: themeProvider);
      await _syncPendingMarker(themeProvider: themeProvider);
      await _syncMapMarkers(themeProvider: themeProvider);
      _queueOverlayAnchorRefresh();
    } catch (e, st) {
      _mapStyleReady = false;
      if (kDebugMode) {
        AppConfig.debugPrint('DesktopMapScreen: style init failed: $e');
        AppConfig.debugPrint('DesktopMapScreen: style init stack: $st');
      }
    } finally {
      _styleInitializationInProgress = false;
    }
  }

  void _queueOverlayAnchorRefresh() {
    if (_markerOverlayMode != _MarkerOverlayMode.anchored) return;
    if (_activeMarker == null) return;
    if (!_mapStyleReady) return;
    _overlayAnchorDebouncer(const Duration(milliseconds: 16), () {
      unawaited(_refreshActiveMarkerAnchor());
    });
  }

  Future<void> _refreshActiveMarkerAnchor() async {
    final controller = _mapController;
    final marker = _activeMarker;
    if (controller == null || marker == null) return;
    if (!_mapStyleReady) return;
    if (_markerOverlayMode != _MarkerOverlayMode.anchored) return;

    try {
      final screen = await controller.toScreenLocation(
        ml.LatLng(marker.position.latitude, marker.position.longitude),
      );
      if (!mounted) return;
      setState(() {
        _activeMarkerAnchor = Offset(screen.x.toDouble(), screen.y.toDouble());
      });
    } catch (_) {
      // Ignore anchor updates during style transitions.
    }
  }

  Future<void> _handleMapTap(
    math.Point<double> point, {
    required ThemeProvider themeProvider,
  }) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_mapStyleReady) return;

    try {
      final features = await controller.queryRenderedFeatures(
        point,
        <String>[_markerLayerId],
        null,
      );

      if (features.isEmpty) {
        setState(() {
          _selectedArtwork = null;
          _selectedExhibition = null;
          _showFiltersPanel = false;
          _showSearchOverlay = false;
          _pendingMarkerLocation = null;
          _activeMarker = null;
          _markerOverlayExpanded = false;
          _activeMarkerAnchor = null;
        });
        unawaited(_syncMapMarkers(themeProvider: themeProvider));
        unawaited(_syncPendingMarker(themeProvider: themeProvider));
        return;
      }

      final dynamic first = features.first;
      final props = (first is Map ? first['properties'] : null) as Map?;
      final kind = props?['kind']?.toString();
      if (kind == 'cluster') {
        final lng = (props?['lng'] as num?)?.toDouble();
        final lat = (props?['lat'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        final nextZoom = math.min(_cameraZoom + 2.0, 18.0);
        await _moveCamera(LatLng(lat, lng), nextZoom);
        return;
      }

      final markerId = (props?['markerId'] ?? props?['id'])?.toString() ?? '';
      if (markerId.isEmpty) return;
      final marker = _artMarkers.where((m) => m.id == markerId).toList(growable: false);
      if (marker.isEmpty) return;
      _handleMarkerTap(marker.first);
      unawaited(_syncMapMarkers(themeProvider: themeProvider));
      _queueOverlayAnchorRefresh();
    } catch (_) {
      // Ignore taps during style transitions / rapid camera moves.
    }
  }

  Future<void> _syncUserLocation({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_mapStyleReady) return;

    final pos = _userLocation;
    final data = (pos == null)
        ? const <String, dynamic>{'type': 'FeatureCollection', 'features': <dynamic>[]}
        : <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <dynamic>[
              <String, dynamic>{
                'type': 'Feature',
                'id': 'me',
                'properties': const <String, dynamic>{'id': 'me'},
                'geometry': <String, dynamic>{
                  'type': 'Point',
                  'coordinates': <double>[pos.longitude, pos.latitude],
                },
              },
            ],
          };

    await controller.setGeoJsonSource(_locationSourceId, data);
  }

  Future<void> _syncPendingMarker({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_mapStyleReady) return;

    final pos = _pendingMarkerLocation;
    final data = (pos == null)
        ? const <String, dynamic>{'type': 'FeatureCollection', 'features': <dynamic>[]}
        : <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <dynamic>[
              <String, dynamic>{
                'type': 'Feature',
                'id': 'pending',
                'properties': const <String, dynamic>{'id': 'pending'},
                'geometry': <String, dynamic>{
                  'type': 'Point',
                  'coordinates': <double>[pos.longitude, pos.latitude],
                },
              },
            ],
          };

    await controller.setGeoJsonSource(_pendingSourceId, data);
  }

  List<_ClusterBucket> _clusterMarkers(List<ArtMarker> markers, double zoom) {
    if (markers.isEmpty) return const <_ClusterBucket>[];

    final level = (GridUtils.resolvePrimaryGridLevel(zoom) - 2).clamp(3, 14);
    final Map<String, _ClusterBucket> buckets = {};

    for (final marker in markers) {
      final cell = GridUtils.gridCellForLevel(marker.position, level);
      buckets.putIfAbsent(cell.anchorKey, () => _ClusterBucket(cell, <ArtMarker>[]));
      buckets[cell.anchorKey]!.markers.add(marker);
    }

    return buckets.values.toList(growable: false);
  }

  Future<void> _syncMapMarkers({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_mapStyleReady) return;
    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final isDark = themeProvider.isDarkMode;

    final zoom = _cameraZoom;
    final visibleMarkers = _artMarkers.where((m) => m.hasValidPosition).toList(growable: false);
    final useClustering = zoom < 12;

    final features = <dynamic>[];

    if (useClustering) {
      final clusters = _clusterMarkers(visibleMarkers, zoom);
      for (final cluster in clusters) {
        if (cluster.markers.length == 1) {
          final marker = cluster.markers.first;
          final feature = await _markerFeatureFor(
              marker: marker,
              themeProvider: themeProvider,
              scheme: scheme,
              roles: roles,
              isDark: isDark,
            );
          if (!mounted) return;
          if (feature.isNotEmpty) features.add(feature);
        } else {
          final feature = await _clusterFeatureFor(
              cluster: cluster,
              scheme: scheme,
              roles: roles,
              isDark: isDark,
            );
          if (!mounted) return;
          if (feature.isNotEmpty) features.add(feature);
        }
      }
    } else {
      for (final marker in visibleMarkers) {
        final feature = await _markerFeatureFor(
            marker: marker,
            themeProvider: themeProvider,
            scheme: scheme,
            roles: roles,
            isDark: isDark,
          );
        if (!mounted) return;
        if (feature.isNotEmpty) features.add(feature);
      }
    }

    final collection = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
    if (!mounted) return;
    await controller.setGeoJsonSource(_markerSourceId, collection);
  }

  Future<Map<String, dynamic>> _markerFeatureFor({
    required ArtMarker marker,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
  }) async {
    final controller = _mapController;
    if (controller == null) return const <String, dynamic>{};

    final selected = _activeMarker?.id == marker.id;
    final typeName = marker.type.name;
    final tier = marker.signalTier;
    final iconId = 'mk_${typeName}_${tier.name}${selected ? '_sel' : ''}_${isDark ? 'd' : 'l'}';

    if (!_registeredMapImages.contains(iconId)) {
      final baseColor = _resolveArtMarkerColor(marker, themeProvider);
      final bytes = await ArtMarkerCubeIconRenderer.renderMarkerPng(
        baseColor: baseColor,
        icon: _resolveArtMarkerIcon(marker.type),
        tier: tier,
        scheme: scheme,
        roles: roles,
        isDark: isDark,
        forceGlow: selected,
      );
      if (!mounted) return const <String, dynamic>{};
      try {
        await controller.addImage(iconId, bytes);
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint('DesktopMapScreen: addImage failed ($iconId): $e');
        }
        return const <String, dynamic>{};
      }
      _registeredMapImages.add(iconId);
    }

    return <String, dynamic>{
      'type': 'Feature',
      'id': marker.id,
      'properties': <String, dynamic>{
        'id': marker.id,
        'markerId': marker.id,
        'kind': 'marker',
        'icon': iconId,
        'markerType': typeName,
      },
      'geometry': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[marker.position.longitude, marker.position.latitude],
      },
    };
  }

  Future<Map<String, dynamic>> _clusterFeatureFor({
    required _ClusterBucket cluster,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
  }) async {
    final controller = _mapController;
    if (controller == null) return const <String, dynamic>{};

    final first = cluster.markers.first;
    final typeName = first.type.name;
    final label = cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
    final iconId = 'cl_${typeName}_${label}_${isDark ? 'd' : 'l'}';

    if (!_registeredMapImages.contains(iconId)) {
      final baseColor = AppColorUtils.markerSubjectColor(
        markerType: typeName,
        metadata: first.metadata,
        scheme: scheme,
        roles: roles,
      );
      final bytes = await ArtMarkerCubeIconRenderer.renderClusterPng(
        count: cluster.markers.length,
        baseColor: baseColor,
        scheme: scheme,
        isDark: isDark,
      );
      if (!mounted) return const <String, dynamic>{};
      try {
        await controller.addImage(iconId, bytes);
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint('DesktopMapScreen: addImage failed ($iconId): $e');
        }
        return const <String, dynamic>{};
      }
      _registeredMapImages.add(iconId);
    }

    final center = cluster.cell.center;
    final id = 'cluster:${cluster.cell.anchorKey}';
    return <String, dynamic>{
      'type': 'Feature',
      'id': id,
      'properties': <String, dynamic>{
        'id': id,
        'kind': 'cluster',
        'icon': iconId,
        'lat': center.latitude,
        'lng': center.longitude,
      },
      'geometry': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[center.longitude, center.latitude],
      },
    };
  }

  Future<GeoBounds?> _getVisibleGeoBounds() async {
    final controller = _mapController;
    if (controller == null) return null;
    try {
      final bounds = await controller.getVisibleRegion();
      return GeoBounds.fromCorners(
        LatLng(bounds.southwest.latitude, bounds.southwest.longitude),
        LatLng(bounds.northeast.latitude, bounds.northeast.longitude),
      );
    } catch (_) {
      return null;
    }
  }

  void _queueMarkerRefresh({required bool fromGesture}) {
    if (_mapController == null) return;

    final center = _cameraCenter;
    final zoom = _cameraZoom;

    if (_travelModeEnabled) {
      final bucket = MapViewportUtils.zoomBucket(zoom);
      final debounceTime = fromGesture
          ? const Duration(milliseconds: 450)
          : const Duration(milliseconds: 350);

      _markerRefreshDebouncer(debounceTime, () {
        unawaited(() async {
          final visibleBounds = await _getVisibleGeoBounds();
          if (visibleBounds == null) return;

          final shouldRefetch = MapViewportUtils.shouldRefetchTravelMode(
            visibleBounds: visibleBounds,
            loadedBounds: _loadedTravelBounds,
            zoomBucket: bucket,
            loadedZoomBucket: _loadedTravelZoomBucket,
            hasMarkers: _artMarkers.isNotEmpty,
          );
          if (!shouldRefetch) return;

          final queryBounds = MapViewportUtils.expandBounds(
            visibleBounds,
            MapViewportUtils.paddingFractionForZoomBucket(bucket),
          );

          await _loadMarkers(
            center: center,
            bounds: queryBounds,
            force: false,
            zoomBucket: bucket,
          );
        }());
      });
      return;
    }

    final shouldRefresh = MapMarkerHelper.shouldRefreshMarkers(
      newCenter: center,
      lastCenter: _lastMarkerFetchCenter,
      lastFetchTime: _lastMarkerFetchTime,
      distance: _distance,
      refreshInterval: _markerRefreshInterval,
      refreshDistanceMeters: _markerRefreshDistanceMeters,
      hasMarkers: _artMarkers.isNotEmpty,
    );

    if (!shouldRefresh) return;

    final debounceTime = fromGesture
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 800);

    _markerRefreshDebouncer(debounceTime, () {
      unawaited(_loadMarkers(center: center, force: false));
    });
  }

  Future<void> _applyIsometricCamera({required bool enabled, bool adjustZoomForScale = false}) async {
    final controller = _mapController;
    if (controller == null) return;

    final shouldEnable = enabled && AppConfig.isFeatureEnabled('mapIsometricView');
    final targetPitch = shouldEnable ? 54.736 : 0.0;
    final targetBearing = shouldEnable
        ? (_lastBearing.abs() < 1.0 ? 18.0 : _lastBearing)
        : 0.0;

    double targetZoom = _cameraZoom;
    if (adjustZoomForScale) {
      const scale = 1.2;
      final delta = math.log(scale) / math.ln2;
      targetZoom = shouldEnable
          ? (_cameraZoom + delta)
          : (_cameraZoom - delta);
      targetZoom = targetZoom.clamp(3.0, 24.0).toDouble();
      _cameraZoom = targetZoom;
    }

    _programmaticCameraMove = true;
    await controller.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(_cameraCenter.latitude, _cameraCenter.longitude),
          zoom: targetZoom,
          bearing: targetBearing,
          tilt: targetPitch,
        ),
      ),
      duration: const Duration(milliseconds: 320),
    );
  }

  Future<void> _moveCamera(LatLng target, double zoom) async {
    _cameraCenter = target;
    _cameraZoom = zoom;
    final controller = _mapController;
    if (!_mapReady || controller == null) {
      _queuedCameraTarget = target;
      _queuedCameraZoom = zoom;
      return;
    }

    _programmaticCameraMove = true;
    await controller.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(target.latitude, target.longitude),
          zoom: zoom,
          bearing: _lastBearing,
          tilt:
              _isometricViewEnabled && AppConfig.isFeatureEnabled('mapIsometricView')
                  ? 54.736
                  : 0.0,
        ),
      ),
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    // Avoid leaving Explore-side panels open when navigating away.
    try {
      DesktopShellScope.of(context)?.closeFunctionsPanel();
    } catch (_) {}

    _mapController = null;
    _mapStyleReady = false;
    _registeredMapImages.clear();
    _animationController.dispose();
    _panelController.dispose();
    _searchDebounce?.cancel();
    _markerRefreshDebouncer.dispose();
    _overlayAnchorDebouncer.dispose();
    _markerStreamSub?.cancel();
    _markerDeletedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Map layer
          KeyedSubtree(
            key: _tutorialMapKey,
            child: _buildMapLayer(themeProvider),
          ),

          // Top bar
          _buildTopBar(themeProvider, animationTheme),

          // Search suggestions overlay
          if (_showSearchOverlay) _buildSearchOverlay(themeProvider),

          // Left side panel (artwork/exhibition details or filters)
          AnimatedPositioned(
            duration: animationTheme.medium,
            curve: animationTheme.defaultCurve,
            left: _selectedArtwork != null ||
                    _selectedExhibition != null ||
                    _showFiltersPanel
                ? 0
                : -400,
            top: 80,
            bottom: 24,
            width: 380,
            child: _selectedExhibition != null
                ? _buildExhibitionDetailPanel(themeProvider, animationTheme)
                : _selectedArtwork != null
                    ? _buildArtworkDetailPanel(themeProvider, animationTheme)
                    : _buildFiltersPanel(themeProvider),
          ),

          // Map controls (bottom-right)
          Positioned(
            left: _selectedArtwork != null || _selectedExhibition != null
                ? 400
                : 24,
            right: 24,
            bottom: 24,
            child: Align(
              alignment: Alignment.bottomRight,
              child: _buildMapControls(themeProvider),
            ),
          ),

          // Discovery path card (bottom-left when no panel is open)
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              final activeProgress = taskProvider.getActiveTaskProgress();
              if (activeProgress.isEmpty) return const SizedBox.shrink();
              final leftOffset =
                  (_selectedArtwork != null || _selectedExhibition != null || _showFiltersPanel)
                      ? 400.0
                      : 24.0;
              return Positioned(
                left: leftOffset,
                bottom: 24,
                child: _buildDiscoveryCard(themeProvider, taskProvider),
              );
            },
          ),

          if (_showMapTutorial)
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                final steps = _buildMapTutorialSteps(l10n);
                final idx = _mapTutorialIndex.clamp(0, steps.length - 1);
                return InteractiveTutorialOverlay(
                  steps: steps,
                  currentIndex: idx,
                  onNext: _tutorialNext,
                  onBack: _tutorialBack,
                  onSkip: _dismissMapTutorial,
                  skipLabel: l10n.commonSkip,
                  backLabel: l10n.commonBack,
                  nextLabel: l10n.commonNext,
                  doneLabel: l10n.commonDone,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMapLayer(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final filteredArtworks = _getFilteredArtworks(artworkProvider.artworks);

        _syncNearbySidebarIfNeeded(themeProvider, filteredArtworks);
        final isDark = themeProvider.isDarkMode;
        final tileProviders = Provider.of<TileProviders?>(context, listen: false);
        final styleAsset = tileProviders?.mapStyleAsset(isDarkMode: isDark) ??
            MapStyleService.primaryStyleRef(isDarkMode: isDark);

        final map = ArtMapView(
          initialCenter: _effectiveCenter,
          initialZoom: _cameraZoom,
          minZoom: 3.0,
          maxZoom: 24.0,
          isDarkMode: isDark,
          styleAsset: styleAsset,
          onMapCreated: _handleMapCreated,
          onStyleLoaded: () {
            unawaited(_handleMapStyleLoaded(themeProvider).then((_) => _handleMapReady()));
          },
          onCameraMove: (position) {
            _cameraCenter = LatLng(position.target.latitude, position.target.longitude);
            _cameraZoom = position.zoom;
            _lastBearing = position.bearing;

            final bucket = MapViewportUtils.zoomBucket(position.zoom);
            if (bucket != _renderZoomBucket) {
              setState(() => _renderZoomBucket = bucket);
            }

            final hasGesture = !_programmaticCameraMove;
            if (hasGesture && _autoFollow) {
              setState(() => _autoFollow = false);
            }
            if (hasGesture && _activeMarker != null) {
              setState(() {
                _activeMarker = null;
                _markerOverlayExpanded = false;
              });
              unawaited(_syncMapMarkers(themeProvider: themeProvider));
            }

            _queueMarkerRefresh(fromGesture: hasGesture);
            _queueOverlayAnchorRefresh();
          },
          onCameraIdle: () {
            _programmaticCameraMove = false;
            _queueMarkerRefresh(fromGesture: false);
            _queueOverlayAnchorRefresh();
          },
          onMapClick: (point, _) {
            unawaited(_handleMapTap(point, themeProvider: themeProvider));
          },
          onMapLongClick: (_, point) {
            setState(() => _pendingMarkerLocation = point);
            unawaited(_syncPendingMarker(themeProvider: themeProvider));
            _startMarkerCreationFlow(position: point);
          },
        );

        return Stack(
          children: [
            Positioned.fill(child: map),
            if (_markerOverlayMode == _MarkerOverlayMode.anchored &&
                _activeMarkerAnchor != null)
              Positioned(
                left: _activeMarkerAnchor!.dx,
                top: _activeMarkerAnchor!.dy,
                child: CompositedTransformTarget(
                  link: _markerOverlayLink,
                  child: const SizedBox(width: 1, height: 1),
                ),
              ),
            _buildMarkerOverlayLayer(
              themeProvider: themeProvider,
              artworkProvider: artworkProvider,
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshUserLocation({bool animate = false}) async {
    if (_isLocating) return;
    final themeProvider = context.read<ThemeProvider>();
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
      unawaited(_syncUserLocation(themeProvider: themeProvider));
      if (animate || _autoFollow) {
        _moveCamera(current, math.max(_effectiveZoom, 15));
      }
    } catch (e) {
      AppConfig.debugPrint('DesktopMapScreen: location fetch failed: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Widget _buildGlassChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    final animationTheme = context.animationTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = themeProvider.accentColor;

    final radius = BorderRadius.circular(20);
    final idleTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12);
    final selectedTint = accent.withValues(alpha: isDark ? 0.14 : 0.16);

    return AnimatedContainer(
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: isSelected
              ? accent.withValues(alpha: 0.85)
              : scheme.outline.withValues(alpha: 0.18),
          width: isSelected ? 1.25 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.sm + KubusSpacing.xs,
          vertical: KubusSpacing.sm + KubusSpacing.xxs,
        ),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        blurSigma: KubusGlassEffects.blurSigmaLight,
        showBorder: false,
        backgroundColor: isSelected ? selectedTint : idleTint,
        onTap: onTap,
        child: Text(
          label,
          style: (isSelected
                  ? theme.textTheme.labelLarge
                  : theme.textTheme.labelMedium)
              ?.copyWith(color: isSelected ? accent : scheme.onSurface),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
    bool isActive = false,
    String? tooltip,
    EdgeInsets? tooltipMargin,
    bool? tooltipPreferBelow,
    double? tooltipVerticalOffset,
    bool tooltipAlignRightEdge = false,
    double size = 42,
    BorderRadius? borderRadius,
    Color? activeTint,
    Color? iconColor,
    Color? activeIconColor,
  }) {
    final animationTheme = context.animationTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = themeProvider.accentColor;

    final radius = borderRadius ?? BorderRadius.circular(12);
    final idleTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12);
    final selectedTint = activeTint ?? accent.withValues(alpha: isDark ? 0.14 : 0.16);

    final resolvedIconColor = isActive
        ? (activeIconColor ?? accent)
        : (iconColor ?? scheme.onSurface);

    final child = SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: resolvedIconColor,
        ),
      ),
    );

    return AnimatedContainer(
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.85)
              : scheme.outline.withValues(alpha: 0.18),
          width: isActive ? 1.25 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: radius,
        blurSigma: KubusGlassEffects.blurSigmaLight,
        showBorder: false,
        backgroundColor: isActive ? selectedTint : idleTint,
        onTap: onTap,
        child: tooltip == null
            ? child
            : (tooltipAlignRightEdge
                ? _RightEdgeAlignedTooltip(
                    message: tooltip,
                    preferBelow: tooltipPreferBelow,
                    verticalOffset: tooltipVerticalOffset,
                    safePadding: tooltipMargin,
                    child: child,
                  )
                : Tooltip(
                    message: tooltip,
                    margin: tooltipMargin,
                    preferBelow: tooltipPreferBelow,
                    verticalOffset: tooltipVerticalOffset ?? 0,
                    child: child,
                  )),
      ),
    );
  }
  Widget _buildTopBar(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KubusSpacing.lg,
            KubusSpacing.sm + KubusSpacing.xs,
            KubusSpacing.lg,
            KubusSpacing.sm + KubusSpacing.xs,
          ),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.md + KubusSpacing.xs,
              vertical: KubusSpacing.md,
            ),
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            blurSigma: KubusGlassEffects.blurSigmaLight,
            backgroundColor:
                scheme.surface.withValues(alpha: isDark ? 0.20 : 0.14),
            showBorder: true,
            child: Row(
              children: [
                // Logo and title
                Row(
                  children: [
                    const AppLogo(
                      width: KubusSpacing.xl + KubusSpacing.xs,
                      height: KubusSpacing.xl + KubusSpacing.xs,
                    ),
                    const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                    Text(
                      l10n.desktopMapTitleDiscover,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: KubusSpacing.xl + KubusSpacing.sm),

                // Search bar
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: CompositedTransformTarget(
                      link: _searchFieldLink,
                      child: KeyedSubtree(
                        key: _tutorialSearchKey,
                        child: DesktopSearchBar(
                          controller: _searchController,
                          hintText: l10n.mapSearchHint,
                          onChanged: _handleSearchChange,
                          onSubmitted: _handleSearchSubmit,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: KubusSpacing.md + KubusSpacing.xs),

                // Filter chips
                KeyedSubtree(
                  key: _tutorialFilterChipsKey,
                  child: Row(
                    children: _filterOptions.map((filter) {
                      final isActive = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(left: KubusSpacing.sm),
                        child: _buildGlassChip(
                          label: _getFilterLabel(filter),
                          isSelected: isActive,
                          themeProvider: themeProvider,
                          onTap: () {
                            setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),

                // Filters button
                KeyedSubtree(
                  key: _tutorialFiltersButtonKey,
                  child: _buildGlassIconButton(
                    icon: _showFiltersPanel ? Icons.close : Icons.tune,
                    themeProvider: themeProvider,
                    isActive: _showFiltersPanel,
                    tooltip: _showFiltersPanel ? l10n.commonClose : l10n.mapFiltersTitle,
                    // Filters sits on the top-right edge; prefer below so the
                    // tooltip never renders off-screen above the window.
                    tooltipPreferBelow: true,
                    tooltipVerticalOffset: 18,
                    // Anchor tooltip to the icon's right edge so the card expands
                    // leftwards (avoids the Nearby sidebar, and aligns the right edge
                    // of the tooltip with the icon).
                    tooltipAlignRightEdge: true,
                    tooltipMargin: const EdgeInsets.symmetric(horizontal: 24),
                    onTap: () {
                      setState(() {
                        _showFiltersPanel = !_showFiltersPanel;
                        _selectedArtwork = null;
                        _selectedExhibition = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final trimmedQuery = _searchQuery.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.22 : 0.26);
    if (!_isFetchingSearch &&
        _searchSuggestions.isEmpty &&
        trimmedQuery.length < 2) {
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
          child: LiquidGlassPanel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(12),
            blurSigma: KubusGlassEffects.blurSigmaLight,
            backgroundColor: glassTint,
            child: Builder(
              builder: (context) {
                if (trimmedQuery.length < 2) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.mapSearchMinCharsHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                          l10n.commonNoResultsFound,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        backgroundColor:
                            themeProvider.accentColor.withValues(alpha: 0.10),
                        child: Icon(
                          suggestion.icon,
                          color: themeProvider.accentColor,
                        ),
                      ),
                      title: Text(
                        suggestion.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: suggestion.subtitle == null
                          ? null
                          : Text(
                              suggestion.subtitle!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    );
  }

  Widget _buildArtworkDetailPanel(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final artworkProvider = context.watch<ArtworkProvider>();
    // Get the latest artwork from provider to ensure like/save states are updated
    final artwork = artworkProvider.getArtworkById(_selectedArtwork!.id) ?? _selectedArtwork!;
    final scheme = Theme.of(context).colorScheme;
    final accent = themeProvider.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: _activeMarker?.metadata ?? artwork.metadata,
    );
    final distanceLabel = _formatDistanceToArtwork(artwork);
    final fallbackIconColor = ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? KubusColors.textPrimaryDark.withValues(alpha: 0.78)
        : KubusColors.textPrimaryLight.withValues(alpha: 0.78);

    return LiquidGlassPanel(
      margin: const EdgeInsets.only(left: 24),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      blurSigma: KubusGlassEffects.blurSigmaLight,
      backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.20 : 0.14),
      showBorder: true,
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
                              accent,
                              accent.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: fallbackIconColor,
                            size: 40,
                          ),
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
                            accent,
                            accent.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: fallbackIconColor,
                          size: 40,
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scheme.shadow.withValues(alpha: 0.35),
                          scheme.shadow.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildGlassIconButton(
                      icon: Icons.close,
                      themeProvider: themeProvider,
                      iconColor: KubusColors.textPrimaryDark,
                      tooltip: AppLocalizations.of(context)!.commonClose,
                      onTap: () {
                        setState(() => _selectedArtwork = null);
                      },
                    ),
                  ),
                  if (artwork.arEnabled)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.view_in_ar,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)!.mapArReadyChipLabel,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ArtworkCreatorByline(
                    artwork: artwork,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  if (artwork.description.isNotEmpty) ...[
                    Text(
                      artwork.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.6,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
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
                      _buildDetailStat(
                          Icons.visibility, '${artwork.viewsCount}'),
                      if (artwork.discoveryCount > 0)
                        _buildDetailStat(
                          Icons.explore,
                          AppLocalizations.of(context)!
                              .desktopMapDiscoveriesCount(
                                  artwork.discoveryCount),
                        ),
                      if (artwork.actualRewards > 0)
                        _buildDetailStat(
                            Icons.token, '${artwork.actualRewards} KUB8'),
                      if (distanceLabel != null)
                        _buildDetailStat(Icons.location_on, distanceLabel),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (artwork.arEnabled)
                        SizedBox(
                          width: 170,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final modelUrl = artwork.model3DURL ??
                                  (artwork.model3DCID != null
                                      ? 'ipfs://${artwork.model3DCID}'
                                      : null);
                              if (modelUrl == null) {
                                final l10n = AppLocalizations.of(context)!;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(l10n.desktopMapNoArAssetToast),
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
                            label: Text(
                                AppLocalizations.of(context)!.commonViewInAr),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: AppColorUtils.contrastText(accent),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                      SizedBox(
                        width: 170,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            unawaited(openArtwork(context, artwork.id,
                                source: 'desktop_map'));
                          },
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: Text(
                              AppLocalizations.of(context)!.commonViewDetails),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            side: BorderSide(
                              color: accent.withValues(alpha: 0.75),
                              width: 1.2,
                            ),
                            foregroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 170,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            unawaited(artworkProvider.toggleFavorite(artwork.id));
                          },
                          icon: Icon(
                            artwork.isFavoriteByCurrentUser || artwork.isFavorite
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 18,
                          ),
                          label: Text(
                            (artwork.isFavoriteByCurrentUser || artwork.isFavorite)
                                ? AppLocalizations.of(context)!.commonSavedToast
                                : AppLocalizations.of(context)!.commonSave,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            side: BorderSide(
                              color: (artwork.isFavoriteByCurrentUser || artwork.isFavorite)
                                  ? accent
                                  : accent.withValues(alpha: 0.55),
                              width: (artwork.isFavoriteByCurrentUser || artwork.isFavorite) 
                                  ? 1.5 
                                  : 1.1,
                            ),
                            foregroundColor: (artwork.isFavoriteByCurrentUser || artwork.isFavorite)
                                ? accent
                                : scheme.onSurface,
                            backgroundColor: (artwork.isFavoriteByCurrentUser || artwork.isFavorite)
                                ? accent.withValues(alpha: 0.08)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      _buildGlassIconButton(
                        icon: artwork.isLikedByCurrentUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        themeProvider: themeProvider,
                        tooltip: '${artwork.likesCount} ${artwork.isLikedByCurrentUser
                            ? AppLocalizations.of(context)!.artworkDetailLiked
                            : AppLocalizations.of(context)!.artworkDetailLike}',
                        isActive: artwork.isLikedByCurrentUser,
                        activeTint: scheme.error.withValues(alpha: 0.18),
                        activeIconColor: scheme.error,
                        onTap: () {
                          unawaited(artworkProvider.toggleLike(artwork.id));
                        },
                      ),
                      _buildGlassIconButton(
                        icon: Icons.share,
                        themeProvider: themeProvider,
                        tooltip: AppLocalizations.of(context)!.commonShare,
                        onTap: () {
                          ShareService().showShareSheet(
                            context,
                            target: ShareTarget.artwork(
                              artworkId: artwork.id,
                              title: artwork.title,
                            ),
                            sourceScreen: 'desktop_map',
                          );
                        },
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
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.directions),
                    label:
                        Text(AppLocalizations.of(context)!.commonGetDirections),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: accent),
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildExhibitionDetailPanel(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final exhibition = _selectedExhibition!;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final exhibitionAccent = AppColorUtils.exhibitionColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackIconColor =
        ThemeData.estimateBrightnessForColor(exhibitionAccent) == Brightness.dark
            ? KubusColors.textPrimaryDark.withValues(alpha: 0.78)
            : KubusColors.textPrimaryLight.withValues(alpha: 0.78);

    // Format date range
    String? dateRange;
    if (exhibition.startsAt != null || exhibition.endsAt != null) {
      final start = exhibition.startsAt != null
          ? _formatExhibitionDate(exhibition.startsAt!)
          : null;
      final end = exhibition.endsAt != null
          ? _formatExhibitionDate(exhibition.endsAt!)
          : null;
      dateRange = [start, end].whereType<String>().join(' â€“ ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final location = (exhibition.locationName ?? '').trim().isNotEmpty
        ? exhibition.locationName!.trim()
        : null;
    final coverUrl = MediaUrlResolver.resolve(exhibition.coverUrl);

    return LiquidGlassPanel(
      margin: const EdgeInsets.only(left: 24),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      blurSigma: KubusGlassEffects.blurSigmaLight,
      backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.20 : 0.14),
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null && coverUrl.isNotEmpty)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              exhibitionAccent,
                              exhibitionAccent.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.museum,
                            color: fallbackIconColor,
                            size: 48,
                          ),
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
                            exhibitionAccent,
                            exhibitionAccent.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.museum,
                          color: fallbackIconColor,
                          size: 48,
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scheme.shadow.withValues(alpha: 0.35),
                          scheme.shadow.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildGlassIconButton(
                      icon: Icons.close,
                      themeProvider: themeProvider,
                      iconColor: KubusColors.textPrimaryDark,
                      tooltip: l10n.commonClose,
                      onTap: () {
                        setState(() => _selectedExhibition = null);
                      },
                    ),
                  ),
                  // Exhibition badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppColorUtils.exhibitionIcon,
                            size: 16,
                            color: exhibitionAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Exhibition',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: exhibitionAccent,
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
                    exhibition.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (exhibition.host != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Hosted by ${exhibition.host!.displayName ?? exhibition.host!.username ?? 'Unknown'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: exhibitionAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Info rows
                  if (dateRange != null)
                    _buildExhibitionInfoRow(Icons.schedule, dateRange, scheme),
                  if (location != null)
                    _buildExhibitionInfoRow(
                        Icons.place_outlined, location, scheme),
                  _buildExhibitionInfoRow(
                    Icons.event_available_outlined,
                    'Status: ${_labelForExhibitionStatus(exhibition.status)}',
                    scheme,
                  ),

                  if ((exhibition.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      exhibition.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.6,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final shellScope = DesktopShellScope.of(context);
                            if (shellScope != null) {
                              shellScope.pushScreen(
                                DesktopSubScreen(
                                  title: exhibition.title,
                                  child: ExhibitionDetailScreen(
                                      exhibitionId: exhibition.id),
                                ),
                              );
                            } else {
                              unawaited(Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExhibitionDetailScreen(
                                      exhibitionId: exhibition.id),
                                ),
                              ));
                            }
                          },
                          icon: Icon(AppColorUtils.exhibitionIcon, size: 20),
                          label: Text(l10n.commonViewDetails),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: exhibitionAccent,
                            foregroundColor:
                                ThemeData.estimateBrightnessForColor(exhibitionAccent) == Brightness.dark
                                    ? KubusColors.textPrimaryDark
                                    : KubusColors.textPrimaryLight,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (exhibition.lat != null && exhibition.lng != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=${exhibition.lat},${exhibition.lng}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.directions),
                      label: Text(l10n.commonGetDirections),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: exhibitionAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExhibitionInfoRow(
      IconData icon, String label, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  String _formatExhibitionDate(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _labelForExhibitionStatus(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return 'Unknown';
    if (v == 'published') return 'Published';
    if (v == 'draft') return 'Draft';
    return v;
  }

  Widget _buildFiltersPanel(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return LiquidGlassPanel(
      margin: const EdgeInsets.only(left: 24),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      blurSigma: KubusGlassEffects.blurSigmaLight,
      backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.20 : 0.14),
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.mapFiltersTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                _buildGlassIconButton(
                  icon: Icons.close,
                  themeProvider: themeProvider,
                  tooltip: l10n.commonClose,
                  onTap: () {
                    setState(() => _showFiltersPanel = false);
                  },
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: scheme.outline.withValues(alpha: 0.14),
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
                    l10n.mapNearbyRadiusTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                          max: 200,
                          divisions: 199,
                          onChanged: _travelModeEnabled
                              ? null
                              : (value) {
                                  setState(() => _searchRadius = value);
                                },
                          activeColor: themeProvider.accentColor,
                        ),
                      ),
                      LiquidGlassPanel(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        margin: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(10),
                        blurSigma: KubusGlassEffects.blurSigmaLight,
                        backgroundColor:
                            scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12),
                        showBorder: true,
                        child: Text(
                          l10n.commonDistanceKm(
                              _searchRadius.toInt().toString()),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Artwork types
                  Text(
                    l10n.desktopMapArtworkTypeTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                      _buildTypeFilterChip(
                        label: l10n.mapFilterAll,
                        filterKey: 'all',
                        themeProvider: themeProvider,
                      ),
                      _buildTypeFilterChip(
                        label: l10n.desktopMapArtworkTypeArArt,
                        filterKey: 'ar',
                        themeProvider: themeProvider,
                      ),
                      _buildTypeFilterChip(
                        label: l10n.desktopMapArtworkTypeNfts,
                        filterKey: 'nfts',
                        themeProvider: themeProvider,
                      ),
                      _buildTypeFilterChip(
                        label: l10n.desktopMapArtworkTypeModels3d,
                        filterKey: 'models3d',
                        themeProvider: themeProvider,
                      ),
                      _buildTypeFilterChip(
                        label: l10n.desktopMapArtworkTypeSculptures,
                        filterKey: 'sculptures',
                        themeProvider: themeProvider,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sort by
                  Text(
                    l10n.desktopMapSortByTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSortOption(
                    label: l10n.desktopMapSortDistance,
                    sortKey: 'distance',
                    icon: Icons.near_me,
                    themeProvider: themeProvider,
                  ),
                  _buildSortOption(
                    label: l10n.desktopMapSortPopularity,
                    sortKey: 'popularity',
                    icon: Icons.trending_up,
                    themeProvider: themeProvider,
                  ),
                  _buildSortOption(
                    label: l10n.desktopMapSortNewest,
                    sortKey: 'newest',
                    icon: Icons.schedule,
                    themeProvider: themeProvider,
                  ),
                  _buildSortOption(
                    label: l10n.desktopMapSortRating,
                    sortKey: 'rating',
                    icon: Icons.star,
                    themeProvider: themeProvider,
                  ),
                ],
              ),
            ),
          ),

          // Apply button
          Divider(
            height: 1,
            color: scheme.outline.withValues(alpha: 0.14),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _searchRadius = 5.0;
                        _selectedFilter = 'nearby';
                        _selectedSort = 'distance';
                      });
                      _loadMarkersForCurrentView(force: true);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.commonReset),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _showFiltersPanel = false);
                      _loadMarkersForCurrentView(force: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.accentColor,
                      foregroundColor:
                          ThemeData.estimateBrightnessForColor(themeProvider.accentColor) == Brightness.dark
                              ? KubusColors.textPrimaryDark
                              : KubusColors.textPrimaryLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.commonApply),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip({
    required String label,
    required String filterKey,
    required ThemeProvider themeProvider,
  }) {
    final isSelected = _selectedFilter == filterKey;
    return _buildGlassChip(
      label: label,
      isSelected: isSelected,
      themeProvider: themeProvider,
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
    );
  }

  Widget _buildSortOption({
    required String label,
    required String sortKey,
    required IconData icon,
    required ThemeProvider themeProvider,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = themeProvider.accentColor;
    final isSelected = _selectedSort == sortKey;

    final radius = BorderRadius.circular(12);
    final idleTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12);
    final selectedTint = accent.withValues(alpha: isDark ? 0.12 : 0.14);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: context.animationTheme.short,
        curve: context.animationTheme.defaultCurve,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.85)
                : scheme.outline.withValues(alpha: 0.18),
            width: isSelected ? 1.25 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: LiquidGlassPanel(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          borderRadius: radius,
          blurSigma: KubusGlassEffects.blurSigmaLight,
          showBorder: false,
          backgroundColor: isSelected ? selectedTint : idleTint,
          onTap: () {
            setState(() {
              _selectedSort = sortKey;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? accent
                      : scheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? accent : scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;

    final scheme = Theme.of(context).colorScheme;

    final accent = themeProvider.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: BorderRadius.circular(14),
      blurSigma: KubusGlassEffects.blurSigmaLight,
      backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.18 : 0.14),
      showBorder: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (AppConfig.isFeatureEnabled('mapTravelMode')) ...[
            KeyedSubtree(
              key: _tutorialTravelButtonKey,
              child: _buildGlassIconButton(
                icon: Icons.travel_explore,
                themeProvider: themeProvider,
                tooltip: l10n.mapTravelModeTooltip,
                isActive: _travelModeEnabled,
                onTap: () =>
                    unawaited(_setTravelModeEnabled(!_travelModeEnabled)),
              ),
            ),
            Container(
              width: 1,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: scheme.outline.withValues(alpha: 0.22),
            ),
          ],
          if (AppConfig.isFeatureEnabled('mapIsometricView')) ...[
            _buildGlassIconButton(
              icon: Icons.filter_tilt_shift,
              themeProvider: themeProvider,
              tooltip: _isometricViewEnabled
                  ? l10n.mapIsometricViewDisableTooltip
                  : l10n.mapIsometricViewEnableTooltip,
              isActive: _isometricViewEnabled,
              onTap: () =>
                  unawaited(_setIsometricViewEnabled(!_isometricViewEnabled)),
            ),
            Container(
              width: 1,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: scheme.outline.withValues(alpha: 0.22),
            ),
          ],
          // Nearby list (functions sidebar)
          KeyedSubtree(
            key: _tutorialNearbyButtonKey,
            child: IconButton(
              onPressed: _isNearbyPanelOpen
                  ? _closeNearbyArtPanel
                  : _openNearbyArtPanel,
              tooltip: _isNearbyPanelOpen
                  ? l10n.commonClose
                  : l10n.arNearbyArtworksTitle,
              icon: Icon(
                Icons.view_list,
                color: _isNearbyPanelOpen ? accent : scheme.onSurface,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: scheme.outline.withValues(alpha: 0.22),
          ),

          // Zoom - / +
          IconButton(
            onPressed: () {
              final nextZoom = (_effectiveZoom - 1).clamp(3.0, 18.0);
              _moveCamera(_effectiveCenter, nextZoom);
            },
            tooltip: l10n.mapEmptyZoomOutAction,
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            onPressed: () {
              final nextZoom = (_effectiveZoom + 1).clamp(3.0, 18.0);
              _moveCamera(_effectiveCenter, nextZoom);
            },
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add),
          ),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: scheme.outline.withValues(alpha: 0.22),
          ),

          // Create marker
          _buildGlassIconButton(
            icon: Icons.add_location_alt_outlined,
            themeProvider: themeProvider,
            tooltip: l10n.mapCreateMarkerHereTooltip,
            borderRadius: BorderRadius.circular(999),
            activeTint: accent.withValues(alpha: isDark ? 0.24 : 0.20),
            activeIconColor: AppColorUtils.contrastText(accent),
            isActive: true,
            onTap: () {
              final target = _pendingMarkerLocation ?? _effectiveCenter;
              _startMarkerCreationFlow(position: target);
            },
          ),
          const SizedBox(width: 6),

          // My location / follow
          _buildGlassIconButton(
            icon: Icons.my_location,
            themeProvider: themeProvider,
            tooltip: l10n.mapCenterOnMeTooltip,
            isActive: _autoFollow,
            activeIconColor: AppColorUtils.contrastText(accent),
            onTap: () {
              setState(() => _autoFollow = true);
              _refreshUserLocation(animate: true);
              if (_userLocation == null) {
                _moveCamera(const LatLng(46.0569, 14.5058), 15.0);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryCard(ThemeProvider themeProvider, TaskProvider taskProvider) {
    final l10n = AppLocalizations.of(context)!;
    final activeProgress = taskProvider.getActiveTaskProgress();
    if (activeProgress.isEmpty) return const SizedBox.shrink();

    final showTasks = _isDiscoveryExpanded;
    final tasksToRender = showTasks ? activeProgress : const <TaskProgress>[];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overall = taskProvider.getOverallProgress();
    final roles = KubusColorRoles.of(context);
    final badgeGradient = LinearGradient(
      colors: [
        roles.statTeal,
        roles.statAmber,
        roles.statCoral,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(18);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.40 : 0.52);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.16 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.all(16),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (rect) => badgeGradient.createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: InlineProgress(
                    progress: overall,
                    rows: 3,
                    cols: 5,
                    color: scheme.onSurface,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mapDiscoveryPathTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        l10n.commonPercentComplete((overall * 100).round()),
                        style: KubusTypography.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildGlassIconButton(
                  icon: _isDiscoveryExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  themeProvider: themeProvider,
                  tooltip: _isDiscoveryExpanded
                      ? l10n.commonCollapse
                      : l10n.commonExpand,
                  onTap: () => setState(
                      () => _isDiscoveryExpanded = !_isDiscoveryExpanded),
                ),
              ],
            ),
            AnimatedCrossFade(
              crossFadeState: showTasks
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
              firstChild: Column(
                children: [
                  const SizedBox(height: 12),
                  for (final progress in tasksToRender)
                    _buildTaskProgressRow(progress),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskProgressRow(TaskProgress progress) {
    final task = TaskService().getTaskById(progress.taskId);
    if (task == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final pct = progress.progressPercentage;
    final accent = CategoryAccentColor.resolve(context, task.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: Icon(task.icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: KubusTypography.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(pct * 100).round()}%',
            style: KubusTypography.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyArtSidebar(
      ThemeProvider themeProvider, List<Artwork> artworks) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = themeProvider.accentColor;

    final basePosition = _userLocation ?? _effectiveCenter;
    final sorted = List<Artwork>.of(artworks)
      ..sort((a, b) {
        final da = _calculateDistance(basePosition, a.position);
        final db = _calculateDistance(basePosition, b.position);
        return da.compareTo(db);
      });

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.arNearbyArtworksTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: _closeNearbyArtPanel,
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _travelModeEnabled
                  ? l10n.mapTravelModeStatusTravelling
                  : '${l10n.mapNearbyRadiusTitle}: ${_effectiveSearchRadiusKm.toStringAsFixed(1)} km',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      l10n.mapEmptyNoArtworksTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final artwork = sorted[index];
                      final cover =
                          ArtworkMediaResolver.resolveCover(artwork: artwork);
                      final meters =
                          _calculateDistance(basePosition, artwork.position);
                      final distanceText = _formatDistance(meters);

                      return LiquidGlassPanel(
                        padding: const EdgeInsets.all(10),
                        borderRadius: BorderRadius.circular(14),
                        showBorder: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              ArtMarker? marker;
                              for (final m in _artMarkers) {
                                if (m.artworkId == artwork.id) {
                                  marker = m;
                                  break;
                                }
                              }

                              _moveCamera(artwork.position,
                                  math.max(_effectiveZoom, 15.0));

                              if (marker != null) {
                                setState(() => _activeMarker = marker);
                              } else {
                                unawaited(_selectArtwork(
                                  artwork,
                                  focusPosition: artwork.position,
                                ));
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              SizedBox(
                                width: 88,
                                child: Stack(
                                  children: [
                                    _buildArtworkThumbnail(
                                      cover,
                                      width: 88,
                                      height: 66,
                                      borderRadius: 10,
                                      iconSize: 24,
                                    ),
                                    if (artwork.arMarkerId != null)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: accent,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.view_in_ar,
                                            size: 12,
                                            color: ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
                                                ? KubusColors.textPrimaryDark
                                                : KubusColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artwork.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      artwork.artist.isNotEmpty
                                          ? artwork.artist
                                          : l10n.commonUnknown,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                accent.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            distanceText,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${artwork.rewards} KUB8',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                  ),
          ),
        ],
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
          final shellScope = DesktopShellScope.of(context);
          if (shellScope != null) {
            shellScope.pushScreen(
              DesktopSubScreen(
                title: hydrated.title,
                child: DesktopArtworkDetailScreen(artworkId: hydrated.id),
              ),
            );
          } else {
            unawaited(openArtwork(context, hydrated.id, source: 'desktop_map_select'));
          }
        }
      }
    } catch (e) {
      AppConfig.debugPrint(
          'DesktopMapScreen: failed to select artwork $artworkId: $e');
    }
  }

  Future<Artwork?> _fetchArtworkDetails(String artworkId) async {
    try {
      final artworkProvider = context.read<ArtworkProvider>();
      await artworkProvider.fetchArtworkIfNeeded(artworkId);
      return artworkProvider.getArtworkById(artworkId);
    } catch (e) {
      AppConfig.debugPrint(
          'DesktopMapScreen: failed to hydrate artwork $artworkId: $e');
      return null;
    }
  }

  /// Calculate distance in meters between two points
  double _calculateDistance(LatLng from, LatLng to) {
    return _distance.as(LengthUnit.Meter, from, to);
  }

  /// Format distance in meters to human-readable string
  String _formatDistance(double meters, {bool includeAway = false}) {
    final l10n = AppLocalizations.of(context)!;
    if (meters < 1) return l10n.mapDistanceHere;
    final suffix = includeAway ? l10n.mapDistanceAwaySuffix : '';
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
    final map = Map<String, dynamic>.from(
        metaArt.map((key, value) => MapEntry(key.toString(), value)));
    map['id'] ??= marker.artworkId ??
        map['_id'] ??
        map['artworkId'] ??
        map['artwork_id'] ??
        '';
    map['title'] ??= marker.name;
    map['artist'] ??=
        map['artistName'] ?? map['artist'] ?? map['creator'] ?? '';
    map['description'] ??= marker.description;
    map['imageUrl'] ??= map['coverImage'] ??
        map['cover_image'] ??
        map['image'] ??
        map['coverUrl'] ??
        map['cover_url'];
    map['latitude'] ??= marker.position.latitude;
    map['longitude'] ??= marker.position.longitude;
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
      final shellScope = DesktopShellScope.of(context);
      if (shellScope != null) {
        shellScope.pushScreen(
          DesktopSubScreen(
            title: suggestion.subtitle ?? suggestion.label,
            child: UserProfileScreen(userId: suggestion.id!),
          ),
        );
      } else {
        unawaited(Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: suggestion.id!),
          ),
        ));
      }
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
        final radiusMeters = (_effectiveSearchRadiusKm * 1000).clamp(0, 500000);
        filtered = filtered
            .where(
              (artwork) => artwork.getDistanceFrom(basePosition) <= radiusMeters,
            )
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
      case 'nfts':
        filtered = filtered.where((artwork) {
          final category = artwork.category.toLowerCase();
          final tags = artwork.tags.map((t) => t.toLowerCase());
          final metaType = (artwork.metadata?['type'] ??
                  artwork.metadata?['assetType'] ??
                  artwork.metadata?['kind'])
              ?.toString()
              .toLowerCase();

          return category.contains('nft') ||
              category.contains('token') ||
              tags.any((t) => t.contains('nft') || t.contains('token')) ||
              (metaType?.contains('nft') ?? false);
        }).toList();
        break;
      case 'models3d':
        filtered = filtered.where((artwork) {
          final category = artwork.category.toLowerCase();
          final tags = artwork.tags.map((t) => t.toLowerCase());
          final has3dModel =
              artwork.model3DCID != null || artwork.model3DURL != null;

          return has3dModel ||
              category.contains('3d') ||
              category.contains('model') ||
              tags.any((t) => t.contains('3d') || t.contains('model'));
        }).toList();
        break;
      case 'sculptures':
        filtered = filtered.where((artwork) {
          final category = artwork.category.toLowerCase();
          final tags = artwork.tags.map((t) => t.toLowerCase());
          return category.contains('sculpt') ||
              tags.any((t) => t.contains('sculpt') || t.contains('statue'));
        }).toList();
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
        filtered.sort((a, b) =>
            a.getDistanceFrom(center).compareTo(b.getDistanceFrom(center)));
        break;
      case 'popularity':
        filtered.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case 'newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'rating':
        filtered.sort(
            (a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0));
        break;
      default:
        break;
    }
    return filtered;
  }

  Color _resolveArtMarkerColor(ArtMarker marker, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    // Delegate to centralized marker color utility for consistency with mobile
    return AppColorUtils.markerSubjectColor(
      markerType: marker.type.name,
      metadata: marker.metadata,
      scheme: scheme,
      roles: roles,
    );
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

  Future<void> _loadMarkersForCurrentView({bool force = false}) async {
    if (_travelModeEnabled && !_mapStyleReady) return;
    final center = _cameraCenter;
    GeoBounds? bounds;
    int? zoomBucket;

    if (_travelModeEnabled) {
      zoomBucket = MapViewportUtils.zoomBucket(_cameraZoom);
      final visible = await _getVisibleGeoBounds();
      if (visible == null) return;
      bounds = MapViewportUtils.expandBounds(
        visible,
        MapViewportUtils.paddingFractionForZoomBucket(zoomBucket),
      );
    }

    await _loadMarkers(
      center: center,
      bounds: bounds,
      force: force,
      zoomBucket: zoomBucket,
    );
  }

  Future<void> _loadMarkers({
    LatLng? center,
    GeoBounds? bounds,
    bool force = false,
    int? zoomBucket,
  }) async {
    final queryCenter = center ?? _userLocation ?? _effectiveCenter;
    final artworkProvider = context.read<ArtworkProvider>();
    final themeProvider = context.read<ThemeProvider>();

    int? bucket = zoomBucket;
    if (_travelModeEnabled && bucket == null) {
      bucket = MapViewportUtils.zoomBucket(_cameraZoom);
    }

    GeoBounds? queryBounds = bounds;
    if (_travelModeEnabled && queryBounds == null) {
      final visible = await _getVisibleGeoBounds();
      if (visible == null) return;
      final effectiveBucket = bucket ?? MapViewportUtils.zoomBucket(_cameraZoom);
      queryBounds = MapViewportUtils.expandBounds(
        visible,
        MapViewportUtils.paddingFractionForZoomBucket(effectiveBucket),
      );
      bucket = effectiveBucket;
    }

    final requestId = ++_markerRequestId;
    _isLoadingMarkers = true;

    try {
      final int? travelLimit = bucket == null
          ? null
          : MapViewportUtils.markerLimitForZoomBucket(bucket);

      final result = (_travelModeEnabled && queryBounds != null)
          ? await MapMarkerHelper.loadAndHydrateMarkersInBounds(
              artworkProvider: artworkProvider,
              mapMarkerService: _mapMarkerService,
              center: queryCenter,
              bounds: queryBounds,
              limit: travelLimit,
              forceRefresh: force,
              zoomBucket: bucket,
            )
          : await MapMarkerHelper.loadAndHydrateMarkers(
              artworkProvider: artworkProvider,
              mapMarkerService: _mapMarkerService,
              center: queryCenter,
              radiusKm: _effectiveSearchRadiusKm,
              limit: _travelModeEnabled ? travelLimit : null,
              forceRefresh: force,
              zoomBucket: bucket,
            );
      if (!mounted) return;
      if (requestId != _markerRequestId) return;

      final merged = ArtMarkerListDiff.mergeById(
        current: _artMarkers,
        next: result.markers,
      );

      final String? activeId = _activeMarker?.id;
      ArtMarker? resolvedActive;
      if (activeId != null && activeId.isNotEmpty) {
        for (final marker in merged) {
          if (marker.id == activeId) {
            resolvedActive = marker;
            break;
          }
        }
      }

      setState(() {
        _artMarkers = merged;
        if (activeId != null && activeId.isNotEmpty) {
          if (resolvedActive != null) {
            _activeMarker = resolvedActive;
          } else {
            _activeMarker = null;
            _markerOverlayExpanded = false;
            _activeMarkerAnchor = null;
          }
        }
      });
      unawaited(_syncMapMarkers(themeProvider: themeProvider));
      _queueOverlayAnchorRefresh();
      _lastMarkerFetchCenter = result.center;
      _lastMarkerFetchTime = result.fetchedAt;
      if (_travelModeEnabled && queryBounds != null && bucket != null) {
        _loadedTravelBounds = queryBounds;
        _loadedTravelZoomBucket = bucket;
      } else {
        _loadedTravelBounds = null;
        _loadedTravelZoomBucket = null;
      }
    } catch (e) {
      AppConfig.debugPrint('DesktopMapScreen: error loading markers: $e');
    } finally {
      if (requestId == _markerRequestId) {
        _isLoadingMarkers = false;
      }
    }
  }

  void _handleMarkerTap(
    ArtMarker marker, {
    _MarkerOverlayMode overlayMode = _MarkerOverlayMode.anchored,
  }) {
    // Desktop UX: do not re-center the map when a marker is clicked.
    setState(() {
      _activeMarker = marker;
      _markerOverlayMode = overlayMode;
      _markerOverlayExpanded = false; // Reset expand state for new marker
    });
    _maybeRecordPresenceVisitForMarker(marker);
    unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
    _queueOverlayAnchorRefresh();

    final primaryExhibition = marker.resolvedExhibitionSummary;
    final isExhibitionMarker = marker.isExhibitionMarker;

    if (isExhibitionMarker) {
      final exhibitionId = primaryExhibition?.id;
      final hasSelection =
          _selectedArtwork != null || _selectedExhibition != null;
      final alreadySelected =
          exhibitionId != null && _selectedExhibition?.id == exhibitionId;
      if (!hasSelection || alreadySelected) {
        unawaited(_openExhibitionFromMarker(marker, primaryExhibition, null));
      }
      return;
    }

    unawaited(_ensureLinkedArtworkLoaded(marker));
  }

  void _maybeRecordPresenceVisitForMarker(ArtMarker marker) {
    if (!AppConfig.isFeatureEnabled('presence')) return;
    if (!AppConfig.isFeatureEnabled('presenceLastVisitedLocation')) return;
    final visit = presenceVisitFromMarker(marker);
    if (visit == null) return;
    if (!shouldRecordPresenceVisitForMarker(
      marker: marker,
      userLocation: _userLocation,
      radiusMeters: kPresenceMarkerVisitRadiusMeters,
    )) {
      return;
    }

    try {
      context
          .read<PresenceProvider>()
          .recordVisit(type: visit.type, id: visit.id);
    } catch (_) {}
  }

  void _handleMarkerCreated(ArtMarker marker) {
    if (!marker.hasValidPosition) return;

    if (_travelModeEnabled) {
      final loadedBounds = _loadedTravelBounds;
      if (loadedBounds == null) return;
      if (!MapViewportUtils.containsPoint(loadedBounds, marker.position)) return;
    } else {
      final withinRadius =
          _distance.as(LengthUnit.Kilometer, _cameraCenter, marker.position) <=
              (_effectiveSearchRadiusKm + 0.5);
      if (!withinRadius) return;
    }

    setState(() {
      final existingIndex = _artMarkers.indexWhere((m) => m.id == marker.id);
      if (existingIndex >= 0) {
        _artMarkers[existingIndex] = marker;
      } else {
        _artMarkers = List<ArtMarker>.from(_artMarkers)..add(marker);
      }
    });
    unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
  }

  void _handleMarkerDeleted(String markerId) {
    try {
      setState(() {
        _artMarkers.removeWhere((m) => m.id == markerId);
      });
    } catch (_) {}
    unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
  }

  Widget _buildMarkerOverlayCard(
    ArtMarker marker,
    Artwork? artwork,
    ThemeProvider themeProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final baseColor = _resolveArtMarkerColor(marker, themeProvider);
    final primaryExhibition = marker.resolvedExhibitionSummary;
    final exhibitionsFeatureEnabled = AppConfig.isFeatureEnabled('exhibitions');
    final exhibitionsApiAvailable = BackendApiService().exhibitionsApiAvailable;
    final canPresentExhibition = exhibitionsFeatureEnabled &&
        primaryExhibition != null &&
        primaryExhibition.id.isNotEmpty &&
        exhibitionsApiAvailable != false;

    final exhibitionTitle = (primaryExhibition?.title ?? '').trim();
    final distanceText = _userLocation != null
        ? _formatDistance(_calculateDistance(_userLocation!, marker.position))
        : null;
    final imageUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: marker.metadata,
    );

    // Use exhibition title if available, then artwork title, then marker name
    final displayTitle = canPresentExhibition && exhibitionTitle.isNotEmpty
        ? exhibitionTitle
        : (artwork?.title.isNotEmpty == true ? artwork!.title : marker.name);
    final rawDescription = (marker.description.isNotEmpty
            ? marker.description
            : (artwork?.description ?? ''))
        .trim();

    // Expand/collapse logic for long descriptions (same as mobile)
    const int maxPreviewChars = 180;
    final bool canExpand = rawDescription.length > maxPreviewChars;
    final String visibleDescription = !canExpand
        ? rawDescription
        : (_markerOverlayExpanded
            ? rawDescription
            : '${rawDescription.substring(0, maxPreviewChars)}…');

    final showChips =
        _hasMetadataChips(marker, artwork) || canPresentExhibition;

    final artworkProvider = context.read<ArtworkProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: baseColor.withValues(alpha: 0.35),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LiquidGlassPanel(
              padding: const EdgeInsets.all(14),
              borderRadius: BorderRadius.circular(18),
              showBorder: false,
              backgroundColor: scheme.surface.withValues(alpha: 0.45),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        // Header row: Title + distance + close button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (canPresentExhibition) ...[
                                    Text(
                                      'Exhibition',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: baseColor,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (distanceText != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: baseColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.near_me, size: 12, color: baseColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      distanceText,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: baseColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            _markerOverlayIconButton(
                              icon: Icons.close,
                              tooltip: l10n.commonClose,
                              scheme: scheme,
                              isDark: isDark,
                              onTap: () {
                                setState(() {
                                  _activeMarker = null;
                                  _markerOverlayExpanded = false;
                                  _activeMarkerAnchor = null;
                                });
                                unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 120,
                            width: double.infinity,
                            child: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _markerImageFallback(baseColor, scheme, marker),
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: baseColor.withValues(alpha: 0.12),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      );
                                    },
                                  )
                                : _markerImageFallback(baseColor, scheme, marker),
                          ),
                        ),

                        // Description with expand/collapse
                        if (visibleDescription.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            visibleDescription,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],

                        // Expand/Collapse button for long descriptions
                        if (canExpand) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setState(
                                () => _markerOverlayExpanded = !_markerOverlayExpanded,
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _markerOverlayExpanded
                                    ? l10n.commonCollapse
                                    : l10n.commonExpand,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: baseColor,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Metadata chips
                        if (showChips) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (canPresentExhibition)
                                _attendanceProofChip(scheme, baseColor),
                              if (artwork != null &&
                                  artwork.category.isNotEmpty &&
                                  artwork.category != 'General')
                                _compactChip(
                                  scheme,
                                  Icons.palette,
                                  artwork.category,
                                  baseColor,
                                ),
                              if (marker.metadata?['subjectCategory'] != null ||
                                  marker.metadata?['subject_category'] != null)
                                _compactChip(
                                  scheme,
                                  Icons.category_outlined,
                                  (marker.metadata!['subjectCategory'] ??
                                          marker.metadata!['subject_category'])
                                      .toString(),
                                  baseColor,
                                ),
                              if (marker.metadata?['locationName'] != null ||
                                  marker.metadata?['location'] != null)
                                _compactChip(
                                  scheme,
                                  Icons.place_outlined,
                                  (marker.metadata!['locationName'] ??
                                          marker.metadata!['location'])
                                      .toString(),
                                  baseColor,
                                ),
                              if (artwork != null && artwork.rewards > 0)
                                _compactChip(
                                  scheme,
                                  Icons.card_giftcard,
                                  '+${artwork.rewards}',
                                  baseColor,
                                ),
                            ],
                          ),
                        ],

                        // Action row: Like, Save, Share buttons (for artworks)
                        if (artwork != null && !canPresentExhibition) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _markerOverlayActionButton(
                                icon: artwork.isLikedByCurrentUser
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                label: '${artwork.likesCount}',
                                isActive: artwork.isLikedByCurrentUser,
                                activeColor: scheme.error,
                                scheme: scheme,
                                isDark: isDark,
                                onTap: () {
                                  unawaited(artworkProvider.toggleLike(artwork.id));
                                },
                              ),
                              const SizedBox(width: 8),
                              _markerOverlayActionButton(
                                icon: artwork.isFavoriteByCurrentUser || artwork.isFavorite
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                label: l10n.commonSave,
                                isActive: artwork.isFavoriteByCurrentUser || artwork.isFavorite,
                                activeColor: baseColor,
                                scheme: scheme,
                                isDark: isDark,
                                onTap: () {
                                  unawaited(artworkProvider.toggleFavorite(artwork.id));
                                },
                              ),
                              const SizedBox(width: 8),
                              _markerOverlayActionButton(
                                icon: Icons.share_outlined,
                                label: l10n.commonShare,
                                isActive: false,
                                activeColor: baseColor,
                                scheme: scheme,
                                isDark: isDark,
                                onTap: () {
                                  ShareService().showShareSheet(
                                    context,
                                    target: ShareTarget.artwork(
                                      artworkId: artwork.id,
                                      title: artwork.title,
                                    ),
                                    sourceScreen: 'desktop_map_marker',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Primary action button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: baseColor,
                              foregroundColor: AppColorUtils.contrastText(baseColor),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onPressed: canPresentExhibition
                                ? () => _openExhibitionFromMarker(
                                    marker, primaryExhibition, artwork)
                                : () => _openMarkerDetail(marker, artwork),
                            icon: Icon(
                              canPresentExhibition
                                  ? Icons.museum_outlined
                                  : Icons.arrow_forward,
                              size: 18,
                            ),
                            label: Text(
                              canPresentExhibition
                                  ? 'Open Exhibition'
                                  : l10n.commonViewDetails,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
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

  Widget _buildMarkerOverlayLayer({
    required ThemeProvider themeProvider,
    required ArtworkProvider artworkProvider,
  }) {
    final marker = _activeMarker;
    if (marker == null) return const SizedBox.shrink();

    final artwork = marker.isExhibitionMarker
        ? null
        : artworkProvider.getArtworkById(marker.artworkId ?? '');

    final card = _buildMarkerOverlayCard(marker, artwork, themeProvider);

    if (_markerOverlayMode == _MarkerOverlayMode.centered) {
      return Positioned.fill(
        child: Align(
          alignment: Alignment.center,
          child: card,
        ),
      );
    }

    if (_activeMarkerAnchor == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: CompositedTransformFollower(
        link: _markerOverlayLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.center,
        followerAnchor: Alignment.bottomCenter,
        offset: const Offset(0, -10),
        child: card,
      ),
    );
  }

  /// Small icon button for marker overlay header
  Widget _markerOverlayIconButton({
    required IconData icon,
    required String tooltip,
    required ColorScheme scheme,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    final bg = scheme.surface.withValues(alpha: isDark ? 0.46 : 0.52);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: LiquidGlassPanel(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(999),
              showBorder: false,
              backgroundColor: bg,
              child: Center(
                child: Icon(icon, size: 16, color: scheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Action button for marker overlay (like, save, share)
  Widget _markerOverlayActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required ColorScheme scheme,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    final bg = isActive
        ? activeColor.withValues(alpha: isDark ? 0.24 : 0.18)
        : scheme.surface.withValues(alpha: isDark ? 0.34 : 0.42);
    final border = isActive
        ? activeColor.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.30);
    final fg = isActive ? activeColor : scheme.onSurfaceVariant;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: LiquidGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              margin: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(10),
              showBorder: false,
              backgroundColor: bg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _attendanceProofChip(ColorScheme scheme, Color baseColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: baseColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 12, color: baseColor),
          const SizedBox(width: 4),
          Text(
            'POAP',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: baseColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Check if marker has any metadata chips to display
  bool _hasMetadataChips(ArtMarker marker, Artwork? artwork) {
    return (artwork != null &&
            artwork.category.isNotEmpty &&
            artwork.category != 'General') ||
        marker.metadata?['subjectCategory'] != null ||
        marker.metadata?['subject_category'] != null ||
        marker.metadata?['subjectLabel'] != null ||
        marker.metadata?['subject_type'] != null ||
        marker.metadata?['locationName'] != null ||
        marker.metadata?['location'] != null ||
        (artwork != null && artwork.rewards > 0);
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
  Widget _buildArtworkThumbnail(
    String? imageUrl, {
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

  Widget _markerImageFallback(
      Color baseColor, ColorScheme scheme, ArtMarker marker) {
    // Determine the appropriate icon - use exhibition icon if marker has exhibitions
    final hasExhibitions =
        marker.isExhibitionMarker || marker.exhibitionSummaries.isNotEmpty;
    final icon = hasExhibitions
        ? AppColorUtils.exhibitionIcon
        : _resolveArtMarkerIcon(marker.type);

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
        icon,
        color: scheme.onPrimary,
        size: 42,
      ),
    );
  }

  Future<void> _openMarkerDetail(ArtMarker marker, Artwork? artwork) async {
    final resolvedArtwork =
        await _ensureLinkedArtworkLoaded(marker, initial: artwork);
    if (!mounted) return;

    if (resolvedArtwork == null) {
      await _showMarkerInfoFallback(marker);
      return;
    }

    // Open the left side panel with artwork details
    setState(() {
      _selectedArtwork = resolvedArtwork;
      _selectedExhibition = null;
      _showFiltersPanel = false;
    });
  }

  Future<void> _openExhibitionFromMarker(
    ArtMarker marker,
    ExhibitionSummaryDto? exhibition,
    Artwork? artwork,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final exhibitionsProvider = context.read<ExhibitionsProvider>();

    final resolved = exhibition ?? marker.resolvedExhibitionSummary;
    final isExhibitionMarker = marker.isExhibitionMarker;

    if (resolved == null || resolved.id.isEmpty) {
      if (isExhibitionMarker) {
        await _showMarkerInfoFallback(marker);
        return;
      }
      await _openMarkerDetail(marker, artwork);
      return;
    }

    if (!AppConfig.isFeatureEnabled('exhibitions') ||
        BackendApiService().exhibitionsApiAvailable == false) {
      if (isExhibitionMarker) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.mapExhibitionsUnavailableToast,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
        return;
      }
      await _openMarkerDetail(marker, artwork);
      return;
    }

    final fetched = await (() async {
      try {
        return await exhibitionsProvider.fetchExhibition(resolved.id,
            force: true);
      } catch (_) {
        return null;
      }
    })();

    if (!mounted) return;

    if (fetched == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.mapExhibitionsUnavailableToast,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Force rebuild so we can hide exhibition UI if the API just got marked unavailable.
      setState(() {});
      if (!isExhibitionMarker) {
        await _openMarkerDetail(marker, artwork);
      }
      return;
    }

    // Open the left side panel with exhibition details
    setState(() {
      _selectedExhibition = fetched;
      _selectedArtwork = null;
      _showFiltersPanel = false;
    });
  }

  Future<Artwork?> _ensureLinkedArtworkLoaded(ArtMarker marker,
      {Artwork? initial}) async {
    if (marker.isExhibitionMarker) return initial;
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
          AppConfig.debugPrint(
              'DesktopMapScreen: failed to fetch artwork $artworkId for marker ${marker.id}: $e');
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
          if (_selectedArtwork == null ||
              _selectedArtwork?.id == resolvedArtwork!.id) {
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

    await showKubusDialog<void>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          marker.name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  errorBuilder: (_, __, ___) => _markerImageFallback(
                      _resolveArtMarkerColor(
                          marker, context.read<ThemeProvider>()),
                      scheme,
                      marker),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              marker.description.isNotEmpty
                  ? marker.description
                  : AppLocalizations.of(context)!.mapNoLinkedArtworkForMarker,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context)!.commonClose),
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
      AppConfig.debugPrint('DesktopMapScreen: subject prefetch failed: $e');
    }
  }

  Future<void> _startMarkerCreationFlow({LatLng? position}) async {
    final targetPosition =
        position ?? _pendingMarkerLocation ?? _effectiveCenter;
    final subjectData = await _refreshMarkerSubjectData(force: true) ??
        _snapshotMarkerSubjectData();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final wallet = context.read<WalletProvider>().currentWalletAddress;
    if (wallet == null || wallet.isEmpty) {
      final bg = scheme.surfaceContainerHigh;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.mapMarkerCreateWalletRequired,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final allowedSubjectTypes = <MarkerSubjectType>{
      MarkerSubjectType.misc,
      if (subjectData.artworks.isNotEmpty) MarkerSubjectType.artwork,
      if (subjectData.exhibitions.isNotEmpty) MarkerSubjectType.exhibition,
      if (subjectData.institutions.isNotEmpty) MarkerSubjectType.institution,
      if (subjectData.events.isNotEmpty) MarkerSubjectType.event,
      if (subjectData.delegates.isNotEmpty) MarkerSubjectType.group,
    };

    final initialSubjectType = allowedSubjectTypes
            .contains(MarkerSubjectType.artwork)
        ? MarkerSubjectType.artwork
        : allowedSubjectTypes.contains(MarkerSubjectType.exhibition)
            ? MarkerSubjectType.exhibition
            : allowedSubjectTypes.contains(MarkerSubjectType.event)
                ? MarkerSubjectType.event
                : allowedSubjectTypes.contains(MarkerSubjectType.institution)
                    ? MarkerSubjectType.institution
                    : MarkerSubjectType.misc;

    final MapMarkerFormResult? result = await MapMarkerDialog.show(
      context: context,
      subjectData: subjectData,
      onRefreshSubjects: ({bool force = false}) =>
          _refreshMarkerSubjectData(force: force),
      initialPosition: targetPosition,
      allowManualPosition: true,
      mapCenter: _effectiveCenter,
      onUseMapCenter: () {
        final center = _effectiveCenter;
        setState(() => _pendingMarkerLocation = center);
      },
      initialSubjectType: initialSubjectType,
      allowedSubjectTypes: allowedSubjectTypes,
      blockedArtworkIds: _artMarkers
          .where((m) => (m.artworkId ?? '').isNotEmpty)
          .map((m) => m.artworkId!)
          .toSet(),
      useSheet: true,
    );

    if (!mounted || result == null) return;

    final selectedPosition = result.positionOverride ?? targetPosition;
    final success = await _createMarkerAtPosition(
      position: selectedPosition,
      form: result,
    );

    if (!mounted) return;

    if (success) {
      final bg = roles.positiveAction;
      final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
          ? KubusColors.textPrimaryDark
          : KubusColors.textPrimaryLight;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.mapMarkerCreatedToast,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ),
            ],
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadMarkersForCurrentView(force: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.mapMarkerCreateFailedToast,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onError,
                ),
          ),
          backgroundColor: scheme.error,
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
      final exhibitionsProvider = context.read<ExhibitionsProvider>();
      final markerManagementProvider = context.read<MarkerManagementProvider>();
      final currentZoom = _effectiveZoom;
      final gridCell = GridUtils.gridCellForZoom(position, currentZoom);
      final tileProviders = Provider.of<TileProviders?>(context, listen: false);
      final LatLng snappedPosition =
          tileProviders?.snapToVisibleGrid(position, currentZoom) ??
              gridCell.center;

      final resolvedCategory = form.category.isNotEmpty
          ? form.category
          : form.subject?.type.defaultCategory ??
              form.subjectType.defaultCategory;

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
        markerManagementProvider.ingestMarker(marker);
        if (form.subjectType == MarkerSubjectType.exhibition) {
          final exhibitionId = (form.subject?.id ?? '').trim();
          if (exhibitionId.isNotEmpty) {
            try {
              await exhibitionsProvider
                  .linkExhibitionMarkers(exhibitionId, [marker.id]);
            } catch (_) {
              // Non-fatal.
            }

            final linkedArtworkId = (form.linkedArtwork?.id ?? '').trim();
            if (linkedArtworkId.isNotEmpty) {
              try {
                await exhibitionsProvider
                    .linkExhibitionArtworks(exhibitionId, [linkedArtworkId]);
              } catch (_) {
                // Non-fatal.
              }
            }
          }
        }

        if (!mounted) return false;
        setState(() {
          _pendingMarkerLocation = null;
          _artMarkers.add(marker);
        });
        return true;
      }
      return false;
    } on StateError catch (e) {
      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.mapMarkerDuplicateToast,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onError,
                  ),
            ),
            backgroundColor: scheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      AppConfig.debugPrint('DesktopMapScreen: duplicate marker prevented: $e');
      return false;
    } catch (e) {
      AppConfig.debugPrint('DesktopMapScreen: error creating marker: $e');
      return false;
    }
  }

  String _getFilterLabel(String filter) {
    final l10n = AppLocalizations.of(context)!;
    switch (filter) {
      case 'all':
        return l10n.mapFilterAll;
      case 'nearby':
        return l10n.mapFilterNearby;
      case 'discovered':
        return l10n.mapFilterDiscovered;
      case 'undiscovered':
        return l10n.mapFilterUndiscovered;
      case 'ar':
        return l10n.commonArShort;
      case 'favorites':
        return l10n.mapFilterFavorites;
      default:
        return filter;
    }
  }
}

/// Desktop-only tooltip that anchors the tooltip card's RIGHT edge to the
/// target widget's right edge.
///
/// This prevents tooltips for right-edge controls (like Filters) from rendering
/// under the Nearby functions sidebar, because the bubble expands leftwards.
class _RightEdgeAlignedTooltip extends StatefulWidget {
  const _RightEdgeAlignedTooltip({
    required this.message,
    required this.child,
    this.preferBelow,
    this.verticalOffset,
    this.safePadding,
  });

  final String message;
  final Widget child;
  final bool? preferBelow;
  final double? verticalOffset;
  final EdgeInsets? safePadding;

  @override
  State<_RightEdgeAlignedTooltip> createState() => _RightEdgeAlignedTooltipState();
}

class _RightEdgeAlignedTooltipState extends State<_RightEdgeAlignedTooltip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _remove();
    super.dispose();
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  void _show() {
    if (_entry != null) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    final theme = Theme.of(context);
    final tooltipTheme = TooltipTheme.of(context);
    final preferBelow = widget.preferBelow ?? tooltipTheme.preferBelow ?? true;
    final verticalOffset =
        widget.verticalOffset ?? tooltipTheme.verticalOffset ?? 24.0;

    // Safe padding constrains tooltip width so it stays inside the visible
    // Explore surface. (Unlike Tooltip, we also anchor to the right edge.)
    final safe = widget.safePadding ?? const EdgeInsets.symmetric(horizontal: 24);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = math.max(0.0, screenWidth - safe.left - safe.right);
    // Keep desktop hover-tooltips compact so they don't feel like giant banners,
    // especially for top-right controls.
    const double tooltipWidthCap = 240;
    final cappedMaxWidth = math.min(maxWidth, tooltipWidthCap);

    final textStyle = tooltipTheme.textStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onInverseSurface,
        );

    final decoration = tooltipTheme.decoration ??
        BoxDecoration(
          color: theme.colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        );

    final padding = tooltipTheme.padding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    _entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor:
                  preferBelow ? Alignment.bottomRight : Alignment.topRight,
              followerAnchor:
                  preferBelow ? Alignment.topRight : Alignment.bottomRight,
              offset: Offset(
                0,
                preferBelow ? verticalOffset : -verticalOffset,
              ),
              // NOTE: Positioned.fill gives tight constraints. Without
              // UnconstrainedBox, the tooltip would expand to full-screen.
              child: UnconstrainedBox(
                alignment: preferBelow ? Alignment.topRight : Alignment.bottomRight,
                constrainedAxis: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // Tooltip expands to the LEFT from the target's right edge.
                    maxWidth: cappedMaxWidth,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: padding,
                      decoration: decoration,
                      child: Text(widget.message, style: textStyle),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);

    // Auto-hide to match native tooltip behavior.
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), _remove);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _remove(),
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onLongPress: _show,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ClusterBucket {
  _ClusterBucket(this.cell, this.markers);
  final GridCell cell;
  final List<ArtMarker> markers;
}
