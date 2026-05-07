import 'dart:async';
import 'dart:convert';
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
import '../../providers/saved_items_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/attestation_provider.dart';
import '../../providers/marker_management_provider.dart';
import '../../providers/presence_provider.dart';
import '../../providers/tile_providers.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/artwork.dart';
import '../../models/art_marker.dart';
import '../../models/event.dart';
import '../../models/exhibition.dart';
import '../../models/map_marker_subject.dart';
import '../../config/config.dart';
import '../../core/app_route_observer.dart';
import '../../services/map_attribution_helper.dart';
import '../../services/map_style_service.dart';
import '../../services/backend_api_service.dart';
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
import '../../utils/presence_marker_visit.dart';
import '../../utils/map_viewport_utils.dart';
import '../../utils/geo_bounds.dart';
import '../../utils/institution_navigation.dart';
import '../../utils/user_profile_navigation.dart';
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
import 'desktop_shell.dart';
import 'art/desktop_artwork_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/exhibition_detail_screen.dart';
import '../../features/map/controller/map_view_preferences_controller.dart';
import '../../features/map/shared/map_marker_collision_config.dart';
import '../../features/map/shared/map_screen_constants.dart';
import '../../features/map/shared/map_artwork_filtering.dart';
import '../../features/map/shared/map_marker_overlay_actions.dart';
import '../../features/map/shared/map_marker_overlay_presentation.dart';
import '../../features/map/shared/map_marker_selection_resolver.dart';
import '../../features/map/shared/map_marker_overlay_viewport_planner.dart';
import '../../features/map/shared/map_overlay_sizing.dart';
import '../../features/map/shared/map_search_filter_assembly.dart';
import '../../features/map/map_layers_manager.dart';
import '../../features/map/map_overlay_stack.dart';
import '../../features/map/controller/kubus_map_controller.dart';
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
import '../../widgets/map/filters/kubus_map_marker_layer_chips.dart';
import '../../widgets/map/dialogs/kubus_map_attribution_dialog.dart';
import '../../widgets/map/dialogs/street_art_claims_dialog.dart';
import '../../widgets/map/kubus_map_glass_surface.dart';
import '../../widgets/common/kubus_filter_panel.dart';
import '../../widgets/common/kubus_glass_icon_button.dart';
import '../../widgets/common/kubus_cached_image.dart';
import '../../widgets/common/kubus_map_controls.dart';
import '../../widgets/common/kubus_sort_option.dart';
import '../../widgets/common/kubus_search_overlay_scaffold.dart';
import '../../widgets/map/overlays/kubus_marker_overlay_card_wrapper.dart'
    as overlay_wrapper;
