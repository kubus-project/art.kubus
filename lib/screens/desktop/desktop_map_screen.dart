import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../features/map/shared/map_screen_shared_helpers.dart';
import '../../providers/themeprovider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/marker_management_provider.dart';
import '../../providers/presence_provider.dart';
import '../../providers/tile_providers.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/artwork.dart';
import '../../models/art_marker.dart';
import '../../models/exhibition.dart';
import '../../models/map_marker_subject.dart';
import '../../config/config.dart';
import '../../core/app_route_observer.dart';
import '../../services/map_style_service.dart';
import '../../services/backend_api_service.dart';
import '../../services/search_service.dart';
import '../../services/map_data_controller.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../services/map_marker_service.dart';
import '../../services/ar_service.dart';
import '../../utils/map_marker_subject_loader.dart';
import '../../utils/map_perf_tracker.dart';
import '../../utils/map_performance_debug.dart';
import '../../utils/map_marker_helper.dart';
import '../../utils/art_marker_list_diff.dart';
import '../../utils/debouncer.dart';
import '../../utils/map_search_suggestion.dart';
import '../../utils/presence_marker_visit.dart';
import '../../utils/map_viewport_utils.dart';
import '../../utils/geo_bounds.dart';
import '../../widgets/map_marker_style_config.dart';
import '../../widgets/artwork_creator_byline.dart';
import '../../widgets/art_map_view.dart';
import '../../widgets/map_marker_dialog.dart';
import '../../widgets/map/panels/kubus_create_marker_panel.dart';
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
import '../../features/map/controller/map_view_preferences_controller.dart';
import '../../features/map/shared/map_marker_collision_config.dart';
import '../../features/map/shared/map_screen_constants.dart';
import '../../features/map/map_layers_manager.dart';
import '../../features/map/map_overlay_stack.dart';
import '../../features/map/controller/kubus_map_controller.dart';
import '../../features/map/search/map_search_controller.dart';
import '../../features/map/tutorial/map_tutorial_coordinator.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/marker_cube_geometry.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/kubus_snackbar.dart';
import '../../widgets/tutorial/interactive_tutorial_overlay.dart';
import '../../widgets/map/tutorial/kubus_map_tutorial_overlay.dart';
import '../../widgets/map/kubus_map_marker_geojson_builder.dart';
import '../../widgets/map/kubus_map_marker_rendering.dart';
import '../../widgets/map/kubus_map_marker_features.dart';
import '../../widgets/map/controls/kubus_map_primary_controls.dart'
    show KubusMapPrimaryControlsLayout;
import '../../widgets/map/cards/kubus_discovery_card.dart';
import '../../widgets/map/filters/kubus_map_marker_layer_chips.dart';
import '../../widgets/common/kubus_filter_panel.dart';
import '../../widgets/common/kubus_glass_chip.dart';
import '../../widgets/common/kubus_glass_icon_button.dart';
import '../../widgets/common/kubus_cached_image.dart';
import '../../widgets/common/kubus_map_controls.dart';
import '../../widgets/common/kubus_marker_overlay_card.dart';
import '../../widgets/common/kubus_search_overlay_scaffold.dart';
import '../../widgets/common/kubus_sort_option.dart';
import '../../widgets/map/overlays/kubus_marker_overlay_card_wrapper.dart';
import '../../widgets/map/panels/kubus_detail_panel.dart';
import '../../features/map/nearby/nearby_art_controller.dart';
import '../../widgets/map/nearby/kubus_nearby_art_panel.dart';
import '../map_core/map_marker_interaction_controller.dart';
import '../map_core/marker_visual_sync_coordinator.dart';
import '../map_core/map_camera_controller.dart';
import '../map_core/map_data_coordinator.dart';
import '../map_core/map_ui_state_coordinator.dart';
import '../map_core/map_marker_render_coordinator.dart';
import '../../providers/task_provider.dart';
import '../../models/task.dart';

/// Desktop map screen with Google Maps-style presentation
/// Features side panel for artwork details and filters
enum _MarkerOverlayMode {
  anchored,
  centered,
}

enum _RightSidebarContent {
  nearby,
  createMarker,
}

