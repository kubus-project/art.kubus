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
import 'package:pointer_interceptor/pointer_interceptor.dart';
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
import '../../widgets/map_marker_style_config.dart';
import '../../widgets/artwork_creator_byline.dart';
import '../../widgets/art_map_view.dart';
import '../../widgets/map_marker_dialog.dart';
import '../../widgets/map_overlay_blocker.dart';
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
import '../../utils/marker_cube_geometry.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/kubus_snackbar.dart';
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  ml.MapLibreMapController? _mapController;
  late AnimationController _animationController;
  late AnimationController _panelController;
  final MapMarkerService _mapMarkerService = MapMarkerService();

  Artwork? _selectedArtwork;
  Exhibition? _selectedExhibition;
  String? _selectedMarkerId;
  ArtMarker? _selectedMarkerData;
  DateTime? _selectedMarkerAt;
  String? _selectedMarkerViewportSignature;
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
  bool _pendingInitialNearbyPanelOpen = true;
  int _nearbyPanelAutoloadAttempts = 0;
  bool _nearbyPanelAutoloadScheduled = false;
  static const int _maxNearbyPanelAutoloadAttempts = 8;
  String? _nearbySidebarSignature;
  bool _nearbySidebarSyncScheduled = false;
  LatLng? _nearbySidebarAnchor;
  DateTime? _nearbySidebarLastSyncAt;
  static const Duration _nearbySidebarSyncCooldown =
      Duration(milliseconds: 250);
  final Distance _distance = const Distance();
  StreamSubscription<ArtMarker>? _markerStreamSub;
  StreamSubscription<String>? _markerDeletedSub;
  final Debouncer _markerRefreshDebouncer = Debouncer();
  bool _isAppForeground = true;
  bool _pendingMarkerRefresh = false;
  bool _pendingMarkerRefreshForce = false;
  LatLng _cameraCenter = const LatLng(46.0569, 14.5058);
  LatLng? _queuedCameraTarget;
  double? _queuedCameraZoom;
  LatLng? _lastMarkerFetchCenter;
  DateTime? _lastMarkerFetchTime;
  GeoBounds? _loadedTravelBounds;
  int? _loadedTravelZoomBucket;
  bool _programmaticCameraMove = false;
  double _lastBearing = 0.0;
  double _lastPitch = 0.0;
  DateTime _lastCameraUpdateTime = DateTime.now();
  static const Duration _cameraUpdateThrottle =
      Duration(milliseconds: 16); // ~60fps
  bool _styleInitialized = false;
  bool _styleInitializationInProgress = false;
  bool _hitboxLayerReady = false;
  int _styleEpoch = 0;
  int _hitboxLayerEpoch = -1;
  final Set<String> _registeredMapImages = <String>{};
  final LayerLink _markerOverlayLink = LayerLink();
  final Debouncer _overlayAnchorDebouncer = Debouncer();
  final Debouncer _cubeSyncDebouncer = Debouncer();
  Offset? _selectedMarkerAnchor;
  static const String _markerSourceId = 'kubus_markers';
  static const String _markerLayerId = 'kubus_marker_layer';
  static const String _markerHitboxLayerId = 'kubus_marker_hitbox_layer';
  static const String _cubeSourceId = 'kubus_marker_cubes';
  static const String _cubeBevelSourceId = 'kubus_marker_cubes_bevel';
  static const String _cubeLayerId = 'kubus_marker_cubes_layer';
  static const String _cubeBevelLayerId = 'kubus_marker_cubes_bevel_layer';
  static const String _cubeIconLayerId = 'kubus_marker_cubes_icon_layer';
  static const String _locationSourceId = 'kubus_user_location';
  static const String _locationLayerId = 'kubus_user_location_layer';
  static const String _pendingSourceId = 'kubus_pending_marker';
  static const String _pendingLayerId = 'kubus_pending_marker_layer';
  static const double _cubePitchThreshold = 5.0;
  bool _cubeLayerVisible = false;
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

  bool _isBuilding = false;
  bool _pendingSafeSetState = false;

  ml.MapLibreMapController? _featureTapBoundController;
  ml.MapLibreMapController? _featureHoverBoundController;
  DateTime? _lastFeatureTapAt;
  math.Point<double>? _lastFeatureTapPoint;
  String? _hoveredMarkerId;
  String? _pressedMarkerId;
  Timer? _pressedClearTimer;
  int _debugFeatureTapListenerCount = 0;
  int _debugFeatureHoverListenerCount = 0;
  int _debugMarkerTapCount = 0;

  late AnimationController _cubeIconSpinController;
  double _cubeIconSpinDegrees = 0.0;
  int _lastMarkerLayerStyleUpdateMs = 0;
  bool _markerLayerStyleUpdateInFlight = false;
  bool _markerLayerStyleUpdateQueued = false;

  // Filter options - same list as mobile for parity
  final List<String> _filterOptions = [
    'all',
    'nearby',
    'discovered',
    'undiscovered',
    'ar',
    'favorites'
  ];
  String _selectedSort = 'distance';

  // Marker type layer visibility - same as mobile for parity
  final Map<ArtMarkerType, bool> _markerLayerVisibility = {
    ArtMarkerType.artwork: true,
    ArtMarkerType.institution: true,
    ArtMarkerType.event: true,
    ArtMarkerType.residency: true,
    ArtMarkerType.drop: true,
    ArtMarkerType.experience: true,
    ArtMarkerType.other: true,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: MapMarkerStyleConfig.selectionPopDuration,
      vsync: this,
    );
    _animationController.addListener(_handleMarkerLayerAnimationTick);
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cubeIconSpinController = AnimationController(
      duration: MapMarkerStyleConfig.cubeIconSpinPeriod,
      vsync: this,
    )..addListener(_handleMarkerLayerAnimationTick);

    _autoFollow = widget.autoFollow;
    _cameraCenter = widget.initialCenter ?? const LatLng(46.0569, 14.5058);
    _cameraZoom = widget.initialZoom ?? _cameraZoom;

    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    final isWidgetTest = bindingName.contains('TestWidgetsFlutterBinding') ||
        bindingName.contains('AutomatedTestWidgetsFlutterBinding');
    if (isWidgetTest) {
      return;
    }

    _cubeIconSpinController.repeat();

    _markerStreamSub =
        _mapMarkerService.onMarkerCreated.listen(_handleMarkerCreated);
    _markerDeletedSub =
        _mapMarkerService.onMarkerDeleted.listen(_handleMarkerDeleted);

    unawaited(_loadMapTravelPrefs());
    unawaited(_loadMapIsometricPrefs());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load markers after the first layout. If travel mode is enabled we will
      // force a bounds refresh once the map reports ready.
      unawaited(_loadMarkersForCurrentView(force: true)
          .then((_) => _maybeOpenInitialMarker()));

      // Only animate camera to user location when we're not deep-linking to a target.
      // When initialCenter is provided (e.g. "Open on Map"), keep the camera focused on that target.
      final bool shouldAnimateToUser =
          widget.initialCenter == null && widget.autoFollow;
      _refreshUserLocation(animate: shouldAnimateToUser);
      _prefetchMarkerSubjects();

      // Desktop UX: show the nearby list in the functions sidebar (right panel)
      // instead of rendering a "nearby" card overlay on the map.
      _scheduleInitialNearbyArtPanelOpen();

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

    unawaited(
        _applyIsometricCamera(enabled: enabled, adjustZoomForScale: true));
  }

  Future<void> _maybeShowInteractiveMapTutorial() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen =
          prefs.getBool(PreferenceKeys.mapOnboardingDesktopSeenV2) ?? false;
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

  void _scheduleInitialNearbyArtPanelOpen() {
    _ensureNearbyPanelAutoloadScheduled();
  }

  void _ensureNearbyPanelAutoloadScheduled() {
    if (!_pendingInitialNearbyPanelOpen || _isNearbyPanelOpen) return;
    if (_nearbyPanelAutoloadScheduled) return;
    if (_nearbyPanelAutoloadAttempts > _maxNearbyPanelAutoloadAttempts) {
      _nearbyPanelAutoloadAttempts = 0;
    }
    _nearbyPanelAutoloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nearbyPanelAutoloadScheduled = false;
      if (!mounted) return;
      _tryOpenInitialNearbyArtPanel();
    });
  }

  void _tryOpenInitialNearbyArtPanel() {
    if (!_pendingInitialNearbyPanelOpen) return;
    if (_isNearbyPanelOpen) {
      _pendingInitialNearbyPanelOpen = false;
      return;
    }

    final shellScope = DesktopShellScope.of(context);
    if (shellScope == null) {
      _nearbyPanelAutoloadAttempts += 1;
      if (_nearbyPanelAutoloadAttempts <= _maxNearbyPanelAutoloadAttempts) {
        _ensureNearbyPanelAutoloadScheduled();
      }
      return;
    }

    _pendingInitialNearbyPanelOpen = false;
    _openNearbyArtPanel();
  }

  void _openNearbyArtPanel() {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope == null) return;

    _safeSetState(() {
      _isNearbyPanelOpen = true;
      _nearbySidebarSignature = null;
      _nearbySidebarSyncScheduled = false;
      _nearbySidebarAnchor = _userLocation ?? _effectiveCenter;
      _nearbySidebarLastSyncAt = null;
      _selectedArtwork = null;
      _selectedExhibition = null;
      _showFiltersPanel = false;
    });

    shellScope.openFunctionsPanel(DesktopFunctionsPanel.exploreNearby);
  }

  void _closeNearbyArtPanel() {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope == null) return;
    _safeSetState(() {
      _isNearbyPanelOpen = false;
      _nearbySidebarSyncScheduled = false;
      _nearbySidebarAnchor = null;
      _nearbySidebarLastSyncAt = null;
    });
    _nearbySidebarSignature = null;
    shellScope.closeFunctionsPanel();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (_isBuilding) {
      if (_pendingSafeSetState) return;
      _pendingSafeSetState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingSafeSetState = false;
        if (!mounted || _isBuilding) return;
        setState(fn);
      });
      return;
    }
    setState(fn);
  }

  Widget _wrapPointerInterceptor({
    required Widget child,
    bool enabled = true,
  }) {
    // On web, MapLibre is a platform view; PointerInterceptor prevents
    // pointer events from leaking through overlays to the map DOM element.
    if (!kIsWeb || !enabled) return child;
    return PointerInterceptor(child: child);
  }

  void _bindFeatureTapController(ml.MapLibreMapController controller) {
    if (_featureTapBoundController == controller) return;
    if (_featureTapBoundController != null) {
      _featureTapBoundController?.onFeatureTapped
          .remove(_handleMapFeatureTapped);
      if (kDebugMode) {
        _debugFeatureTapListenerCount =
            math.max(0, _debugFeatureTapListenerCount - 1);
      }
    }
    _featureTapBoundController = controller;
    controller.onFeatureTapped.add(_handleMapFeatureTapped);
    if (kDebugMode) {
      _debugFeatureTapListenerCount += 1;
    }
    _bindFeatureHoverController(controller);
  }

  void _bindFeatureHoverController(ml.MapLibreMapController controller) {
    if (!kIsWeb) return;
    if (_featureHoverBoundController == controller) return;
    if (_featureHoverBoundController != null) {
      _featureHoverBoundController?.onFeatureHover
          .remove(_handleMapFeatureHover);
      if (kDebugMode) {
        _debugFeatureHoverListenerCount =
            math.max(0, _debugFeatureHoverListenerCount - 1);
      }
    }
    _featureHoverBoundController = controller;
    controller.onFeatureHover.add(_handleMapFeatureHover);
    if (kDebugMode) {
      _debugFeatureHoverListenerCount += 1;
    }
  }

  void _handleMapFeatureTapped(
    math.Point<double> point,
    ml.LatLng coordinates,
    String id,
    String layerId,
    ml.Annotation? annotation,
  ) {
    if (!mounted) return;

    _lastFeatureTapAt = DateTime.now();
    _lastFeatureTapPoint = point;

    if (id.startsWith('cluster:')) {
      final nextZoom = math.min(_cameraZoom + 2.0, 18.0);
      unawaited(
        _moveCamera(
          LatLng(coordinates.latitude, coordinates.longitude),
          nextZoom,
        ),
      );
      return;
    }

    ArtMarker? selected;
    for (final marker in _artMarkers) {
      if (marker.id == id) {
        selected = marker;
        break;
      }
    }
    if (selected == null) return;

    _handleMarkerTap(selected);
  }

  void _handleMapFeatureHover(
    math.Point<double> point,
    ml.LatLng coordinates,
    String id,
    ml.Annotation? annotation,
    ml.HoverEventType eventType,
  ) {
    if (!mounted) return;
    if (!kIsWeb) return;
    if (id.startsWith('cluster:')) {
      if (_hoveredMarkerId != null) {
        _safeSetState(() => _hoveredMarkerId = null);
        _requestMarkerLayerStyleUpdate();
      }
      return;
    }

    final next = eventType == ml.HoverEventType.leave ? null : id;
    if (next == _hoveredMarkerId) return;
    _safeSetState(() => _hoveredMarkerId = next);
    _requestMarkerLayerStyleUpdate();
  }

  String _nearbySidebarSignatureFor(
    List<Artwork> filteredArtworks, {
    LatLng? basePosition,
  }) {
    final base = basePosition ?? _nearbySidebarAnchor ?? _userLocation;
    final ids = filteredArtworks.take(30).map((a) => a.id).toList()..sort();
    final modeSig = _travelModeEnabled
        ? 'travel'
        : _effectiveSearchRadiusKm.toStringAsFixed(1);
    final baseSig = base == null
        ? 'none'
        : '${base.latitude.toStringAsFixed(4)},${base.longitude.toStringAsFixed(4)}';
    return '$modeSig|$baseSig|${filteredArtworks.length}|${ids.join(',')}';
  }

  void _syncNearbySidebarIfNeeded(
    ThemeProvider themeProvider,
    List<Artwork> filteredArtworks, {
    LatLng? basePosition,
  }) {
    if (!_isNearbyPanelOpen) return;
    if (!mounted) return;
    final shellScope = DesktopShellScope.of(context);
    if (shellScope == null) return;

    // Build a compact signature so we only push sidebar updates when something
    // meaningful changes (avoids setState->build feedback loops).
    final sig = _nearbySidebarSignatureFor(
      filteredArtworks,
      basePosition: basePosition,
    );
    if (_nearbySidebarSignature == sig) return;
    _nearbySidebarSignature = sig;

    // NOTE: This method is now always called from a post-frame callback,
    // so we can directly update the shell content without another deferral.
    shellScope.setFunctionsPanelContent(
      KeyedSubtree(
        key: ValueKey<String>('nearby_sidebar_$sig'),
        child: _buildNearbyArtSidebar(themeProvider, filteredArtworks),
      ),
    );
  }

  Future<void> _maybeOpenInitialMarker() async {
    if (_didOpenInitialMarker) return;
    final markerId = widget.initialMarkerId?.trim() ?? '';
    if (markerId.isEmpty) return;

    _didOpenInitialMarker = true;

    final existing =
        _artMarkers.where((m) => m.id == markerId).toList(growable: false);
    if (existing.isNotEmpty) {
      _moveCamera(existing.first.position, math.max(_effectiveZoom, 15));
      _handleMarkerTap(existing.first,
          overlayMode: _MarkerOverlayMode.centered);
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

  bool get _pollingEnabled => _isAppForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state != AppLifecycleState.paused &&
        state != AppLifecycleState.inactive;
    if (_pollingEnabled) {
      _resumePolling();
    } else {
      _pausePolling();
    }
    super.didChangeAppLifecycleState(state);
  }

  void _pausePolling() {
    _markerRefreshDebouncer.cancel();
  }

  void _resumePolling() {
    _flushPendingMarkerRefresh();
  }

  void _queuePendingMarkerRefresh({bool force = false}) {
    _pendingMarkerRefresh = true;
    if (force) {
      _pendingMarkerRefreshForce = true;
    }
  }

  void _flushPendingMarkerRefresh() {
    if (!_pendingMarkerRefresh || !_pollingEnabled) return;
    final shouldForce = _pendingMarkerRefreshForce;
    _pendingMarkerRefresh = false;
    _pendingMarkerRefreshForce = false;
    unawaited(_loadMarkersForCurrentView(force: shouldForce));
  }

  void _handleMapCreated(ml.MapLibreMapController controller) {
    _mapController = controller;
    _bindFeatureTapController(controller);
    _styleInitialized = false;
    _hitboxLayerReady = false;
    _registeredMapImages.clear();
    AppConfig.debugPrint(
      'DesktopMapScreen: map created (platform=${defaultTargetPlatform.name}, web=$kIsWeb)',
    );
  }

  String _hexRgb(Color color) {
    return MapLibreStyleUtils.hexRgb(color);
  }

  double _markerPixelRatio() {
    if (kIsWeb) return 1.0;
    final dpr = WidgetsBinding
            .instance.platformDispatcher.implicitView?.devicePixelRatio ??
        1.0;
    return dpr.clamp(1.0, 2.5);
  }

  Future<void> _handleMapStyleLoaded(ThemeProvider themeProvider) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!mounted) return;
    if (_styleInitializationInProgress) return;

    final stopwatch = Stopwatch()..start();
    final scheme = Theme.of(context).colorScheme;
    _styleInitializationInProgress = true;
    _styleInitialized = false;
    _styleEpoch += 1;
    _hitboxLayerReady = false;
    _hitboxLayerEpoch = -1;
    _registeredMapImages.clear();

    AppConfig.debugPrint('DesktopMapScreen: style init start');

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
         _markerHitboxLayerId,
         _cubeLayerId,
         _cubeBevelLayerId,
         _cubeIconLayerId,
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
         _cubeSourceId,
         _cubeBevelSourceId,
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
      await controller.addGeoJsonSource(
        _cubeSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[]
        },
        promoteId: 'id',
      );
      await controller.addGeoJsonSource(
        _cubeBevelSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[]
        },
        promoteId: 'id',
      );

      // Layer order (bottom to top):
      // 1. Fill-extrusion (3D bevel base)
      // 2. Fill-extrusion (3D cube top)
      // 3. Marker symbol layer (2D icons)
      // 4. Cube icon layer (3D mode floating icons)
      // 5. Hitbox circle layer (TOPMOST for click detection)

      // 1. Fill-extrusion layer for 3D bevel base (bottom)
      await controller.addFillExtrusionLayer(
        _cubeBevelSourceId,
        _cubeBevelLayerId,
        ml.FillExtrusionLayerProperties(
          fillExtrusionColor: <Object>['get', 'color'],
          fillExtrusionHeight: <Object>['get', 'height'],
          fillExtrusionBase: 0.0,
          fillExtrusionOpacity: 0.88,
          fillExtrusionVerticalGradient: true,
          visibility: 'none',
        ),
      );

      // 2. Fill-extrusion layer for 3D cube top (above bevel)
      await controller.addFillExtrusionLayer(
        _cubeSourceId,
        _cubeLayerId,
        ml.FillExtrusionLayerProperties(
          fillExtrusionColor: <Object>['get', 'color'],
          fillExtrusionHeight: <Object>['get', 'height'],
          fillExtrusionBase: 0.0,
          fillExtrusionOpacity: 0.96,
          fillExtrusionVerticalGradient: true,
          visibility: 'none',
        ),
      );

      // 3. Main marker symbol layer for 2D icons
      await controller.addSymbolLayer(
        _markerSourceId,
        _markerLayerId,
        ml.SymbolLayerProperties(
          iconImage: <Object>['get', 'icon'],
          iconSize: MapMarkerStyleConfig.iconSizeExpression(),
          iconOpacity: <Object>[
            'case',
            <Object>[
              '==',
              <Object>['get', 'kind'],
              'cluster'
            ],
            1.0,
            1.0,
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          iconPitchAlignment: 'map',
          iconRotationAlignment: 'map',
        ),
      );

      // 4. Cube floating icon layer (above fill-extrusion, same icons as marker layer)
      await controller.addSymbolLayer(
        _markerSourceId,
        _cubeIconLayerId,
        ml.SymbolLayerProperties(
          iconImage: <Object>['get', 'icon'],
          iconSize: <Object>[
            '*',
            MapMarkerStyleConfig.iconSizeExpression(),
            0.92,
          ],
          iconOpacity: <Object>[
            'case',
            <Object>[
              '==',
              <Object>['get', 'kind'],
              'cluster'
            ],
            1.0,
            1.0,
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          iconPitchAlignment: 'viewport',
          iconRotationAlignment: 'viewport',
          iconOffset: MapMarkerStyleConfig.cubeFloatingIconOffsetEm,
          visibility: 'none',
        ),
      );

      // 5. Invisible hitbox layer (topmost) for consistent tap detection (2D + 3D)
      final Object hitboxRadius = kIsWeb
          ? 32.0
          : <Object>[
              'interpolate',
              <Object>['linear'],
              <Object>['zoom'],
              3,
              <Object>[
                'case',
                <Object>['==', <Object>['get', 'kind'], 'cluster'],
                18,
                14,
              ],
              12,
              <Object>[
                'case',
                <Object>['==', <Object>['get', 'kind'], 'cluster'],
                26,
                22,
              ],
              15,
              <Object>[
                'case',
                <Object>['==', <Object>['get', 'kind'], 'cluster'],
                32,
                28,
              ],
              24,
              <Object>[
                'case',
                <Object>['==', <Object>['get', 'kind'], 'cluster'],
                42,
                38,
              ],
            ];
      try {
        await controller.addCircleLayer(
          _markerSourceId,
          _markerHitboxLayerId,
          ml.CircleLayerProperties(
            circleColor: '#000000',
            circleOpacity: 0.0,
            circleStrokeOpacity: 0.0,
            circleRadius: hitboxRadius,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint('DesktopMapScreen: hitbox layer add failed: $e');
        }
        await controller.addCircleLayer(
          _markerSourceId,
          _markerHitboxLayerId,
          ml.CircleLayerProperties(
            circleColor: '#000000',
            circleOpacity: 0.0,
            circleStrokeOpacity: 0.0,
            circleRadius: kIsWeb ? 32 : 28,
          ),
        );
      }

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
      _styleInitialized = true;
      _hitboxLayerReady = true;
      _hitboxLayerEpoch = _styleEpoch;

      await _applyIsometricCamera(enabled: _isometricViewEnabled);
      await _syncUserLocation(themeProvider: themeProvider);
      await _syncPendingMarker(themeProvider: themeProvider);
      await _syncMapMarkers(themeProvider: themeProvider);
      await _updateMarkerRenderMode();
      _queueOverlayAnchorRefresh();

      stopwatch.stop();
      AppConfig.debugPrint(
        'DesktopMapScreen: style init done in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, st) {
      _styleInitialized = false;
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
    if (_selectedMarkerData == null) return;
    if (!_styleInitialized) return;
    _overlayAnchorDebouncer(const Duration(milliseconds: 16), () {
      unawaited(_refreshActiveMarkerAnchor());
    });
  }

  Future<void> _refreshActiveMarkerAnchor() async {
    final controller = _mapController;
    final marker = _selectedMarkerData;
    if (controller == null || marker == null) return;
    if (!_styleInitialized) return;
    if (_markerOverlayMode != _MarkerOverlayMode.anchored) return;

    try {
      final screen = await controller.toScreenLocation(
        ml.LatLng(marker.position.latitude, marker.position.longitude),
      );
      if (!mounted) return;
      setState(() {
        _selectedMarkerAnchor =
            Offset(screen.x.toDouble(), screen.y.toDouble());
      });
    } catch (_) {
      // Ignore anchor updates during style transitions.
    }
  }

  Future<bool> _canQueryMarkerHitbox({bool forceRefresh = false}) async {
    final controller = _mapController;
    if (controller == null) return false;
    if (!_styleInitialized) return false;
    if (!forceRefresh &&
        _hitboxLayerReady &&
        _hitboxLayerEpoch == _styleEpoch) {
      return true;
    }

    try {
      final raw = await controller.getLayerIds();
      for (final id in raw) {
        if (id == _markerHitboxLayerId) {
          _hitboxLayerReady = true;
          _hitboxLayerEpoch = _styleEpoch;
          return true;
        }
      }
    } catch (_) {
      // Ignore lookup failures; we'll fall back to manual picking.
    }
    _hitboxLayerReady = false;
    _hitboxLayerEpoch = -1;
    return false;
  }

  Future<void> _handleMapTap(
    math.Point<double> point, {
    required ThemeProvider themeProvider,
  }) async {
    final controller = _mapController;
    if (controller == null) return;
    final double? debugDpr =
        kDebugMode ? MediaQuery.of(context).devicePixelRatio : null;

    final lastAt = _lastFeatureTapAt;
    final lastPoint = _lastFeatureTapPoint;
    if (lastAt != null && lastPoint != null) {
      final ageMs = DateTime.now().difference(lastAt).inMilliseconds;
      if (ageMs >= 0 && ageMs < 60) {
        final dx = (point.x - lastPoint.x).abs();
        final dy = (point.y - lastPoint.y).abs();
        if (dx < 2 && dy < 2) return;
      }
    }

    // On web, taps that hit interactive style layers are delivered via
    // `controller.onFeatureTapped`. Treat `onMapClick` as a background tap and
    // avoid doing feature queries here.
    if (kIsWeb) {
      setState(() {
        _selectedArtwork = null;
        _selectedExhibition = null;
        _showFiltersPanel = false;
        _showSearchOverlay = false;
        _pendingMarkerLocation = null;
        _selectedMarkerId = null;
        _selectedMarkerData = null;
        _selectedMarkerAt = null;
        _selectedMarkerViewportSignature = null;
      });
      unawaited(_syncMapMarkers(themeProvider: themeProvider));
      unawaited(_syncPendingMarker(themeProvider: themeProvider));
      return;
    }

    if (_styleInitializationInProgress || !_styleInitialized) {
      final fallbackMarker = await _fallbackPickMarkerAtPoint(point);
      if (!mounted) return;
      if (fallbackMarker != null) {
        _handleMarkerTap(fallbackMarker);
      }
      return;
    }

    if (!await _canQueryMarkerHitbox(forceRefresh: true)) {
      final fallbackMarker = await _fallbackPickMarkerAtPoint(point);
      if (!mounted) return;
      if (fallbackMarker != null) {
        _handleMarkerTap(fallbackMarker);
      }
      return;
    }

    // Debug instrumentation (kDebugMode only)
    if (kDebugMode) {
      AppConfig.debugPrint(
        'DesktopMapScreen: tap at (${point.x.toStringAsFixed(1)}, ${point.y.toStringAsFixed(1)}) '
        'pitch=${_lastPitch.toStringAsFixed(1)} bearing=${_lastBearing.toStringAsFixed(1)} '
        'zoom=${_cameraZoom.toStringAsFixed(2)} dpr=$debugDpr 3D=$_is3DMarkerModeActive',
      );
    }

    try {
      // Query the hitbox layer for consistent tap detection (2D + 3D).
      final layerIds = <String>[_markerHitboxLayerId];

      // Use a small rect (point-like) so the hitbox layer controls the tap area.
      const double tapTolerance = 6.0;
      final rect = Rect.fromCenter(
        center: Offset(point.x, point.y),
        width: tapTolerance * 2,
        height: tapTolerance * 2,
      );
      final features = await controller.queryRenderedFeaturesInRect(
        rect,
        layerIds,
        null,
      );

      if (!mounted) return;

      if (kDebugMode && features.isNotEmpty) {
        final dynamic first = features.first;
        final propsRaw = first is Map ? first['properties'] : null;
        final Map props =
            propsRaw is Map ? propsRaw : const <String, dynamic>{};
        AppConfig.debugPrint(
          'DesktopMapScreen: queryRenderedFeaturesInRect hits=${features.length} '
          'first.markerId=${props['markerId'] ?? props['id']} kind=${props['kind']}',
        );
      }

      if (features.isEmpty) {
        if (kDebugMode) {
          AppConfig.debugPrint('DesktopMapScreen: no features in rect');
        }
        setState(() {
          _selectedArtwork = null;
          _selectedExhibition = null;
          _showFiltersPanel = false;
          _showSearchOverlay = false;
          _pendingMarkerLocation = null;
          _selectedMarkerId = null;
          _selectedMarkerData = null;
          _selectedMarkerAt = null;
          _selectedMarkerViewportSignature = null;
        });
        unawaited(_syncMapMarkers(themeProvider: themeProvider));
        unawaited(_syncPendingMarker(themeProvider: themeProvider));
        return;
      }

      final dynamic first = features.first;
      final propsRaw = first is Map ? first['properties'] : null;
      final Map props = propsRaw is Map ? propsRaw : const <String, dynamic>{};
      final kind = props['kind']?.toString();
      if (kDebugMode) {
        AppConfig.debugPrint(
          'DesktopMapScreen: tap query hits=${features.length} kind=${kind ?? 'marker'}',
        );
      }
      if (kind == 'cluster') {
        final lng = (props['lng'] as num?)?.toDouble();
        final lat = (props['lat'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        final nextZoom = math.min(_cameraZoom + 2.0, 18.0);
        if (kDebugMode) {
          AppConfig.debugPrint(
            'DesktopMapScreen: cluster tap → zoom=${nextZoom.toStringAsFixed(1)}',
          );
        }
        await _moveCamera(LatLng(lat, lng), nextZoom);
        return;
      }

      final markerId = (props['markerId'] ?? props['id'])?.toString() ?? '';
      if (markerId.isEmpty) return;
      if (kDebugMode) {
        AppConfig.debugPrint('DesktopMapScreen: marker tap id=$markerId');
      }
      ArtMarker? selected;
      for (final marker in _artMarkers) {
        if (marker.id == markerId) {
          selected = marker;
          break;
        }
      }
      if (selected == null) return;
      _handleMarkerTap(selected);
      _queueOverlayAnchorRefresh();
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint(
            'DesktopMapScreen: queryRenderedFeatures failed: $e');
      }
      _hitboxLayerReady = false;
      _hitboxLayerEpoch = -1;
      final fallbackMarker = await _fallbackPickMarkerAtPoint(point);
      if (!mounted) return;
      if (fallbackMarker == null) return;
      _handleMarkerTap(fallbackMarker);
    }
  }

  Future<ArtMarker?> _fallbackPickMarkerAtPoint(
    math.Point<double> point,
  ) async {
    final controller = _mapController;
    if (controller == null) return null;

    // Tight fallback radius to avoid oversized hitboxes.
    final zoomScale = (_cameraZoom / 15.0).clamp(0.7, 1.4);
    final double base = _is3DMarkerModeActive
      ? (kIsWeb ? 34.0 : 28.0)
      : (kIsWeb ? 28.0 : 22.0);
    final double maxDistance = base * zoomScale;
    ArtMarker? best;
    double bestDistance = maxDistance;

    final visibleMarkers = _artMarkers.where(
      (marker) => _markerLayerVisibility[marker.type] ?? true,
    );

    for (final marker in visibleMarkers) {
      try {
        final screen = await controller.toScreenLocation(
          ml.LatLng(marker.position.latitude, marker.position.longitude),
        );
        final dx = screen.x.toDouble() - point.x;
        final dy = screen.y.toDouble() - point.y;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance <= bestDistance) {
          bestDistance = distance;
          best = marker;
        }
      } catch (_) {
        // Ignore projection failures during style transitions.
      }
    }

    return best;
  }

  Future<void> _syncUserLocation({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;

    final pos = _userLocation;
    final data = (pos == null)
        ? const <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <dynamic>[]
          }
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

  Future<void> _syncPendingMarker(
      {required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;

    final pos = _pendingMarkerLocation;
    final data = (pos == null)
        ? const <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <dynamic>[]
          }
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
      buckets.putIfAbsent(
          cell.anchorKey, () => _ClusterBucket(cell, <ArtMarker>[]));
      buckets[cell.anchorKey]!.markers.add(marker);
    }

    return buckets.values.toList(growable: false);
  }

  Future<void> _syncMapMarkers({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;
    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final isDark = themeProvider.isDarkMode;

    final zoom = _cameraZoom;
    // Filter markers by position validity AND layer visibility (same as mobile)
    final visibleMarkers = _artMarkers
        .where((m) => m.hasValidPosition)
        .where((m) => _markerLayerVisibility[m.type] ?? true)
        .toList(growable: false);
    final useClustering = zoom < 12;

    // Pre-register all needed icons in parallel to avoid waterfall.
    await _preregisterMarkerIcons(
      markers: visibleMarkers,
      themeProvider: themeProvider,
      scheme: scheme,
      roles: roles,
      isDark: isDark,
      useClustering: useClustering,
      zoom: zoom,
    );
    if (!mounted) return;

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

    if (_is3DMarkerModeActive) {
      await _syncMarkerCubes(themeProvider: themeProvider);
    }
  }

  /// Pre-registers marker icons in batched parallel to avoid waterfall.
  Future<void> _preregisterMarkerIcons({
    required List<ArtMarker> markers,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    required bool useClustering,
    required double zoom,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    final toRender = <_IconRenderTask>[];

    if (useClustering) {
      final clusters = _clusterMarkers(markers, zoom);
      for (final cluster in clusters) {
        if (cluster.markers.length == 1) {
          final marker = cluster.markers.first;
          final selected = _selectedMarkerId == marker.id;
          final typeName = marker.type.name;
          final tier = marker.signalTier;
          final iconId =
              'mk_${typeName}_${tier.name}${selected ? '_sel' : ''}_${isDark ? 'd' : 'l'}';
          if (!_registeredMapImages.contains(iconId)) {
            toRender.add(_IconRenderTask(
              iconId: iconId,
              marker: marker,
              cluster: null,
              isCluster: false,
              selected: selected,
            ));
          }
        } else {
          final first = cluster.markers.first;
          final typeName = first.type.name;
          final label =
              cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
          final iconId = 'cl_${typeName}_${label}_${isDark ? 'd' : 'l'}';
          if (!_registeredMapImages.contains(iconId)) {
            toRender.add(_IconRenderTask(
              iconId: iconId,
              marker: null,
              cluster: cluster,
              isCluster: true,
              selected: false,
            ));
          }
        }
      }
    } else {
      for (final marker in markers) {
        final selected = _selectedMarkerId == marker.id;
        final typeName = marker.type.name;
        final tier = marker.signalTier;
        final iconId =
            'mk_${typeName}_${tier.name}${selected ? '_sel' : ''}_${isDark ? 'd' : 'l'}';
        if (!_registeredMapImages.contains(iconId)) {
          toRender.add(_IconRenderTask(
            iconId: iconId,
            marker: marker,
            cluster: null,
            isCluster: false,
            selected: selected,
          ));
        }
      }
    }

    if (toRender.isEmpty) return;

    final uniqueTasks = <String, _IconRenderTask>{};
    for (final task in toRender) {
      uniqueTasks.putIfAbsent(task.iconId, () => task);
    }

    const batchSize = 8;
    final tasks = uniqueTasks.values.toList();
    for (var i = 0; i < tasks.length; i += batchSize) {
      if (!mounted) return;
      final batch = tasks.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((task) async {
        if (_registeredMapImages.contains(task.iconId)) return;
        try {
          Uint8List bytes;
          if (task.isCluster && task.cluster != null) {
            final first = task.cluster!.markers.first;
            final baseColor = AppColorUtils.markerSubjectColor(
              markerType: first.type.name,
              metadata: first.metadata,
              scheme: scheme,
              roles: roles,
            );
            bytes = await ArtMarkerCubeIconRenderer.renderClusterPng(
              count: task.cluster!.markers.length,
              baseColor: baseColor,
              scheme: scheme,
              isDark: isDark,
              pixelRatio: _markerPixelRatio(),
            );
          } else if (task.marker != null) {
            final baseColor =
                _resolveArtMarkerColor(task.marker!, themeProvider);
            bytes = await ArtMarkerCubeIconRenderer.renderMarkerPng(
              baseColor: baseColor,
              icon: _resolveArtMarkerIcon(task.marker!.type),
              tier: task.marker!.signalTier,
              scheme: scheme,
              roles: roles,
              isDark: isDark,
              forceGlow: task.selected,
              pixelRatio: _markerPixelRatio(),
            );
          } else {
            return;
          }
          if (!mounted) return;
          await controller.addImage(task.iconId, bytes);
          _registeredMapImages.add(task.iconId);
        } catch (e) {
          if (kDebugMode) {
            AppConfig.debugPrint(
                'DesktopMapScreen: preregister icon failed (${task.iconId}): $e');
          }
        }
      }));
    }
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

    final selected = _selectedMarkerId == marker.id;
    final typeName = marker.type.name;
    final tier = marker.signalTier;
    final iconId =
        'mk_${typeName}_${tier.name}${selected ? '_sel' : ''}_${isDark ? 'd' : 'l'}';

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
        pixelRatio: _markerPixelRatio(),
      );
      if (!mounted) return const <String, dynamic>{};
      try {
        await controller.addImage(iconId, bytes);
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint(
              'DesktopMapScreen: addImage failed ($iconId): $e');
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
        'coordinates': <double>[
          marker.position.longitude,
          marker.position.latitude
        ],
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
    final label =
        cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
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
        pixelRatio: _markerPixelRatio(),
      );
      if (!mounted) return const <String, dynamic>{};
      try {
        await controller.addImage(iconId, bytes);
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint(
              'DesktopMapScreen: addImage failed ($iconId): $e');
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
        'renderMode': 'cluster',
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
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh();
      return;
    }
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

  Future<void> _applyIsometricCamera(
      {required bool enabled, bool adjustZoomForScale = false}) async {
    final controller = _mapController;
    if (controller == null) return;

    final shouldEnable =
        enabled && AppConfig.isFeatureEnabled('mapIsometricView');
    final targetPitch = shouldEnable ? 54.736 : 0.0;
    final targetBearing =
        shouldEnable ? (_lastBearing.abs() < 1.0 ? 18.0 : _lastBearing) : 0.0;

    double targetZoom = _cameraZoom;
    if (adjustZoomForScale) {
      const scale = 1.2;
      final delta = math.log(scale) / math.ln2;
      targetZoom = shouldEnable ? (_cameraZoom + delta) : (_cameraZoom - delta);
      targetZoom = targetZoom.clamp(3.0, 24.0).toDouble();
      _cameraZoom = targetZoom;
    }

    _programmaticCameraMove = true;
    try {
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
    } catch (e, st) {
      AppConfig.debugPrint('DesktopMapScreen: animateCamera failed: $e');
      if (kDebugMode) {
        AppConfig.debugPrint('DesktopMapScreen: animateCamera stack: $st');
      }
    }
    if (!mounted) return;
    unawaited(_updateMarkerRenderMode());
  }

  /// Reset map bearing to 0 (north up) while preserving zoom and pitch.
  Future<void> _resetBearing() async {
    final controller = _mapController;
    if (!_mapReady || controller == null) return;

    // Skip if already pointing north
    if (_lastBearing.abs() < 0.5) return;

    _programmaticCameraMove = true;
    try {
      await controller.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: ml.LatLng(_cameraCenter.latitude, _cameraCenter.longitude),
            zoom: _cameraZoom,
            bearing: 0.0,
            tilt: _isometricViewEnabled &&
                    AppConfig.isFeatureEnabled('mapIsometricView')
                ? 54.736
                : 0.0,
          ),
        ),
        duration: const Duration(milliseconds: 320),
      );
    } catch (e, st) {
      AppConfig.debugPrint('DesktopMapScreen: _resetBearing failed: $e');
      if (kDebugMode) {
        AppConfig.debugPrint('DesktopMapScreen: _resetBearing stack: $st');
      }
    }
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
    try {
      await controller.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: ml.LatLng(target.latitude, target.longitude),
            zoom: zoom,
            bearing: _lastBearing,
            tilt: _isometricViewEnabled &&
                    AppConfig.isFeatureEnabled('mapIsometricView')
                ? 54.736
                : 0.0,
          ),
        ),
        duration: const Duration(milliseconds: 320),
      );
    } catch (e, st) {
      AppConfig.debugPrint(
          'DesktopMapScreen: _moveCamera animateCamera failed: $e');
      if (kDebugMode) {
        AppConfig.debugPrint(
            'DesktopMapScreen: _moveCamera animateCamera stack: $st');
      }
    }
  }

  Future<void> _moveCameraWithOffset(
    LatLng target, {
    required Offset offset,
    double? zoom,
    Duration duration = const Duration(milliseconds: 320),
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    final double targetZoom = zoom ?? _cameraZoom;
    ml.LatLng resolvedTarget = ml.LatLng(target.latitude, target.longitude);
    if (offset != Offset.zero) {
      try {
        final screen = await controller.toScreenLocation(resolvedTarget);
        final shifted = math.Point<double>(
          screen.x.toDouble() + offset.dx,
          screen.y.toDouble() + offset.dy,
        );
        resolvedTarget = await controller.toLatLng(shifted);
      } catch (_) {
        // Best-effort: if projection fails, fall back to the original target.
      }
    }

    _programmaticCameraMove = true;
    try {
      await controller.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: resolvedTarget,
            zoom: targetZoom,
            bearing: _lastBearing,
            tilt: _isometricViewEnabled &&
                    AppConfig.isFeatureEnabled('mapIsometricView')
                ? 54.736
                : 0.0,
          ),
        ),
        duration: duration,
      );
    } catch (e, st) {
      AppConfig.debugPrint(
          'DesktopMapScreen: _moveCameraWithOffset animateCamera failed: $e');
      if (kDebugMode) {
        AppConfig.debugPrint(
            'DesktopMapScreen: _moveCameraWithOffset stack: $st');
      }
    }
  }

  void _scheduleEnsureMarkerOverlayInView({
    required ArtMarker marker,
    required double overlayHeight,
  }) {
    final screen = MediaQuery.of(context);
    final topSafe = screen.padding.top + 12;
    final size = screen.size;

    // Push marker down so the card can sit above it.
    final double desiredDy = math.min(
      size.height * 0.22,
      (overlayHeight / 2) + 24 + topSafe,
    );

    final signature =
        '${marker.id}|${overlayHeight.round()}|${_cameraZoom.toStringAsFixed(2)}|${_lastBearing.toStringAsFixed(3)}|${desiredDy.round()}';
    if (signature == _selectedMarkerViewportSignature) return;
    _selectedMarkerViewportSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedMarkerId != marker.id) return;
      final targetZoom = math.max(_cameraZoom, 15.0);
      unawaited(_moveCameraWithOffset(
        marker.position,
        offset: Offset(0, desiredDy),
        zoom: targetZoom,
      ));
    });
  }

  @override
  void dispose() {
    // Avoid leaving Explore-side panels open when navigating away.
    try {
      DesktopShellScope.of(context)?.closeFunctionsPanel();
    } catch (_) {}

    final controller = _mapController;
    _mapController = null;
    controller?.onFeatureTapped.remove(_handleMapFeatureTapped);
    controller?.onFeatureHover.remove(_handleMapFeatureHover);
    if (_featureTapBoundController == controller) {
      if (kDebugMode) {
        _debugFeatureTapListenerCount =
            math.max(0, _debugFeatureTapListenerCount - 1);
      }
      _featureTapBoundController = null;
    }
    if (_featureHoverBoundController == controller) {
      if (kDebugMode) {
        _debugFeatureHoverListenerCount =
            math.max(0, _debugFeatureHoverListenerCount - 1);
      }
      _featureHoverBoundController = null;
    }
    _styleInitialized = false;
    _registeredMapImages.clear();
    _pressedClearTimer?.cancel();
    _pressedClearTimer = null;
    _animationController.dispose();
    _cubeIconSpinController.dispose();
    _panelController.dispose();
    _searchDebounce?.cancel();
    _markerRefreshDebouncer.dispose();
    _overlayAnchorDebouncer.dispose();
    _cubeSyncDebouncer.dispose();
    _markerStreamSub?.cancel();
    _markerDeletedSub?.cancel();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isBuilding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isBuilding = false;
    });
    _ensureNearbyPanelAutoloadScheduled();
    assert(_assertMarkerModeInvariant());
    assert(_assertMarkerRenderModeInvariant());
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Map layer
          AbsorbPointer(
            absorbing: _showMapTutorial,
            child: KeyedSubtree(
              key: _tutorialMapKey,
              child: _buildMapLayer(themeProvider),
            ),
          ),

          // Top bar - absorb pointer events to prevent map interaction
          _buildTopBar(themeProvider, animationTheme),

          // Search suggestions overlay - absorb pointer events
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
            child: MapOverlayBlocker(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // absorb taps
                child: _selectedExhibition != null
                    ? Semantics(
                        label: 'left_info_panel',
                        container: true,
                        child: _buildExhibitionDetailPanel(
                          themeProvider,
                          animationTheme,
                        ),
                      )
                    : _selectedArtwork != null
                        ? Semantics(
                            label: 'left_info_panel',
                            container: true,
                            child: _buildArtworkDetailPanel(
                              themeProvider,
                              animationTheme,
                            ),
                          )
                        : _buildFiltersPanel(themeProvider),
              ),
            ),
          ),

          // Map controls (bottom-right) - absorb pointer events
          Positioned(
            left: _selectedArtwork != null || _selectedExhibition != null
                ? 400
                : 24,
            right: 24,
            bottom: 24,
            child: Align(
              alignment: Alignment.bottomRight,
              child: MapOverlayBlocker(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // absorb taps
                  child: _buildMapControls(themeProvider),
                ),
              ),
            ),
          ),

          // Discovery path card (bottom-left when no panel is open)
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              final activeProgress = taskProvider.getActiveTaskProgress();
              if (activeProgress.isEmpty) return const SizedBox.shrink();
              final leftOffset = (_selectedArtwork != null ||
                      _selectedExhibition != null ||
                      _showFiltersPanel)
                  ? 400.0
                  : 24.0;
              return Positioned(
                left: leftOffset,
                bottom: 24,
                child: MapOverlayBlocker(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // absorb taps
                    child: _buildDiscoveryCard(themeProvider, taskProvider),
                  ),
                ),
              );
            },
          ),

          if (_showMapTutorial)
            Positioned.fill(
              child: _wrapPointerInterceptor(
                child: const ModalBarrier(
                  dismissible: false,
                  color: Colors.transparent,
                ),
              ),
            ),

          if (_showMapTutorial)
            Positioned.fill(
              child: _wrapPointerInterceptor(
                child: Builder(
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapLayer(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final nearbyBasePosition =
            _nearbySidebarAnchor ?? _userLocation ?? _effectiveCenter;
        final filteredArtworks = _getFilteredArtworks(
          artworkProvider.artworks,
          basePositionOverride: nearbyBasePosition,
        );

        // FIX: Move sidebar sync out of the build phase to avoid infinite
        // recursion. The shell's setFunctionsPanelContent triggers setState,
        // which rebuilds this Consumer, which was calling _syncNearbySidebarIfNeeded
        // again, creating a loop when the signature changed.
        if (_isNearbyPanelOpen) {
          final sig = _nearbySidebarSignatureFor(
            filteredArtworks,
            basePosition: nearbyBasePosition,
          );
          if (sig != _nearbySidebarSignature && !_nearbySidebarSyncScheduled) {
            final now = DateTime.now();
            if (_nearbySidebarLastSyncAt != null &&
                now.difference(_nearbySidebarLastSyncAt!) <
                    _nearbySidebarSyncCooldown) {
              // Cooldown active: skip scheduling, but keep map layer built.
              // Returning an empty widget here can cause platform view
              // layout churn and map freezes on web.
              // Intentionally do nothing.
            }
            _nearbySidebarLastSyncAt = now;
            _nearbySidebarSyncScheduled = true;
            // Schedule the sync AFTER the current build completes.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _nearbySidebarSyncScheduled = false;
              if (!mounted) return;
              _syncNearbySidebarIfNeeded(
                themeProvider,
                filteredArtworks,
                basePosition: nearbyBasePosition,
              );
            });
          }
        }

        final isDark = themeProvider.isDarkMode;
        final tileProviders =
            Provider.of<TileProviders?>(context, listen: false);
        final styleAsset = tileProviders?.mapStyleAsset(isDarkMode: isDark) ??
            MapStyleService.primaryStyleRef(isDarkMode: isDark);

        final map = MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: ArtMapView(
            initialCenter: _effectiveCenter,
            initialZoom: _cameraZoom,
            minZoom: 3.0,
            maxZoom: 24.0,
            isDarkMode: isDark,
            styleAsset: styleAsset,
            onMapCreated: _handleMapCreated,
            onStyleLoaded: () {
              AppConfig.debugPrint(
                'DesktopMapScreen: onStyleLoadedCallback (dark=$isDark, style="$styleAsset")',
              );
              unawaited(_handleMapStyleLoaded(themeProvider)
                  .then((_) => _handleMapReady()));
            },
            onCameraMove: (position) {
              _cameraCenter =
                  LatLng(position.target.latitude, position.target.longitude);
              _cameraZoom = position.zoom;
              _lastBearing = position.bearing;
              _lastPitch = position.tilt;
              final shouldShowCubes = _is3DMarkerModeActive;
              if (shouldShowCubes != _cubeLayerVisible) {
                unawaited(_updateMarkerRenderMode());
              }

              final bucket = MapViewportUtils.zoomBucket(position.zoom);
              final bucketChanged = bucket != _renderZoomBucket;
              // Throttle setState for 3D overlay repaints to ~60fps max
              final now = DateTime.now();
              final shouldUpdate = _isometricViewEnabled &&
                  now.difference(_lastCameraUpdateTime) > _cameraUpdateThrottle;
              if (bucketChanged || shouldUpdate) {
                _lastCameraUpdateTime = now;
                _safeSetState(() => _renderZoomBucket = bucket);
              }
              if (bucketChanged && _is3DMarkerModeActive) {
                _cubeSyncDebouncer(const Duration(milliseconds: 60), () {
                  unawaited(_syncMarkerCubes(themeProvider: themeProvider));
                });
              }

              final hasGesture = !_programmaticCameraMove;
              if (hasGesture && _autoFollow) {
                _safeSetState(() => _autoFollow = false);
              }
              if (hasGesture && _selectedMarkerId != null) {
                _safeSetState(() {
                  _selectedMarkerId = null;
                  _selectedMarkerData = null;
                  _selectedMarkerAt = null;
                });
                unawaited(_syncMapMarkers(themeProvider: themeProvider));
              }

              _queueMarkerRefresh(fromGesture: hasGesture);
              _queueOverlayAnchorRefresh();
            },
            onCameraIdle: () {
              _programmaticCameraMove = false;
              unawaited(_updateMarkerRenderMode());
              _queueMarkerRefresh(fromGesture: false);
              _queueOverlayAnchorRefresh();
            },
            onMapClick: (point, _) {
              unawaited(_handleMapTap(point, themeProvider: themeProvider));
            },
            onMapLongClick: (_, point) {
              setState(() {
                _pendingMarkerLocation = point;
                _selectedMarkerId = null;
                _selectedMarkerData = null;
                _selectedMarkerAt = null;
                _selectedMarkerAnchor = null;
              });
              unawaited(_syncPendingMarker(themeProvider: themeProvider));
              _startMarkerCreationFlow(position: point);
            },
          ),
        );

        // Capture anchor value to avoid race condition between null check and access.
        final markerAnchor = _selectedMarkerAnchor;
        // Use StackFit.expand to ensure bounded constraints for Positioned.fill
        // children (especially the marker overlay layer).
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: map),
            if (_markerOverlayMode == _MarkerOverlayMode.anchored &&
                markerAnchor != null)
              Positioned(
                left: markerAnchor.dx,
                top: markerAnchor.dy,
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
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
    final selectedTint =
        activeTint ?? accent.withValues(alpha: isDark ? 0.14 : 0.16);

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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
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
              : Tooltip(
                  message: tooltip,
                  margin: tooltipMargin,
                  preferBelow: tooltipPreferBelow,
                  verticalOffset: tooltipVerticalOffset ?? 0,
                  child: child,
                ),
        ),
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
      child: MapOverlayBlocker(
        cursor: SystemMouseCursors.basic,
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
                        const SizedBox(
                            width: KubusSpacing.sm + KubusSpacing.xs),
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
                            child: Semantics(
                              label: 'map_search_input',
                              textField: true,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.text,
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
                            padding:
                                const EdgeInsets.only(left: KubusSpacing.sm),
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
                        tooltip: _showFiltersPanel
                            ? l10n.commonClose
                            : l10n.mapFiltersTitle,
                        // Filters sits on the top-right edge; prefer below so the
                        // tooltip never renders off-screen above the window.
                        tooltipPreferBelow: true,
                        tooltipVerticalOffset: 18,
                        // Anchor tooltip to the icon's right edge so the card expands
                        // leftwards (avoids the Nearby sidebar, and aligns the right edge
                        // of the tooltip with the icon).
                        tooltipAlignRightEdge: true,
                        tooltipMargin:
                            const EdgeInsets.symmetric(horizontal: 24),
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
            )
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
      child: MapOverlayBlocker(
        cursor: SystemMouseCursors.basic,
        child: Stack(
          children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showSearchOverlay = false),
                  child: const SizedBox.expand(),
                ),
              ),
              CompositedTransformFollower(
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.6),
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
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.4),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.commonNoResultsFound,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.6),
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
                                backgroundColor: themeProvider.accentColor
                                    .withValues(alpha: 0.10),
                                child: Icon(
                                  suggestion.icon,
                                  color: themeProvider.accentColor,
                                ),
                              ),
                              title: Text(
                                suggestion.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: suggestion.subtitle == null
                                  ? null
                                  : Text(
                                      suggestion.subtitle!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.6),
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
            ],
          ),
        ),
    );
  }

  Widget _buildArtworkDetailPanel(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final artworkProvider = context.watch<ArtworkProvider>();
    // Guard against null to prevent race condition between check and access.
    final selectedArtwork = _selectedArtwork;
    if (selectedArtwork == null) {
      return const SizedBox.shrink();
    }
    // Get the latest artwork from provider to ensure like/save states are updated
    final artwork =
        artworkProvider.getArtworkById(selectedArtwork.id) ?? selectedArtwork;
    final scheme = Theme.of(context).colorScheme;
    final accent = themeProvider.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: _selectedMarkerData?.metadata ?? artwork.metadata,
    );
    final distanceLabel = _formatDistanceToArtwork(artwork);
    final fallbackIconColor =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
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
                          color: scheme.surface
                              .withValues(alpha: isDark ? 0.88 : 0.92),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
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
                      if (artwork.arEnabled &&
                          AppConfig.isFeatureEnabled('ar') &&
                          !kIsWeb)
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
                                messenger.showKubusSnackBar(
                                  SnackBar(
                                    content:
                                        Text(l10n.desktopMapNoArAssetToast),
                                  ),
                                  tone: KubusSnackBarTone.warning,
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
                              foregroundColor:
                                  AppColorUtils.contrastText(accent),
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
                            unawaited(
                                artworkProvider.toggleFavorite(artwork.id));
                          },
                          icon: Icon(
                            artwork.isFavoriteByCurrentUser ||
                                    artwork.isFavorite
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 18,
                          ),
                          label: Text(
                            (artwork.isFavoriteByCurrentUser ||
                                    artwork.isFavorite)
                                ? AppLocalizations.of(context)!.commonSavedToast
                                : AppLocalizations.of(context)!.commonSave,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            side: BorderSide(
                              color: (artwork.isFavoriteByCurrentUser ||
                                      artwork.isFavorite)
                                  ? accent
                                  : accent.withValues(alpha: 0.55),
                              width: (artwork.isFavoriteByCurrentUser ||
                                      artwork.isFavorite)
                                  ? 1.5
                                  : 1.1,
                            ),
                            foregroundColor: (artwork.isFavoriteByCurrentUser ||
                                    artwork.isFavorite)
                                ? accent
                                : scheme.onSurface,
                            backgroundColor: (artwork.isFavoriteByCurrentUser ||
                                    artwork.isFavorite)
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
                        tooltip:
                            '${artwork.likesCount} ${artwork.isLikedByCurrentUser ? AppLocalizations.of(context)!.artworkDetailLiked : AppLocalizations.of(context)!.artworkDetailLike}',
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
    // Guard against null to prevent race condition between check and access.
    final exhibition = _selectedExhibition;
    if (exhibition == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final exhibitionAccent = AppColorUtils.exhibitionColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackIconColor =
        ThemeData.estimateBrightnessForColor(exhibitionAccent) ==
                Brightness.dark
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
                        color: scheme.surface
                            .withValues(alpha: isDark ? 0.88 : 0.92),
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
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
                                ThemeData.estimateBrightnessForColor(
                                            exhibitionAccent) ==
                                        Brightness.dark
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 13, color: scheme.onSurface),
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

    // Wrap filters panel in a Listener to absorb pointer events and prevent them
    // from passing through to the map underneath (gesture conflict resolution).
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {},
        onPointerMove: (_) {},
        onPointerUp: (_) {},
        onPointerSignal: (_) {}, // Absorb mouse wheel / trackpad scroll
        child: LiquidGlassPanel(
          margin: const EdgeInsets.only(left: 24),
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(20),
          blurSigma: KubusGlassEffects.blurSigmaLight,
          backgroundColor:
              scheme.surface.withValues(alpha: isDark ? 0.20 : 0.14),
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
                            backgroundColor: scheme.surface
                                .withValues(alpha: isDark ? 0.16 : 0.12),
                            showBorder: true,
                            child: Text(
                              l10n.commonDistanceKm(
                                  _searchRadius.toInt().toString()),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Marker type layers (matches mobile's "Layers" section)
                      Text(
                        l10n.mapLayersTitle,
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
                        children: ArtMarkerType.values.map((type) {
                          final selected = _markerLayerVisibility[type] ?? true;
                          final roles = KubusColorRoles.of(context);
                          final layerAccent = AppColorUtils.markerSubjectColor(
                            markerType: type.name,
                            metadata: null,
                            scheme: scheme,
                            roles: roles,
                          );
                          return _buildLayerChip(
                            label: _markerTypeLabel(l10n, type),
                            icon: _resolveArtMarkerIcon(type),
                            selected: selected,
                            accent: layerAccent,
                            themeProvider: themeProvider,
                            onTap: () => setState(
                                () => _markerLayerVisibility[type] = !selected),
                          );
                        }).toList(),
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
                            // Reset layer visibility to all visible
                            for (final type in ArtMarkerType.values) {
                              _markerLayerVisibility[type] = true;
                            }
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
                          foregroundColor: ThemeData.estimateBrightnessForColor(
                                      themeProvider.accentColor) ==
                                  Brightness.dark
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
        ),
      ),
    );
  }

  /// Layer chip with icon and accent color - matches mobile's _glassChip style
  Widget _buildLayerChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color accent,
    required ThemeProvider themeProvider,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.24 : 0.18)
        : scheme.surface.withValues(alpha: isDark ? 0.34 : 0.42);
    final border = selected
        ? accent.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.30);
    final fg = selected ? accent : scheme.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: LiquidGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(999),
              showBorder: false,
              backgroundColor: bg,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: KubusTypography.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
          ),
        ),
      ),
    )
  );
  }

  /// Returns human-readable label for marker type - same as mobile
  String _markerTypeLabel(AppLocalizations l10n, ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return l10n.mapMarkerTypeArtworks;
      case ArtMarkerType.institution:
        return l10n.mapMarkerTypeInstitutions;
      case ArtMarkerType.event:
        return l10n.mapMarkerTypeEvents;
      case ArtMarkerType.residency:
        return l10n.mapMarkerTypeResidencies;
      case ArtMarkerType.drop:
        return l10n.mapMarkerTypeDrops;
      case ArtMarkerType.experience:
        return l10n.mapMarkerTypeExperiences;
      case ArtMarkerType.other:
        return l10n.mapMarkerTypeMisc;
    }
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

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: LiquidGlassPanel(
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
            Semantics(
              label: 'map_zoom_out',
              button: true,
              child: _buildGlassIconButton(
                icon: Icons.remove,
                themeProvider: themeProvider,
                tooltip: l10n.mapEmptyZoomOutAction,
                onTap: () {
                  final nextZoom = (_effectiveZoom - 1).clamp(3.0, 18.0);
                  _moveCamera(_effectiveCenter, nextZoom);
                },
              ),
            ),
            Semantics(
              label: 'map_zoom_in',
              button: true,
              child: _buildGlassIconButton(
                icon: Icons.add,
                themeProvider: themeProvider,
                tooltip: 'Zoom in',
                onTap: () {
                  final nextZoom = (_effectiveZoom + 1).clamp(3.0, 18.0);
                  _moveCamera(_effectiveCenter, nextZoom);
                },
              ),
            ),
            // Point north / reset bearing button (visible when map is rotated)
            if (_lastBearing.abs() > 1.0) ...[
              Container(
                width: 1,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: scheme.outline.withValues(alpha: 0.22),
              ),
              IconButton(
                onPressed: () => unawaited(_resetBearing()),
                tooltip: l10n.mapResetBearingTooltip,
                icon: const Icon(Icons.explore),
              ),
            ],
            Container(
              width: 1,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: scheme.outline.withValues(alpha: 0.22),
            ),

            // Create marker - use squared corners to match mobile
            Semantics(
              label: 'map_create_marker',
              button: true,
              child: _buildGlassIconButton(
                icon: Icons.add_location_alt_outlined,
                themeProvider: themeProvider,
                tooltip: l10n.mapCreateMarkerHereTooltip,
                // Use default borderRadius (12) for squared look like mobile
                activeTint: accent.withValues(alpha: isDark ? 0.24 : 0.20),
                activeIconColor: AppColorUtils.contrastText(accent),
                isActive: true,
                onTap: () {
                  final target = _pendingMarkerLocation ?? _effectiveCenter;
                  _startMarkerCreationFlow(position: target);
                },
              ),
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
      ),
    );
  }

  Widget _buildDiscoveryCard(
      ThemeProvider themeProvider, TaskProvider taskProvider) {
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

    return Semantics(
      label: 'discovery_path',
      container: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            borderRadius: radius,
            border:
                Border.all(color: scheme.outlineVariant.withValues(alpha: 0.30)),
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
                      backgroundColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mapDiscoveryPathTitle,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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

    final basePosition =
        _nearbySidebarAnchor ?? _userLocation ?? _effectiveCenter;
    final sorted = List<Artwork>.of(artworks)
      ..sort((a, b) {
        final da = _calculateDistance(basePosition, a.position);
        final db = _calculateDistance(basePosition, b.position);
        return da.compareTo(db);
      });

    // Wrap sidebar in a Listener to absorb pointer events and prevent them
    // from passing through to the map underneath (gesture conflict resolution).
    // This ensures scrolling/interacting with the sidebar doesn't pan the map.
    return _wrapPointerInterceptor(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {},
          onPointerMove: (_) {},
          onPointerUp: (_) {},
          onPointerSignal: (_) {}, // Absorb mouse wheel / trackpad scroll
          child: SafeArea(
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 13,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.65),
                                ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: sorted.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final artwork = sorted[index];
                            final cover = ArtworkMediaResolver.resolveCover(
                                artwork: artwork);
                            final meters = _calculateDistance(
                                basePosition, artwork.position);
                            final distanceText = _formatDistance(meters);

                            // Find marker for this artwork to get subject-based color
                            ArtMarker? marker;
                            for (final m in _artMarkers) {
                              if (m.artworkId == artwork.id) {
                                marker = m;
                                break;
                              }
                            }
                            // Use marker color if available, otherwise fallback to artwork type
                            final cardAccent = marker != null
                                ? _resolveArtMarkerColor(marker, themeProvider)
                                : AppColorUtils.markerSubjectColor(
                                    markerType: 'artwork',
                                    metadata: null,
                                    scheme: scheme,
                                    roles: KubusColorRoles.of(context),
                                  );

                            return LiquidGlassPanel(
                              padding: const EdgeInsets.all(10),
                              borderRadius: BorderRadius.circular(14),
                              showBorder: true,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _moveCamera(artwork.position,
                                        math.max(_effectiveZoom, 15.0));

                                    if (marker != null) {
                                      _handleMarkerTap(
                                        marker,
                                        overlayMode:
                                            _MarkerOverlayMode.centered,
                                      );
                                    } else {
                                      unawaited(_selectArtwork(
                                        artwork,
                                        focusPosition: artwork.position,
                                      ));
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: cardAccent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Icon(
                                                    Icons.view_in_ar,
                                                    size: 12,
                                                    color: ThemeData
                                                                .estimateBrightnessForColor(
                                                                    cardAccent) ==
                                                            Brightness.dark
                                                        ? KubusColors
                                                            .textPrimaryDark
                                                        : KubusColors
                                                            .textPrimaryLight,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              artwork.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
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
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontSize: 12,
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        cardAccent.withValues(
                                                            alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: Text(
                                                    distanceText,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: cardAccent,
                                                        ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  '${artwork.rewards} KUB8',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: scheme
                                                            .onSurfaceVariant,
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
          ),
        ),
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
            unawaited(openArtwork(context, hydrated.id,
                source: 'desktop_map_select'));
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
    final metaRaw = map['metadata'];
    final Map<String, dynamic> meta = metaRaw is Map
        ? Map<String, dynamic>.from(
            metaRaw.map((key, value) => MapEntry(key.toString(), value)),
          )
        : <String, dynamic>{};
    map['metadata'] = {
      ...meta,
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

  List<Artwork> _getFilteredArtworks(
    List<Artwork> artworks, {
    LatLng? basePositionOverride,
  }) {
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

    final basePosition = basePositionOverride ?? _userLocation;
    switch (_selectedFilter) {
      case 'nearby':
        if (basePosition != null) {
          final radiusMeters =
              (_effectiveSearchRadiusKm * 1000).clamp(0, 500000);
          filtered = filtered
              .where(
                (artwork) =>
                    artwork.getDistanceFrom(basePosition) <= radiusMeters,
              )
              .toList();
        }
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
        if (center != null) {
          filtered.sort((a, b) =>
              a.getDistanceFrom(center).compareTo(b.getDistanceFrom(center)));
        }
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

  bool _markersEquivalent(List<ArtMarker> current, List<ArtMarker> next) {
    if (identical(current, next)) return true;
    if (current.length != next.length) return false;
    final byId = <String, ArtMarker>{
      for (final marker in current) marker.id: marker,
    };
    if (byId.length != current.length) return false;
    for (final marker in next) {
      final existing = byId[marker.id];
      if (existing == null) return false;
      if (existing.type != marker.type) return false;
      if (existing.artworkId != marker.artworkId) return false;
      if (existing.position.latitude != marker.position.latitude) return false;
      if (existing.position.longitude != marker.position.longitude) {
        return false;
      }
    }
    return true;
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
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh(force: force);
      return;
    }
    if (_travelModeEnabled && !_styleInitialized) return;
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
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh(force: force);
      return;
    }

    if (_isLoadingMarkers) {
      _queuePendingMarkerRefresh(force: force);
      return;
    }

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
      final effectiveBucket =
          bucket ?? MapViewportUtils.zoomBucket(_cameraZoom);
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

      final markersChanged = !_markersEquivalent(_artMarkers, merged);

      final String? selectedIdBeforeSetState = _selectedMarkerId;
      ArtMarker? resolvedSelected;
      if (selectedIdBeforeSetState != null &&
          selectedIdBeforeSetState.isNotEmpty) {
        for (final marker in merged) {
          if (marker.id == selectedIdBeforeSetState) {
            resolvedSelected = marker;
            break;
          }
        }
      }

      if (markersChanged ||
          (resolvedSelected != null &&
              _selectedMarkerId == resolvedSelected.id &&
              _selectedMarkerData != resolvedSelected)) {
        setState(() {
          if (markersChanged) {
            _artMarkers = merged;
          }
          final stillSelectedId = _selectedMarkerId;
          if (stillSelectedId == null || stillSelectedId.isEmpty) return;
          if (stillSelectedId != selectedIdBeforeSetState) return;

          if (resolvedSelected != null) {
            _selectedMarkerData = resolvedSelected;
            _selectedMarkerAnchor = null;
            return;
          }

          _selectedMarkerId = null;
          _selectedMarkerData = null;
          _selectedMarkerAt = null;
          _selectedMarkerAnchor = null;
        });
        if (markersChanged) {
          unawaited(_syncMapMarkers(themeProvider: themeProvider));
        }
      }
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
      // Schedule flush for next frame to avoid tight retry loop on repeated errors.
      if (_pendingMarkerRefresh && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _flushPendingMarkerRefresh();
        });
      }
    }
  }

  void _handleMarkerTap(
    ArtMarker marker, {
    _MarkerOverlayMode overlayMode = _MarkerOverlayMode.anchored,
  }) {
    // Guard against rapid repeated taps on the same marker
    if (_selectedMarkerId == marker.id && _selectedMarkerAt != null) {
      final elapsed = DateTime.now().difference(_selectedMarkerAt!);
      if (elapsed.inMilliseconds < 300) return;
    }
    if (kDebugMode) {
      _debugMarkerTapCount += 1;
      if (_debugMarkerTapCount % 30 == 0) {
        AppConfig.debugPrint(
          'DesktopMapScreen: marker taps=$_debugMarkerTapCount '
          'featureTapListeners=$_debugFeatureTapListenerCount '
          'featureHoverListeners=$_debugFeatureHoverListenerCount',
        );
      }
    }
    // Desktop UX: do not re-center the map when a marker is clicked.
    setState(() {
      _selectedMarkerId = marker.id;
      _selectedMarkerData = marker;
      _selectedMarkerAt = DateTime.now();
      _selectedMarkerViewportSignature = null;
      _markerOverlayMode = overlayMode;
      _selectedMarkerAnchor = null;
      _pendingMarkerLocation = null;
      _selectedArtwork = null;
      _selectedExhibition = null;
    });
    _startPressedMarkerFeedback(marker.id);
    _startSelectionPopAnimation();
    _maybeRecordPresenceVisitForMarker(marker);
    unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
    _queueOverlayAnchorRefresh();
    unawaited(_ensureLinkedArtworkLoaded(marker, allowAutoSelect: false));
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
      if (!MapViewportUtils.containsPoint(loadedBounds, marker.position)) {
        return;
      }
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
        // Clear selection if the deleted marker was selected
        if (_selectedMarkerId == markerId) {
          _selectedMarkerId = null;
          _selectedMarkerData = null;
          _selectedMarkerAt = null;
          _selectedMarkerViewportSignature = null;
          _selectedMarkerAnchor = null;
        }
      });
    } catch (_) {}
    unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
  }

  void _dismissSelectedMarkerOverlay() {
    setState(() {
      _selectedMarkerId = null;
      _selectedMarkerData = null;
      _selectedMarkerAt = null;
      _selectedMarkerViewportSignature = null;
      _selectedMarkerAnchor = null;
    });
    _pressedClearTimer?.cancel();
    _pressedClearTimer = null;
    _pressedMarkerId = null;
    _requestMarkerLayerStyleUpdate();
    unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
  }

  void _startPressedMarkerFeedback(String markerId) {
    _pressedClearTimer?.cancel();
    _pressedClearTimer = null;
    _pressedMarkerId = markerId;
    _requestMarkerLayerStyleUpdate();

    _pressedClearTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_pressedMarkerId != markerId) return;
      _safeSetState(() => _pressedMarkerId = null);
      _requestMarkerLayerStyleUpdate();
    });
  }

  void _startSelectionPopAnimation() {
    if (!_styleInitialized) return;
    _animationController.forward(from: 0.0);
    _requestMarkerLayerStyleUpdate();
  }

  void _handleMarkerLayerAnimationTick() {
    if (!mounted) return;
    if (!_styleInitialized) return;

    final shouldSpin = _cubeLayerVisible && _is3DMarkerModeActive;
    final shouldPop = _animationController.isAnimating;
    if (!shouldSpin && !shouldPop) return;

    if (shouldSpin) {
      _cubeIconSpinDegrees = _cubeIconSpinController.value * 360.0;
    }
    _requestMarkerLayerStyleUpdate();
  }

  void _requestMarkerLayerStyleUpdate({bool force = false}) {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && nowMs - _lastMarkerLayerStyleUpdateMs < 66) return;
    _lastMarkerLayerStyleUpdateMs = nowMs;

    if (_markerLayerStyleUpdateInFlight) {
      _markerLayerStyleUpdateQueued = true;
      return;
    }
    _markerLayerStyleUpdateInFlight = true;
    unawaited(_applyMarkerLayerStyle(controller).whenComplete(() {
      _markerLayerStyleUpdateInFlight = false;
      if (_markerLayerStyleUpdateQueued) {
        _markerLayerStyleUpdateQueued = false;
        _requestMarkerLayerStyleUpdate(force: true);
      }
    }));
  }

  Future<void> _applyMarkerLayerStyle(ml.MapLibreMapController controller) async {
    final base = MapMarkerStyleConfig.iconSizeExpression();
    final iconSize = _interactiveIconSizeExpression(base);
    final cubeIconSize = <Object>['*', iconSize, 0.92];
    final iconOpacity = <Object>[
      'case',
      <Object>['==', <Object>['get', 'kind'], 'cluster'],
      1.0,
      1.0,
    ];

    final markerVisible = !_cubeLayerVisible;
    final cubeIconVisible = _cubeLayerVisible;

    try {
      await controller.setLayerProperties(
        _markerLayerId,
        ml.SymbolLayerProperties(
          iconImage: <Object>['get', 'icon'],
          iconSize: iconSize,
          iconOpacity: iconOpacity,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          iconPitchAlignment: 'map',
          iconRotationAlignment: 'map',
          visibility: markerVisible ? 'visible' : 'none',
        ),
      );
      await controller.setLayerProperties(
        _cubeIconLayerId,
        ml.SymbolLayerProperties(
          iconImage: <Object>['get', 'icon'],
          iconSize: cubeIconSize,
          iconOpacity: iconOpacity,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          iconPitchAlignment: 'viewport',
          iconRotationAlignment: 'viewport',
          iconOffset: MapMarkerStyleConfig.cubeFloatingIconOffsetEm,
          iconRotate: _cubeIconSpinDegrees,
          visibility: cubeIconVisible ? 'visible' : 'none',
        ),
      );
    } catch (_) {
      // Best-effort: style swaps or platform limitations can reject updates.
    }
  }

  Object _interactiveIconSizeExpression(Object base) {
    final pressedId = _pressedMarkerId;
    final hoveredId = _hoveredMarkerId;
    final selectedId = _selectedMarkerId;
    final any = pressedId != null || hoveredId != null || selectedId != null;
    if (!any) return base;

    final double pop = selectedId == null
        ? 1.0
        : (1.0 +
            (MapMarkerStyleConfig.selectedPopScaleFactor - 1.0) *
                math.sin(_animationController.value * math.pi));

    // MapLibre expressions allow only a single zoom-based "step"/"interpolate"
    // subexpression. `base` is zoom-based, so it must appear exactly once.
    final multiplier = <Object>['case'];
    if (pressedId != null) {
      multiplier.addAll(<Object>[
        <Object>['==', <Object>['id'], pressedId],
        MapMarkerStyleConfig.pressedScaleFactor,
      ]);
    }
    if (selectedId != null) {
      multiplier.addAll(<Object>[
        <Object>['==', <Object>['id'], selectedId],
        pop,
      ]);
    }
    if (hoveredId != null) {
      multiplier.addAll(<Object>[
        <Object>['==', <Object>['id'], hoveredId],
        MapMarkerStyleConfig.hoverScaleFactor,
      ]);
    }
    multiplier.add(1.0);
    return <Object>['*', base, multiplier];
  }

  bool _assertMarkerModeInvariant() {
    final hasSelection =
        _selectedMarkerId != null || _selectedMarkerData != null;
    final hasPending = _pendingMarkerLocation != null;
    if (hasSelection && hasPending) return false;
    return true;
  }

  bool get _is3DMarkerModeActive {
    if (!AppConfig.isFeatureEnabled('mapIsometricView')) return false;
    return _lastPitch > _cubePitchThreshold;
  }

  bool _assertMarkerRenderModeInvariant() {
    if (!_styleInitialized) return true;
    if (_cubeLayerVisible && !_is3DMarkerModeActive) return false;
    if (!_cubeLayerVisible && _is3DMarkerModeActive) return false;
    return true;
  }

  Future<void> _updateMarkerRenderMode() async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;

    final shouldShowCubes = _is3DMarkerModeActive;
    if (shouldShowCubes == _cubeLayerVisible) return;

    _cubeLayerVisible = shouldShowCubes;

    try {
      await controller.setLayerVisibility(_cubeBevelLayerId, shouldShowCubes);
      await controller.setLayerVisibility(_cubeLayerId, shouldShowCubes);
      await controller.setLayerVisibility(_cubeIconLayerId, shouldShowCubes);
      await controller.setLayerVisibility(_markerLayerId, !shouldShowCubes);
    } catch (_) {
      // Best-effort: layer visibility may fail during style swaps.
    }

    if (!mounted) return;
    _requestMarkerLayerStyleUpdate(force: true);
    if (shouldShowCubes) {
      final themeProvider = context.read<ThemeProvider>();
      await _syncMarkerCubes(themeProvider: themeProvider);
    } else {
      try {
        await controller.setGeoJsonSource(
          _cubeSourceId,
          const <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <dynamic>[],
          },
        );
        await controller.setGeoJsonSource(
          _cubeBevelSourceId,
          const <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <dynamic>[],
          },
        );
      } catch (_) {
        // Ignore source update failures during transitions.
      }
    }
  }

  Future<void> _syncMarkerCubes({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;
    if (!mounted) return;
    if (!_is3DMarkerModeActive) return;

    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final zoom = _cameraZoom;
    final visibleMarkers =
        _artMarkers.where((m) => m.hasValidPosition).toList(growable: false);

    final topFeatures = <Map<String, dynamic>>[];
    final bevelFeatures = <Map<String, dynamic>>[];
    for (final marker in visibleMarkers) {
      final baseColor = AppColorUtils.markerSubjectColor(
        markerType: marker.type.name,
        metadata: marker.metadata,
        scheme: scheme,
        roles: roles,
      );
      final fullSizeMeters = MarkerCubeGeometry.cubeBaseSizeMeters(
        zoom: zoom,
        latitude: marker.position.latitude,
      );
      final topSizeMeters = fullSizeMeters * 0.92;
      final topHeightMeters = fullSizeMeters * 0.90;
      final bevelHeightMeters = fullSizeMeters * 0.72;

      final topColor = AppColorUtils.shiftLightness(baseColor, 0.04);
      final topColorHex = MarkerCubeGeometry.toHex(topColor);
      final bevelColor = AppColorUtils.shiftLightness(baseColor, -0.10);
      final bevelColorHex = MarkerCubeGeometry.toHex(bevelColor);

      topFeatures.add(
        MarkerCubeGeometry.cubeFeatureForMarkerWithMeters(
          marker: marker,
          colorHex: topColorHex,
          sizeMeters: topSizeMeters,
          heightMeters: topHeightMeters,
          kind: 'cubeTop',
        ),
      );
      bevelFeatures.add(
        MarkerCubeGeometry.cubeFeatureForMarkerWithMeters(
          marker: marker,
          colorHex: bevelColorHex,
          sizeMeters: fullSizeMeters,
          heightMeters: bevelHeightMeters,
          kind: 'cubeBevel',
        ),
      );
    }

    final topCollection = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': topFeatures,
    };
    final bevelCollection = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': bevelFeatures,
    };

    if (!mounted) return;
    await controller.setGeoJsonSource(_cubeBevelSourceId, bevelCollection);
    await controller.setGeoJsonSource(_cubeSourceId, topCollection);
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

    final displayTitle = canPresentExhibition && exhibitionTitle.isNotEmpty
        ? exhibitionTitle
        : (artwork?.title.isNotEmpty == true ? artwork!.title : marker.name);
    final rawDescription = (marker.description.isNotEmpty
            ? marker.description
            : (artwork?.description ?? ''))
        .trim();

    const int maxPreviewChars = 300;
    final String visibleDescription = rawDescription.length <= maxPreviewChars
        ? rawDescription
        : '${rawDescription.substring(0, maxPreviewChars)}...';

    final showChips =
        _hasMetadataChips(marker, artwork) || canPresentExhibition;
    final artworkProvider = context.read<ArtworkProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final viewportHeight = MediaQuery.of(context).size.height;
    final safeVerticalPadding = MediaQuery.of(context).padding.vertical;
    final double maxCardHeight = math
        .max(240.0, viewportHeight - safeVerticalPadding - 24)
        .toDouble();

    return Semantics(
      label: 'marker_floating_card',
      container: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 280, maxHeight: maxCardHeight),
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
                child: CustomScrollView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
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
                                      Icon(Icons.near_me,
                                          size: 12, color: baseColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        distanceText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
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
                                onTap: _dismissSelectedMarkerOverlay,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
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
                                          _markerImageFallback(
                                              baseColor, scheme, marker),
                                      loadingBuilder:
                                          (context, child, progress) {
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
                                  : _markerImageFallback(
                                      baseColor, scheme, marker),
                            ),
                          ),
                          if (visibleDescription.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              visibleDescription,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                          ],
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
                                    unawaited(
                                        artworkProvider.toggleLike(artwork.id));
                                  },
                                ),
                                const SizedBox(width: 8),
                                _markerOverlayActionButton(
                                  icon: artwork.isFavoriteByCurrentUser ||
                                          artwork.isFavorite
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  label: l10n.commonSave,
                                  isActive: artwork.isFavoriteByCurrentUser ||
                                      artwork.isFavorite,
                                  activeColor: baseColor,
                                  scheme: scheme,
                                  isDark: isDark,
                                  onTap: () {
                                    unawaited(artworkProvider
                                        .toggleFavorite(artwork.id));
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
                          SizedBox(
                            width: double.infinity,
                            child: Semantics(
                              label: 'marker_more_info',
                              button: true,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: baseColor,
                                  foregroundColor:
                                      AppColorUtils.contrastText(baseColor),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    final marker = _selectedMarkerData;
    final selectionKey = _selectedMarkerAt?.millisecondsSinceEpoch ?? 0;
    final animationKey = marker == null
        ? const ValueKey<String>('marker_overlay_empty')
        : ValueKey<String>('marker_overlay:${marker.id}:$selectionKey');
    final shouldIntercept = marker != null;
    final overlay = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
      child: marker == null
          ? const SizedBox.shrink(key: ValueKey('marker_overlay_hidden'))
          // Use StackFit.expand to ensure bounded constraints for
          // Positioned.fill children during AnimatedSwitcher transitions.
          // Without this, web can throw "RenderBox was not laid out".
          : Stack(
              key: animationKey,
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) {},
                    onPointerMove: (_) {},
                    onPointerUp: (_) {},
                    onPointerSignal: (_) {},
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismissSelectedMarkerOverlay,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _buildMarkerOverlayPositionedCard(
                    marker: marker,
                    artworkProvider: artworkProvider,
                    themeProvider: themeProvider,
                  ),
                ),
              ],
            ),
    );

    return Positioned.fill(
      child: _wrapPointerInterceptor(
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          child: overlay,
        ),
        enabled: shouldIntercept,
      ),
    );
  }

  Widget _buildMarkerOverlayPositionedCard({
    required ArtMarker marker,
    required ArtworkProvider artworkProvider,
    required ThemeProvider themeProvider,
  }) {
    final artwork = marker.isExhibitionMarker
        ? null
        : artworkProvider.getArtworkById(marker.artworkId ?? '');

    final card = _buildMarkerOverlayCard(marker, artwork, themeProvider);

    // Wrap card in a Listener to absorb pointer events and prevent them
    // from passing through to the map underneath (gesture conflict resolution).
    final wrappedCard = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      onPointerMove: (_) {},
      onPointerUp: (_) {},
      onPointerSignal: (_) {},
      child: card,
    );

    if (_markerOverlayMode == _MarkerOverlayMode.centered ||
        _selectedMarkerAnchor == null) {
      // Use UnconstrainedBox to prevent Positioned.fill from passing
      // full-screen constraints to the card, which caused the 1-frame
      // "correct then huge" snap issue on desktop.
      return Center(
        child: UnconstrainedBox(
          child: wrappedCard,
        ),
      );
    }

    // Offset the card above the marker (flat square markers).
    // Account for icon scaling at different zoom levels.
    const double baseOffset = 32.0;
    final zoomFactor = (_cameraZoom / 15.0).clamp(0.5, 1.5);
    final verticalOffset = baseOffset * zoomFactor;

    // Use LayoutBuilder + Positioned for proper viewport clamping
    // instead of CompositedTransformFollower which has no viewport awareness.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against null to prevent race condition.
        final anchor = _selectedMarkerAnchor;
        if (anchor == null) {
          return Center(child: UnconstrainedBox(child: wrappedCard));
        }
        const double cardWidth =
            280; // Match maxWidth in _buildMarkerOverlayCard
        const double padding = 16;
        // Estimate card height (match maxHeight used in the card itself)
        final viewportHeight = MediaQuery.of(context).size.height;
        final safeVerticalPadding = MediaQuery.of(context).padding.vertical;
        final double estimatedCardHeight = math
            .max(240.0, viewportHeight - safeVerticalPadding - 24)
            .toDouble();

        // Center horizontally around anchor, clamped to viewport
        double left = anchor.dx - (cardWidth / 2);
        left = left.clamp(padding, constraints.maxWidth - cardWidth - padding);

        // Calculate available space above the marker
        final topSafe = MediaQuery.of(context).padding.top + padding;
        final bottomPadding = padding;
        final spaceAbove = anchor.dy - topSafe - verticalOffset;

        // Position above marker; if not enough space, keep within safe area
        // and nudge the camera down so the marker remains visible below.
        double top = anchor.dy - estimatedCardHeight - verticalOffset;
        if (top < topSafe) {
          top = topSafe;
          _scheduleEnsureMarkerOverlayInView(
            marker: marker,
            overlayHeight: estimatedCardHeight,
          );
        }

        // Final clamp to ensure card never goes off-screen
        top = top.clamp(
          topSafe,
          math.max(topSafe,
              constraints.maxHeight - estimatedCardHeight - bottomPadding),
        );

        if (kDebugMode) {
          AppConfig.debugPrint(
            'DesktopMapScreen: card positioned at ($left, $top) anchor=(${anchor.dx.toStringAsFixed(0)}, ${anchor.dy.toStringAsFixed(0)}) '
            'spaceAbove=${spaceAbove.toStringAsFixed(0)}',
          );
        }

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              // Use UnconstrainedBox to prevent the Positioned widget from
              // passing unbounded height constraints to the card, which would
              // cause the card to expand to fill all available space.
              // constrainedAxis: Axis.horizontal ensures width is respected.
              child: UnconstrainedBox(
                alignment: Alignment.topLeft,
                constrainedAxis: Axis.horizontal,
                child: SizedBox(
                  width: cardWidth,
                  child: wrappedCard,
                ),
              ),
            ),
          ],
        );
      },
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
    final cursor =
        onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click;
    return MouseRegion(
      cursor: cursor,
      child: Tooltip(
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

    final cursor =
        onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click;
    return Expanded(
      child: MouseRegion(
        cursor: cursor,
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
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.mapExhibitionsUnavailableToast)),
          tone: KubusSnackBarTone.warning,
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
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapExhibitionsUnavailableToast)),
        tone: KubusSnackBarTone.warning,
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

  Future<Artwork?> _ensureLinkedArtworkLoaded(
    ArtMarker marker, {
    Artwork? initial,
    bool allowAutoSelect = true,
  }) async {
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
          if (mounted && _selectedMarkerId == marker.id) {
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
      if (mounted && _selectedMarkerId == marker.id) {
        if (allowAutoSelect) {
          setState(() {
            if (_selectedArtwork == null ||
                _selectedArtwork?.id == resolvedArtwork!.id) {
              _selectedArtwork = resolvedArtwork;
            }
            _selectedExhibition = null;
            _showFiltersPanel = false;
          });
        } else {
          setState(() {});
        }
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
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
    setState(() {
      _selectedMarkerId = null;
      _selectedMarkerData = null;
      _selectedMarkerAt = null;
      _selectedMarkerAnchor = null;
    });
    final subjectData = await _refreshMarkerSubjectData(force: true) ??
        _snapshotMarkerSubjectData();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final wallet = context.read<WalletProvider>().currentWalletAddress;
    if (wallet == null || wallet.isEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerCreateWalletRequired)),
        tone: KubusSnackBarTone.warning,
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
        setState(() {
          _pendingMarkerLocation = center;
          _selectedMarkerId = null;
          _selectedMarkerData = null;
          _selectedMarkerAt = null;
          _selectedMarkerAnchor = null;
        });
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
      final messenger = ScaffoldMessenger.of(context);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerCreatedToast)),
        tone: KubusSnackBarTone.success,
      );
      await _loadMarkersForCurrentView(force: true);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerCreateFailedToast)),
        tone: KubusSnackBarTone.error,
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
        final messenger = ScaffoldMessenger.of(context);
        messenger.showKubusSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.mapMarkerDuplicateToast)),
          tone: KubusSnackBarTone.error,
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

/// Helper for batched icon pre-registration.
class _IconRenderTask {
  const _IconRenderTask({
    required this.iconId,
    required this.marker,
    required this.cluster,
    required this.isCluster,
    required this.selected,
  });
  final String iconId;
  final ArtMarker? marker;
  final _ClusterBucket? cluster;
  final bool isCluster;
  final bool selected;
}

class _ClusterBucket {
  _ClusterBucket(this.cell, this.markers);
  final GridCell cell;
  final List<ArtMarker> markers;
}