import '../../widgets/detail/artwork_engagement_sections.dart';
import '../../widgets/detail/detail_shell_primitives.dart';
import '../../widgets/detail/poap_detail_card.dart';
import '../../widgets/search/kubus_general_search.dart';
import '../../widgets/search/kubus_search_config.dart';
import '../../widgets/search/kubus_search_controller.dart';
import '../../widgets/search/kubus_search_result.dart';
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
  final String? initialArtworkId;
  final String? initialSubjectId;
  final String? initialSubjectType;
  final String? initialTargetLabel;

  const DesktopMapScreen({
    super.key,
    this.initialCenter,
    this.initialZoom,
    this.autoFollow = true,
    this.initialMarkerId,
    this.initialArtworkId,
    this.initialSubjectId,
    this.initialSubjectType,
    this.initialTargetLabel,
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
  KubusEvent? _selectedEvent;
  _MarkerOverlayMode _markerOverlayMode = _MarkerOverlayMode.anchored;
  bool _markerStackPagerSyncing = false;
  final PageController _markerStackPageController = PageController();
  bool _didOpenInitialSelection = false;
  int _lastMarkerOverlayNudgeSelectionToken = -1;
  bool _showFiltersPanel = false;
  bool _isDiscoveryExpanded = false;
  String _selectedFilter = 'nearby';
  double _searchRadius = 5.0; // km
  bool _travelModeEnabled = false;
  bool _isometricViewEnabled = false;
  bool _isClaimingSelectedExhibitionPoap = false;

  // Travel mode is viewport-based (bounds query), not huge-radius.
  double get _effectiveSearchRadiusKm => _searchRadius;

  // Interactive onboarding tutorial (coach marks)
  final GlobalKey _tutorialMapKey = GlobalKey();
  final GlobalKey _tutorialSearchKey = GlobalKey();
  final GlobalKey _tutorialSearchPanelKey = GlobalKey();
  final GlobalKey _tutorialFilterChipsKey = GlobalKey();
  final GlobalKey _tutorialFiltersButtonKey = GlobalKey();
  final GlobalKey _tutorialNearbyButtonKey = GlobalKey();
  final GlobalKey _tutorialTravelButtonKey = GlobalKey();
  LatLng? _pendingMarkerLocation;
  bool _mapReady = false;
  double _cameraZoom = 13.0;
  int _lastCameraZoomBucket = MapViewportUtils.zoomBucket(13.0);
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
  LatLng? _nearbySidebarAnchor;
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
  static const Duration _markerRefreshInterval =
      MapScreenConstants.markerRefreshInterval;

  late final KubusSearchController _mapSearchController;
  late final MapViewPreferencesController _mapViewPreferencesController;
  late final MapTutorialCoordinator _mapTutorialCoordinator;
  bool _pendingSafeSetState = false;
  int _debugMarkerTapCount = 0;
  int _debugMarkerSourceWriteCount = 0;
  int _webResizeRecoveryToken = 0;

  late AnimationController _cubeIconSpinController;

  final GlobalKey _mapViewKey = GlobalKey();
  bool? _lastAppliedMapThemeDark;
  bool _themeResyncScheduled = false;

  bool get _hasLeftDetailPanel =>
      _selectedArtwork != null ||
      _selectedExhibition != null ||
      _selectedEvent != null;

  bool get _isLeftPanelVisible => _hasLeftDetailPanel || _showFiltersPanel;

  static const double _clusterMaxZoom = MapScreenConstants.clusterMaxZoom;
  static const int _markerVisualSyncThrottleMs =
      MapScreenConstants.markerVisualSyncThrottleMs;
  int _lastClusterGridLevel = -1;
  bool _lastClusterEnabled = false;

  String _selectedSort = 'distance';
  final ArtworkCommentsPanelController _mapCommentsPanelController =
      ArtworkCommentsPanelController();

  // Marker type layer visibility - same as mobile for parity
  final Map<ArtMarkerType, bool> _markerLayerVisibility = {
    ArtMarkerType.artwork: true,
    ArtMarkerType.streetArt: true,
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
    _mapViewPreferencesController.addListener(_handleMapViewPreferencesChanged);
    _mapTutorialCoordinator = MapTutorialCoordinator(
      seenPreferenceKey: PreferenceKeys.mapOnboardingDesktopSeenV2,
    );
    _mapTutorialCoordinator.addListener(_handleTutorialCoordinatorChanged);

    _mapSearchController = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.map,
        limit: 8,
        showOverlayOnFocus: false,
      ),
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
        final prevSelection = _mapUiStateCoordinator.value.markerSelection;
        final prevToken = prevSelection.selectionToken;
        final tokenChanged = state.selectionToken != prevToken;
        final prevStack = prevSelection.stackedMarkers;
        final nextStack = state.stackedMarkers;
        final stackChanged = prevStack.length != nextStack.length ||
            (() {
              final minLen = math.min(prevStack.length, nextStack.length);
              for (var i = 0; i < minLen; i++) {
                if (prevStack[i].id != nextStack[i].id) return true;
              }
              return false;
            })();
        if (tokenChanged) {
          _perf.recordSetState('markerSelection');
          _safeSetState(() {
            _selectedArtwork = null;
            _selectedExhibition = null;
            _selectedEvent = null;
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
            final stackToPrefetch =
                nextStack.isNotEmpty ? nextStack : <ArtMarker>[marker];
            unawaited(_prefetchStackArtworkData(stackToPrefetch));
          } else if (stackChanged) {
            unawaited(_prefetchStackArtworkData(nextStack));
          }
          // Keep the active overlay card hydrated even when paging within an
          // existing stack selection, where the selection token does not change.
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
        _mapSearchController.dismissOverlay();
        _safeSetState(() {
          _selectedArtwork = null;
          _selectedExhibition = null;
          _selectedEvent = null;
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
    MapAttributionHelper.setDesktopMapEnabled(true);
    MapAttributionHelper.setDesktopMapAttributionBottomPx(
      KubusSpacing.xl.toDouble(),
    );

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
          .then((_) => _maybeOpenInitialSelection()));

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
      if (enabled) {
        _autoFollow = false;
      }
    });
    if (enabled) {
      _kubusMapController.setAutoFollow(false);
      _kubusMapController.dismissSelection();
    }

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
    _safeSetState(() {});
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
        isAnchorAvailable: () =>
            _tutorialNearbyButtonKey.currentContext != null,
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
        isAnchorAvailable: () => _tutorialSearchPanelKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialSearchPanelKey,
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

    _pendingInitialNearbyPanelOpen = false;
    _openNearbyArtPanel();
  }

  void _openNearbyArtPanel() {
    final anchor = _userLocation ?? _effectiveCenter;

    _safeSetState(() {
      _rightSidebarContent = _RightSidebarContent.nearby;
      _nearbySidebarAnchor = anchor;
      _selectedArtwork = null;
      _selectedExhibition = null;
      _selectedEvent = null;
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
      _nearbySidebarAnchor = null;
    });
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

  Future<void> _maybeOpenInitialSelection() async {
    if (_didOpenInitialSelection) return;
    final markerId = widget.initialMarkerId?.trim() ?? '';
    final artworkId = widget.initialArtworkId?.trim() ?? '';
    final subjectId = widget.initialSubjectId?.trim() ?? '';
    if (markerId.isEmpty && artworkId.isEmpty && subjectId.isEmpty) return;

    _didOpenInitialSelection = true;
    if (markerId.isNotEmpty) {
      final opened = await _openMarkerById(markerId);
      if (opened) return;
    }

    await _openMarkerBySelection(
      exactMarkerId: markerId,
      artworkId: artworkId,
      subjectId: subjectId,
      subjectType: widget.initialSubjectType,
      preferredLabel: widget.initialTargetLabel,
      preferredPosition: widget.initialCenter,
    );
  }

  Future<bool> _openMarkerById(String markerId) async {
    final id = markerId.trim();
    if (id.isEmpty) return false;

    for (var attempt = 0; attempt < 4; attempt++) {
      final existing =
          _artMarkers.where((m) => m.id == id).toList(growable: false);
      if (existing.isNotEmpty) {
        final marker = existing.first;
        await _moveCamera(marker.position, math.max(_effectiveZoom, 15));
        _handleMarkerTap(marker);
        return true;
      }

      try {
        _perf.recordFetch('marker:get');
        final marker = await MapDataController().getArtMarkerById(id);
        if (!mounted) return false;
        if (marker != null && marker.hasValidPosition) {
          setState(() {
            _artMarkers.removeWhere((m) => m.id == marker.id);
            _artMarkers.add(marker);
          });
          await _moveCamera(marker.position, math.max(_effectiveZoom, 15));
          _handleMarkerTap(marker);
          return true;
        }
      } catch (_) {
        // Keep retrying for hydration races.
      }

      if (attempt < 3) {
        await Future<void>.delayed(
          Duration(milliseconds: 220 * (attempt + 1)),
        );
        if (!mounted) return false;
      }
    }
    return false;
  }

  Future<bool> _openMarkerBySelection({
    String? exactMarkerId,
    String? artworkId,
    String? subjectId,
    String? subjectType,
    String? preferredLabel,
    LatLng? preferredPosition,
  }) async {
    final markerId = exactMarkerId?.trim() ?? '';
    final normalizedArtworkId = artworkId?.trim() ?? '';
    final normalizedSubjectId = subjectId?.trim() ?? '';
    final normalizedSubjectType = subjectType?.trim() ?? '';
    if (markerId.isEmpty &&
        normalizedArtworkId.isEmpty &&
        normalizedSubjectId.isEmpty) {
      return false;
    }

    final targetPosition = preferredPosition ?? widget.initialCenter;
    for (var attempt = 0; attempt < 4; attempt++) {
      final existing = resolveBestMarkerCandidate(
        _artMarkers,
        exactMarkerId: markerId,
        artworkId: normalizedArtworkId,
        subjectId: normalizedSubjectId,
        subjectType: normalizedSubjectType,
        preferredLabel: preferredLabel,
        preferredPosition: targetPosition,
      );
      if (existing != null) {
        await _moveCamera(existing.position, math.max(_effectiveZoom, 15));
        _handleMarkerTap(existing);
        return true;
      }

      if (targetPosition != null) {
        await _loadMarkers(center: targetPosition, force: true);
        if (!mounted) return false;

        final refreshed = resolveBestMarkerCandidate(
          _artMarkers,
          exactMarkerId: markerId,
          artworkId: normalizedArtworkId,
          subjectId: normalizedSubjectId,
          subjectType: normalizedSubjectType,
          preferredLabel: preferredLabel,
          preferredPosition: targetPosition,
        );
        if (refreshed != null) {
          await _moveCamera(refreshed.position, math.max(_effectiveZoom, 15));
          _handleMarkerTap(refreshed);
          return true;
        }
      }

      if (attempt < 3) {
        await Future<void>.delayed(
          Duration(milliseconds: 220 * (attempt + 1)),
        );
        if (!mounted) return false;
      }
    }

    return false;
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
    _safeSetState(() => _webResizeRecoveryToken += 1);
    _perf.logEvent(
      'webResizeRecovery',
      extra: <String, Object?>{
        'reason': reason,
      },
    );
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
    _mapSearchController.dismissOverlay();

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
    KubusMapLifecycleHelpers.handleMapCreated(
      controller: controller,
      kubusMapController: _kubusMapController,
      setMapController: (value) => _mapController = value,
      setLayersManager: (manager) => _layersManager = manager,
      clearManagedState: () {
        _registeredMapImages.clear();
        _managedLayerIds.clear();
        _managedSourceIds.clear();
      },
    );
    _styleInitialized = false;
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
    final scheme = Theme.of(context).colorScheme;
    await KubusMapStyleInitHelpers.handleStyleLoaded(
      controller: _mapController,
      mounted: mounted,
      styleInitializationInProgress: _styleInitializationInProgress,
      setStyleInitializationInProgress: (value) =>
          _styleInitializationInProgress = value,
      setStyleInitialized: (value) => _styleInitialized = value,
      setStyleEpoch: (value) => _styleEpoch = value,
      setLastAppliedMapThemeDark: (value) => _lastAppliedMapThemeDark = value,
      kubusMapController: _kubusMapController,
      scheme: scheme,
      isDarkMode: themeProvider.isDarkMode,
      themeSpec: MapLayersThemeSpec(
        locationFill: scheme.secondary,
        locationStroke: scheme.surface,
        pendingFill: scheme.primary,
        pendingStroke: scheme.surface,
      ),
      debugLabel: 'DesktopMapScreen',
      onBeforeHandleStyleLoaded: () {
        _registeredMapImages.clear();
        _managedLayerIds.clear();
        _managedSourceIds.clear();
      },
      onStyleReady: () async {
        if (_styleInitialized) {
          await _applyThemeToMapStyle(themeProvider: themeProvider);
          await _applyIsometricCamera(enabled: _isometricViewEnabled);
          await _syncUserLocation();
          await _syncPendingMarker();
          await _syncMapMarkers(themeProvider: themeProvider);
          await _renderCoordinator.updateRenderMode();
        }
      },
    );
  }

  Future<void> _syncUserLocation() async {
    await KubusMapSourceSyncHelpers.syncPointSource(
      controller: _mapController,
      styleInitialized: _styleInitialized,
      managedSourceIds: _managedSourceIds,
      sourceId: _locationSourceId,
      featureId: 'me',
      position: _userLocation,
    );
  }

  Future<void> _syncPendingMarker() async {
    await KubusMapSourceSyncHelpers.syncPointSource(
      controller: _mapController,
      styleInitialized: _styleInitialized,
      managedSourceIds: _managedSourceIds,
      sourceId: _pendingSourceId,
      featureId: 'pending',
      position: _pendingMarkerLocation,
    );
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
    final visibleMarkers =
        renderedMarkers.map((m) => m.marker).toList(growable: false);
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
      _debugMarkerSourceWriteCount += 1;
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

  Size? _mapViewportSize() {
    final context = _mapViewKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return null;
  }

  double _desiredPitch() {
    if (!_isometricViewEnabled) return 0.0;
    if (!AppConfig.isFeatureEnabled('mapIsometricView')) return 0.0;
    return 54.736;
  }

  void _handleMarkerOverlayLayoutResolved(
    MapMarkerSelectionState selection,
    overlay_wrapper.KubusMarkerOverlayResolvedLayout resolvedLayout,
  ) {
    if (!mounted) return;
    if (_styleInitializationInProgress || !_styleInitialized) return;
    final marker = selection.selectedMarker;
    if (marker == null) return;
    if (selection.selectionToken !=
        _kubusMapController.selectionState.selectionToken) {
      return;
    }
    if (_lastMarkerOverlayNudgeSelectionToken == selection.selectionToken) {
      return;
    }

    final anchor = resolvedLayout.layout.anchor;
    if (anchor == null) return;
    final viewportSize = _mapViewportSize() ?? resolvedLayout.viewportSize;
    if (!viewportSize.width.isFinite || !viewportSize.height.isFinite) return;

    final media = resolvedLayout.mediaQuery;
    final plan = planSelectedMarkerOverlayViewport(
      viewportSize: viewportSize,
      markerAnchor: anchor,
      cardSize: Size(
        resolvedLayout.layout.cardWidth,
        resolvedLayout.layout.cardHeight,
      ),
      safeInsets: EdgeInsets.only(
        top: media.padding.top,
        bottom: MapOverlaySizing.bottomSafeInset(media),
      ),
      markerOffset: resolvedLayout.markerOffset,
      topChromePx: KubusSpacing.md,
      bottomChromePx: MapOverlaySizing.defaultVerticalPadding,
    );

    _lastMarkerOverlayNudgeSelectionToken = selection.selectionToken;
    if (!plan.needsNudge) return;

    unawaited(
      _mapCameraController
          .animateTo(
        marker.position,
        zoom: _cameraZoom,
        rotation: _lastBearing,
        tilt: _desiredPitch(),
        duration: const Duration(milliseconds: 260),
        compositionYOffsetPx: plan.compositionYOffsetPx,
        queueIfNotReady: false,
      )
          .then((_) {
        if (!mounted) return;
        _kubusMapController.queueOverlayAnchorRefresh(force: true);
      }),
    );
  }

  @override
  void deactivate() {
    // Detach early (top-down) so listeners are removed before the MapLibre
    // plugin disposes the controller during child disposal.
    _deactivateDetachedMapController =
        KubusMapLifecycleHelpers.detachMapController(
      controller: _mapController,
      kubusMapController: _kubusMapController,
      setMapController: (controller) => _mapController = controller,
      setLayersManager: (manager) => _layersManager = manager,
    );
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final controller = _deactivateDetachedMapController;
    _deactivateDetachedMapController = null;
    KubusMapLifecycleHelpers.reactivateDetachedMapController(
      currentMapController: _mapController,
      detachedController: controller,
      kubusMapController: _kubusMapController,
      setMapController: (value) => _mapController = value,
      setLayersManager: (manager) => _layersManager = manager,
    );
  }

  @override
  void dispose() {
    MapAttributionHelper.setDesktopMapEnabled(false);
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
        'markerSourceWrites': _debugMarkerSourceWriteCount,
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
    final tutorial = _mapTutorialCoordinator.state;
    final showMapTutorial = tutorial.show;
    final mapTutorialIndex = tutorial.index;
    // Always show the nearby panel as a local overlay on top of the map
    // (glass panel with blur). This keeps the map at full width; only the
    // UI chrome (controls, search bar) shifts to avoid overlap.
    final showLocalNearbyPanel = _isRightSidebarOpen;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Map layer
          AbsorbPointer(
            absorbing: showMapTutorial,
            child: KeyedSubtree(
              key: _tutorialMapKey,
              child: _buildMapLayer(themeProvider),
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
            left: _isLeftPanelVisible ? 0 : -400,
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
                    : _selectedEvent != null
                        ? Semantics(
                            label: 'left_info_panel',
                            container: true,
                            child: _buildEventDetailPanel(
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
            child: Consumer<ArtworkProvider>(
              builder: (context, artworkProvider, _) {
                return _buildRightSidebarContent(
                  themeProvider,
                  artworkProvider,
                );
              },
            ),
          ),

          // Map controls (bottom-right) - absorb pointer events
          Positioned(
            left: _hasLeftDetailPanel ? 400 : 24,
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
              final leftOffset = _isLeftPanelVisible ? 400.0 : 24.0;

              if (activeProgress.isEmpty) {
                // No active tasks: show attribution icon standalone in bottom-left
                return Positioned(
                  left: 24,
                  bottom: KubusSpacing.xl +
                      KubusHeaderMetrics.actionHitArea +
                      KubusSpacing.sm,
                  child: MapOverlayBlocker(
                    child: _buildDesktopAttributionButton(),
                  ),
                );
              }

              // Active tasks: show column with attribution + discovery card
              return Positioned(
                left: leftOffset,
                bottom: 24,
                child: MapOverlayBlocker(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // absorb taps
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDiscoveryCard(taskProvider),
                        const SizedBox(height: KubusSpacing.sm),
                        _buildDesktopAttributionButton(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          ValueListenableBuilder<MapUiStateSnapshot>(
            valueListenable: _mapUiStateCoordinator.state,
            builder: (context, uiState, _) {
              final selection = uiState.markerSelection;
              return Consumer<ArtworkProvider>(
                builder: (context, artworkProvider, _) {
                  return _buildMarkerOverlayLayer(
                    themeProvider: themeProvider,
                    artworkProvider: artworkProvider,
                    selection: selection,
                  );
                },
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
      ),
    );
  }

  Widget _buildMapLayer(
    ThemeProvider themeProvider,
  ) {
    // The nearby art panel is rendered as a local overlay in the map's Stack
    // (not via DesktopShell functions panel), so it auto-updates through the
    // normal build cycle. No explicit sync needed here.
    final isDark = themeProvider.isDarkMode;
    final tileProviders = context.read<TileProviders?>();
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
          attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
          attributionButtonMargins: math.Point<double>(
            24.0,
            KubusSpacing.xl.toDouble(),
          ),
          webResizeRecoveryToken: _webResizeRecoveryToken,
          onMapCreated: _handleMapCreated,
          onStyleLoaded: () {
            AppConfig.debugPrint(
              'DesktopMapScreen: onStyleLoadedCallback (dark=$isDark, style="$styleAsset")',
            );
            unawaited(
              _handleMapStyleLoaded(themeProvider)
                  .then((_) => _handleMapReady()),
            );
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

            final zoomChanged = (position.zoom - previousZoom).abs() > 0.001;
            if (_styleInitialized && zoomChanged) {
              _queueMarkerVisualRefreshForZoom(position.zoom);
            }

            final shouldShowCubes = _renderCoordinator.is3DModeActive;
            if (shouldShowCubes != _renderCoordinator.cubeLayerVisible) {
              unawaited(_renderCoordinator.updateRenderMode());
            }

            final bucket = MapViewportUtils.zoomBucket(position.zoom);
            final bucketChanged = bucket != _lastCameraZoomBucket;
            final now = DateTime.now();
            final shouldSyncCubes = _isometricViewEnabled &&
                now.difference(_lastCameraUpdateTime) > _cameraUpdateThrottle;
            if (bucketChanged || shouldSyncCubes) {
              _lastCameraUpdateTime = now;
              _lastCameraZoomBucket = bucket;
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
            final wasProgrammatic = _kubusMapController.programmaticCameraMove;
            _kubusMapController.handleCameraIdle(
              fromProgrammaticMove: wasProgrammatic,
            );
            if (_styleInitialized) {
              _queueMarkerVisualRefreshForZoom(_cameraZoom);
              unawaited(_renderCoordinator.updateRenderMode());
            }
            if (_isNearbyPanelOpen && _userLocation == null) {
              final nextAnchor = _effectiveCenter;
              final currentAnchor = _nearbySidebarAnchor;
              final anchorChanged = currentAnchor == null ||
                  (currentAnchor.latitude - nextAnchor.latitude).abs() >
                      0.000001 ||
                  (currentAnchor.longitude - nextAnchor.longitude).abs() >
                      0.000001;
              if (anchorChanged) {
                _safeSetState(() => _nearbySidebarAnchor = nextAnchor);
              }
            }
            _queueMarkerRefresh(fromGesture: false);
          },
          onMapClick: (dynamic point, _) {
            unawaited(_markerInteractionController.handleMapClick(point));
          },
          onMapLongClick: (_, point) {
            _kubusMapController.dismissSelection();
            setState(() {
              _pendingMarkerLocation = point;
            });
            unawaited(_syncPendingMarker());
            _startMarkerCreationFlow(position: point);
          },
        ),
      ),
    );

    return map;
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
      unawaited(_syncUserLocation());

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
    return KeyedSubtree(
      key: _tutorialSearchPanelKey,
      child: KubusMapSearchOverlayAssembly(
        controller: _mapSearchController,
        layout: KubusSearchOverlayLayout.sidePanel,
        sidePanelSurfaceMode: kIsWeb
            ? KubusSearchSidePanelSurfaceMode.hostless
            : KubusSearchSidePanelSurfaceMode.glassHost,
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
              style: KubusTextStyles.screenTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        searchField: _buildDesktopSearchField(l10n),
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
            enableBlur: kubusMapBlurEnabled(context),
            onPressed: () {
              setState(() {
                _showFiltersPanel = !_showFiltersPanel;
                _selectedArtwork = null;
                _selectedExhibition = null;
                _selectedEvent = null;
              });
            },
            tooltipPreferBelow: true,
            tooltipVerticalOffset: 18,
            tooltipMargin: const EdgeInsets.symmetric(horizontal: 24),
          ),
        ),
        accentColor: themeProvider.accentColor,
        minCharsHint: l10n.mapSearchMinCharsHint,
        noResultsText: l10n.commonNoResultsFound,
        onResultTap: (result) {
          unawaited(_handleSearchResultTap(result));
        },
      ),
    );
  }

  Widget _buildDesktopSearchField(AppLocalizations l10n) {
    final useMapBlur = kubusMapBlurEnabled(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: KeyedSubtree(
        key: _tutorialSearchKey,
        child: KubusGeneralSearch(
          controller: _mapSearchController,
          hintText: l10n.mapSearchHint,
          semanticsLabel: 'map_search_input',
          enableBlur: useMapBlur,
          mouseCursor: SystemMouseCursors.text,
          onSubmitted: _handleSearchSubmit,
        ),
      ),
    );
  }

  Widget _buildDesktopFilterChipRow(ThemeProvider themeProvider) {
    final useMapBlur = kubusMapBlurEnabled(context);
    final filters = KubusMapFilterCatalog.buildOptions(context,
        accentColor: themeProvider.accentColor);
    return KeyedSubtree(
      key: _tutorialFilterChipsKey,
      child: KubusMapFilterChipStrip(
        options: filters,
        selectedKey: _selectedFilter,
        layout: KubusMapFilterChipLayout.row,
        spacing: KubusSpacing.sm,
        enableBlur: useMapBlur,
        keyPadding: EdgeInsets.zero,
        onSelected: (key) {
          setState(() => _selectedFilter = key);
          // Reload markers so the nearby panel reflects the new filter.
          unawaited(_loadMarkersForCurrentView(force: true).then((_) {
            if (!mounted) return;
            _requestMarkerVisualSync(force: true);
          }));
        },
      ),
    );
  }

  Widget _buildArtworkDetailPanel(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    // Guard against null to prevent race condition between check and access.
    final selectedArtwork = _selectedArtwork;
    if (selectedArtwork == null) {
      return const SizedBox.shrink();
    }
    final hydratedArtwork = context.select<ArtworkProvider, Artwork?>(
      (provider) => provider.getArtworkById(selectedArtwork.id),
    );
    // Get the latest artwork from provider to ensure like/save states are updated
    final artwork = hydratedArtwork ?? selectedArtwork;
    final artworkProvider = context.read<ArtworkProvider>();
    final savedItemsProvider = context.read<SavedItemsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final accent = themeProvider.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final isSignedIn = context.select<ProfileProvider, bool>(
      (provider) => provider.isSignedIn,
    );
    final coverUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata:
          _kubusMapController.selectedMarkerData?.metadata ?? artwork.metadata,
    );
    final distanceLabel = _formatDistanceToArtwork(artwork);
    final categoryLabel = artwork.category.trim();
    final artistLabel = artwork.artist.trim();
    final isSaved = savedItemsProvider.isArtworkSaved(artwork.id);
    final arBadge = artwork.arEnabled
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.92),
              borderRadius: BorderRadius.circular(KubusRadius.xl),
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
                  l10n.mapArReadyChipLabel,
                  style: KubusTextStyles.navMetaLabel.copyWith(
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
        height: 248,
        accentColor: accent,
        closeTooltip: l10n.commonClose,
        onClose: () {
          setState(() => _selectedArtwork = null);
        },
        badge: arBadge,
        closeAccentColor: themeProvider.accentColor,
        fallbackIcon: Icons.image_not_supported,
      ),
      sections: [
        Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailIdentityBlock(
                title: artwork.title,
                kicker: l10n.commonArtwork,
                subtitle:
                    (artistLabel.isNotEmpty && artistLabel != artwork.title)
                        ? artistLabel
                        : null,
              ),
              const SizedBox(height: KubusSpacing.xs),
              ArtworkCreatorByline(
                artwork: artwork,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: KubusHeaderMetrics.screenSubtitle,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: 1,
              ),
              const SizedBox(height: KubusSpacing.md),
              DetailMetadataBlock(
                compact: true,
                items: [
                  if (distanceLabel != null)
                    DetailMetaItem(
                      icon: Icons.near_me,
                      label: distanceLabel,
                    ),
                  if (categoryLabel.isNotEmpty && categoryLabel != 'General')
                    DetailMetaItem(
                      icon: Icons.palette_outlined,
                      label: categoryLabel,
                    ),
                  DetailMetaItem(
                    icon: Icons.calendar_today_outlined,
                    label: _formatPanelDate(artwork.createdAt),
                  ),
                ],
              ),
              if (artwork.description.isNotEmpty) ...[
                const SizedBox(height: KubusSpacing.md),
                DetailSectionLabel(label: l10n.commonDescription),
              ],
              if (artwork.description.isNotEmpty) ...[
                Text(
                  artwork.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: KubusHeaderMetrics.screenSubtitle,
                        height: 1.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.78),
                      ),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: KubusSpacing.md),
              ],
              DetailSectionLabel(label: l10n.commonDetails),
              DetailContextCluster(
                compact: true,
                items: [
                  DetailContextItem(
                    icon: Icons.visibility,
                    value: '${artwork.viewsCount}',
                  ),
                  if (artwork.discoveryCount > 0)
                    DetailContextItem(
                      icon: Icons.explore,
                      value: l10n.desktopMapDiscoveriesCount(
                        artwork.discoveryCount,
                      ),
                    ),
                  if (artwork.actualRewards > 0)
                    DetailContextItem(
                      icon: Icons.token,
                      value: '${artwork.actualRewards}',
                      label: 'KUB8',
                    ),
                ],
              ),
              _buildArtworkPoapPanel(artwork),
              const SizedBox(height: KubusSpacing.lg),
              DetailActionsSection(
                title: l10n.commonActions,
                labelPosition: DetailActionLabelPosition.afterPrimary,
                primaryToLabelSpacing: KubusSpacing.md,
                maxVisibleActions: 5,
                primaryAction: SizedBox(
                  width: double.infinity,
                  child: DetailPrimaryCtaButton(
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
                    icon: Icons.info_outline,
                    iconSize: 18,
                    label: l10n.commonViewDetails,
                    backgroundColor: accent,
                    foregroundColor: AppColorUtils.contrastText(accent),
                  ),
                ),
                actions: [
                  if (artwork.arEnabled &&
                      AppConfig.isFeatureEnabled('ar') &&
                      !kIsWeb)
                    DetailSecondaryAction(
                      icon: Icons.view_in_ar,
                      label: l10n.commonViewInAr,
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final modelUrl = artwork.model3DURL ??
                            (artwork.model3DCID != null
                                ? 'ipfs://${artwork.model3DCID}'
                                : null);
                        if (modelUrl == null) {
                          messenger.showKubusSnackBar(
                            SnackBar(
                                content: Text(l10n.desktopMapNoArAssetToast)),
                            tone: KubusSnackBarTone.warning,
                          );
                          return;
                        }
                        unawaited(ARService().launchARViewer(
                          modelUrl: modelUrl,
                          title: artwork.title,
                        ));
                      },
                      tooltip: l10n.commonViewInAr,
                    ),
                  DetailSecondaryAction(
                    icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                    label: isSaved ? l10n.commonSavedToast : l10n.commonSave,
                    onTap: () {
                      unawaited(artworkProvider.toggleArtworkSaved(artwork.id));
                    },
                    isActive: isSaved,
                    activeColor: accent,
                    tooltip: l10n.commonSave,
                  ),
                  DetailSecondaryAction(
                    icon: artwork.isLikedByCurrentUser
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: '${artwork.likesCount}',
                    onTap: () {
                      unawaited(artworkProvider.toggleLike(artwork.id));
                    },
                    isActive: artwork.isLikedByCurrentUser,
                    activeColor: scheme.error,
                    tooltip: l10n.commonLikes,
                  ),
                  DetailSecondaryAction(
                    icon: Icons.comment_outlined,
                    label: '${artwork.commentsCount}',
                    onTap: () {
                      _mapCommentsPanelController.openAndScrollToTop();
                    },
                    tooltip: l10n.commonComments,
                  ),
                  DetailSecondaryAction(
                    icon: Icons.share,
                    label: l10n.commonShare,
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
                    tooltip: l10n.commonShare,
                  ),
                  DetailSecondaryAction(
                    icon: Icons.directions,
                    label: l10n.commonGetDirections,
                    onTap: () async {
                      final uri = Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&destination=${artwork.position.latitude},${artwork.position.longitude}',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    tooltip: l10n.commonGetDirections,
                  ),
                ],
              ),
              const SizedBox(height: KubusSpacing.lg),
              if (AppConfig.isFeatureEnabled('collabInvites') && isSignedIn)
                ArtworkCollaboratorsExpandableCard(
                  artwork: artwork,
                  initiallyExpanded: false,
                ),
              if (AppConfig.isFeatureEnabled('collabInvites') && isSignedIn)
                const SizedBox(height: KubusSpacing.md),
              ArtworkCommentsExpandableCard(
                artwork: artwork,
                isSignedIn: isSignedIn,
                controller: _mapCommentsPanelController,
                layoutMode: ArtworkCommentsLayoutMode.compact,
                compactListConstraints: const BoxConstraints(
                  minHeight: 120,
                  maxHeight: 280,
                ),
                signInArguments: {
                  'redirectRoute': '/artwork',
                  'redirectArguments': {'artworkId': artwork.id},
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArtworkPoapPanel(Artwork artwork) {
    final l10n = AppLocalizations.of(context)!;
    final metadataPoap = artwork.metadata?['poap'];
    final poapMeta = metadataPoap is Map
        ? Map<String, dynamic>.from(metadataPoap)
        : const <String, dynamic>{};

    final enabled = artwork.poapEnabled ||
        artwork.poapMode != ArtworkPoapMode.none ||
        poapMeta['enabled'] == true ||
        poapMeta['poapEnabled'] == true ||
        poapMeta['poap_enabled'] == true;
    final eventId = (artwork.poapEventId ??
            poapMeta['eventId'] ??
            poapMeta['poapEventId'] ??
            poapMeta['event_id'])
        ?.toString()
        .trim();
    final claimUrl = (artwork.poapClaimUrl ??
            poapMeta['claimUrl'] ??
            poapMeta['poapClaimUrl'] ??
            poapMeta['claim_url'])
        ?.toString()
        .trim();
    final hasReference = (eventId != null && eventId.isNotEmpty) ||
        (claimUrl != null && claimUrl.isNotEmpty);
    if (!enabled && !hasReference) return const SizedBox.shrink();

    final rewardAmount = artwork.poapRewardAmount ??
        (poapMeta['rewardAmount'] is num
            ? (poapMeta['rewardAmount'] as num).toInt()
            : int.tryParse(
                (poapMeta['poapRewardAmount'] ?? '').toString(),
              ));

    return Padding(
      padding: const EdgeInsets.only(top: KubusSpacing.lg),
      child: PoapDetailCard(
        title: l10n.exhibitionDetailPoapTitle,
        description: (artwork.poapDescription ?? poapMeta['description'])
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? (artwork.poapDescription ?? poapMeta['description']).toString()
            : l10n.exhibitionDetailPoapDescription,
        code: eventId,
        iconUrl: artwork.poapImageUrl ?? poapMeta['imageUrl']?.toString(),
        rewardLabel: rewardAmount != null && rewardAmount > 0
            ? '+$rewardAmount KUB8'
            : null,
        stateLabel: l10n.exhibitionDetailPoapNotClaimedStatus,
        eligibilityLabel: l10n.exhibitionDetailPoapEligibilityVisitRequired,
        eligibilityHint: l10n.exhibitionDetailPoapAttendanceHint,
        isClaimed: false,
        canClaim: false,
        claimActionLabel: l10n.exhibitionDetailPoapClaimAction,
        claimingActionLabel: l10n.exhibitionDetailPoapClaimingAction,
      ),
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
      dateRange = [start, end].whereType<String>().join(' - ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final location = (exhibition.locationName ?? '').trim().isNotEmpty
        ? exhibition.locationName!.trim()
        : null;
    final coverUrl = MediaUrlResolver.resolve(exhibition.coverUrl);
    final poap =
        context.watch<ExhibitionsProvider>().poapStatusFor(exhibition.id);

    List<DetailContextItem> buildPoapContextItems() {
      final items = <DetailContextItem>[];
      final currentPoap = poap;
      if (currentPoap == null) return items;
      if (currentPoap.proofType?.trim().isNotEmpty == true) {
        items.add(
          DetailContextItem(
            icon: Icons.verified_outlined,
            value: l10n.exhibitionDetailPoapProofTypeMarkerAttendance,
          ),
        );
      }
      if (currentPoap.linkedMarkerCount > 0) {
        items.add(
          DetailContextItem(
            icon: Icons.route_outlined,
            value: currentPoap.linkedMarkerCount.toString(),
            label: l10n.exhibitionDetailPoapLinkedMarkersLabel,
          ),
        );
      }
      if (currentPoap.latestAttendanceAt != null) {
        items.add(
          DetailContextItem(
            icon: Icons.schedule_outlined,
            value: MaterialLocalizations.of(context)
                .formatMediumDate(currentPoap.latestAttendanceAt!.toLocal()),
            label: l10n.exhibitionDetailPoapLatestCheckInLabel,
          ),
        );
      }
      return items;
    }

    String? poapEligibilityLabel() {
      if (poap == null) return null;
      if (poap.claimed) return l10n.exhibitionDetailPoapEligibilityClaimed;
      if (poap.canClaim) return l10n.exhibitionDetailPoapEligibilityVerified;
      switch ((poap.eligibilityReason ?? '').trim().toLowerCase()) {
        case 'sign_in_required':
          return l10n.exhibitionDetailPoapEligibilitySignedOut;
        case 'exhibition_not_published':
          return l10n.exhibitionDetailPoapEligibilityNotPublished;
        case 'marker_link_required':
          return l10n.exhibitionDetailPoapEligibilityMarkerLinkRequired;
        case 'marker_attendance_required':
          return l10n.exhibitionDetailPoapEligibilityAttendanceRequired;
        default:
          return l10n.exhibitionDetailPoapEligibilityVisitRequired;
      }
    }

    String? poapEligibilityHint() {
      if (poap == null || poap.claimed) return null;
      if (poap.canClaim) {
        return l10n.exhibitionDetailPoapEligibilityClaimReadyHint;
      }
      switch ((poap.eligibilityReason ?? '').trim().toLowerCase()) {
        case 'sign_in_required':
          return l10n.exhibitionDetailPoapSignedOutHint;
        case 'exhibition_not_published':
          return l10n.exhibitionDetailPoapEligibilityNotPublishedHint;
        case 'marker_link_required':
          return l10n.exhibitionDetailPoapEligibilityMarkerLinkHint;
        case 'marker_attendance_required':
          return l10n.exhibitionDetailPoapEligibilityAttendanceHint;
        default:
          return l10n.exhibitionDetailPoapAttendanceHint;
      }
    }

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.92),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
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
            l10n.commonExhibition,
            style: KubusTextStyles.navMetaLabel.copyWith(
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
        height: 248,
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
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailIdentityBlock(
                title: exhibition.title,
                kicker: l10n.commonExhibition,
                subtitle: exhibition.host == null
                    ? null
                    : l10n.exhibitionDetailHostedBy(
                        exhibition.host!.displayName ??
                            exhibition.host!.username ??
                            l10n.commonUnknown,
                      ),
              ),
              const SizedBox(height: KubusSpacing.md),
              DetailMetadataBlock(
                compact: true,
                items: [
                  if (dateRange != null)
                    DetailMetaItem(icon: Icons.schedule, label: dateRange),
                  if (location != null)
                    DetailMetaItem(
                      icon: Icons.place_outlined,
                      label: location,
                    ),
                  DetailMetaItem(
                    icon: Icons.event_available_outlined,
                    label: _labelForExhibitionStatus(l10n, exhibition.status),
                  ),
                ],
              ),
              if ((exhibition.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: KubusSpacing.md),
                DetailSectionLabel(label: l10n.commonDescription),
                Text(
                  exhibition.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: KubusHeaderMetrics.screenSubtitle,
                        height: 1.5,
                        color: scheme.onSurface.withValues(alpha: 0.78),
                      ),
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: KubusSpacing.lg),
              ],
              DetailSectionLabel(label: l10n.commonDetails),
              DetailContextCluster(
                compact: true,
                items: [
                  DetailContextItem(
                    icon: Icons.art_track,
                    value: '${exhibition.artworkIds.length}',
                    label: l10n.exhibitionDetailArtworksTitle,
                  ),
                ],
              ),
              if (poap?.poap != null) ...[
                const SizedBox(height: KubusSpacing.lg),
                PoapDetailCard(
                  title: l10n.exhibitionDetailPoapTitle,
                  description: poap!.poap.description?.trim().isNotEmpty == true
                      ? poap.poap.description!.trim()
                      : l10n.exhibitionDetailPoapDescription,
                  code: poap.poap.code,
                  iconUrl: poap.poap.iconUrl,
                  rarityLabel: poap.poap.rarity,
                  rewardLabel: poap.poap.rewardKub8 > 0
                      ? '+${poap.poap.rewardKub8} KUB8'
                      : null,
                  stateLabel: poap.claimed
                      ? l10n.exhibitionDetailPoapClaimedStatus
                      : l10n.exhibitionDetailPoapNotClaimedStatus,
                  eligibilityLabel: poapEligibilityLabel(),
                  eligibilityHint: poapEligibilityHint(),
                  signedOutHint: null,
                  contextItems: buildPoapContextItems(),
                  isClaimed: poap.claimed,
                  canClaim: !poap.claimed && poap.canClaim,
                  isClaiming: _isClaimingSelectedExhibitionPoap,
                  onClaim: () => unawaited(
                    _claimSelectedExhibitionPoap(exhibition.id),
                  ),
                  claimActionLabel: l10n.exhibitionDetailPoapClaimAction,
                  claimingActionLabel: l10n.exhibitionDetailPoapClaimingAction,
                ),
              ],
              const SizedBox(height: KubusSpacing.lg),
              DetailActionsSection(
                title: l10n.commonActions,
                labelPosition: DetailActionLabelPosition.afterPrimary,
                primaryToLabelSpacing: KubusSpacing.md,
                maxVisibleActions: 3,
                primaryAction: Row(
                  children: [
                    Expanded(
                      child: DetailPrimaryCtaButton(
                        onPressed: () {
                          final attendanceMarkerId =
                              _kubusMapController.selectedMarkerData?.id;
                          _openDesktopSubScreenOrPush(
                            title: exhibition.title,
                            screenBuilder: (embedded) => ExhibitionDetailScreen(
                              exhibitionId: exhibition.id,
                              attendanceMarkerId: attendanceMarkerId,
                              embedded: embedded,
                            ),
                          );
                        },
                        icon: AppColorUtils.exhibitionIcon,
                        iconSize: 20,
                        label: l10n.commonViewDetails,
                        backgroundColor: exhibitionAccent,
                        foregroundColor: ThemeData.estimateBrightnessForColor(
                                    exhibitionAccent) ==
                                Brightness.dark
                            ? KubusColors.textPrimaryDark
                            : KubusColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                actions: [
                  DetailSecondaryAction(
                    icon: Icons.share_outlined,
                    label: l10n.commonShare,
                    onTap: () {
                      ShareService().showShareSheet(
                        context,
                        target: ShareTarget.exhibition(
                          exhibitionId: exhibition.id,
                          title: exhibition.title,
                        ),
                        sourceScreen: 'desktop_map',
                      );
                    },
                    tooltip: l10n.commonShare,
                  ),
                  if (exhibition.lat != null && exhibition.lng != null)
                    DetailSecondaryAction(
                      icon: Icons.directions,
                      label: l10n.commonGetDirections,
                      onTap: () async {
                        final uri = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${exhibition.lat},${exhibition.lng}',
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      tooltip: l10n.commonGetDirections,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventDetailPanel(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final event = _selectedEvent;
    if (event == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final eventAccent = AppColorUtils.eventColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exhibitionsCount = context.select<EventsProvider, int>(
      (provider) => provider.exhibitionsForEvent(event.id).length,
    );

    String? dateRange;
    if (event.startsAt != null || event.endsAt != null) {
      final start =
          event.startsAt != null ? _formatPanelDate(event.startsAt!) : null;
      final end = event.endsAt != null ? _formatPanelDate(event.endsAt!) : null;
      dateRange = [start, end].whereType<String>().join(' - ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final locationBits = <String>[
      if ((event.locationName ?? '').trim().isNotEmpty)
        event.locationName!.trim(),
      if ((event.city ?? '').trim().isNotEmpty) event.city!.trim(),
      if ((event.country ?? '').trim().isNotEmpty) event.country!.trim(),
    ];
    final location = locationBits.isNotEmpty ? locationBits.join(', ') : null;
    final coverUrl = MediaUrlResolver.resolve(event.coverUrl);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.92),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_outlined,
            size: 16,
            color: eventAccent,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.mapMarkerSubjectTypeEvent,
            style: KubusTextStyles.navMetaLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: eventAccent,
            ),
          ),
        ],
      ),
    );

    return KubusDetailPanel(
      kind: DetailPanelKind.event,
      presentation: PanelPresentation.sidePanel,
      margin: const EdgeInsets.only(left: 24),
      header: DetailHeader(
        imageUrl: coverUrl,
        imageVersion: KubusCachedImage.versionTokenFromDate(
          event.updatedAt ?? event.createdAt,
        ),
        height: 248,
        accentColor: eventAccent,
        closeTooltip: l10n.commonClose,
        onClose: () {
          setState(() => _selectedEvent = null);
        },
        badge: badge,
        closeAccentColor: themeProvider.accentColor,
        fallbackIcon: Icons.event_outlined,
      ),
      sections: [
        Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailIdentityBlock(
                title: event.title,
                kicker: l10n.mapMarkerSubjectTypeEvent,
                subtitle: event.host == null
                    ? null
                    : l10n.exhibitionDetailHostedBy(
                        event.host!.displayName ??
                            event.host!.username ??
                            l10n.commonUnknown,
                      ),
              ),
              const SizedBox(height: KubusSpacing.md),
              DetailMetadataBlock(
                compact: true,
                items: [
                  if (dateRange != null)
                    DetailMetaItem(icon: Icons.schedule, label: dateRange),
                  if (location != null)
                    DetailMetaItem(
                      icon: Icons.place_outlined,
                      label: location,
                    ),
                  DetailMetaItem(
                    icon: Icons.collections_outlined,
                    label: l10n
                        .eventDetailLinkedExhibitionsSummary(exhibitionsCount),
                  ),
                  if ((event.status ?? '').trim().isNotEmpty)
                    DetailMetaItem(
                      icon: Icons.event_available_outlined,
                      label: _labelForPanelStatus(l10n, event.status),
                    ),
                ],
              ),
              if ((event.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: KubusSpacing.md),
                DetailSectionLabel(label: l10n.commonDescription),
                Text(
                  event.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: KubusHeaderMetrics.screenSubtitle,
                        height: 1.5,
                        color: scheme.onSurface.withValues(alpha: 0.78),
                      ),
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: KubusSpacing.lg),
              ],
              DetailSectionLabel(label: l10n.commonDetails),
              DetailContextCluster(
                compact: true,
                items: [
                  DetailContextItem(
                    icon: Icons.collections_outlined,
                    value: '$exhibitionsCount',
                    label: l10n.eventDetailLinkedExhibitionsLabel,
                  ),
                ],
              ),
              const SizedBox(height: KubusSpacing.lg),
              DetailActionsSection(
                title: l10n.commonActions,
                labelPosition: DetailActionLabelPosition.afterPrimary,
                primaryToLabelSpacing: KubusSpacing.md,
                maxVisibleActions: 3,
                primaryAction: SizedBox(
                  width: double.infinity,
                  child: DetailPrimaryCtaButton(
                    onPressed: () {
                      _openDesktopSubScreenOrPush(
                        title: event.title,
                        screenBuilder: (_) => EventDetailScreen(
                          eventId: event.id,
                          initialEvent: event,
                        ),
                      );
                    },
                    icon: Icons.event_outlined,
                    iconSize: 20,
                    label: l10n.commonViewDetails,
                    backgroundColor: eventAccent,
                    foregroundColor:
                        ThemeData.estimateBrightnessForColor(eventAccent) ==
                                Brightness.dark
                            ? KubusColors.textPrimaryDark
                            : KubusColors.textPrimaryLight,
                  ),
                ),
                actions: [
                  DetailSecondaryAction(
                    icon: Icons.share_outlined,
                    label: l10n.commonShare,
                    onTap: () {
                      ShareService().showShareSheet(
                        context,
                        target: ShareTarget.event(
                          eventId: event.id,
                          title: event.title,
                        ),
                        sourceScreen: 'desktop_map',
                      );
                    },
                    tooltip: l10n.commonShare,
                  ),
                  if (event.lat != null && event.lng != null)
                    DetailSecondaryAction(
                      icon: Icons.directions,
                      label: l10n.commonGetDirections,
                      onTap: () async {
                        final uri = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${event.lat},${event.lng}',
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      tooltip: l10n.commonGetDirections,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatPanelDate(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _formatExhibitionDate(DateTime dt) => _formatPanelDate(dt);

  String _labelForPanelStatus(AppLocalizations l10n, String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return l10n.commonUnknown;
    if (v == 'published') return l10n.commonPublished;
    if (v == 'draft') return l10n.commonDraft;
    return v;
  }

  String _labelForExhibitionStatus(AppLocalizations l10n, String? raw) =>
      _labelForPanelStatus(l10n, raw);

  void _openDesktopSubScreenOrPush({
    required String title,
    required Widget Function(bool embedded) screenBuilder,
  }) {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(
          title: title,
          child: screenBuilder(true),
        ),
      );
      return;
    }

    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => screenBuilder(false),
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final useMapBlur = kubusMapBlurEnabled(context);
    return KubusFilterPanel(
      title: l10n.mapFiltersTitle,
      onClose: () => setState(() => _showFiltersPanel = false),
      closeTooltip: l10n.commonClose,
      margin: const EdgeInsets.only(left: KubusSpacing.lg),
      contentPadding: const EdgeInsets.all(KubusSpacing.lg),
      expandContent: true,
      absorbPointer: true,
      showFooterDivider: true,
      footer: Padding(
        padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
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
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
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
                    borderRadius: BorderRadius.circular(KubusRadius.md),
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
            style: KubusTextStyles.navLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
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
                              milliseconds: MapMarkerCollisionConfig
                                  .nearbyRadiusDebounceMs,
                            ),
                            () {
                              if (mounted) {
                                unawaited(
                                  _loadMarkersForCurrentView(
                                    force: true,
                                  ),
                                );
                              }
                            },
                          );
                        },
                  activeColor: themeProvider.accentColor,
                ),
              ),
              buildKubusMapGlassSurface(
                context: context,
                kind: KubusMapGlassSurfaceKind.button,
                borderRadius: BorderRadius.circular(KubusRadius.sm),
                tintBase: scheme.surface,
                useBlur: useMapBlur,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  l10n.commonDistanceKm(
                    _searchRadius.toStringAsFixed(1),
                  ),
                  style: KubusTextStyles.navLabel.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          Text(
            l10n.mapLayersTitle,
            style: KubusTextStyles.navLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          KubusMapMarkerLayerChips(
            l10n: l10n,
            visibility: _markerLayerVisibility,
            onToggle: (type, nextSelected) {
              setState(
                () => _markerLayerVisibility[type] = nextSelected,
              );
              _kubusMapController
                  .setMarkerTypeVisibility(_markerLayerVisibility);
              _renderCoordinator.requestStyleUpdate(force: true);
              _requestMarkerVisualSync(force: true);
            },
          ),
          const SizedBox(height: KubusSpacing.lg),
          Text(
            l10n.desktopMapSortByTitle,
            style: KubusTextStyles.navLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        KubusMapControls(
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
          showIsometricViewToggle:
              AppConfig.isFeatureEnabled('mapIsometricView'),
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
        ),
      ],
    );
  }

  Widget _buildDesktopAttributionButton() {
    final useMapBlur = kubusMapBlurEnabled(context);
    return KubusGlassIconButton(
      icon: Icons.info_outline,
      tooltip: 'Map attributions',
      borderRadius: KubusRadius.sm,
      iconColor: Theme.of(context).colorScheme.primary,
      enableBlur: useMapBlur,
      onPressed: () => unawaited(showKubusMapAttributionDialog(context)),
    );
  }

  Widget _buildDiscoveryCard(TaskProvider taskProvider) {
    final activeProgress = taskProvider.getActiveTaskProgress();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overall = taskProvider.getOverallProgress();

    return KubusMapDiscoveryCardHelpers.build(
      activeProgress: activeProgress,
      overallProgress: overall,
      expanded: _isDiscoveryExpanded,
      onToggleExpanded: () =>
          setState(() => _isDiscoveryExpanded = !_isDiscoveryExpanded),
      buildTaskRow: _buildTaskProgressRow,
      titleStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      percentStyle: KubusTypography.textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.75),
      ),
      glassPadding: const EdgeInsets.all(KubusSpacing.md),
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
        child: MapOverlayBlocker(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: _buildCreateMarkerSidebar(),
          ),
        ),
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
          .where((marker) => (marker.artworkId ?? '').trim().isNotEmpty)
          .map((marker) => marker.artworkId!.trim())
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

    unawaited(_syncPendingMarker());

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
    unawaited(_syncPendingMarker());
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
      _selectedExhibition = null;
      _selectedEvent = null;
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

  Future<void> _handleSearchResultTap(KubusSearchResult result) async {
    _mapSearchController.commitSelection(result.label);
    FocusScope.of(context).unfocus();

    if (result.position != null) {
      _moveCamera(
        result.position!,
        math.max(_effectiveZoom, 15.0),
      );
    }

    if (result.kind == KubusSearchResultKind.artwork && result.id != null) {
      unawaited(_selectArtworkById(
        result.id!,
        focusPosition: result.position,
        openDetail: true,
      ));
      return;
    }

    if (result.kind == KubusSearchResultKind.profile && result.id != null) {
      unawaited(UserProfileNavigation.open(context, userId: result.id!));
      return;
    }

    if (result.kind == KubusSearchResultKind.institution) {
      final marker = _findLoadedMarkerForSearchResult(result);
      if (marker != null) {
        _handleMarkerTap(marker);
        return;
      }

      final markerId = result.markerId?.trim() ?? '';
      if (markerId.isNotEmpty) {
        final opened = await _openMarkerById(markerId);
        if (opened) return;
      }

      final openedBySelection = await _openMarkerBySelection(
        exactMarkerId: result.markerId,
        artworkId: result.artworkId,
        subjectId: result.subjectId,
        subjectType: result.subjectType,
        preferredLabel: result.label,
        preferredPosition: result.position,
      );
      if (openedBySelection) return;

      final institutionId = result.id?.trim() ?? '';
      final profileTargetId = InstitutionNavigation.resolveProfileTargetId(
        institutionId: institutionId,
        data: result.data,
      );
      if (institutionId.isNotEmpty || profileTargetId != null) {
        if (!mounted) return;
        await InstitutionNavigation.open(
          context,
          institutionId: institutionId,
          profileTargetId: profileTargetId,
          data: result.data,
          title: result.label,
        );
      }
      return;
    }

    final isMarkerSelection = result.kind == KubusSearchResultKind.marker ||
        result.kind == KubusSearchResultKind.event;
    if (!isMarkerSelection) return;

    final marker = _findLoadedMarkerForSearchResult(result);
    if (marker != null) {
      _handleMarkerTap(marker);
      return;
    }

    final markerId = result.markerId?.trim() ?? '';
    if (markerId.isNotEmpty) {
      final opened = await _openMarkerById(markerId);
      if (opened) return;
    }

    await _openMarkerBySelection(
      exactMarkerId: result.markerId,
      artworkId: result.artworkId,
      subjectId: result.subjectId,
      subjectType: result.subjectType,
      preferredLabel: result.label,
      preferredPosition: result.position,
    );
  }

  ArtMarker? _findLoadedMarkerForSearchResult(KubusSearchResult result) {
    return resolveBestMarkerCandidate(
      _artMarkers,
      exactMarkerId: result.markerId,
      artworkId: result.artworkId,
      subjectId: result.subjectId,
      subjectType: result.subjectType,
      preferredLabel: result.label,
      preferredPosition: result.position,
    );
  }

  String _markerQueryFiltersKey() {
    final query = _mapSearchController.state.query.trim().toLowerCase();
    return 'filter=$_selectedFilter|sort=$_selectedSort|query=$query|travel=${_travelModeEnabled ? 1 : 0}';
  }

  List<Artwork> _getFilteredArtworks(
    List<Artwork> artworks, {
    LatLng? basePositionOverride,
  }) {
    final basePosition = basePositionOverride ?? _userLocation;
    var filtered = MapArtworkFiltering.filter(
      artworks: artworks,
      markers: _artMarkers,
      markerLayerVisibility: _markerLayerVisibility,
      query: _mapSearchController.state.query,
      filterKey: _selectedFilter,
      basePosition: basePosition,
      radiusKm: _effectiveSearchRadiusKm,
      strictNearbyWithoutBase: true,
    );

    switch (_selectedFilter) {
      case 'discovered':
      case 'undiscovered':
      case 'ar':
      case 'favorites':
      case 'nearby':
      case 'all':
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
    if (existingIndex >= 0 &&
        scope != _MarkerSocketScope.outOfScope &&
        _markersHaveEquivalentVisibleState(
            _artMarkers[existingIndex], marker)) {
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
    if (_artMarkers.indexWhere((m) => m.id == markerId) < 0) {
      return;
    }

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

  bool _markersHaveEquivalentVisibleState(ArtMarker current, ArtMarker next) {
    try {
      return jsonEncode(current.toMap()) == jsonEncode(next.toMap());
    } catch (_) {
      return false;
    }
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
    required double maxCardHeight,
    required int stackCount,
    required int stackIndex,
    VoidCallback? onNextStacked,
    VoidCallback? onPreviousStacked,
    ValueChanged<int>? onSelectStackIndex,
    ValueChanged<DragEndDetails>? onHorizontalDragEnd,
  }) {
    final baseColor = _resolveArtMarkerColor(marker, themeProvider);
    final primaryExhibition = marker.resolvedExhibitionSummary;
    final linkedEvent = KubusMarkerOverlayHelpers.resolveLinkedEvent(
      marker: marker,
      events: context.read<EventsProvider>().events,
    );
    final presentation = resolveMarkerOverlayPresentation(
      marker: marker,
      artwork: artwork,
      event: linkedEvent,
    );
    final exhibitionsFeatureEnabled = AppConfig.isFeatureEnabled('exhibitions');
    final exhibitionsApiAvailable = BackendApiService().exhibitionsApiAvailable;
    final canPresentExhibition = presentation.primaryTarget ==
            MapMarkerOverlayPrimaryTarget.exhibition &&
        exhibitionsFeatureEnabled &&
        primaryExhibition != null &&
        primaryExhibition.id.isNotEmpty &&
        exhibitionsApiAvailable != false;

    final distanceText = _userLocation != null
        ? _formatDistance(_calculateDistance(_userLocation!, marker.position))
        : null;
    final overlayActions = buildMarkerOverlayActions(
      context: context,
      marker: marker,
      artwork: artwork,
      canPresentExhibition: canPresentExhibition,
      baseColor: baseColor,
      sourceScreen: 'desktop_map_marker',
      onClaimTap: KubusMarkerOverlayHelpers.canOpenStreetArtClaims(marker)
          ? () {
              unawaited(_openStreetArtClaimsDialog(marker));
            }
          : null,
    );

    void openDetails() {
      unawaited(
        _openMarkerPrimaryTarget(
          marker,
          artwork: artwork,
          exhibition: primaryExhibition,
          event: linkedEvent,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MapOverlaySizing.maxCardWidth,
        maxHeight: maxCardHeight,
      ),
      child: KubusMarkerOverlayHelpers.buildOverlayCard(
        context: context,
        marker: marker,
        artwork: artwork,
        event: linkedEvent,
        baseColor: baseColor,
        canPresentExhibition: canPresentExhibition,
        distanceText: distanceText,
        onClose: _kubusMapController.dismissSelection,
        onOpenDetails: openDetails,
        actions: overlayActions,
        stackCount: stackCount,
        stackIndex: stackIndex,
        onNextStacked: onNextStacked,
        onPreviousStacked: onPreviousStacked,
        onSelectStackIndex: onSelectStackIndex,
        onHorizontalDragEnd: onHorizontalDragEnd,
        maxCardHeight: maxCardHeight,
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
    return KubusMapMarkerOverlayShell.build(
      isVisible: marker != null,
      anchorListenable: _selectedMarkerAnchorNotifier,
      contentKey: animationKey,
      onDismiss: _kubusMapController.dismissSelection,
      cursor: SystemMouseCursors.basic,
      // Keep map interactions live while a marker is selected; only the card
      // itself should intercept input.
      blockMapGestures: false,
      dismissOnBackdropTap: false,
      placementStrategy: _markerOverlayMode == _MarkerOverlayMode.centered
          ? overlay_wrapper.KubusMarkerOverlayPlacementStrategy.centered
          : overlay_wrapper.KubusMarkerOverlayPlacementStrategy.anchored,
      widthResolver: (constraints, mediaQuery) {
        return MapOverlaySizing.resolveCardWidth(
          constraints,
          preferred: MapOverlaySizing.preferredCardWidth,
          horizontalPadding: KubusSpacing.md,
        );
      },
      maxHeightResolver: (constraints, mediaQuery) {
        return MapOverlaySizing.resolveMaxCardHeight(
          constraints: constraints,
          media: mediaQuery,
        );
      },
      heightResolver: (constraints, mediaQuery, maxHeight) {
        final selectedMarker = selection.selectedMarker;
        if (selectedMarker == null) {
          return MapOverlaySizing.resolveFixedCardHeight(
            maxCardHeight: maxHeight,
          );
        }

        final selectedArtwork = selectedMarker.isExhibitionMarker
            ? null
            : artworkProvider.getArtworkById(selectedMarker.artworkId ?? '');
        final linkedEvent = KubusMarkerOverlayHelpers.resolveLinkedEvent(
          marker: selectedMarker,
          events: context.read<EventsProvider>().events,
        );

        return KubusMarkerOverlayHelpers.estimateCardHeight(
          marker: selectedMarker,
          artwork: selectedArtwork,
          event: linkedEvent,
          maxCardHeight: maxHeight,
          isCompactWidth: constraints.maxWidth < 600,
        );
      },
      markerOffset: (() {
        const baseOffset = 32.0;
        final zoomFactor = (_cameraZoom / 15.0).clamp(0.5, 1.5);
        return baseOffset * zoomFactor;
      })(),
      horizontalPadding: KubusSpacing.md,
      topPadding: KubusSpacing.md,
      bottomPadding: KubusSpacing.md,
      animation: const overlay_wrapper.KubusMarkerOverlayAnimationConfig(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
      onLayoutResolved: (resolvedLayout) {
        _handleMarkerOverlayLayoutResolved(selection, resolvedLayout);
      },
      cardBuilder: (context, layout) {
        return _buildMarkerOverlayPositionedCard(
          selection: selection,
          marker: marker!,
          artworkProvider: artworkProvider,
          themeProvider: themeProvider,
          layout: layout,
        );
      },
    );
  }

  Widget _buildMarkerOverlayPositionedCard({
    required MapMarkerSelectionState selection,
    required ArtMarker marker,
    required ArtworkProvider artworkProvider,
    required ThemeProvider themeProvider,
    required overlay_wrapper.KubusMarkerOverlayLayoutState layout,
  }) {
    final stack = selection.stackedMarkers.isNotEmpty
        ? selection.stackedMarkers
        : <ArtMarker>[marker];
    final count = stack.length;

    final int stackIndex =
        selection.stackIndex.clamp(0, math.max(0, count - 1));
    final ArtMarker visibleMarker = stack[stackIndex];
    final Artwork? visibleArtwork = visibleMarker.isExhibitionMarker
        ? null
        : artworkProvider.getArtworkById(visibleMarker.artworkId ?? '');

    return SizedBox(
      width: layout.cardWidth,
      child: RepaintBoundary(
        child: _buildMarkerOverlayCard(
          visibleMarker,
          visibleArtwork,
          themeProvider,
          maxCardHeight: layout.maxCardHeight,
          stackCount: count,
          stackIndex: stackIndex,
          onPreviousStacked: count > 1
              ? () => unawaited(_animateMarkerStackToIndex(stackIndex - 1))
              : null,
          onNextStacked: count > 1
              ? () => unawaited(_animateMarkerStackToIndex(stackIndex + 1))
              : null,
          onSelectStackIndex: count > 1
              ? (i) {
                  unawaited(_animateMarkerStackToIndex(i));
                }
              : null,
          onHorizontalDragEnd: count > 1
              ? (details) {
                  final velocityX = details.primaryVelocity ??
                      details.velocity.pixelsPerSecond.dx;
                  if (!velocityX.isFinite || velocityX.abs() < 120) {
                    return;
                  }
                  if (velocityX < 0) {
                    unawaited(_animateMarkerStackToIndex(stackIndex + 1));
                  } else {
                    unawaited(_animateMarkerStackToIndex(stackIndex - 1));
                  }
                }
              : null,
        ),
      ),
    );
  }

  bool _canOpenStreetArtClaims(ArtMarker marker) {
    return KubusMarkerOverlayHelpers.canOpenStreetArtClaims(marker);
  }

  bool _markerOwnedByCurrentUser(ArtMarker marker) {
    return KubusMarkerOverlayHelpers.markerOwnedByCurrentUser(
      marker: marker,
      walletAddress: context.read<WalletProvider>().currentWalletAddress,
      currentUserId: context.read<ProfileProvider>().currentUser?.id,
    );
  }

  Future<void> _openStreetArtClaimsDialog(ArtMarker marker) async {
    if (!_canOpenStreetArtClaims(marker)) return;

    await StreetArtClaimsDialog.show(
      context: context,
      marker: marker,
      isMarkerOwner: _markerOwnedByCurrentUser(marker),
      canUseDaoReviewActions: false,
    );
  }

  Future<void> _openMarkerPrimaryTarget(
    ArtMarker marker, {
    Artwork? artwork,
    ExhibitionSummaryDto? exhibition,
    KubusEvent? event,
  }) async {
    final resolvedEvent = event ??
        KubusMarkerOverlayHelpers.resolveLinkedEvent(
          marker: marker,
          events: context.read<EventsProvider>().events,
        );
    final presentation = resolveMarkerOverlayPresentation(
      marker: marker,
      artwork: artwork,
      event: resolvedEvent,
    );
    switch (presentation.primaryTarget) {
      case MapMarkerOverlayPrimaryTarget.exhibition:
        await _openExhibitionFromMarker(marker, exhibition, artwork);
        return;
      case MapMarkerOverlayPrimaryTarget.event:
        await _openEventFromMarker(marker, resolvedEvent);
        return;
      case MapMarkerOverlayPrimaryTarget.institution:
        await _openInstitutionFromMarker(marker, presentation.linkedSubject.id);
        return;
      case MapMarkerOverlayPrimaryTarget.artwork:
        await _openMarkerDetail(marker, artwork);
        return;
      case MapMarkerOverlayPrimaryTarget.markerInfo:
        await _showMarkerInfoFallback(marker);
        return;
    }
  }

  Future<void> _openEventFromMarker(
    ArtMarker marker,
    KubusEvent? event,
  ) async {
    final eventId = (event?.id ?? marker.subjectId ?? '').trim();
    if (eventId.isEmpty ||
        !AppConfig.isFeatureEnabled('events') ||
        BackendApiService().eventsApiAvailable == false) {
      await _showMarkerInfoFallback(marker);
      return;
    }

    final eventsProvider = context.read<EventsProvider>();
    final fetched = event ??
        await (() async {
          try {
            return await eventsProvider.fetchEvent(eventId, force: true);
          } catch (_) {
            return null;
          }
        })();

    if (!mounted) return;
    if (fetched == null) {
      await _showMarkerInfoFallback(marker);
      return;
    }

    unawaited(eventsProvider.loadEventExhibitions(fetched.id, refresh: true));
    setState(() {
      _selectedEvent = fetched;
      _selectedArtwork = null;
      _selectedExhibition = null;
      _showFiltersPanel = false;
    });
  }

  Future<void> _openInstitutionFromMarker(
    ArtMarker marker,
    String? linkedInstitutionId,
  ) async {
    final institutionId =
        (linkedInstitutionId ?? marker.subjectId ?? '').trim();
    final profileTargetId = InstitutionNavigation.resolveProfileTargetId(
      institutionId: institutionId,
      data: marker.metadata,
    );
    if (institutionId.isEmpty && profileTargetId == null) {
      await _showMarkerInfoFallback(marker);
      return;
    }

    await InstitutionNavigation.open(
      context,
      institutionId: institutionId,
      profileTargetId: profileTargetId,
      data: marker.metadata,
      title: marker.subjectTitle?.trim().isNotEmpty == true
          ? marker.subjectTitle!.trim()
          : marker.name,
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
      _selectedEvent = null;
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
        final exhibition = await exhibitionsProvider.fetchExhibition(
          resolved.id,
          force: true,
        );
        if (exhibition != null) {
          await exhibitionsProvider.fetchExhibitionPoap(
            resolved.id,
            force: true,
          );
        }
        return exhibition;
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
      _selectedEvent = null;
      _showFiltersPanel = false;
    });
  }

  Future<void> _claimSelectedExhibitionPoap(String exhibitionId) async {
    if (_isClaimingSelectedExhibitionPoap) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final exhibitionsProvider = context.read<ExhibitionsProvider>();
    final attestationProvider = context.read<AttestationProvider>();

    setState(() {
      _isClaimingSelectedExhibitionPoap = true;
    });

    try {
      final status =
          await exhibitionsProvider.claimExhibitionPoap(exhibitionId);
      if (!mounted) return;
      if (status == null) {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.exhibitionDetailPoapClaimFailedToast)),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }

      unawaited(attestationProvider.refresh(force: true));
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.exhibitionDetailPoapClaimSuccessToast)),
        tone: KubusSnackBarTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.exhibitionDetailPoapClaimFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClaimingSelectedExhibitionPoap = false;
        });
      }
    }
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
            _selectedEvent = null;
            _showFiltersPanel = false;
          });
        } else {
          setState(() {});
        }
      }
    }

    return resolvedArtwork;
  }

  Future<void> _prefetchStackArtworkData(List<ArtMarker> markers) async {
    if (!mounted || markers.isEmpty) return;

    final artworkProvider = context.read<ArtworkProvider>();
    final tasks = <Future<void>>[];

    for (final marker in markers) {
      if (marker.isExhibitionMarker) continue;
      final artworkId = (marker.artworkId ?? '').trim();
      if (artworkId.isEmpty ||
          artworkProvider.getArtworkById(artworkId) != null) {
        continue;
      }
      tasks.add(
        artworkProvider.fetchArtworkIfNeeded(artworkId).then((_) {}).catchError(
          (Object error, StackTrace _) {
            AppConfig.debugPrint(
              'DesktopMapScreen: failed to prefetch artwork $artworkId for marker ${marker.id}: $error',
            );
          },
        ),
      );
    }

    if (tasks.isEmpty) return;
    await Future.wait(tasks, eagerError: false);
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
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
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
                      : AppLocalizations.of(context)!
                          .mapNoLinkedArtworkForMarker,
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
      if (AppConfig.isFeatureEnabled('streetArtMarkers'))
        MarkerSubjectType.streetArt,
      if (subjectData.artworks.isNotEmpty) MarkerSubjectType.artwork,
      if (subjectData.exhibitions.isNotEmpty) MarkerSubjectType.exhibition,
      if (subjectData.institutions.isNotEmpty) MarkerSubjectType.institution,
      if (subjectData.events.isNotEmpty) MarkerSubjectType.event,
      if (subjectData.delegates.isNotEmpty) MarkerSubjectType.group,
    };

    final initialSubjectType =
        allowedSubjectTypes.contains(MarkerSubjectType.artwork)
            ? MarkerSubjectType.artwork
            : allowedSubjectTypes.contains(MarkerSubjectType.streetArt)
                ? MarkerSubjectType.streetArt
                : allowedSubjectTypes.contains(MarkerSubjectType.exhibition)
                    ? MarkerSubjectType.exhibition
                    : allowedSubjectTypes.contains(MarkerSubjectType.event)
                        ? MarkerSubjectType.event
                        : allowedSubjectTypes
                                .contains(MarkerSubjectType.institution)
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
      _selectedEvent = null;
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
      final walletAddress = context.read<WalletProvider>().currentWalletAddress;
      final tileProviders = Provider.of<TileProviders?>(context, listen: false);
      String? coverImageUrl;
      if (KubusMapMarkerCreationHelpers.shouldUploadStreetArtCover(
        markerType: form.markerType,
        subjectType: form.subjectType,
        coverImageBytes: form.coverImageBytes,
      )) {
        coverImageUrl =
            await KubusMapMarkerCreationHelpers.uploadStreetArtCover(
          fileBytes: form.coverImageBytes!,
          fileName: form.coverImageFileName,
          fileType: form.coverImageFileType,
          walletAddress: walletAddress,
          source: 'desktop_map_screen_create_marker',
          debugLabel: 'DesktopMapScreen',
        );
        if (coverImageUrl == null) return false;
      }

      final currentZoom = _effectiveZoom;
      final gridCell = GridUtils.gridCellForZoom(position, currentZoom);
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
          if (coverImageUrl != null && coverImageUrl.isNotEmpty)
            'coverImageUrl': coverImageUrl,
          if (form.isCommunity) ...{
            'isCommunity': true,
            'community': 'community',
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
          SnackBar(content: Text(e.message)),
          tone: KubusSnackBarTone.error,
        );
      }
      AppConfig.debugPrint('DesktopMapScreen: marker creation rejected: $e');
      return false;
    } catch (e) {
      AppConfig.debugPrint('DesktopMapScreen: error creating marker: $e');
      return false;
    }
  }
}