enum _MarkerSocketScope { inScope, outOfScope, unknown }

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
    with WidgetsBindingObserver, TickerProviderStateMixin, RouteAware {
  final MapPerfTracker _perf = MapPerfTracker('DesktopMapScreen');

  late final KubusMapController _kubusMapController;
  late final MapMarkerInteractionController _markerInteractionController;
  late final MapCameraController _mapCameraController;
  late final MarkerVisualSyncCoordinator _markerVisualSyncCoordinator;
  late final MapDataCoordinator _mapDataCoordinator;
  late final NearbyArtController _nearbyArtController;
  late final MapUiStateCoordinator _mapUiStateCoordinator;
  late final MapMarkerRenderCoordinator _renderCoordinator;

  ml.MapLibreMapController? _mapController;
  ml.MapLibreMapController? _deactivateDetachedMapController;
  MapLayersManager? _layersManager;
  late AnimationController _animationController;
  late AnimationController _panelController;
  final MapMarkerService _mapMarkerService = MapMarkerService();

  Artwork? _selectedArtwork;
  Exhibition? _selectedExhibition;
  _MarkerOverlayMode _markerOverlayMode = _MarkerOverlayMode.anchored;
  bool _markerStackPagerSyncing = false;
  final PageController _markerStackPageController = PageController();
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
  LatLng? _pendingMarkerLocation;
  bool _mapReady = false;
  double _cameraZoom = 13.0;
  int _renderZoomBucket = MapViewportUtils.zoomBucket(13.0);
  List<ArtMarker> _artMarkers = [];
  bool _isLoadingMarkers = false; // Tracks the latest marker request
  int _markerRequestId = 0;
  MarkerSubjectLoader get _subjectLoader => MarkerSubjectLoader(context);
  LatLng? _userLocation;
  double? _userLocationAccuracyMeters;
  int? _userLocationTimestampMs;
  bool _autoFollow = true;
  bool _isLocating = false;
  _RightSidebarContent? _rightSidebarContent;
  bool get _isNearbyPanelOpen =>
      _rightSidebarContent == _RightSidebarContent.nearby;
  bool get _isRightSidebarOpen => _rightSidebarContent != null;
  bool _pendingInitialNearbyPanelOpen = true;
  int _nearbyPanelAutoloadAttempts = 0;
  bool _nearbyPanelAutoloadScheduled = false;
  static const int _maxNearbyPanelAutoloadAttempts = 8;
  String? _nearbySidebarSignature;
  bool _nearbySidebarSyncScheduled = false;
  Timer? _nearbySidebarSyncTimer;
  LatLng? _nearbySidebarAnchor;
  DateTime? _nearbySidebarLastSyncAt;
  List<Artwork> _nearbySidebarPendingArtworks = const <Artwork>[];
  LatLng? _nearbySidebarPendingBasePosition;
  static const Duration _nearbySidebarSyncCooldown =
      Duration(milliseconds: 250);
  // Create-marker sidebar state
  MarkerSubjectData? _createMarkerSubjectData;
  Set<MarkerSubjectType>? _createMarkerAllowedTypes;
  MarkerSubjectType? _createMarkerInitialType;
  LatLng? _createMarkerPosition;
  final Distance _distance = const Distance();
  StreamSubscription<ArtMarker>? _markerStreamSub;
  StreamSubscription<String>? _markerDeletedSub;
  bool _isAppForeground = true;
  bool _isRouteVisible = true;
  PageRoute<dynamic>? _subscribedRoute;
  bool _pendingMarkerRefresh = false;
  bool _pendingMarkerRefreshForce = false;
  LatLng _cameraCenter = const LatLng(46.0569, 14.5058);
  LatLng? _lastMarkerFetchCenter;
  DateTime? _lastMarkerFetchTime;
  GeoBounds? _loadedTravelBounds;
  int? _loadedTravelZoomBucket;
  double _lastBearing = 0.0;
  double _lastPitch = 0.0;
  DateTime _lastCameraUpdateTime = DateTime.now();
  static const Duration _cameraUpdateThrottle =
      MapScreenConstants.cameraUpdateThrottle; // ~60fps
  bool _styleInitialized = false;
  bool _styleInitializationInProgress = false;
  int _styleEpoch = 0;
  final Set<String> _registeredMapImages = <String>{};
  final Set<String> _managedLayerIds = <String>{};
  final Set<String> _managedSourceIds = <String>{};
  final LayerLink _markerOverlayLink = LayerLink();
  final Debouncer _cubeSyncDebouncer = Debouncer();
  final Debouncer _radiusChangeDebouncer = Debouncer();
  late final ValueNotifier<Offset?> _selectedMarkerAnchorNotifier;
  // Shared constants – canonical values live in MapScreenConstants.
  static const String _markerSourceId = MapScreenConstants.markerSourceId;
  static const String _markerLayerId = MapScreenConstants.markerLayerId;
  static const String _cubeSourceId = MapScreenConstants.cubeSourceId;
  static const String _cubeLayerId = MapScreenConstants.cubeLayerId;
  static const String _cubeIconLayerId = MapScreenConstants.cubeIconLayerId;
  static const String _locationSourceId = MapScreenConstants.locationSourceId;
  static const String _locationLayerId = MapScreenConstants.locationLayerId;
  static const String _pendingSourceId = MapScreenConstants.pendingSourceId;
  static const double _markerRefreshDistanceMeters =
      MapScreenConstants.markerRefreshDistanceMeters;
  static const Duration _markerRefreshInterval = MapScreenConstants.markerRefreshInterval;

  late final MapSearchController _mapSearchController;
  late final MapViewPreferencesController _mapViewPreferencesController;
  late final MapTutorialCoordinator _mapTutorialCoordinator;
  bool _pendingSafeSetState = false;
  int _debugMarkerTapCount = 0;

  late AnimationController _cubeIconSpinController;

  final GlobalKey _mapViewKey = GlobalKey();
  bool? _lastAppliedMapThemeDark;
  bool _themeResyncScheduled = false;

  static const double _clusterMaxZoom = MapScreenConstants.clusterMaxZoom;
  static const int _markerVisualSyncThrottleMs = MapScreenConstants.markerVisualSyncThrottleMs;
  int _lastClusterGridLevel = -1;
  bool _lastClusterEnabled = false;

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

    // Shared UI state mirror (selection/tutorial/etc). Not yet used by the UI;
    // this is a no-behavior-change bridge for incremental refactors.
    _mapUiStateCoordinator = MapUiStateCoordinator();
    _mapViewPreferencesController = MapViewPreferencesController();
    _mapViewPreferencesController
        .addListener(_handleMapViewPreferencesChanged);
    _mapTutorialCoordinator = MapTutorialCoordinator(
      seenPreferenceKey: PreferenceKeys.mapOnboardingDesktopSeenV2,
    );
    _mapTutorialCoordinator.addListener(_handleTutorialCoordinatorChanged);

    _mapSearchController = MapSearchController(
      scope: SearchScope.map,
      limit: 8,
      showOverlayOnFocus: false,
    );
    _mapSearchController.addListener(_handleMapSearchControllerChanged);

    _markerVisualSyncCoordinator = MarkerVisualSyncCoordinator(
      throttleMs: _markerVisualSyncThrottleMs,
      isReady: () => mounted && _styleInitialized && _mapController != null,
      sync: () async {
        if (!mounted) return;
        final themeProvider = context.read<ThemeProvider>();
        await _syncMapMarkersSafe(themeProvider: themeProvider);
      },
    );

    _kubusMapController = KubusMapController(
      ids: const KubusMapControllerIds(
        layers: MapScreenConstants.desktopLayerIds,
      ),
      debugTracing: kDebugMode && MapPerformanceDebug.isEnabled,
      tapConfig: const KubusMapTapConfig(
        clusterTapZoomDelta: 2.0,
      ),
      distance: _distance,
      supportsPendingMarker: true,
      managedLayerIdsOut: _managedLayerIds,
      managedSourceIdsOut: _managedSourceIds,
      registeredMapImagesOut: _registeredMapImages,
      onAutoFollowChanged: (value) {
        if (!mounted) return;
        _safeSetState(() => _autoFollow = value);
      },
      onSelectionChanged: (state) {
        if (!mounted) return;
        final prevToken =
            _mapUiStateCoordinator.value.markerSelection.selectionToken;
        final tokenChanged = state.selectionToken != prevToken;
        if (tokenChanged) {
          _perf.recordSetState('markerSelection');
          _safeSetState(() {
            _selectedArtwork = null;
            _selectedExhibition = null;
            _pendingMarkerLocation = null;
          });
        }

        _mapUiStateCoordinator.setMarkerSelection(
          selectionToken: state.selectionToken,
          selectedMarkerId: state.selectedMarkerId,
          selectedMarker: state.selectedMarker,
          stackedMarkers: state.stackedMarkers,
          stackIndex: state.stackIndex,
          selectedAt: state.selectedAt,
        );

        final marker = state.selectedMarker;
        if (marker != null) {
          // Run selection-only side effects once per selection token.
          if (tokenChanged) {
            _renderCoordinator.startSelectionPopAnimation();
            _maybeRecordPresenceVisitForMarker(marker);
          }
          unawaited(_ensureLinkedArtworkLoaded(marker, allowAutoSelect: false));

          final userLocation = _userLocation;
          if (userLocation != null) {
            context.read<AttendanceProvider>().updateProximity(
                  markerId: marker.id,
                  lat: userLocation.latitude,
                  lng: userLocation.longitude,
                  distanceMeters:
                      _calculateDistance(userLocation, marker.position),
                  activationRadiusMeters: marker.activationRadius,
                  requiresProximity: marker.requiresProximity,
                  accuracyMeters: _userLocationAccuracyMeters,
                  timestampMs: _userLocationTimestampMs,
                );
          }
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncMarkerStackPager();
        });
      },
      onBackgroundTap: () {
        if (!mounted) return;
        _perf.recordSetState('backgroundTap');
        _mapSearchController.dismissOverlay(unfocus: true);
        _safeSetState(() {
          _selectedArtwork = null;
          _selectedExhibition = null;
          _showFiltersPanel = false;
          _pendingMarkerLocation = null;
        });
      },
      onRequestMarkerLayerStyleUpdate: () {
        _renderCoordinator.requestStyleUpdate(force: true);
      },
      onRequestMarkerDataSync: () {
        _requestMarkerVisualSync();
      },
    );
    _selectedMarkerAnchorNotifier = _kubusMapController.selectedMarkerAnchor;
    _kubusMapController.setMarkerTypeVisibility(_markerLayerVisibility);
    _kubusMapController.setMarkers(_artMarkers);

    _mapCameraController = MapCameraController(
      mapController: _kubusMapController,
      isReady: () => mounted && _mapReady && _mapController != null,
    );

    _mapDataCoordinator = MapDataCoordinator(
      pollingEnabled: () => _pollingEnabled,
      mapReady: () => mounted && _mapReady && _mapController != null,
      cameraCenter: () => _cameraCenter,
      cameraZoom: () => _cameraZoom,
      travelModeEnabled: () => _travelModeEnabled,
      hasMarkers: () => _artMarkers.isNotEmpty,
      lastFetchCenter: () => _lastMarkerFetchCenter,
      lastFetchTime: () => _lastMarkerFetchTime,
      loadedTravelBounds: () => _loadedTravelBounds,
      loadedTravelZoomBucket: () => _loadedTravelZoomBucket,
      distance: _distance,
      refreshInterval: _markerRefreshInterval,
      refreshDistanceMeters: _markerRefreshDistanceMeters,
      getVisibleBounds: _getVisibleGeoBounds,
      refreshRadiusMode: ({required center}) async {
        await _loadMarkers(center: center, force: false);
      },
      refreshTravelMode: ({
        required center,
        required bounds,
        required zoomBucket,
      }) async {
        await _loadMarkers(
          center: center,
          bounds: bounds,
          force: false,
          zoomBucket: zoomBucket,
        );
      },
      queuePendingRefresh: ({bool force = false}) {
        _queuePendingMarkerRefresh(force: force);
      },
    );

    _markerInteractionController = MapMarkerInteractionController(
      mapController: _kubusMapController,
      isWeb: kIsWeb,
    );

    _nearbyArtController = NearbyArtController(
      map: KubusNearbyArtMapDelegate(_kubusMapController),
      distance: _distance,
    );

    _renderCoordinator = MapMarkerRenderCoordinator(
      screenName: 'DesktopMapScreen',
      markerLayerId: _markerLayerId,
      cubeLayerId: _cubeLayerId,
      cubeIconLayerId: _cubeIconLayerId,
      cubeSourceId: _cubeSourceId,
      isMounted: () => mounted,
      isStyleInitialized: () => _styleInitialized,
      isStyleInitInProgress: () => _styleInitializationInProgress,
      isCameraMoving: () => _kubusMapController.cameraIsMoving,
      getLastPitch: () => _lastPitch,
      getKubusMapController: () => _kubusMapController,
      getMapController: () => _mapController,
      getLayersManager: () => _layersManager,
      getSelectionController: () => _animationController,
      getCubeSpinController: () => _cubeIconSpinController,
      getManagedLayerIds: () => _managedLayerIds,
      getManagedSourceIds: () => _managedSourceIds,
      isPollingEnabled: () => _pollingEnabled,
      syncMarkerCubes: () async {
        if (!mounted) return;
        final themeProvider = context.read<ThemeProvider>();
        await _syncMarkerCubes(themeProvider: themeProvider);
      },
    );

    _animationController = AnimationController(
      duration: MapMarkerStyleConfig.selectionPopDuration,
      vsync: this,
    );
    _animationController.addListener(_renderCoordinator.handleAnimationTick);
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cubeIconSpinController = AnimationController(
      duration: MapMarkerStyleConfig.cubeIconSpinPeriod,
      vsync: this,
    )..addListener(_renderCoordinator.handleAnimationTick);
    _perf.controllerCreated('selection_pop');
    _perf.controllerCreated('panel');
    _perf.controllerCreated('cube_spin');
    _perf.logEvent('initState');

    _autoFollow = widget.autoFollow;
    _cameraCenter = widget.initialCenter ?? const LatLng(46.0569, 14.5058);
    _cameraZoom = widget.initialZoom ?? _cameraZoom;

    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    final isWidgetTest = bindingName.contains('TestWidgetsFlutterBinding') ||
        bindingName.contains('AutomatedTestWidgetsFlutterBinding');
    if (isWidgetTest) {
      return;
    }

    _markerStreamSub =
        _mapMarkerService.onMarkerCreated.listen(_handleMarkerCreated);
    _markerDeletedSub =
        _mapMarkerService.onMarkerDeleted.listen(_handleMarkerDeleted);
    _perf.subscriptionStarted('marker_socket_created');
    _perf.subscriptionStarted('marker_socket_deleted');

    unawaited(_loadMapViewPreferences());

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

      unawaited(_mapTutorialCoordinator.maybeStart());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      if (_subscribedRoute != route) {
        if (_subscribedRoute != null) {
          appRouteObserver.unsubscribe(this);
        }
        _subscribedRoute = route;
        appRouteObserver.subscribe(this, route);
      }
      _setRouteVisible(route.isCurrent);
    }
  }

  void _handleMapViewPreferencesChanged() {
    if (!mounted) return;
    final next = _mapViewPreferencesController.value;
    if (_travelModeEnabled == next.travelModeEnabled &&
        _isometricViewEnabled == next.isometricViewEnabled) {
      return;
    }
    setState(() {
      _travelModeEnabled = next.travelModeEnabled;
      _isometricViewEnabled = next.isometricViewEnabled;
    });
  }

  Future<void> _loadMapViewPreferences() async {
    final prefs = await _mapViewPreferencesController.load();
    if (!mounted) return;
    setState(() {
      _travelModeEnabled = prefs.travelModeEnabled;
      _isometricViewEnabled = prefs.isometricViewEnabled;
    });
  }

  Future<void> _setTravelModeEnabled(bool enabled) async {
    if (!mounted) return;

    setState(() {
      _travelModeEnabled = enabled;
    });

    // Switching query strategy (radius vs bounds) should invalidate caches.
    _mapMarkerService.clearCache();
    _loadedTravelBounds = null;
    _loadedTravelZoomBucket = null;

    try {
      await _mapViewPreferencesController.setTravelMode(enabled);
    } catch (_) {
      // Best-effort.
    }

    unawaited(_loadMarkersForCurrentView(force: true));
  }

  Future<void> _setIsometricViewEnabled(bool enabled) async {
    if (!mounted) return;
    setState(() {
      _isometricViewEnabled = enabled;
    });

    try {
      await _mapViewPreferencesController.setIsometric(enabled);
    } catch (_) {
      // Best-effort.
    }

    unawaited(
        _applyIsometricCamera(enabled: enabled, adjustZoomForScale: true));
  }

  void _handleTutorialCoordinatorChanged() {
    if (!mounted) return;
    final tutorial = _mapTutorialCoordinator.state;
    _mapUiStateCoordinator.setTutorial(
      show: tutorial.show,
      index: tutorial.index,
    );
  }

  List<MapTutorialStepBinding> _buildMapTutorialStepBindings(
    AppLocalizations l10n,
  ) {
    final bindings = <MapTutorialStepBinding>[
      MapTutorialStepBinding(
        id: 'map',
        isAnchorAvailable: () => _tutorialMapKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialMapKey,
          icon: Icons.map_outlined,
          title: l10n.mapTutorialStepMapTitle,
          body: l10n.mapTutorialStepMapBody,
        ),
      ),
      MapTutorialStepBinding(
        id: 'markers',
        isAnchorAvailable: () => _tutorialMapKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialMapKey,
          icon: Icons.place_outlined,
          title: l10n.mapTutorialStepMarkersTitle,
          body: l10n.mapTutorialStepMarkersBody,
        ),
      ),
      MapTutorialStepBinding(
        id: 'nearby',
        isAnchorAvailable: () => _tutorialNearbyButtonKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialNearbyButtonKey,
          icon: Icons.view_list,
          title: l10n.mapTutorialStepNearbyTitle,
          body: l10n.mapTutorialStepNearbyDesktopBody,
          onTargetTap: _openNearbyArtPanel,
        ),
      ),
      MapTutorialStepBinding(
        id: 'types',
        isAnchorAvailable: () => _tutorialFilterChipsKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialFilterChipsKey,
          icon: Icons.auto_awesome,
          title: l10n.mapTutorialStepTypesTitle,
          body: l10n.mapTutorialStepTypesDesktopBody,
        ),
      ),
      MapTutorialStepBinding(
        id: 'filters',
        isAnchorAvailable: () =>
            _tutorialFiltersButtonKey.currentContext != null,
        step: TutorialStepDefinition(
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
      ),
      MapTutorialStepBinding(
        id: 'search',
        isAnchorAvailable: () => _tutorialSearchKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialSearchKey,
          icon: Icons.search,
          title: l10n.mapTutorialStepSearchTitle,
          body: l10n.mapTutorialStepSearchBody,
        ),
      ),
    ];

    if (AppConfig.isFeatureEnabled('mapTravelMode')) {
      bindings.insert(
        5,
        MapTutorialStepBinding(
          id: 'travel_mode',
          isAnchorAvailable: () =>
              _tutorialTravelButtonKey.currentContext != null,
          step: TutorialStepDefinition(
            targetKey: _tutorialTravelButtonKey,
            icon: Icons.travel_explore,
            title: l10n.mapTutorialStepTravelTitle,
            body: l10n.mapTutorialStepTravelBody,
            onTargetTap: () => unawaited(_setTravelModeEnabled(true)),
          ),
        ),
      );
    }

    return bindings;
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
      // DesktopMapScreen can be opened outside of DesktopShell (e.g. via
      // MapNavigation). In that case there is no functions sidebar; render the
      // nearby panel locally inside this screen.
      _pendingInitialNearbyPanelOpen = false;
      _openNearbyArtPanel();
      return;
    }

    _pendingInitialNearbyPanelOpen = false;
    _openNearbyArtPanel();
  }

  Widget _buildNearbyFunctionsPanelContent(
    List<Artwork> filteredArtworks, {
    LatLng? basePosition,
  }) {
    // Keep the subtree key stable so rapid updates (like radius changes)
    // update in-place instead of remounting the whole sidebar.
    return KeyedSubtree(
      key: const ValueKey<String>('nearby_sidebar'),
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();
          final isLoadingArtworks =
              context.watch<ArtworkProvider>().isLoading('load_artworks');
          return _buildNearbyArtSidebar(
            themeProvider,
            filteredArtworks,
            basePosition: basePosition,
            isLoading: isLoadingArtworks,
          );
        },
      ),
    );
  }

  void _openNearbyArtPanel() {
    final anchor = _userLocation ?? _effectiveCenter;

    _safeSetState(() {
      _rightSidebarContent = _RightSidebarContent.nearby;
      _nearbySidebarSignature = null;
      _nearbySidebarSyncScheduled = false;
      _nearbySidebarAnchor = anchor;
      _nearbySidebarLastSyncAt = null;
      _selectedArtwork = null;
      _selectedExhibition = null;
      _showFiltersPanel = false;
      // Clear any lingering create-marker state.
      _createMarkerSubjectData = null;
      _createMarkerAllowedTypes = null;
      _createMarkerInitialType = null;
      _createMarkerPosition = null;
    });
    // The nearby panel is always rendered as a local glass overlay inside
    // the map Stack (see build → AnimatedPositioned). We no longer push it
    // into the DesktopShell's functions sidebar so the map stays full width.
  }

  void _closeNearbyArtPanel() {
    _safeSetState(() {
      _rightSidebarContent = null;
      _nearbySidebarSyncScheduled = false;
      _nearbySidebarAnchor = null;
      _nearbySidebarLastSyncAt = null;
    });
    _nearbySidebarSignature = null;
    // Close the shell panel too in case it was still open from a previous
    // session (defensive).
    DesktopShellScope.of(context)?.closeFunctionsPanel();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;

    // Guard against setState being invoked synchronously during build.
    // (Avoids needing any build()-time bookkeeping.)
    final phase = SchedulerBinding.instance.schedulerPhase;
    final bool shouldDefer = phase == SchedulerPhase.persistentCallbacks;
    if (shouldDefer) {
      if (_pendingSafeSetState) return;
      _pendingSafeSetState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingSafeSetState = false;
        if (!mounted) return;
        setState(fn);
      });
      return;
    }
    setState(fn);
  }

  int _clusterGridLevelForZoom(double zoom) {
    final double targetSpacingPx =
        zoom < 6.5 ? 56.0 : (zoom < 9.5 ? 64.0 : 72.0);
    final level = GridUtils.resolvePrimaryGridLevel(zoom,
        targetScreenSpacing: targetSpacingPx);
    return level.clamp(3, 14);
  }

  void _queueMarkerVisualRefreshForZoom(double zoom) {
    final shouldCluster = zoom < _clusterMaxZoom;
    final gridLevel = shouldCluster ? _clusterGridLevelForZoom(zoom) : -1;
    if (shouldCluster == _lastClusterEnabled &&
        gridLevel == _lastClusterGridLevel) {
      return;
    }
    _lastClusterEnabled = shouldCluster;
    _lastClusterGridLevel = gridLevel;
    _requestMarkerVisualSync();
  }

  void _requestMarkerVisualSync({bool force = false}) {
    _markerVisualSyncCoordinator.request(force: force);
  }

  Future<void> _syncMapMarkersSafe(
      {required ThemeProvider themeProvider}) async {
    try {
      await _syncMapMarkers(themeProvider: themeProvider);
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint('DesktopMapScreen: _syncMapMarkers failed: $e');
      }
    }
  }

  Future<void> _applyThemeToMapStyle(
      {required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;

    final scheme = Theme.of(context).colorScheme;
    try {
      await _layersManager?.safeSetLayerProperties(
        _locationLayerId,
        ml.CircleLayerProperties(
          circleRadius: 6,
          circleColor: KubusMapMarkerHelpers.hexRgb(scheme.secondary),
          circleOpacity: 1.0,
          circleStrokeWidth: 2,
          circleStrokeColor: KubusMapMarkerHelpers.hexRgb(scheme.surface),
        ),
      );
    } catch (_) {
      // Best-effort: style swaps or platform limitations can reject updates.
    }

    if (!mounted) return;
    _renderCoordinator.requestStyleUpdate(force: true);
  }

  void _maybeScheduleThemeResync(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final last = _lastAppliedMapThemeDark;
    if (last != null && last == isDark) return;
    _lastAppliedMapThemeDark = isDark;
    if (!_styleInitialized) return;
    if (_themeResyncScheduled) return;
    _themeResyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _themeResyncScheduled = false;
      if (!mounted) return;
      unawaited(_applyThemeToMapStyle(themeProvider: themeProvider));
      unawaited(_syncMapMarkersSafe(themeProvider: themeProvider));
    });
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
    return '$modeSig|$baseSig|$_selectedFilter|${filteredArtworks.length}|${ids.join(',')}';
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

    // Throttle updates (e.g. radius slider changes) to avoid visible flashing
    // from repeatedly replacing the desktop shell's functions panel content.
    final now = DateTime.now();
    final lastAt = _nearbySidebarLastSyncAt;
    if (lastAt != null && now.difference(lastAt) < _nearbySidebarSyncCooldown) {
      _nearbySidebarPendingArtworks = filteredArtworks;
      _nearbySidebarPendingBasePosition = basePosition;
      if (_nearbySidebarSyncScheduled) return;
      _nearbySidebarSyncScheduled = true;
      final remaining = _nearbySidebarSyncCooldown - now.difference(lastAt);
      _nearbySidebarSyncTimer?.cancel();
      _nearbySidebarSyncTimer = Timer(remaining, () {
        if (!mounted) return;
        _nearbySidebarSyncScheduled = false;
        final pending = _nearbySidebarPendingArtworks;
        final pendingBase = _nearbySidebarPendingBasePosition;
        _nearbySidebarPendingArtworks = const <Artwork>[];
        _nearbySidebarPendingBasePosition = null;
        _nearbySidebarSyncTimer = null;
        _syncNearbySidebarIfNeeded(
          themeProvider,
          pending,
          basePosition: pendingBase,
        );
      });
      return;
    }
    _nearbySidebarLastSyncAt = now;

    // NOTE: This method is now always called from a post-frame callback,
    // so we can directly update the shell content without another deferral.
    shellScope.setFunctionsPanelContent(
      _buildNearbyFunctionsPanelContent(
        filteredArtworks,
        basePosition: basePosition,
      ),
    );
  }

  /// Forces an immediate sidebar sync after user actions like filter or radius
  /// changes. Invalidates the cached signature so the next sync detects a
  /// change, then schedules the update for the next frame.
  void _forceNearbySidebarSync() {
    if (!_isNearbyPanelOpen || !mounted) return;
    // Invalidate signature so _syncNearbySidebarIfNeeded sees a change.
    _nearbySidebarSignature = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isNearbyPanelOpen) return;
      final themeProvider = context.read<ThemeProvider>();
      final artworkProvider = context.read<ArtworkProvider>();
      final anchor =
          _nearbySidebarAnchor ?? _userLocation ?? _effectiveCenter;
      final filteredArtworks = _getFilteredArtworks(
        artworkProvider.artworks,
        basePositionOverride: anchor,
      );
      _syncNearbySidebarIfNeeded(
        themeProvider,
        filteredArtworks,
        basePosition: anchor,
      );
    });
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
      _handleMarkerTap(existing.first);
      return;
    }

    try {
      _perf.recordFetch('marker:get');
      final marker = await MapDataController().getArtMarkerById(markerId);
      if (!mounted) return;
      if (marker == null || !marker.hasValidPosition) return;

      setState(() {
        _artMarkers.removeWhere((m) => m.id == marker.id);
        _artMarkers.add(marker);
      });
      _moveCamera(marker.position, math.max(_effectiveZoom, 15));
      _handleMarkerTap(marker);
    } catch (_) {
      // Best-effort: keep user on map if marker fetch fails.
    }
  }

  LatLng get _effectiveCenter => _cameraCenter;
  double get _effectiveZoom => _cameraZoom;

  void _handleMapReady() {
    setState(() => _mapReady = true);
    _mapCameraController.flushQueuedIfReady();

    // Travel mode needs a bounds-based fetch once the viewport exists.
    if (_travelModeEnabled) {
      unawaited(_loadMarkersForCurrentView(force: true));
    } else if (_artMarkers.isEmpty && !_isLoadingMarkers) {
      unawaited(_loadMarkersForCurrentView(force: true));
    }
  }

  bool get _pollingEnabled => _isAppForeground && _isRouteVisible;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state != AppLifecycleState.paused &&
        state != AppLifecycleState.inactive;
    _handleActiveStateChanged();
    super.didChangeAppLifecycleState(state);
  }

  void _setRouteVisible(bool isVisible) {
    if (_isRouteVisible == isVisible) return;
    _isRouteVisible = isVisible;
    _handleActiveStateChanged();
    if (isVisible) {
      _scheduleWebMapResizeRecovery(reason: 'routeVisible');
    }
  }

  void _scheduleWebMapResizeRecovery({required String reason}) {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _mapController;
      if (controller == null) return;

      try {
        controller.forceResizeWebMap();
      } catch (_) {}
      try {
        controller.resizeWebMap();
      } catch (_) {}

      _perf.logEvent(
        'webResizeRecovery',
        extra: <String, Object?>{
          'reason': reason,
        },
      );
    });
  }

  void _handleActiveStateChanged() {
    if (_pollingEnabled) {
      _resumePolling();
    } else {
      _pausePolling();
    }
    _renderCoordinator.updateCubeSpinTicker();
  }

  void _pausePolling() {
    _mapDataCoordinator.cancelPending();
    _cubeSyncDebouncer.cancel();
    _nearbySidebarSyncTimer?.cancel();
    _nearbySidebarSyncTimer = null;
    _mapSearchController.dismissOverlay(unfocus: false);

    final createdSub = _markerStreamSub;
    if (createdSub != null) {
      try {
        createdSub.pause();
      } catch (_) {}
      _perf.subscriptionStopped('marker_socket_created');
    }
    final deletedSub = _markerDeletedSub;
    if (deletedSub != null) {
      try {
        deletedSub.pause();
      } catch (_) {}
      _perf.subscriptionStopped('marker_socket_deleted');
    }
  }

  void _resumePolling() {
    final createdSub = _markerStreamSub;
    if (createdSub != null) {
      try {
        createdSub.resume();
      } catch (_) {}
      _perf.subscriptionStarted('marker_socket_created');
    }
    final deletedSub = _markerDeletedSub;
    if (deletedSub != null) {
      try {
        deletedSub.resume();
      } catch (_) {}
      _perf.subscriptionStarted('marker_socket_deleted');
    }
    _flushPendingMarkerRefresh();
  }

  @override
  void didPushNext() {
    KubusMapRouteAwareHelpers.didPushNext(setRouteVisible: _setRouteVisible);
  }

  @override
  void didPopNext() {
    KubusMapRouteAwareHelpers.didPopNext(setRouteVisible: _setRouteVisible);
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
    _kubusMapController.attachMapController(controller);
    _layersManager = _kubusMapController.layersManager;
    _styleInitialized = false;
    _registeredMapImages.clear();
    _managedLayerIds.clear();
    _managedSourceIds.clear();
    AppConfig.debugPrint(
      'DesktopMapScreen: map created (platform=${defaultTargetPlatform.name}, web=$kIsWeb)',
    );
    _perf.logEvent('mapCreated');
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
    _registeredMapImages.clear();
    _managedLayerIds.clear();
    _managedSourceIds.clear();

    AppConfig.debugPrint('DesktopMapScreen: style init start');

    try {
      await _kubusMapController.handleStyleLoaded(
        themeSpec: MapLayersThemeSpec(
          locationFill: scheme.secondary,
          locationStroke: scheme.surface,
          pendingFill: scheme.primary,
          pendingStroke: scheme.surface,
        ),
      );

      if (!mounted) return;

      _styleInitialized = _kubusMapController.styleInitialized;
      _styleEpoch = _kubusMapController.styleEpoch;
      _lastAppliedMapThemeDark = themeProvider.isDarkMode;

      if (_styleInitialized) {
        await _applyThemeToMapStyle(themeProvider: themeProvider);
        await _applyIsometricCamera(enabled: _isometricViewEnabled);
        await _syncUserLocation(themeProvider: themeProvider);
        await _syncPendingMarker(themeProvider: themeProvider);
        await _syncMapMarkers(themeProvider: themeProvider);
        await _renderCoordinator.updateRenderMode();
      }

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

  Future<void> _syncUserLocation({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;
    if (!_managedSourceIds.contains(_locationSourceId)) return;

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
    if (!_managedSourceIds.contains(_pendingSourceId)) return;

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

  Future<void> _syncMapMarkers({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;
    if (!_managedSourceIds.contains(_markerSourceId)) return;
    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final isDark = themeProvider.isDarkMode;

    final zoom = _cameraZoom;
    final useClustering =
        zoom < _clusterMaxZoom && !_kubusMapController.hasExpandedSameLocation;
    final renderedMarkers = _kubusMapController.buildRenderedMarkers();
    final visibleMarkers = renderedMarkers
        .map((m) => m.marker)
        .toList(growable: false);
    final renderById = <String, KubusRenderedMarker>{
      for (final marker in renderedMarkers) marker.marker.id: marker,
    };
    final geoMarkers = renderedMarkers
        .map((m) => m.marker.copyWith(position: m.position))
        .toList(growable: false);

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

    final features = await kubusBuildMarkerFeatureList(
      markers: geoMarkers,
      useClustering: useClustering,
      zoom: zoom,
      clusterGridLevelForZoom: _clusterGridLevelForZoom,
      sortClustersBySizeDesc: false,
      shouldAbort: () => !mounted,
      buildMarkerFeature: (marker) => _markerFeatureFor(
        marker: marker,
        renderMarker: renderById[marker.id],
        themeProvider: themeProvider,
        scheme: scheme,
        roles: roles,
        isDark: isDark,
      ),
      buildClusterFeature: (cluster) => _clusterFeatureFor(
        cluster: cluster,
        scheme: scheme,
        roles: roles,
        isDark: isDark,
      ),
    );
    if (!mounted) return;

    final collection = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
    if (!mounted) return;
    try {
      await controller.setGeoJsonSource(_markerSourceId, collection);
    } catch (_) {
      // Best-effort: style swaps can temporarily invalidate sources.
    }

    if (_renderCoordinator.is3DModeActive) {
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

    await kubusPreregisterMarkerIcons(
      controller: controller,
      registeredMapImages: _registeredMapImages,
      markers: markers,
      isDark: isDark,
      useClustering: useClustering,
      zoom: zoom,
      clusterGridLevelForZoom: _clusterGridLevelForZoom,
      sortClustersBySizeDesc: false,
      scheme: scheme,
      roles: roles,
      pixelRatio: _markerPixelRatio(),
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      resolveMarkerBaseColor: (marker) =>
          _resolveArtMarkerColor(marker, themeProvider),
    );
  }

  Future<Map<String, dynamic>> _markerFeatureFor({
    required ArtMarker marker,
    required KubusRenderedMarker? renderMarker,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
  }) async {
    final controller = _mapController;
    if (controller == null) return const <String, dynamic>{};

    return kubusMarkerFeatureFor(
      controller: controller,
      registeredMapImages: _registeredMapImages,
      marker: marker,
      isDark: isDark,
      scheme: scheme,
      roles: roles,
      pixelRatio: _markerPixelRatio(),
      shouldAbort: () => !mounted,
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      resolveMarkerBaseColor: (m) => _resolveArtMarkerColor(m, themeProvider),
      entryScale: renderMarker?.entryScale ?? 1.0,
      entryOpacity: renderMarker?.entryOpacity ?? 1.0,
      spiderfied: renderMarker?.isSpiderfied ?? false,
      coordinateKey: renderMarker?.sameCoordinateKey,
      entrySerial: renderMarker?.entrySerial ?? 0,
    );
  }

  Future<Map<String, dynamic>> _clusterFeatureFor({
    required KubusClusterBucket cluster,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
  }) async {
    final controller = _mapController;
    if (controller == null) return const <String, dynamic>{};

    return kubusClusterFeatureFor(
      controller: controller,
      registeredMapImages: _registeredMapImages,
      cluster: cluster,
      isDark: isDark,
      scheme: scheme,
      roles: roles,
      pixelRatio: _markerPixelRatio(),
      shouldAbort: () => !mounted,
    );
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
    _mapDataCoordinator.queueMarkerRefresh(fromGesture: fromGesture);
  }

  Future<void> _applyIsometricCamera(
      {required bool enabled, bool adjustZoomForScale = false}) async {
    final nextZoom = await _mapCameraController.applyIsometricCamera(
      enabled: enabled,
      center: _cameraCenter,
      zoom: _cameraZoom,
      bearing: _lastBearing,
      adjustZoomForScale: adjustZoomForScale,
      duration: const Duration(milliseconds: 320),
    );
    if (adjustZoomForScale) {
      _cameraZoom = nextZoom;
    }
    if (!mounted) return;
    unawaited(_renderCoordinator.updateRenderMode());
  }

  Future<void> _moveCamera(LatLng target, double zoom) async {
    _cameraCenter = target;
    _cameraZoom = zoom;
    final tilt =
        _isometricViewEnabled && AppConfig.isFeatureEnabled('mapIsometricView')
            ? 54.736
            : 0.0;
    await _mapCameraController.animateTo(
      target,
      zoom: zoom,
      rotation: _lastBearing,
      tilt: tilt,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void deactivate() {
    // Detach early (top-down) so listeners are removed before the MapLibre
    // plugin disposes the controller during child disposal.
    _deactivateDetachedMapController = _mapController;
    _kubusMapController.detachMapController();
    _mapController = null;
    _layersManager = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final controller = _deactivateDetachedMapController;
    _deactivateDetachedMapController = null;
    if (controller == null || _mapController != null) return;

    _mapController = controller;
    _kubusMapController.attachMapController(controller);
    _layersManager = _kubusMapController.layersManager;
  }

  @override
  void dispose() {
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    // Avoid leaving Explore-side panels open when navigating away.
    try {
      DesktopShellScope.of(context)?.closeFunctionsPanel();
    } catch (_) {}

    _mapController = null;
    _deactivateDetachedMapController = null;
    _layersManager = null;
    _styleInitialized = false;
    _registeredMapImages.clear();
    _managedLayerIds.clear();
    _managedSourceIds.clear();
    _nearbySidebarSyncTimer?.cancel();
    _nearbySidebarSyncTimer = null;
    _animationController.dispose();
    _perf.controllerDisposed('selection_pop');
    _cubeIconSpinController.dispose();
    _perf.controllerDisposed('cube_spin');
    _panelController.dispose();
    _perf.controllerDisposed('panel');
    _cubeSyncDebouncer.dispose();
    _radiusChangeDebouncer.dispose();
    _mapViewPreferencesController
        .removeListener(_handleMapViewPreferencesChanged);
    _mapViewPreferencesController.dispose();
    _mapTutorialCoordinator.removeListener(_handleTutorialCoordinatorChanged);
    _mapTutorialCoordinator.dispose();
    _markerStreamSub?.cancel();
    _perf.subscriptionStopped('marker_socket_created');
    _markerDeletedSub?.cancel();
    _perf.subscriptionStopped('marker_socket_deleted');
    _mapSearchController.removeListener(_handleMapSearchControllerChanged);
    _mapSearchController.dispose();
    _markerStackPageController.dispose();
    _mapCameraController.dispose();
    _markerVisualSyncCoordinator.dispose();
    _mapDataCoordinator.dispose();
    _mapUiStateCoordinator.dispose();
    _kubusMapController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _perf.logSummary(
      'dispose',
      extra: <String, Object?>{
        'markerTaps': _debugMarkerTapCount,
        'styleEpoch': _styleEpoch,
      },
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _perf.recordBuild();
    _ensureNearbyPanelAutoloadScheduled();
    assert(_renderCoordinator.assertMarkerModeInvariant());
    assert(_renderCoordinator.assertRenderModeInvariant());
    final themeProvider = Provider.of<ThemeProvider>(context);
    _maybeScheduleThemeResync(themeProvider);
    final animationTheme = context.animationTheme;
    final l10n = AppLocalizations.of(context)!;
    _mapTutorialCoordinator.configure(
      bindings: _buildMapTutorialStepBindings(l10n),
    );
    final tutorialSteps = _mapTutorialCoordinator.steps;

    // Always show the nearby panel as a local overlay on top of the map
    // (glass panel with blur). This keeps the map at full width; only the
    // UI chrome (controls, search bar) shifts to avoid overlap.
    final showLocalNearbyPanel = _isRightSidebarOpen;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<MapUiStateSnapshot>(
        valueListenable: _mapUiStateCoordinator.state,
        builder: (context, ui, _) {
          final showMapTutorial = ui.tutorial.show;
          final mapTutorialIndex = ui.tutorial.index;
          final selection = ui.markerSelection;

          return Stack(
            children: [
              // Map layer
              AbsorbPointer(
                absorbing: showMapTutorial,
                child: KeyedSubtree(
                  key: _tutorialMapKey,
                  child: _buildMapLayer(
                    themeProvider,
                    selection: selection,
                  ),
                ),
              ),

              _buildSearchOverlayScaffold(
                themeProvider,
                animationTheme,
                nearbyPanelOpen: showLocalNearbyPanel,
              ),

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

              // Local nearby sidebar (only when DesktopMapScreen is opened
              // outside of DesktopShellScope).
              AnimatedPositioned(
                duration: animationTheme.medium,
                curve: animationTheme.defaultCurve,
                right: showLocalNearbyPanel ? 0 : -420,
                top: 0,
                bottom: 0,
                width: 360,
                child: KubusMapWebPointerInterceptor.wrap(
                  child: Consumer<ArtworkProvider>(
                    builder: (context, artworkProvider, _) {
                      return _buildRightSidebarContent(
                        themeProvider,
                        artworkProvider,
                      );
                    },
                  ),
                ),
              ),

              // Map controls (bottom-right) - absorb pointer events
              Positioned(
                left: _selectedArtwork != null || _selectedExhibition != null
                    ? 400
                    : 24,
                right: showLocalNearbyPanel ? (24 + 360) : 24,
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
                        child: _buildDiscoveryCard(taskProvider),
                      ),
                    ),
                  );
                },
              ),

              KubusMapTutorialOverlay(
                visible: showMapTutorial,
                steps: tutorialSteps,
                currentIndex: mapTutorialIndex,
                onNext: _mapTutorialCoordinator.next,
                onBack: _mapTutorialCoordinator.back,
                onSkip: () => unawaited(_mapTutorialCoordinator.dismiss()),
                skipLabel: l10n.commonSkip,
                backLabel: l10n.commonBack,
                nextLabel: l10n.commonNext,
                doneLabel: l10n.commonDone,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapLayer(
    ThemeProvider themeProvider, {
    required MapMarkerSelectionState selection,
  }) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        // The nearby art panel is rendered as a local overlay in the map's
        // Stack (not via DesktopShell functions panel), so it auto-updates
        // through the normal build cycle. No explicit sync needed here.

        final isDark = themeProvider.isDarkMode;
        final tileProviders =
            Provider.of<TileProviders?>(context, listen: false);
        final styleAsset = tileProviders?.mapStyleAsset(isDarkMode: isDark) ??
            MapStyleService.primaryStyleRef(isDarkMode: isDark);

        final map = MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: KeyedSubtree(
            key: _mapViewKey,
            child: ArtMapView(
              initialCenter: _effectiveCenter,
              initialZoom: _cameraZoom,
              minZoom: 3.0,
              maxZoom: 24.0,
              isDarkMode: isDark,
              styleAsset: styleAsset,
              attributionButtonPosition:
                  ml.AttributionButtonPosition.bottomLeft,
              onMapCreated: _handleMapCreated,
              onStyleLoaded: () {
                AppConfig.debugPrint(
                  'DesktopMapScreen: onStyleLoadedCallback (dark=$isDark, style="$styleAsset")',
                );
                unawaited(_handleMapStyleLoaded(themeProvider)
                    .then((_) => _handleMapReady()));
              },
              onCameraMove: (position) {
                if (_mapController == null) return;
                _kubusMapController.handleCameraMove(position);

                final previousZoom = _cameraZoom;
                final nextBearing = position.bearing;
                _cameraCenter = LatLng(
                  position.target.latitude,
                  position.target.longitude,
                );
                _cameraZoom = position.zoom;
                _lastBearing = nextBearing;
                _lastPitch = position.tilt;

                final zoomChanged =
                    (position.zoom - previousZoom).abs() > 0.001;
                if (_styleInitialized && zoomChanged) {
                  _queueMarkerVisualRefreshForZoom(position.zoom);
                }

                final shouldShowCubes = _renderCoordinator.is3DModeActive;
                if (shouldShowCubes != _renderCoordinator.cubeLayerVisible) {
                  unawaited(_renderCoordinator.updateRenderMode());
                }

                final bucket = MapViewportUtils.zoomBucket(position.zoom);
                final bucketChanged = bucket != _renderZoomBucket;
                // Throttle setState for 3D overlay repaints to ~60fps max
                final now = DateTime.now();
                final shouldUpdate = _isometricViewEnabled &&
                    now.difference(_lastCameraUpdateTime) >
                        _cameraUpdateThrottle;
                if (bucketChanged || shouldUpdate) {
                  _lastCameraUpdateTime = now;
                  _safeSetState(() => _renderZoomBucket = bucket);
                }
                if (bucketChanged && _renderCoordinator.is3DModeActive) {
                  _cubeSyncDebouncer(const Duration(milliseconds: 60), () {
                    unawaited(_syncMarkerCubes(themeProvider: themeProvider));
                  });
                }

                final hasGesture = !_kubusMapController.programmaticCameraMove;
                _queueMarkerRefresh(fromGesture: hasGesture);
              },
              onCameraIdle: () {
                if (_mapController == null) return;
                final wasProgrammatic =
                    _kubusMapController.programmaticCameraMove;
                _kubusMapController.handleCameraIdle(
                  fromProgrammaticMove: wasProgrammatic,
                );
                if (_styleInitialized) {
                  _queueMarkerVisualRefreshForZoom(_cameraZoom);
                  unawaited(_renderCoordinator.updateRenderMode());
                }
                if (_isNearbyPanelOpen && _userLocation == null) {
                  _nearbySidebarAnchor = _effectiveCenter;
                  _forceNearbySidebarSync();
                }
                _queueMarkerRefresh(fromGesture: false);
              },
              onMapClick: (dynamic point, _) {
                unawaited(
                  _markerInteractionController.handleMapClick(point),
                );
              },
              onMapLongClick: (_, point) {
                _kubusMapController.dismissSelection();
                setState(() {
                  _pendingMarkerLocation = point;
                });
                unawaited(_syncPendingMarker(themeProvider: themeProvider));
                _startMarkerCreationFlow(position: point);
              },
            ),
          ),
        );

        // Use StackFit.expand to ensure bounded constraints for Positioned.fill
        // children (especially the marker overlay layer).
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: map),
            ValueListenableBuilder<Offset?>(
              valueListenable: _selectedMarkerAnchorNotifier,
              builder: (context, markerAnchor, _) {
                if (_markerOverlayMode != _MarkerOverlayMode.anchored ||
                    markerAnchor == null) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: markerAnchor.dx,
                  top: markerAnchor.dy,
                  child: CompositedTransformTarget(
                    link: _markerOverlayLink,
                    child: const SizedBox(width: 1, height: 1),
                  ),
                );
              },
            ),
            _buildMarkerOverlayLayer(
              themeProvider: themeProvider,
              artworkProvider: artworkProvider,
              selection: selection,
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
        _userLocationAccuracyMeters = position.accuracy;
        _userLocationTimestampMs = position.timestamp.millisecondsSinceEpoch;
        if (_autoFollow) {
          _cameraCenter = current;
        }
      });
      unawaited(_syncUserLocation(themeProvider: themeProvider));

      final selectedMarker = _kubusMapController.selectedMarkerData;
      if (selectedMarker != null) {
        context.read<AttendanceProvider>().updateProximity(
              markerId: selectedMarker.id,
              lat: current.latitude,
              lng: current.longitude,
              distanceMeters:
                  _calculateDistance(current, selectedMarker.position),
              activationRadiusMeters: selectedMarker.activationRadius,
              requiresProximity: selectedMarker.requiresProximity,
              accuracyMeters: _userLocationAccuracyMeters,
              timestampMs: _userLocationTimestampMs,
            );
      }
      if (animate || _autoFollow) {
        _moveCamera(current, math.max(_effectiveZoom, 15));
      }
    } catch (e) {
      AppConfig.debugPrint('DesktopMapScreen: location fetch failed: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Widget _buildSearchOverlayScaffold(
    ThemeProvider themeProvider,
    AppAnimationTheme animationTheme, {
    required bool nearbyPanelOpen,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _mapSearchController,
      builder: (context, _) {
        final state = _mapSearchController.state;
        final trimmed = state.query.trim();
        final shouldShow = state.isOverlayVisible &&
            (state.isFetching ||
                state.suggestions.isNotEmpty ||
                trimmed.length >= _mapSearchController.minChars);

        return KubusSearchOverlayScaffold(
          layout: KubusSearchOverlayLayout.sidePanel,
          sidePanelAnimated: true,
          positionAnimationDuration: animationTheme.medium,
          positionAnimationCurve: animationTheme.defaultCurve,
          panelInsets: const EdgeInsets.fromLTRB(
            KubusSpacing.lg,
            KubusSpacing.sm + KubusSpacing.xs,
            KubusSpacing.lg,
            0,
          ),
          rightInset: nearbyPanelOpen ? 360 : 0,
          leading: Row(
            children: [
              const AppLogo(
                width: KubusSpacing.xl + KubusSpacing.xs,
                height: KubusSpacing.xl + KubusSpacing.xs,
              ),
              const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
              Text(
                l10n.desktopMapTitleDiscover,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
          searchField: _buildDesktopSearchField(l10n),
          searchFieldLink: _mapSearchController.fieldLink,
          filterChips: _buildDesktopFilterChipRow(themeProvider),
          mapToggle: KeyedSubtree(
            key: _tutorialFiltersButtonKey,
            child: KubusGlassIconButton(
              icon: _showFiltersPanel ? Icons.close : Icons.tune,
              tooltip:
                  _showFiltersPanel ? l10n.commonClose : l10n.mapFiltersTitle,
              active: _showFiltersPanel,
              accentColor: themeProvider.accentColor,
              borderRadius: 10,
              onPressed: () {
                setState(() {
                  _showFiltersPanel = !_showFiltersPanel;
                  _selectedArtwork = null;
                  _selectedExhibition = null;
                });
              },
              tooltipPreferBelow: true,
              tooltipVerticalOffset: 18,
              tooltipMargin: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
          showSuggestions: shouldShow,
          query: state.query,
          isFetching: state.isFetching,
          suggestions: state.suggestions,
          accentColor: themeProvider.accentColor,
          minCharsHint: l10n.mapSearchMinCharsHint,
          noResultsText: l10n.commonNoResultsFound,
          onDismissSuggestions: () {
            _mapSearchController.dismissOverlay(unfocus: false);
          },
          onSuggestionTap: _handleSuggestionTap,
        );
      },
    );
  }

  Widget _buildDesktopSearchField(AppLocalizations l10n) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: CompositedTransformTarget(
        link: _mapSearchController.fieldLink,
        child: KeyedSubtree(
          key: _tutorialSearchKey,
          child: Semantics(
            label: 'map_search_input',
            textField: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: DesktopSearchBar(
                controller: _mapSearchController.textController,
                focusNode: _mapSearchController.focusNode,
                hintText: l10n.mapSearchHint,
                onChanged: (value) {
                  _mapSearchController.onQueryChanged(
                    context,
                    value,
                  );
                },
                onSubmitted: _handleSearchSubmit,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFilterChipRow(ThemeProvider themeProvider) {
    return KeyedSubtree(
      key: _tutorialFilterChipsKey,
      child: Row(
        children: _filterOptions.map((filter) {
          final isActive = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(left: KubusSpacing.sm),
            child: KubusGlassChip(
              label: _getFilterLabel(filter),
              icon: Icons.filter_alt_outlined,
              active: isActive,
              accentColor: themeProvider.accentColor,
              borderRadius: 10,
              onPressed: () {
                setState(() => _selectedFilter = filter);
                // Reload markers so the nearby panel and
                // sidebar reflect the new filter immediately.
                unawaited(_loadMarkersForCurrentView(force: true).then((_) {
                  if (!mounted) return;
                  _requestMarkerVisualSync(force: true);
                }));
                // Force immediate sidebar sync for the shell-scope nearby panel.
                _forceNearbySidebarSync();
              },
            ),
          );
        }).toList(),
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
      metadata:
          _kubusMapController.selectedMarkerData?.metadata ?? artwork.metadata,
    );
    final distanceLabel = _formatDistanceToArtwork(artwork);
    final arBadge = artwork.arEnabled
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          )
        : null;

    return KubusDetailPanel(
      kind: DetailPanelKind.artwork,
      presentation: PanelPresentation.sidePanel,
      margin: const EdgeInsets.only(left: 24),
      header: DetailHeader(
        imageUrl: coverUrl,
        imageVersion: KubusCachedImage.versionTokenFromDate(
          artwork.updatedAt ?? artwork.createdAt,
        ),
        accentColor: accent,
        closeTooltip: AppLocalizations.of(context)!.commonClose,
        onClose: () {
          setState(() => _selectedArtwork = null);
        },
        badge: arBadge,
        closeAccentColor: themeProvider.accentColor,
        fallbackIcon: Icons.image_not_supported,
      ),
      sections: [
        Padding(
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
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _buildDetailStat(Icons.favorite, '${artwork.likesCount}'),
                  _buildDetailStat(Icons.visibility, '${artwork.viewsCount}'),
                  if (artwork.discoveryCount > 0)
                    _buildDetailStat(
                      Icons.explore,
                      AppLocalizations.of(context)!
                          .desktopMapDiscoveriesCount(artwork.discoveryCount),
                    ),
                  if (artwork.actualRewards > 0)
                    _buildDetailStat(
                      Icons.token,
                      '${artwork.actualRewards} KUB8',
                    ),
                  if (distanceLabel != null)
                    _buildDetailStat(Icons.location_on, distanceLabel),
                ],
              ),
              const SizedBox(height: 24),
              DetailActionRow(
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
                                content: Text(l10n.desktopMapNoArAssetToast),
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
                        label: Text(AppLocalizations.of(context)!.commonViewInAr),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: AppColorUtils.contrastText(accent),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
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
                          openArtwork(
                            context,
                            artwork.id,
                            source: 'desktop_map',
                            attendanceMarkerId: artwork.arMarkerId,
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: Text(AppLocalizations.of(context)!.commonViewDetails),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
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
                          vertical: 14,
                          horizontal: 12,
                        ),
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
                        foregroundColor:
                            (artwork.isFavoriteByCurrentUser || artwork.isFavorite)
                                ? accent
                                : scheme.onSurface,
                        backgroundColor:
                            (artwork.isFavoriteByCurrentUser || artwork.isFavorite)
                                ? accent.withValues(alpha: 0.08)
                                : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  KubusGlassIconButton(
                    icon: artwork.isLikedByCurrentUser
                        ? Icons.favorite
                        : Icons.favorite_border,
                    tooltip:
                        '${artwork.likesCount} ${artwork.isLikedByCurrentUser ? AppLocalizations.of(context)!.artworkDetailLiked : AppLocalizations.of(context)!.artworkDetailLike}',
                    active: artwork.isLikedByCurrentUser,
                    accentColor: themeProvider.accentColor,
                    activeTint: scheme.error.withValues(alpha: 0.18),
                    activeIconColor: scheme.error,
                    onPressed: () {
                      unawaited(artworkProvider.toggleLike(artwork.id));
                    },
                  ),
                  KubusGlassIconButton(
                    icon: Icons.share,
                    accentColor: themeProvider.accentColor,
                    tooltip: AppLocalizations.of(context)!.commonShare,
                    onPressed: () {
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
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=${artwork.position.latitude},${artwork.position.longitude}',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.directions),
                label: Text(AppLocalizations.of(context)!.commonGetDirections),
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
      ],
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
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );

    return KubusDetailPanel(
      kind: DetailPanelKind.exhibition,
      presentation: PanelPresentation.sidePanel,
      margin: const EdgeInsets.only(left: 24),
      header: DetailHeader(
        imageUrl: coverUrl,
        imageVersion: KubusCachedImage.versionTokenFromDate(
          exhibition.updatedAt ?? exhibition.createdAt,
        ),
        accentColor: exhibitionAccent,
        closeTooltip: l10n.commonClose,
        onClose: () {
          setState(() => _selectedExhibition = null);
        },
        badge: badge,
        closeAccentColor: themeProvider.accentColor,
        fallbackIcon: Icons.museum,
      ),
      sections: [
        Padding(
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
              if (dateRange != null)
                DetailMetaRow(
                  icon: Icons.schedule,
                  label: dateRange,
                ),
              if (location != null)
                DetailMetaRow(
                  icon: Icons.place_outlined,
                  label: location,
                ),
              DetailMetaRow(
                icon: Icons.event_available_outlined,
                label: 'Status: ${_labelForExhibitionStatus(exhibition.status)}',
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
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final attendanceMarkerId =
                            _kubusMapController.selectedMarkerData?.id;
                        final shellScope = DesktopShellScope.of(context);
                        if (shellScope != null) {
                          shellScope.pushScreen(
                            DesktopSubScreen(
                              title: exhibition.title,
                              child: ExhibitionDetailScreen(
                                exhibitionId: exhibition.id,
                                attendanceMarkerId: attendanceMarkerId,
                              ),
                            ),
                          );
                        } else {
                          unawaited(Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExhibitionDetailScreen(
                                exhibitionId: exhibition.id,
                                attendanceMarkerId: attendanceMarkerId,
                              ),
                            ),
                          ));
                        }
                      },
                      icon: Icon(AppColorUtils.exhibitionIcon, size: 20),
                      label: Text(l10n.commonViewDetails),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: exhibitionAccent,
                        foregroundColor:
                            ThemeData.estimateBrightnessForColor(exhibitionAccent) ==
                                    Brightness.dark
                                ? KubusColors.textPrimaryDark
                                : KubusColors.textPrimaryLight,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
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
                      'https://www.google.com/maps/dir/?api=1&destination=${exhibition.lat},${exhibition.lng}',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      ],
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
    return KubusFilterPanel(
      title: l10n.mapFiltersTitle,
      onClose: () => setState(() => _showFiltersPanel = false),
      closeTooltip: l10n.commonClose,
      margin: const EdgeInsets.only(left: 24),
      contentPadding: const EdgeInsets.all(24),
      expandContent: true,
      absorbPointer: true,
      showFooterDivider: true,
      footer: Padding(
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
                  _kubusMapController
                      .setMarkerTypeVisibility(_markerLayerVisibility);
                  _renderCoordinator.requestStyleUpdate(force: true);
                  _requestMarkerVisualSync(force: true);
                  _forceNearbySidebarSync();
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
                  _requestMarkerVisualSync(force: true);
                  _forceNearbySidebarSync();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mapNearbyRadiusTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
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
                          _radiusChangeDebouncer(
                            const Duration(
                              milliseconds:
                                  MapMarkerCollisionConfig.nearbyRadiusDebounceMs,
                            ),
                            () {
                              if (mounted) {
                                unawaited(
                                  _loadMarkersForCurrentView(
                                    force: true,
                                  ),
                                );
                                _forceNearbySidebarSync();
                              }
                            },
                          );
                        },
                  activeColor: themeProvider.accentColor,
                ),
              ),
              LiquidGlassPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(10),
                blurSigma: KubusGlassEffects.blurSigmaLight,
                backgroundColor:
                    scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12),
                showBorder: true,
                child: Text(
                  l10n.commonDistanceKm(
                    _searchRadius.toStringAsFixed(1),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.mapLayersTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          KubusMapMarkerLayerChips(
            l10n: l10n,
            visibility: _markerLayerVisibility,
            onToggle: (type, nextSelected) {
              setState(
                () => _markerLayerVisibility[type] = nextSelected,
              );
              _kubusMapController.setMarkerTypeVisibility(_markerLayerVisibility);
              _renderCoordinator.requestStyleUpdate(force: true);
              _requestMarkerVisualSync(force: true);
              _forceNearbySidebarSync();
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.desktopMapSortByTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          KubusSortOption(
            label: l10n.desktopMapSortDistance,
            icon: Icons.near_me,
            selected: _selectedSort == 'distance',
            accentColor: themeProvider.accentColor,
            onPressed: () => setState(() => _selectedSort = 'distance'),
          ),
          KubusSortOption(
            label: l10n.desktopMapSortPopularity,
            icon: Icons.trending_up,
            selected: _selectedSort == 'popularity',
            accentColor: themeProvider.accentColor,
            onPressed: () => setState(() => _selectedSort = 'popularity'),
          ),
          KubusSortOption(
            label: l10n.desktopMapSortNewest,
            icon: Icons.schedule,
            selected: _selectedSort == 'newest',
            accentColor: themeProvider.accentColor,
            onPressed: () => setState(() => _selectedSort = 'newest'),
          ),
          KubusSortOption(
            label: l10n.desktopMapSortRating,
            icon: Icons.star,
            selected: _selectedSort == 'rating',
            accentColor: themeProvider.accentColor,
            onPressed: () => setState(() => _selectedSort = 'rating'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;

    return KubusMapControls(
      controller: _kubusMapController,
      layout: KubusMapPrimaryControlsLayout.desktopToolbar,
      accentColor: themeProvider.accentColor,
      onCenterOnMe: () {
        _kubusMapController.setAutoFollow(true);
        _refreshUserLocation(animate: true);
        if (_userLocation == null) {
          unawaited(_moveCamera(const LatLng(46.0569, 14.5058), 15.0));
        }
      },
      centerOnMeActive: _autoFollow,
      centerOnMeTooltip: l10n.mapCenterOnMeTooltip,
      onCreateMarker: () {
        if (_rightSidebarContent == _RightSidebarContent.createMarker) {
          _handleMarkerFormCancel();
          return;
        }
        final target = _pendingMarkerLocation ?? _effectiveCenter;
        _startMarkerCreationFlow(position: target);
      },
      createMarkerTooltip: l10n.mapCreateMarkerHereTooltip,
      createMarkerHighlighted:
          _rightSidebarContent == _RightSidebarContent.createMarker,
      showTravelModeToggle: AppConfig.isFeatureEnabled('mapTravelMode'),
      travelModeActive: _travelModeEnabled,
      onToggleTravelMode: () =>
          unawaited(_setTravelModeEnabled(!_travelModeEnabled)),
      travelModeKey: _tutorialTravelButtonKey,
      travelModeTooltip: l10n.mapTravelModeTooltip,
      showIsometricViewToggle: AppConfig.isFeatureEnabled('mapIsometricView'),
      isometricViewActive: _isometricViewEnabled,
      onToggleIsometricView: () =>
          unawaited(_setIsometricViewEnabled(!_isometricViewEnabled)),
      isometricViewTooltipWhenActive: l10n.mapIsometricViewDisableTooltip,
      isometricViewTooltipWhenInactive: l10n.mapIsometricViewEnableTooltip,
      showNearbyToggle: true,
      nearbyActive: _isNearbyPanelOpen,
      onToggleNearby:
          _isNearbyPanelOpen ? _closeNearbyArtPanel : _openNearbyArtPanel,
      nearbyKey: _tutorialNearbyButtonKey,
      nearbyTooltipWhenActive: l10n.commonClose,
      nearbyTooltipWhenInactive: l10n.arNearbyArtworksTitle,
      zoomOutTooltip: l10n.mapEmptyZoomOutAction,
      zoomInTooltip: 'Zoom in',
      resetBearingTooltip: l10n.mapResetBearingTooltip,
    );
  }

  Widget _buildDiscoveryCard(TaskProvider taskProvider) {
    final activeProgress = taskProvider.getActiveTaskProgress();
    if (activeProgress.isEmpty) return const SizedBox.shrink();

    final showTasks = _isDiscoveryExpanded;
    final tasksToRender = showTasks ? activeProgress : const <TaskProgress>[];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overall = taskProvider.getOverallProgress();

    return KubusDiscoveryCard(
      overallProgress: overall,
      expanded: _isDiscoveryExpanded,
      taskRows: [
        for (final progress in tasksToRender) _buildTaskProgressRow(progress),
      ],
      onToggleExpanded: () =>
          setState(() => _isDiscoveryExpanded = !_isDiscoveryExpanded),
      titleStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      percentStyle: KubusTypography.textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.75),
      ),
      glassPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 340),
      enableMouseRegion: true,
      mouseCursor: SystemMouseCursors.basic,
      badgeGap: 12,
      tasksTopGap: 12,
    );
  }

  Widget _buildTaskProgressRow(TaskProgress progress) {
    return KubusMapTaskProgressRow.build(context: context, progress: progress);
  }

  Widget _buildRightSidebarContent(
    ThemeProvider themeProvider,
    ArtworkProvider artworkProvider,
  ) {
    if (_rightSidebarContent == _RightSidebarContent.createMarker) {
      return Semantics(
        label: 'create_marker_sidebar_panel',
        container: true,
        child: _buildCreateMarkerSidebar(),
      );
    }
    // Default: nearby art panel
    final nearbyBasePosition =
        _nearbySidebarAnchor ?? _userLocation ?? _effectiveCenter;
    final filteredArtworks = _getFilteredArtworks(
      artworkProvider.artworks,
      basePositionOverride: nearbyBasePosition,
    );
    final isLoadingArtworks = artworkProvider.isLoading('load_artworks');
    return Semantics(
      label: 'nearby_sidebar_panel',
      container: true,
      child: MapOverlayBlocker(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: _buildNearbyArtSidebar(
            themeProvider,
            filteredArtworks,
            basePosition: nearbyBasePosition,
            isLoading: isLoadingArtworks,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateMarkerSidebar() {
    final subjectData = _createMarkerSubjectData;
    if (subjectData == null) return const SizedBox.shrink();

    return KubusCreateMarkerPanel(
      key: const ValueKey<String>('kubus_create_marker_panel_desktop'),
      subjectData: subjectData,
      onRefreshSubjects: ({bool force = false}) =>
          _refreshMarkerSubjectData(force: force),
      initialPosition: _createMarkerPosition ?? _effectiveCenter,
      allowManualPosition: true,
      mapCenter: _effectiveCenter,
      onUseMapCenter: () {
        final center = _effectiveCenter;
        setState(() {
          _pendingMarkerLocation = center;
          _createMarkerPosition = center;
        });
        _kubusMapController.dismissSelection();
      },
      initialSubjectType: _createMarkerInitialType ?? MarkerSubjectType.artwork,
      allowedSubjectTypes: _createMarkerAllowedTypes,
      blockedArtworkIds: _artMarkers
          .where((m) => (m.artworkId ?? '').isNotEmpty)
          .map((m) => m.artworkId!)
          .toSet(),
      onSubmit: _handleMarkerFormSubmit,
      onCancel: _handleMarkerFormCancel,
    );
  }

  Future<void> _handleMarkerFormSubmit(MapMarkerFormResult result) async {
    final targetPosition = _createMarkerPosition ?? _effectiveCenter;
    final selectedPosition = result.positionOverride ?? targetPosition;

    // Close the sidebar.
    _safeSetState(() {
      _rightSidebarContent = null;
      _createMarkerSubjectData = null;
      _createMarkerAllowedTypes = null;
      _createMarkerInitialType = null;
      _createMarkerPosition = null;
      _pendingMarkerLocation = null;
    });

    final themeProvider = context.read<ThemeProvider>();
    unawaited(_syncPendingMarker(themeProvider: themeProvider));

    final success = await _createMarkerAtPosition(
      position: selectedPosition,
      form: result,
    );

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerCreatedToast)),
        tone: KubusSnackBarTone.success,
      );
      await _loadMarkersForCurrentView(force: true);
    } else {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerCreateFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  void _handleMarkerFormCancel() {
    _safeSetState(() {
      _rightSidebarContent = null;
      _createMarkerSubjectData = null;
      _createMarkerAllowedTypes = null;
      _createMarkerInitialType = null;
      _createMarkerPosition = null;
      _pendingMarkerLocation = null;
    });
    final themeProvider = context.read<ThemeProvider>();
    unawaited(_syncPendingMarker(themeProvider: themeProvider));
  }

  Widget _buildNearbyArtSidebar(
    ThemeProvider themeProvider,
    List<Artwork> artworks, {
    LatLng? basePosition,
    required bool isLoading,
  }) {
    final base = basePosition ??
        _nearbySidebarAnchor ??
        _userLocation ??
        _effectiveCenter;

    return KubusNearbyArtPanel(
      key: const ValueKey<String>('kubus_nearby_art_panel_desktop'),
      controller: _nearbyArtController,
      layout: KubusNearbyArtPanelLayout.desktopSidePanel,
      artworks: artworks,
      markers: _artMarkers,
      basePosition: base,
      isLoading: isLoading,
      travelModeEnabled: _travelModeEnabled,
      radiusKm: _effectiveSearchRadiusKm,
      onClose: _closeNearbyArtPanel,
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

  void _handleMapSearchControllerChanged() {
    if (!mounted) return;
    // Rebuild to apply query-based filtering (lists/panels) in addition to the overlay.
    _perf.recordSetState('map_search');
    _safeSetState(() {});
  }

  void _handleSearchSubmit(String value) {
    final trimmed = value.trim();
    if (trimmed != _mapSearchController.textController.text) {
      _mapSearchController.textController.text = trimmed;
      _mapSearchController.textController.selection =
          TextSelection.collapsed(offset: trimmed.length);
      _mapSearchController.onQueryChanged(context, trimmed);
    }
    _mapSearchController.onSubmitted();
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
    _mapSearchController.textController.text = suggestion.label;
    _mapSearchController.textController.selection =
        TextSelection.collapsed(offset: suggestion.label.length);
    // Sync controller state without leaving a pending debounced fetch.
    _mapSearchController.onQueryChanged(context, suggestion.label);
    _mapSearchController.dismissOverlay(unfocus: true);

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

  String _markerQueryFiltersKey() {
    final query = _mapSearchController.state.query.trim().toLowerCase();
    return 'filter=$_selectedFilter|sort=$_selectedSort|query=$query|travel=${_travelModeEnabled ? 1 : 0}';
  }

  Set<String> _visibleArtworkIdsFromLoadedMarkers() {
    final ids = <String>{};
    for (final marker in _artMarkers) {
      if (!marker.hasValidPosition) continue;
      if (!(_markerLayerVisibility[marker.type] ?? true)) continue;
      final artworkId = marker.artworkId?.trim();
      if (artworkId == null || artworkId.isEmpty) continue;
      ids.add(artworkId);
    }
    return ids;
  }

  List<Artwork> _getFilteredArtworks(
    List<Artwork> artworks, {
    LatLng? basePositionOverride,
  }) {
    final visibleArtworkIds = _visibleArtworkIdsFromLoadedMarkers();
    final enforceMarkerScope = _artMarkers.isNotEmpty;
    var filtered = artworks
        .where((a) =>
            a.hasValidLocation &&
            (!enforceMarkerScope || visibleArtworkIds.contains(a.id)))
        .toList();
    final query = _mapSearchController.state.query.trim().toLowerCase();
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
    return KubusMapMarkerHelpers.markersEquivalent(current, next);
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
    final dev.TimelineTask? timeline = MapPerformanceDebug.isEnabled
        ? (dev.TimelineTask()..start('DesktopMapScreen.loadMarkers'))
        : null;

    try {
      final int? travelLimit = bucket == null
          ? null
          : MapViewportUtils.markerLimitForZoomBucket(bucket);

      _perf.recordFetch(
        (_travelModeEnabled && queryBounds != null)
            ? 'markers:bounds'
            : 'markers:radius',
      );
      final result = (_travelModeEnabled && queryBounds != null)
          ? await MapMarkerHelper.loadAndHydrateMarkersInBounds(
              artworkProvider: artworkProvider,
              mapMarkerService: _mapMarkerService,
              center: queryCenter,
              bounds: queryBounds,
              limit: travelLimit,
              forceRefresh: force,
              zoomBucket: bucket,
              filtersKey: _markerQueryFiltersKey(),
            )
          : await MapMarkerHelper.loadAndHydrateMarkers(
              artworkProvider: artworkProvider,
              mapMarkerService: _mapMarkerService,
              center: queryCenter,
              radiusKm: _effectiveSearchRadiusKm,
              limit: _travelModeEnabled ? travelLimit : null,
              forceRefresh: force,
              zoomBucket: bucket,
              filtersKey: _markerQueryFiltersKey(),
            );
      if (!mounted) return;
      if (requestId != _markerRequestId) return;

      final merged = ArtMarkerListDiff.mergeById(
        current: _artMarkers,
        next: result.markers,
      );

      final markersChanged = !_markersEquivalent(_artMarkers, merged);

      if (markersChanged) {
        setState(() {
          _artMarkers = merged;
        });
      }

      // Keep the shared map controller's marker list in sync so hit testing and
      // stacked-marker selection stays correct. The controller will refresh the
      // selected marker/stack and schedule an anchor refresh when needed.
      _kubusMapController.setMarkers(merged);

      if (markersChanged) {
        unawaited(_syncMapMarkers(themeProvider: themeProvider));
      }
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
      timeline?.finish();
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

  void _syncMarkerStackPager({int? targetIndex}) {
    if (!_markerStackPageController.hasClients) return;
    final stack = _kubusMapController.selectedMarkerStack;
    if (stack.length <= 1) return;
    final desired =
        (targetIndex ?? _kubusMapController.selectedMarkerStackIndex)
            .clamp(0, stack.length - 1);
    final current = _markerStackPageController.page?.round();
    if (current == desired) return;
    _markerStackPagerSyncing = true;
    try {
      _markerStackPageController.jumpToPage(desired);
    } catch (_) {
      // Ignore pager sync failures when the controller detaches mid-frame.
    } finally {
      _markerStackPagerSyncing = false;
    }
  }

  Future<void> _animateMarkerStackToIndex(int index) async {
    final stack = _kubusMapController.selectedMarkerStack;
    if (stack.length <= 1) return;
    final desired = index.clamp(0, stack.length - 1);

    if (!_markerStackPageController.hasClients) {
      _handleMarkerStackPageChanged(desired);
      return;
    }

    try {
      await _markerStackPageController.animateToPage(
        desired,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // Fall back to state update if the controller is not attached.
      _handleMarkerStackPageChanged(desired);
    }
  }

  void _handleMarkerStackPageChanged(int index) {
    if (_markerStackPagerSyncing) return;
    final stack = _kubusMapController.selectedMarkerStack;
    if (stack.length <= 1) return;
    final desired = index.clamp(0, stack.length - 1);
    if (desired == _kubusMapController.selectedMarkerStackIndex) return;
    final marker = stack[desired];

    // Keep shared controller selection state in sync without triggering a new
    // selection token (no haptics/focus).
    _kubusMapController.setSelectedStackIndex(desired);

    final userLocation = _userLocation;
    if (userLocation != null) {
      context.read<AttendanceProvider>().updateProximity(
            markerId: marker.id,
            lat: userLocation.latitude,
            lng: userLocation.longitude,
            distanceMeters: _calculateDistance(userLocation, marker.position),
            activationRadiusMeters: marker.activationRadius,
            requiresProximity: marker.requiresProximity,
            accuracyMeters: _userLocationAccuracyMeters,
            timestampMs: _userLocationTimestampMs,
          );
    }
    unawaited(_ensureLinkedArtworkLoaded(marker, allowAutoSelect: false));
  }

  void _handleMarkerTap(
    ArtMarker marker, {
    _MarkerOverlayMode overlayMode = _MarkerOverlayMode.anchored,
  }) {
    _markerInteractionController.handleMarkerTap(
      marker,
      beforeSelect: () {
        if (kDebugMode) {
          _debugMarkerTapCount += 1;
          if (_debugMarkerTapCount % 30 == 0) {
            AppConfig.debugPrint(
              'DesktopMapScreen: marker taps=$_debugMarkerTapCount',
            );
          }
        }

        // Desktop UX: open the marker overlay anchored above the marker.
        if (_markerStackPageController.hasClients) {
          _markerStackPagerSyncing = true;
          try {
            _markerStackPageController.jumpToPage(0);
          } catch (_) {
            // Ignore pager reset failures when detaching/attaching between selections.
          } finally {
            _markerStackPagerSyncing = false;
          }
        }
        _perf.recordSetState('markerTap');
        setState(() {
          _markerOverlayMode = overlayMode;
        });
      },
    );
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

    final existingIndex = _artMarkers.indexWhere((m) => m.id == marker.id);
    final scope = _resolveMarkerScope(marker);
    if (scope == _MarkerSocketScope.outOfScope && existingIndex < 0) {
      return;
    }

    var changed = false;
    setState(() {
      final next = List<ArtMarker>.from(_artMarkers, growable: true);
      if (scope == _MarkerSocketScope.outOfScope) {
        if (existingIndex >= 0) {
          next.removeAt(existingIndex);
          changed = true;
        }
      } else if (existingIndex >= 0) {
        next[existingIndex] = marker;
        changed = true;
      } else if (scope == _MarkerSocketScope.inScope) {
        next.add(marker);
        changed = true;
      }
      if (changed) {
        _artMarkers = next;
      }
    });
    if (!changed) return;
    _kubusMapController.setMarkers(_artMarkers);
    unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
  }

  _MarkerSocketScope _resolveMarkerScope(ArtMarker marker) {
    if (_travelModeEnabled) {
      final loadedBounds = _loadedTravelBounds;
      if (loadedBounds == null) return _MarkerSocketScope.unknown;
      return MapViewportUtils.containsPoint(loadedBounds, marker.position)
          ? _MarkerSocketScope.inScope
          : _MarkerSocketScope.outOfScope;
    }

    final withinRadius =
        _distance.as(LengthUnit.Kilometer, _cameraCenter, marker.position) <=
            (_effectiveSearchRadiusKm + 0.5);
    return withinRadius
        ? _MarkerSocketScope.inScope
        : _MarkerSocketScope.outOfScope;
  }

  void _handleMarkerDeleted(String markerId) {
    if (!mounted) return;

    try {
      setState(() {
        _artMarkers.removeWhere((m) => m.id == markerId);
      });
    } catch (_) {
      // Best-effort; state may be tearing down.
      return;
    }

    _kubusMapController.setMarkers(_artMarkers);
    _renderCoordinator.requestStyleUpdate(force: true);
    unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
  }

  Future<void> _syncMarkerCubes({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;
    if (!_managedSourceIds.contains(_cubeSourceId)) return;
    if (!mounted) return;
    if (!_renderCoordinator.is3DModeActive) return;

    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final zoom = _cameraZoom;
    final renderedMarkers = _kubusMapController.buildRenderedMarkers();
    final visibleMarkers = renderedMarkers
        .map((m) => m.marker.copyWith(position: m.position))
        .toList(growable: false);

    final cubeFeatures = <Map<String, dynamic>>[];
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
      final heightMeters = fullSizeMeters * 0.90;
      final colorHex = MarkerCubeGeometry.toHex(baseColor);

      cubeFeatures.add(
        MarkerCubeGeometry.cubeFeatureForMarkerWithMeters(
          marker: marker,
          colorHex: colorHex,
          sizeMeters: fullSizeMeters,
          heightMeters: heightMeters,
          kind: 'cube',
        ),
      );
    }

    final cubeCollection = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': cubeFeatures,
    };

    if (!mounted) return;
    await controller.setGeoJsonSource(_cubeSourceId, cubeCollection);
  }

  Widget _buildMarkerOverlayCard(
    ArtMarker marker,
    Artwork? artwork,
    ThemeProvider themeProvider, {
    required int stackCount,
    required int stackIndex,
    VoidCallback? onNextStacked,
    VoidCallback? onPreviousStacked,
    ValueChanged<int>? onSelectStackIndex,
  }) {
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
    final displayTitle = canPresentExhibition && exhibitionTitle.isNotEmpty
        ? exhibitionTitle
        : (artwork?.title.isNotEmpty == true ? artwork!.title : marker.name);
    final rawDescription = (marker.description.isNotEmpty
            ? marker.description
            : (artwork?.description ?? ''))
        .trim();
    final viewportHeight = MediaQuery.of(context).size.height;
    final safeVerticalPadding = MediaQuery.of(context).padding.vertical;
    final double maxCardHeight =
        math.max(240.0, viewportHeight - safeVerticalPadding - 24).toDouble();

    final artworkProvider = context.read<ArtworkProvider>();
    final overlayActions = <MarkerOverlayActionSpec>[];
    if (artwork != null && !canPresentExhibition) {
      overlayActions.addAll([
        MarkerOverlayActionSpec(
          icon: artwork.isLikedByCurrentUser
              ? Icons.favorite
              : Icons.favorite_border,
          label: '${artwork.likesCount}',
          isActive: artwork.isLikedByCurrentUser,
          activeColor: scheme.error,
          tooltip: l10n.commonLikes,
          semanticsLabel: 'marker_like',
          onTap: () {
            unawaited(artworkProvider.toggleLike(artwork.id));
          },
        ),
        MarkerOverlayActionSpec(
          icon: artwork.isFavoriteByCurrentUser || artwork.isFavorite
              ? Icons.bookmark
              : Icons.bookmark_border,
          label: l10n.commonSave,
          isActive: artwork.isFavoriteByCurrentUser || artwork.isFavorite,
          activeColor: baseColor,
          tooltip: l10n.commonSave,
          semanticsLabel: 'marker_save',
          onTap: () {
            unawaited(artworkProvider.toggleFavorite(artwork.id));
          },
        ),
        MarkerOverlayActionSpec(
          icon: Icons.share_outlined,
          label: l10n.commonShare,
          isActive: false,
          activeColor: baseColor,
          tooltip: l10n.commonShare,
          semanticsLabel: 'marker_share',
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
      ]);
    }

    // Keep the card height stable (matches the positioning estimate) so the
    // shared overlay widget can reserve space for its sticky footer.
    final estimatedCardHeight = math.min(360.0, maxCardHeight);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 280, maxHeight: maxCardHeight),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: estimatedCardHeight,
          child: KubusMarkerOverlayCard(
            marker: marker,
            artwork: artwork,
            baseColor: baseColor,
            displayTitle: displayTitle,
            canPresentExhibition: canPresentExhibition,
            distanceText: distanceText,
            description: rawDescription,
            onClose: _kubusMapController.dismissSelection,
            onPrimaryAction: canPresentExhibition
                ? () => _openExhibitionFromMarker(
                      marker,
                      primaryExhibition,
                      artwork,
                    )
                : () => _openMarkerDetail(marker, artwork),
            primaryActionIcon: canPresentExhibition
                ? Icons.museum_outlined
                : Icons.arrow_forward,
            primaryActionLabel: l10n.commonViewDetails,
            actions: overlayActions,
            stackCount: stackCount,
            stackIndex: stackIndex,
            onNextStacked: onNextStacked,
            onPreviousStacked: onPreviousStacked,
            onSelectStackIndex: onSelectStackIndex,
            maxHeight: estimatedCardHeight,
          ),
        ),
      ),
    );
  }

  Widget _buildMarkerOverlayLayer({
    required ThemeProvider themeProvider,
    required ArtworkProvider artworkProvider,
    required MapMarkerSelectionState selection,
  }) {
    final marker = selection.selectedMarker;
    final selectionKey = selection.selectionToken;
    final animationKey = marker == null
        ? const ValueKey<String>('marker_overlay_empty')
        : ValueKey<String>('marker_overlay:$selectionKey');
    return KubusMapMarkerOverlayLayer(
      content: marker == null
          ? null
          : Positioned.fill(
              child: _buildMarkerOverlayPositionedCard(
                selection: selection,
                marker: marker,
                artworkProvider: artworkProvider,
                themeProvider: themeProvider,
              ),
            ),
      contentKey: animationKey,
      onDismiss: _kubusMapController.dismissSelection,
      cursor: SystemMouseCursors.basic,
      // Keep map interactions live while a marker is selected; only the card
      // itself should intercept input.
      blockMapGestures: false,
      dismissOnBackdropTap: false,
    );
  }

  Widget _buildMarkerOverlayPositionedCard({
    required MapMarkerSelectionState selection,
    required ArtMarker marker,
    required ArtworkProvider artworkProvider,
    required ThemeProvider themeProvider,
  }) {
    final stack = selection.stackedMarkers.isNotEmpty
        ? selection.stackedMarkers
        : <ArtMarker>[marker];
    final count = stack.length;

    final media = MediaQuery.of(context);
    final viewportHeight = media.size.height;
    final safeVerticalPadding = media.padding.vertical;
    final double maxCardHeight = math
        .max(240.0, viewportHeight - safeVerticalPadding - 24)
        .toDouble();
    final double estimatedCardHeight = math.min(360.0, maxCardHeight);

    Widget card;
    if (count <= 1) {
      final single = stack.first;
      final artwork = single.isExhibitionMarker
          ? null
          : artworkProvider.getArtworkById(single.artworkId ?? '');
      card = _buildMarkerOverlayCard(
        single,
        artwork,
        themeProvider,
        stackCount: 1,
        stackIndex: 0,
      );
    } else {
      card = SizedBox(
        height: estimatedCardHeight,
        width: 280,
        child: PageView.builder(
          controller: _markerStackPageController,
          onPageChanged: _handleMarkerStackPageChanged,
          itemCount: count,
          itemBuilder: (context, index) {
            final stackedMarker = stack[index];
            final artwork = stackedMarker.isExhibitionMarker
                ? null
                : artworkProvider.getArtworkById(
                    stackedMarker.artworkId ?? '',
                  );
            final onPrev = index > 0
                ? () => unawaited(_animateMarkerStackToIndex(index - 1))
                : null;
            final onNext = index < count - 1
                ? () => unawaited(_animateMarkerStackToIndex(index + 1))
                : null;

            return RepaintBoundary(
              child: _buildMarkerOverlayCard(
                stackedMarker,
                artwork,
                themeProvider,
                stackCount: count,
                stackIndex: index,
                onPreviousStacked: onPrev,
                onNextStacked: onNext,
                onSelectStackIndex: (i) {
                  unawaited(_animateMarkerStackToIndex(i));
                },
              ),
            );
          },
        ),
      );
    }

    const baseOffset = 32.0;
    final zoomFactor = (_cameraZoom / 15.0).clamp(0.5, 1.5);
    final verticalOffset = baseOffset * zoomFactor;

    return KubusMarkerOverlayCardWrapper(
      anchorListenable: _selectedMarkerAnchorNotifier,
      placementStrategy: _markerOverlayMode == _MarkerOverlayMode.centered
          ? KubusMarkerOverlayPlacementStrategy.centered
          : KubusMarkerOverlayPlacementStrategy.anchored,
      widthResolver: (constraints, mediaQuery) => 280,
      maxHeightResolver: (constraints, mediaQuery) {
        return math
            .max(240.0, constraints.maxHeight - mediaQuery.padding.vertical - 24)
            .toDouble();
      },
      heightResolver: (constraints, mediaQuery, maxHeight) {
        return math.min(360.0, maxHeight);
      },
      markerOffset: verticalOffset,
      horizontalPadding: 16,
      topPadding: 16,
      bottomPadding: 16,
      animation: const KubusMarkerOverlayAnimationConfig(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
      cardBuilder: (context, layout) {
        return SizedBox(
          width: layout.cardWidth,
          height: layout.cardHeight,
          child: card,
        );
      },
    );
  }

  // Build a thumbnail widget for artwork cover images with error fallback.
  // ignore: unused_element
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

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheWidth = width.isFinite && width > 0
        ? (width * dpr).clamp(64.0, 1024.0).round()
        : null;
    final cacheHeight = height.isFinite && height > 0
        ? (height * dpr).clamp(64.0, 1024.0).round()
        : null;
    final resolvedImageUrl = MediaUrlResolver.resolveDisplayUrl(
      imageUrl,
      maxWidth: cacheWidth,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: resolvedImageUrl != null
            ? KubusCachedImage(
                imageUrl: resolvedImageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                maxDisplayWidth: cacheWidth,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
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
          if (mounted && _kubusMapController.selectedMarkerId == marker.id) {
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
      if (mounted && _kubusMapController.selectedMarkerId == marker.id) {
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
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheWidth = (640 * dpr).clamp(256.0, 1600.0).round();
    final cacheHeight = (360 * dpr).clamp(144.0, 1200.0).round();
    final coverUrl = MediaUrlResolver.resolveDisplayUrl(
      ArtworkMediaResolver.resolveCover(
        metadata: marker.metadata,
      ),
      maxWidth: cacheWidth,
    );

    await showKubusDialog<void>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          marker.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (coverUrl != null && coverUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: KubusCachedImage(
                    imageUrl: coverUrl,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: cacheWidth,
                    cacheHeight: cacheHeight,
                    maxDisplayWidth: cacheWidth,
                    cacheVersion: KubusCachedImage.versionTokenFromDate(
                      marker.updatedAt,
                    ),
                    errorBuilder: (_, __, ___) =>
                        KubusMapMarkerHelpers.markerImageFallback(
                      baseColor: _resolveArtMarkerColor(
                          marker, context.read<ThemeProvider>()),
                      scheme: scheme,
                      marker: marker,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  marker.description.isNotEmpty
                      ? marker.description
                      : AppLocalizations.of(context)!.mapNoLinkedArtworkForMarker,
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
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
    _kubusMapController.dismissSelection();
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

    _safeSetState(() {
      _createMarkerSubjectData = subjectData;
      _createMarkerAllowedTypes = allowedSubjectTypes;
      _createMarkerInitialType = initialSubjectType;
      _createMarkerPosition = targetPosition;
      _rightSidebarContent = _RightSidebarContent.createMarker;
      // Close left panels to avoid clutter.
      _selectedArtwork = null;
      _selectedExhibition = null;
      _showFiltersPanel = false;
    });
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
