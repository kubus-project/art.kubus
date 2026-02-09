import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/map/shared/map_screen_shared_helpers.dart';
import '../providers/artwork_provider.dart';
import '../providers/task_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/themeprovider.dart';
import '../providers/map_deep_link_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/main_tab_provider.dart';
import '../providers/exhibitions_provider.dart';
import '../providers/marker_management_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/presence_provider.dart';
import '../models/artwork.dart';
import '../models/task.dart';
import '../models/map_marker_subject.dart';
import '../services/ar_integration_service.dart';
import '../services/map_marker_service.dart';
import '../services/search_service.dart';
import '../services/push_notification_service.dart';
import '../services/map_attribution_helper.dart';
import '../core/app_route_observer.dart';
import '../models/art_marker.dart';
import '../widgets/map_marker_style_config.dart';
import '../utils/artwork_navigation.dart';
import 'community/user_profile_screen.dart';
import '../utils/grid_utils.dart';
import '../utils/artwork_media_resolver.dart';
import '../utils/design_tokens.dart';

import '../utils/app_color_utils.dart';
import '../utils/kubus_color_roles.dart';
import '../utils/art_marker_list_diff.dart';
import '../utils/debouncer.dart';
import '../utils/map_marker_helper.dart';
import '../utils/map_marker_subject_loader.dart';
import '../utils/map_search_suggestion.dart';
import '../utils/map_viewport_utils.dart';
import '../utils/map_perf_tracker.dart';
import '../utils/map_performance_debug.dart';
import '../utils/presence_marker_visit.dart';
import '../utils/geo_bounds.dart';
import '../widgets/map_marker_dialog.dart';
import '../providers/tile_providers.dart';
import '../widgets/art_map_view.dart';
import 'dart:ui' as ui;
import '../services/backend_api_service.dart';
import '../services/map_data_controller.dart';
import '../services/map_style_service.dart';
import '../config/config.dart';
import '../features/map/map_view_mode_prefs.dart';
import '../features/map/shared/map_screen_constants.dart';
import '../features/map/map_layers_manager.dart';
import '../features/map/map_overlay_stack.dart';
import '../features/map/controller/kubus_map_controller.dart';
import '../features/map/search/map_search_controller.dart';
import '../features/map/nearby/nearby_art_controller.dart';
import '../utils/marker_cube_geometry.dart';
import 'events/exhibition_detail_screen.dart';
import '../widgets/glass_components.dart';
import '../widgets/kubus_snackbar.dart';
import '../widgets/map_overlay_blocker.dart';
import '../widgets/search/kubus_search_bar.dart';
import '../widgets/map/nearby/kubus_nearby_art_panel.dart';
import '../widgets/map/controls/kubus_map_primary_controls.dart';
import '../widgets/tutorial/interactive_tutorial_overlay.dart';
import '../widgets/marker_overlay_card.dart';
import '../widgets/map/kubus_map_marker_rendering.dart';
import '../widgets/map/kubus_map_marker_geojson_builder.dart';
import '../widgets/map/kubus_map_marker_features.dart';
import '../widgets/map/discovery/kubus_discovery_path_card.dart';
import '../widgets/map/filters/kubus_map_glass_chip.dart';
import '../widgets/map/filters/kubus_map_marker_layer_chips.dart';
import 'map_core/map_marker_interaction_controller.dart';
import 'map_core/map_camera_controller.dart';
import 'map_core/marker_visual_sync_coordinator.dart';
import 'map_core/map_data_coordinator.dart';
import 'map_core/map_ui_state_coordinator.dart';
import 'map_core/map_marker_render_coordinator.dart';

/// Custom painter for the direction cone indicator
class DirectionConePainter extends CustomPainter {
  final Color color;

  DirectionConePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Center of the size
    final center = Offset(size.width / 2, size.height / 2);

    // Draw cone pointing upward (will be rotated by the parent Transform)
    // Cone dimensions: 60Â° spread angle
    final coneAngle = math.pi / 3; // 60 degrees in radians
    final coneLength = size.height * 0.8;

    // Calculate the two edges of the cone
    final leftEdge = Offset(
      center.dx - coneLength * math.sin(coneAngle / 2),
      center.dy + coneLength * math.cos(coneAngle / 2),
    );

    final rightEdge = Offset(
      center.dx + coneLength * math.sin(coneAngle / 2),
      center.dy + coneLength * math.cos(coneAngle / 2),
    );

    // Draw the cone as a filled path
    final conePath = ui.Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(leftEdge.dx, leftEdge.dy)
      ..arcToPoint(
        rightEdge,
        radius: Radius.circular(coneLength * math.sin(coneAngle / 2) * 2),
        clockwise: false,
      )
      ..close();

    canvas.drawPath(conePath, paint);
    canvas.drawPath(conePath, strokePaint);
  }

  @override
  bool shouldRepaint(DirectionConePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class MapScreen extends StatefulWidget {
  final LatLng? initialCenter;
  final double? initialZoom;
  final bool autoFollow;
  final String? initialMarkerId;

  const MapScreen({
    super.key,
    this.initialCenter,
    this.initialZoom,
    this.autoFollow = true,
    this.initialMarkerId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin, RouteAware {
  static const String _kPrefLocationPermissionRequested =
      'map_location_permission_requested';
  static const String _kPrefLocationServiceRequested =
      'map_location_service_requested';

  final MapPerfTracker _perf = MapPerfTracker('MapScreen');
  // Location and Map State
  LatLng? _currentPosition;
  double? _currentPositionAccuracyMeters;
  int? _currentPositionTimestampMs;
  Location? _mobileLocation;
  Timer? _timer;
  ml.MapLibreMapController? _mapController;
  MapLayersManager? _layersManager;
  late final KubusMapController _kubusMapController;
  late final MapMarkerInteractionController _markerInteractionController;
  late final MapCameraController _mapCameraController;
  late final MarkerVisualSyncCoordinator _markerVisualSyncCoordinator;
  late final NearbyArtController _nearbyArtController;
  late final MapUiStateCoordinator _mapUiStateCoordinator;
  late final MapMarkerRenderCoordinator _renderCoordinator;
  bool _autoFollow = true;
  double? _direction; // Compass direction
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<LocationData>? _mobileLocationSubscription;
  StreamSubscription<Position>? _webPositionSubscription;
  bool _mobileLocationStreamStarted = false;
  bool _mobileLocationStreamFailed = false;
  bool _cameraIsMoving = false;
  double _lastBearing = 0.0;
  double _lastPitch = 0.0;
  DateTime _lastCameraUpdateTime = DateTime.now();
  static const Duration _cameraUpdateThrottle =
      MapScreenConstants.cameraUpdateThrottle; // ~60fps
  bool _styleInitialized = false;
  bool _styleInitializationInProgress = false;
  bool _hitboxLayerReady = false;
  int _styleEpoch = 0;
  int _hitboxLayerEpoch = -1;
  final Set<String> _registeredMapImages = <String>{};
  final Set<String> _managedLayerIds = <String>{};
  final Set<String> _managedSourceIds = <String>{};
  double _lastWebAttributionBottomPx = -1;
  // Shared constants – canonical values live in MapScreenConstants.
  static const String _markerSourceId = MapScreenConstants.markerSourceId;
  static const String _markerLayerId = MapScreenConstants.markerLayerId;
  static const String _markerHitboxLayerId = MapScreenConstants.markerHitboxLayerId;
  static const String _cubeSourceId = MapScreenConstants.cubeSourceId;
  static const String _cubeLayerId = MapScreenConstants.cubeLayerId;
  static const String _cubeIconLayerId = MapScreenConstants.cubeIconLayerId;
  static const String _locationSourceId = MapScreenConstants.locationSourceId;
  static const String _locationLayerId = MapScreenConstants.locationLayerId;

  // Avoid repeatedly requesting permission/service on each timer tick
  bool _locationPermissionRequested = false;
  bool _locationServiceRequested = false;
  AppLifecycleState? _lastLifecycleState;

  // Animation
  late AnimationController _animationController;
  AnimationController? _locationIndicatorController;

  // AR Integration
  final ARIntegrationService _arIntegrationService = ARIntegrationService();
  final MapMarkerService _mapMarkerService = MapMarkerService();
  final PushNotificationService _pushNotificationService =
      PushNotificationService();
  List<ArtMarker> _artMarkers = [];
  final Set<String> _notifiedMarkers =
      {}; // Track which markers we've notified about
  final PageController _markerStackPageController = PageController();
  int _lastFocusedSelectionToken = -1;
  double _lastComputedMarkerOverlayHeightPx = 320.0;
  Offset? _markerTapRippleOffset;
  DateTime? _markerTapRippleAt;
  Color? _markerTapRippleColor;
  late final ValueNotifier<Offset?> _selectedMarkerAnchorNotifier;
  final Debouncer _cubeSyncDebouncer = Debouncer();
  bool _didOpenInitialMarker = false;
  MapDeepLinkProvider? _mapDeepLinkProvider;
  MainTabProvider? _tabProvider;
  bool _handlingDeepLinkIntent = false;
  String? _lastDeepLinkMarkerId;
  DateTime? _lastDeepLinkHandledAt;
  Timer? _proximityCheckTimer;
  bool _proximityChecksEnabled = false;
  StreamSubscription<ArtMarker>? _markerSocketSubscription;
  StreamSubscription<String>? _markerDeletedSubscription;
  bool _isMapTabVisible = true;
  bool _isAppForeground = true;
  bool _isRouteVisible = true;
  bool _mapViewMounted = true;
  PageRoute<dynamic>? _subscribedRoute;
  bool _pendingMarkerRefresh = false;
  bool _pendingMarkerRefreshForce = false;

  late final MapDataCoordinator _mapDataCoordinator;

  // Map search (shared controller + UI)
  late final MapSearchController _mapSearchController;

  final Map<ArtMarkerType, bool> _markerLayerVisibility = {
    ArtMarkerType.artwork: true,
    ArtMarkerType.institution: true,
    ArtMarkerType.event: true,
    ArtMarkerType.residency: true,
    ArtMarkerType.drop: true,
    ArtMarkerType.experience: true,
    // Default to true so backend markers with generic/legacy types are visible.
    ArtMarkerType.other: true,
  };

  String _artworkFilter = 'all';
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isSheetInteracting = false;
  // Only block map gestures in the sheet area when the sheet is expanded.
  // The default collapsed extent should not disable map interactions.
  bool _isSheetBlocking = false;
  double _nearbySheetExtent = _nearbySheetMin;
  double _markerRadiusKm = 5.0;
  bool _travelModeEnabled = false;
  bool _isometricViewEnabled = false;

  static const double _nearbySheetMin = 0.16;
  static const double _nearbySheetMax = 0.85;

  // Travel mode is viewport-based (bounds query), not huge-radius.
  double get _effectiveMarkerRadiusKm => _markerRadiusKm;

  // Interactive onboarding tutorial (coach marks)
  final GlobalKey _tutorialMapKey = GlobalKey();
  final GlobalKey _tutorialFilterButtonKey = GlobalKey();
  final GlobalKey _tutorialNearbyTitleKey = GlobalKey();
  final GlobalKey _tutorialTravelButtonKey = GlobalKey();
  final GlobalKey _tutorialCenterButtonKey = GlobalKey();
  final GlobalKey _tutorialAddMarkerButtonKey = GlobalKey();

  // Discovery and Progress
  bool _isDiscoveryExpanded = false;
  bool _filtersExpanded = false;

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

  // Camera helpers
  LatLng _cameraCenter = const LatLng(46.056946, 14.505751);
  double _lastZoom = 16.0;

  final Distance _distanceCalculator = const Distance();
  LatLng? _lastMarkerFetchCenter;
  DateTime? _lastMarkerFetchTime;
  GeoBounds? _loadedTravelBounds;
  int? _loadedTravelZoomBucket;
  static const double _markerRefreshDistanceMeters =
      MapScreenConstants.markerRefreshDistanceMeters;
  static const Duration _markerRefreshInterval =
      MapScreenConstants.markerRefreshInterval;
  bool _isLoadingMarkers = false; // Tracks the latest marker request
  int _markerRequestId = 0;

  /// NOTE: Do not cache a BuildContext-backed loader as a field/getter.
  /// Timer/async callbacks can outlive this State, and reading providers via a
  /// deactivated context triggers "Looking up a deactivated widget's ancestor".
  MarkerSubjectLoader _createSubjectLoader() => MarkerSubjectLoader(context);

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
        _perf.recordSetState('safeSetState(postFrame)');
        setState(fn);
      });
      return;
    }
    _perf.recordSetState('safeSetState');
    setState(fn);
  }

  Future<void> _handleMapStyleLoaded(ThemeProvider themeProvider) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!mounted) return;
    if (_kubusMapController.styleInitializationInProgress) return;

    final stopwatch = Stopwatch()..start();
    final scheme = Theme.of(context).colorScheme;
    _styleInitializationInProgress = true;
    _styleInitialized = false;
    _hitboxLayerReady = false;
    _hitboxLayerEpoch = -1;

    final layersManager = _layersManager;
    if (layersManager == null) {
      _styleInitializationInProgress = false;
      return;
    }

    AppConfig.debugPrint('MapScreen: style init start');

    try {
      await _kubusMapController.handleStyleLoaded(
        themeSpec: MapLayersThemeSpec(
          locationFill: scheme.secondary,
          locationStroke: scheme.surface,
        ),
      );

      if (!_kubusMapController.styleInitialized) {
        _styleInitialized = false;
        return;
      }

      if (!mounted) return;
      _styleInitialized = true;
      _styleEpoch = _kubusMapController.styleEpoch;
      _hitboxLayerReady = true;
      _hitboxLayerEpoch = _styleEpoch;
      _lastAppliedMapThemeDark = themeProvider.isDarkMode;

      await _applyThemeToMapStyle(themeProvider: themeProvider);
      await _applyIsometricCamera(enabled: _isometricViewEnabled);
      await _syncUserLocation(themeProvider: themeProvider);
      await _syncMapMarkers(themeProvider: themeProvider);
      await _renderCoordinator.updateRenderMode();

      stopwatch.stop();
      AppConfig.debugPrint(
        'MapScreen: style init done in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, st) {
      _styleInitialized = false;
      if (kDebugMode) {
        AppConfig.debugPrint('MapScreen: style init failed: $e');
      }
      if (kDebugMode) {
        AppConfig.debugPrint('MapScreen: style init stack: $st');
      }
    } finally {
      _styleInitializationInProgress = false;
    }
  }

  @override
  void initState() {
    super.initState();
    MapAttributionHelper.setMobileMapEnabled(true);
    _autoFollow = widget.autoFollow;

    // Shared UI state mirror (selection/tutorial/etc). Not yet used by the UI;
    // this is a no-behavior-change bridge for incremental refactors.
    _mapUiStateCoordinator = MapUiStateCoordinator();

    _mapSearchController = MapSearchController(
      // Preserve mobile's current UX: show the hint panel when the field is
      // focused even if the query is still empty.
      showOverlayOnFocus: true,
      scope: SearchScope.map,
      limit: 8,
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
        layers: MapScreenConstants.mobileLayerIds,
      ),
      debugTracing: kDebugMode && MapPerformanceDebug.isEnabled,
      tapConfig: const KubusMapTapConfig(
        clusterTapZoomDelta: 1.5,
      ),
      distance: _distanceCalculator,
      dismissSelectionOnUserGesture: false,
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
        final prevId = prevSelection.selectedMarkerId;
        final tokenChanged = state.selectionToken != prevToken;
        final idChanged = state.selectedMarkerId != prevId;

        final marker = state.selectedMarker;
        if (marker != null && (tokenChanged || idChanged)) {
          _maybeRecordPresenceVisitForMarker(marker);
        }

        _mapUiStateCoordinator.setMarkerSelection(
          selectionToken: state.selectionToken,
          selectedMarkerId: state.selectedMarkerId,
          selectedMarker: state.selectedMarker,
          stackedMarkers: state.stackedMarkers,
          stackIndex: state.stackIndex,
          selectedAt: state.selectedAt,
        );

        if (marker != null) {
          if (tokenChanged) {
            _renderCoordinator.startSelectionPopAnimation();
            _renderCoordinator.requestStyleUpdate(force: true);
            unawaited(_playMarkerSelectionFeedback(marker));
            _syncMarkerStackPager(state.selectionToken);
            _requestFocusSelectedMarker(state.selectionToken);
            if (!marker.isExhibitionMarker) {
              _ensureLinkedArtworkLoaded(marker);
            }
          } else if (idChanged) {
            // Paged within a stacked selection.
            _renderCoordinator.requestStyleUpdate(force: true);
            if (!marker.isExhibitionMarker) {
              _ensureLinkedArtworkLoaded(marker);
            }
          } else {
            // Selection is unchanged; marker instances may have refreshed.
            _renderCoordinator.requestStyleUpdate(force: true);
          }
        } else {
          // Selection dismissed.
          _syncMarkerStackPager(state.selectionToken);
          _renderCoordinator.requestStyleUpdate(force: true);
        }
      },
      onBackgroundTap: () {
        // Mobile currently only dismisses marker selection on background taps.
        // Keep extra UI state unchanged for parity.
      },
      onRequestMarkerLayerStyleUpdate: () {
        _renderCoordinator.requestStyleUpdate(force: true);
      },
      onRequestMarkerDataSync: () {
        _requestMarkerVisualSync();
      },
    );

    _mapCameraController = MapCameraController(
      mapController: _kubusMapController,
      isReady: () => mounted && _mapController != null,
    );

    _mapDataCoordinator = MapDataCoordinator(
      pollingEnabled: () => _pollingEnabled,
      mapReady: () => mounted && _mapController != null,
      cameraCenter: () => _cameraCenter,
      cameraZoom: () => _lastZoom,
      travelModeEnabled: () => _travelModeEnabled,
      hasMarkers: () => _artMarkers.isNotEmpty,
      lastFetchCenter: () => _lastMarkerFetchCenter,
      lastFetchTime: () => _lastMarkerFetchTime,
      loadedTravelBounds: () => _loadedTravelBounds,
      loadedTravelZoomBucket: () => _loadedTravelZoomBucket,
      distance: _distanceCalculator,
      refreshInterval: _markerRefreshInterval,
      refreshDistanceMeters: _markerRefreshDistanceMeters,
      getVisibleBounds: _getVisibleGeoBounds,
      refreshRadiusMode: ({required center}) async {
        await _maybeRefreshMarkers(center, force: false);
      },
      refreshTravelMode: ({
        required center,
        required bounds,
        required zoomBucket,
      }) async {
        await _loadArtMarkers(
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
    _selectedMarkerAnchorNotifier = _kubusMapController.selectedMarkerAnchor;
    _kubusMapController.setMarkerTypeVisibility(_markerLayerVisibility);
    _kubusMapController.setMarkers(_artMarkers);
    _kubusMapController.setAutoFollow(_autoFollow);

    _nearbyArtController = NearbyArtController(
      map: KubusNearbyArtMapDelegate(_kubusMapController),
      distance: _distanceCalculator,
    );

    _renderCoordinator = MapMarkerRenderCoordinator(
      screenName: 'MapScreen',
      markerLayerId: _markerLayerId,
      cubeLayerId: _cubeLayerId,
      cubeIconLayerId: _cubeIconLayerId,
      cubeSourceId: _cubeSourceId,
      isMounted: () => mounted,
      isStyleInitialized: () => _styleInitialized,
      isStyleInitInProgress: () => _styleInitializationInProgress,
      isCameraMoving: () => _cameraIsMoving,
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
    _locationIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _cubeIconSpinController = AnimationController(
      duration: MapMarkerStyleConfig.cubeIconSpinPeriod,
      vsync: this,
    )..addListener(_renderCoordinator.handleAnimationTick);
    _perf.controllerCreated('selection_pop');
    _perf.controllerCreated('location_indicator');
    _perf.controllerCreated('cube_spin');
    _perf.logEvent('initState');

    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    final isWidgetTest = bindingName.contains('TestWidgetsFlutterBinding') ||
        bindingName.contains('AutomatedTestWidgetsFlutterBinding');
    if (isWidgetTest) return;

    // Load persisted permission/service request flags, then initialize map
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Track this screen visit for quick actions
      if (mounted) {
        Provider.of<NavigationProvider>(context, listen: false)
            .trackScreenVisit('map');
      }

      await _loadPersistedPermissionFlags();
      if (!mounted) return;

      await _loadMapTravelPrefs();
      if (!mounted) return;

      await _loadMapIsometricPrefs();
      if (!mounted) return;

      _initializeMap();

      if (!mounted) return;
      if (widget.initialCenter != null) {
        _autoFollow = widget.autoFollow;
        _kubusMapController.setAutoFollow(_autoFollow);
        _cameraCenter = widget.initialCenter!;
        _lastZoom = widget.initialZoom ?? _lastZoom;
      }

      // Initialize providers and calculate progress after build completes
      if (!mounted) return;
      final artworkProvider = context.read<ArtworkProvider>();
      if (artworkProvider.artworks.isEmpty) {
        _perf.recordFetch('artworks:load');
        artworkProvider.loadArtworks();
      }
      final taskProvider = context.read<TaskProvider>();
      final walletProvider = context.read<WalletProvider>();

      taskProvider.initializeProgress(); // Ensure proper initialization

      // Load real progress from backend if wallet is connected
      if (walletProvider.currentWalletAddress != null &&
          walletProvider.currentWalletAddress!.isNotEmpty) {
        AppConfig.debugPrint(
            'MapScreen: loading progress from backend for wallet: ${walletProvider.currentWalletAddress}');
        _perf.recordFetch('task:progress');
        await taskProvider
            .loadProgressFromBackend(walletProvider.currentWalletAddress!);
      } else {
        AppConfig.debugPrint(
            'MapScreen: no wallet connected; using default empty progress');
      }

      if (!mounted) return;

      unawaited(_maybeShowInteractiveMapTutorial());
    });
  }

  void _handleMapSearchControllerChanged() {
    // Keep legacy behaviors that rely on widget rebuilds (e.g. filtering the
    // nearby panel list by query) without reintroducing screen-local search
    // state.
    _safeSetState(() {});
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

    final tabProvider = Provider.of<MainTabProvider>(context);
    if (_tabProvider != tabProvider) {
      _tabProvider?.removeListener(_handleTabProviderChanged);
      _tabProvider = tabProvider;
      _tabProvider?.addListener(_handleTabProviderChanged);
      _handleTabProviderChanged();
    }

    final provider = Provider.of<MapDeepLinkProvider>(context);
    if (_mapDeepLinkProvider == provider) return;

    _mapDeepLinkProvider?.removeListener(_handleMapDeepLinkProviderChanged);
    _mapDeepLinkProvider = provider;
    _mapDeepLinkProvider?.addListener(_handleMapDeepLinkProviderChanged);

    // If an intent was queued before the map mounted, handle it now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleMapDeepLinkProviderChanged();
    });
  }

  bool get _pollingEnabled =>
      _isAppForeground && _isMapTabVisible && _isRouteVisible;

  void _handleTabProviderChanged() {
    final isVisible = (_tabProvider?.currentIndex ?? 0) == 0;
    _setMapTabVisible(isVisible);
  }

  void _setMapTabVisible(bool isVisible) {
    if (_isMapTabVisible == isVisible) return;
    _isMapTabVisible = isVisible;
    _handleActiveStateChanged();
    if (isVisible) {
      _scheduleWebMapResizeRecovery(reason: 'tabVisible');
    }
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

      // MapLibre GL JS can end up with a blank canvas after transient route
      // overlays (e.g. modal bottom sheets) on first load. A forced resize
      // reliably triggers a repaint without requiring a full page refresh.
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
      _setMapViewMounted(true);
      _resumePolling();
    } else {
      _pausePolling();
      _setMapViewMounted(false);
    }
  }

  void _setMapViewMounted(bool mounted) {
    if (_mapViewMounted == mounted) return;
    if (!mounted) {
      _detachMapControllerForInactivity();
    }
    MapAttributionHelper.setMobileMapEnabled(mounted);
    _safeSetState(() => _mapViewMounted = mounted);
  }

  void _detachMapControllerForInactivity() {
    final controller = _mapController;
    if (controller == null) return;

    _kubusMapController.detachMapController();

    _mapController = null;
    _layersManager = null;
    _styleInitialized = false;
    _styleInitializationInProgress = false;
    _hitboxLayerReady = false;
    _styleEpoch = _kubusMapController.styleEpoch;
    _perf.logEvent('mapDetached');
  }

  @override
  void didPushNext() {
    KubusMapRouteAwareHelpers.didPushNext(setRouteVisible: _setRouteVisible);
  }

  @override
  void didPopNext() {
    KubusMapRouteAwareHelpers.didPopNext(setRouteVisible: _setRouteVisible);
  }

  void _pausePolling() {
    _timer?.cancel();
    _perf.timerStopped('location_timer');
    _proximityCheckTimer?.cancel();
    _perf.timerStopped('proximity_timer');
    // Search UI is local-only; no background polling required.
    _mapDataCoordinator.cancelPending();
    _cubeSyncDebouncer.cancel();

    _renderCoordinator.updateCubeSpinTicker();
    final mobileSub = _mobileLocationSubscription;
    if (mobileSub != null) {
      try {
        mobileSub.pause();
      } catch (_) {}
      _perf.subscriptionStopped('mobile_location_stream');
    }
    final webSub = _webPositionSubscription;
    if (webSub != null) {
      try {
        webSub.pause();
      } catch (_) {}
      _perf.subscriptionStopped('web_location_stream');
    }
    final compassSub = _compassSubscription;
    if (compassSub != null) {
      try {
        compassSub.pause();
      } catch (_) {}
      _perf.subscriptionStopped('compass');
    }
    final markerCreatedSub = _markerSocketSubscription;
    if (markerCreatedSub != null) {
      try {
        markerCreatedSub.pause();
      } catch (_) {}
      _perf.subscriptionStopped('marker_socket_created');
    }
    final markerDeletedSub = _markerDeletedSubscription;
    if (markerDeletedSub != null) {
      try {
        markerDeletedSub.pause();
      } catch (_) {}
      _perf.subscriptionStopped('marker_socket_deleted');
    }
  }

  void _resumePolling() {
    final mobileSub = _mobileLocationSubscription;
    if (mobileSub != null) {
      try {
        mobileSub.resume();
      } catch (_) {}
      _perf.subscriptionStarted('mobile_location_stream');
    }
    final webSub = _webPositionSubscription;
    if (webSub != null) {
      try {
        webSub.resume();
      } catch (_) {}
      _perf.subscriptionStarted('web_location_stream');
    }
    final compassSub = _compassSubscription;
    if (compassSub != null) {
      try {
        compassSub.resume();
      } catch (_) {}
      _perf.subscriptionStarted('compass');
    }
    final markerCreatedSub = _markerSocketSubscription;
    if (markerCreatedSub != null) {
      try {
        markerCreatedSub.resume();
      } catch (_) {}
      _perf.subscriptionStarted('marker_socket_created');
    }
    final markerDeletedSub = _markerDeletedSubscription;
    if (markerDeletedSub != null) {
      try {
        markerDeletedSub.resume();
      } catch (_) {}
      _perf.subscriptionStarted('marker_socket_deleted');
    }

    _startLocationTimer();

    if (_proximityChecksEnabled &&
        (_proximityCheckTimer == null ||
            !(_proximityCheckTimer?.isActive ?? false))) {
      _proximityCheckTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkProximityNotifications(),
      );
      _perf.timerStarted('proximity_timer');
    }

    _renderCoordinator.updateCubeSpinTicker();
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

  Future<void> _loadMapTravelPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = await MapViewModePrefs.loadTravelModeEnabled(prefs);
      if (!mounted) return;
      setState(() {
        _travelModeEnabled = enabled;
      });
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _loadMapIsometricPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = await MapViewModePrefs.loadIsometricViewEnabled(prefs);
      if (!mounted) return;
      setState(() {
        _isometricViewEnabled = enabled;
      });
    } catch (_) {
      // Best-effort.
    }
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
      final prefs = await SharedPreferences.getInstance();
      await MapViewModePrefs.persistTravelModeEnabled(prefs, enabled);
    } catch (_) {
      // Best-effort.
    }

    // In travel mode we want an immediate viewport refresh (bounds-based).
    unawaited(_loadMarkersForCurrentView(force: true));
  }

  Future<void> _setIsometricViewEnabled(bool enabled) async {
    if (!mounted) return;
    setState(() {
      _isometricViewEnabled = enabled;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await MapViewModePrefs.persistIsometricViewEnabled(prefs, enabled);
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
          prefs.getBool(PreferenceKeys.mapOnboardingMobileSeenV2) ?? false;
      if (seen) return;

      // Wait until the UI is laid out so we can compute highlight rects.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapUiStateCoordinator.setTutorial(show: true, index: 0);
      });
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _setMapTutorialSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PreferenceKeys.mapOnboardingMobileSeenV2, true);
    } catch (_) {
      // Best-effort.
    }
  }

  void _dismissMapTutorial() {
    KubusMapTutorialNav.dismiss(
      mounted: mounted,
      coordinator: _mapUiStateCoordinator,
      persistSeen: _setMapTutorialSeen,
    );
  }

  void _tutorialNext() {
    final steps = _buildMapTutorialSteps(AppLocalizations.of(context)!);
    KubusMapTutorialNav.next(
      mounted: mounted,
      coordinator: _mapUiStateCoordinator,
      stepsLength: steps.length,
      onDismiss: _dismissMapTutorial,
    );
  }

  void _tutorialBack() {
    KubusMapTutorialNav.back(
      mounted: mounted,
      coordinator: _mapUiStateCoordinator,
    );
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
        targetKey: _tutorialAddMarkerButtonKey,
        icon: Icons.add_location_alt,
        title: l10n.mapTutorialStepCreateMarkerTitle,
        body: l10n.mapTutorialStepCreateMarkerBody,
      ),
      TutorialStepDefinition(
        targetKey: _tutorialNearbyTitleKey,
        icon: Icons.view_list,
        title: l10n.mapTutorialStepNearbyTitle,
        body: l10n.mapTutorialStepNearbyBody,
        onTargetTap: () {
          // Expand the sheet a bit so users see the list.
          try {
            _sheetController.animateTo(
              0.50,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          } catch (_) {}
        },
      ),
      TutorialStepDefinition(
        targetKey: _tutorialFilterButtonKey,
        icon: Icons.filter_alt_outlined,
        title: l10n.mapTutorialStepFiltersTitle,
        body: l10n.mapTutorialStepFiltersBody,
        onTargetTap: () {
          if (!mounted) return;
          setState(() {
            _filtersExpanded = true;
          });
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

    // Optional: end on the recenter control so users know how to get back.
    steps.add(
      TutorialStepDefinition(
        targetKey: _tutorialCenterButtonKey,
        icon: Icons.my_location,
        title: l10n.mapTutorialStepRecenterTitle,
        body: l10n.mapTutorialStepRecenterBody,
      ),
    );

    return steps;
  }

  Future<void> _loadPersistedPermissionFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p1 = prefs.getBool(_kPrefLocationPermissionRequested) ?? false;
      final p2 = prefs.getBool(_kPrefLocationServiceRequested) ?? false;
      if (!mounted) return;
      setState(() {
        _locationPermissionRequested = p1;
        _locationServiceRequested = p2;
      });
    } catch (e) {
      AppConfig.debugPrint(
          'MapScreen: failed to load persisted permission flags: $e');
    }
  }

  @override
  void dispose() {
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    MapAttributionHelper.setMobileMapEnabled(false);
    _mapDeepLinkProvider?.removeListener(_handleMapDeepLinkProviderChanged);
    _mapDeepLinkProvider = null;
    _tabProvider?.removeListener(_handleTabProviderChanged);
    _tabProvider = null;
    _mapCameraController.dispose();
    _markerVisualSyncCoordinator.dispose();
    _mapDataCoordinator.dispose();
    _mapUiStateCoordinator.dispose();
    _kubusMapController.dispose();
    _mapController = null;
    _layersManager = null;
    _styleInitialized = false;
    _registeredMapImages.clear();
    _managedLayerIds.clear();
    _managedSourceIds.clear();
    _timer?.cancel();
    _perf.timerStopped('location_timer');
    _mapSearchController.dispose();
    if (_compassSubscription != null) {
      _perf.subscriptionStopped('compass');
      unawaited(_compassSubscription!.cancel().catchError((_) {/* ignore */}));
    }
    if (_mobileLocationSubscription != null) {
      _perf.subscriptionStopped('mobile_location_stream');
      unawaited(
        _mobileLocationSubscription!.cancel().catchError((_) {/* ignore */}),
      );
    }
    if (_webPositionSubscription != null) {
      _perf.subscriptionStopped('web_location_stream');
      unawaited(
          _webPositionSubscription!.cancel().catchError((_) {/* ignore */}));
    }
    _proximityCheckTimer?.cancel();
    _perf.timerStopped('proximity_timer');
    _markerSocketSubscription?.cancel();
    _perf.subscriptionStopped('marker_socket_created');
    _markerDeletedSubscription?.cancel();
    _perf.subscriptionStopped('marker_socket_deleted');
    _cubeSyncDebouncer.dispose();
    _animationController.dispose();
    _perf.controllerDisposed('selection_pop');
    _cubeIconSpinController.dispose();
    _perf.controllerDisposed('cube_spin');
    _locationIndicatorController?.dispose();
    _perf.controllerDisposed('location_indicator');
    _markerStackPageController.dispose();
    _sheetController.dispose();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    _isAppForeground = state != AppLifecycleState.paused &&
        state != AppLifecycleState.inactive;
    _handleActiveStateChanged();
    super.didChangeAppLifecycleState(state);
  }

  void _initializeMap() {
    if (!kIsWeb) {
      _mobileLocation = Location();
    }

    // Do not block first entry with OS permission dialogs. We'll still resolve
    // location immediately when already granted, and only prompt on explicit
    // user action (e.g. tapping the location controls).
    _getLocation(promptForPermission: false);
    _startLocationTimer();

    final supportsCompass = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (supportsCompass) {
      try {
        final compassStream = FlutterCompass.events;
        if (compassStream != null) {
          _compassSubscription?.cancel();
          _perf.subscriptionStopped('compass');
          _compassSubscription = compassStream.listen((CompassEvent event) {
            if (mounted) {
              _updateDirection(event.heading);
            }
          });
          _perf.subscriptionStarted('compass');
        }
      } catch (e) {
        AppConfig.debugPrint('MapScreen: compass unavailable: $e');
      }
    }

    WidgetsBinding.instance.addObserver(this);

    if (kIsWeb) {
      _startWebLocationStream();
    }

    // Socket listeners for real-time marker sync (all platforms).
    _initializeMarkerSocketListeners();

    if (!kIsWeb && AppConfig.isFeatureEnabled('ar')) {
      // Initialize AR integration (mobile-only).
      _initializeARIntegration();
    }
  }

  /// Sets up socket listeners for real-time marker updates.
  /// Called unconditionally from _initializeMap() for all users.
  void _initializeMarkerSocketListeners() {
    // Avoid duplicate subscriptions if called multiple times.
    if (_markerSocketSubscription == null) {
      _markerSocketSubscription =
          _mapMarkerService.onMarkerCreated.listen(_handleMarkerCreated);
      _perf.subscriptionStarted('marker_socket_created');
    }
    if (_markerDeletedSubscription == null) {
      _markerDeletedSubscription =
          _mapMarkerService.onMarkerDeleted.listen(_handleMarkerDeleted);
      _perf.subscriptionStarted('marker_socket_deleted');
    }
  }

  Future<void> _initializeARIntegration() async {
    try {
      await _arIntegrationService.initialize();
      await _pushNotificationService.initialize();

      // Set up notification tap handler
      _pushNotificationService.onNotificationTap = _handleNotificationTap;

      // Start proximity checking timer (every 10 seconds)
      _proximityCheckTimer?.cancel();
      _perf.timerStopped('proximity_timer');
      _proximityCheckTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkProximityNotifications(),
      );
      _perf.timerStarted('proximity_timer');
      _proximityChecksEnabled = true;
    } catch (e) {
      _proximityChecksEnabled = false;
      AppConfig.debugPrint(
          'MapScreen: failed to initialize AR integration: $e');
    }
  }

  Future<void> _loadMarkersForCurrentView({bool force = false}) async {
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh(force: force);
      return;
    }
    LatLng? center;
    GeoBounds? bounds;
    int? zoomBucket;

    center = _cameraCenter;
    if (_travelModeEnabled) {
      zoomBucket = MapViewportUtils.zoomBucket(_lastZoom);
      final visible = await _getVisibleGeoBounds();
      if (visible != null) {
        bounds = MapViewportUtils.expandBounds(
          visible,
          MapViewportUtils.paddingFractionForZoomBucket(zoomBucket),
        );
      }
    }

    await _loadArtMarkers(
      center: center,
      bounds: bounds,
      force: force,
      zoomBucket: zoomBucket,
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
      _showArtMarkerDialog(existing.first);
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
      _kubusMapController.setMarkers(_artMarkers);
      _showArtMarkerDialog(marker);
    } catch (_) {
      // Best-effort: if marker fetch fails, keep user on the map screen.
    }
  }

  void _handleMapDeepLinkProviderChanged() {
    final provider = _mapDeepLinkProvider;
    if (provider == null) return;

    final intent = provider.consumePending();
    if (intent == null) return;

    unawaited(_handleMapDeepLinkIntent(intent).catchError((e) {
      if (kDebugMode) debugPrint('MapScreen: deep link intent error: $e');
    }));
  }

  Future<void> _handleMapDeepLinkIntent(MapDeepLinkIntent intent) async {
    final markerId = intent.markerId.trim();
    if (markerId.isEmpty) return;

    final now = DateTime.now();
    final lastAt = _lastDeepLinkHandledAt;
    if (_lastDeepLinkMarkerId == markerId &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(seconds: 2)) {
      return;
    }

    if (_handlingDeepLinkIntent) return;
    _handlingDeepLinkIntent = true;
    _lastDeepLinkMarkerId = markerId;
    _lastDeepLinkHandledAt = now;

    try {
      if (intent.center != null) {
        final zoom = intent.zoom ?? _lastZoom;
        unawaited(_animateMapTo(intent.center!, zoom: zoom));
      }

      await _openMarkerById(markerId);
    } finally {
      _handlingDeepLinkIntent = false;
    }
  }

  Future<void> _openMarkerById(String markerId) async {
    final id = markerId.trim();
    if (id.isEmpty) return;

    if (_kubusMapController.selectedMarkerId == id) {
      final marker = _kubusMapController.selectedMarkerData;
      if (marker != null) _showArtMarkerDialog(marker);
      return;
    }

    final existing =
        _artMarkers.where((m) => m.id == id).toList(growable: false);
    if (existing.isNotEmpty) {
      _showArtMarkerDialog(existing.first);
      return;
    }

    try {
      _perf.recordFetch('marker:get');
      final marker = await MapDataController().getArtMarkerById(id);
      if (!mounted) return;
      if (marker == null || !marker.hasValidPosition) return;
      setState(() {
        _artMarkers.removeWhere((m) => m.id == marker.id);
        _artMarkers.add(marker);
      });
      _kubusMapController.setMarkers(_artMarkers);
      _showArtMarkerDialog(marker);
    } catch (_) {
      // Best-effort: keep user on the map screen if marker fetch fails.
    }
  }

  Future<void> _loadArtMarkers(
      {LatLng? center,
      GeoBounds? bounds,
      bool force = false,
      int? zoomBucket}) async {
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh(force: force);
      return;
    }

    if (_isLoadingMarkers) {
      _queuePendingMarkerRefresh(force: force);
      return;
    }

    final queryCenter = center ?? _currentPosition ?? _cameraCenter;
    final artworkProvider = context.read<ArtworkProvider>();
    final themeProvider = context.read<ThemeProvider>();

    int? bucket = zoomBucket;
    if (_travelModeEnabled && bucket == null) {
      bucket = MapViewportUtils.zoomBucket(_lastZoom);
    }

    GeoBounds? queryBounds = bounds;
    if (_travelModeEnabled && queryBounds == null) {
      final visible = await _getVisibleGeoBounds();
      if (visible != null) {
        final effectiveBucket =
            bucket ?? MapViewportUtils.zoomBucket(_lastZoom);
        queryBounds = MapViewportUtils.expandBounds(
          visible,
          MapViewportUtils.paddingFractionForZoomBucket(effectiveBucket),
        );
        bucket = effectiveBucket;
      }
    }

    final requestId = ++_markerRequestId;
    _isLoadingMarkers = true;
    final dev.TimelineTask? timeline = MapPerformanceDebug.isEnabled
        ? (dev.TimelineTask()..start('MapScreen.loadArtMarkers'))
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
              radiusKm: _effectiveMarkerRadiusKm,
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

      final String? selectedIdBeforeSetState =
          _kubusMapController.selectedMarkerId;
      final ArtMarker? selectedMarkerBeforeSetState =
          _kubusMapController.selectedMarkerData;
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

      // Keep marker list + controller in sync. Selection/stack/anchor refresh is
      // owned by KubusMapController.
      final selectionNeedsRefresh = resolvedSelected != null &&
          selectedIdBeforeSetState == resolvedSelected.id &&
          !identical(selectedMarkerBeforeSetState, resolvedSelected);

      if (markersChanged || selectionNeedsRefresh) {
        setState(() {
          _artMarkers = merged;
        });
        _kubusMapController.setMarkers(_artMarkers);
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
      AppConfig.debugPrint('MapScreen: error loading markers: $e');
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

  void _handleMarkerCreated(ArtMarker marker) {
    try {
      if (!marker.hasValidPosition) return;
      if (_travelModeEnabled) {
        final bounds = _loadedTravelBounds;
        if (bounds == null ||
            !MapViewportUtils.containsPoint(bounds, marker.position)) {
          return;
        }
      } else if (_currentPosition != null) {
        final distanceKm = _distanceCalculator.as(
          LengthUnit.Kilometer,
          _currentPosition!,
          marker.position,
        );
        if (distanceKm > _mapMarkerService.lastQueryRadiusKm + 1) {
          // Ignore markers far outside the current view; cache will refresh when user pans/refreshes.
          return;
        }
      }
      setState(() {
        _artMarkers.removeWhere((m) => m.id == marker.id);
        _artMarkers.add(marker);
      });
      _kubusMapController.setMarkers(_artMarkers);
      unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
      AppConfig.debugPrint('MapScreen: added marker from socket ${marker.id}');
    } catch (e) {
      AppConfig.debugPrint('MapScreen: failed to handle socket marker: $e');
    }
  }

  void _handleMarkerDeleted(String markerId) {
    try {
      setState(() {
        _artMarkers.removeWhere((m) => m.id == markerId);
      });
      _kubusMapController.setMarkers(_artMarkers);
      unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
    } catch (_) {}
  }

  void _handleNotificationTap(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      final type = data['type'] as String?;

      if (type == 'ar_proximity') {
        final markerId = data['markerId']?.toString().trim();
        if (markerId == null || markerId.isEmpty) return;
        final index = _artMarkers.indexWhere((m) => m.id == markerId);
        if (index < 0) return;
        final marker = _artMarkers[index];
        if (marker.isExhibitionMarker) {
          unawaited(_openExhibitionFromMarker(marker, null, null));
          return;
        }
        final artworkId = marker.artworkId;
        if (artworkId != null && artworkId.trim().isNotEmpty) {
          unawaited(
            openArtwork(
              context,
              artworkId,
              source: 'map_proximity_push',
              attendanceMarkerId: marker.id,
            ),
          );
          return;
        }
        unawaited(_showMarkerInfoFallback(marker));
      }
    } catch (e) {
      AppConfig.debugPrint('MapScreen: failed to handle notification tap: $e');
    }
  }

  Future<void> _maybeRefreshMarkers(LatLng center, {bool force = false}) async {
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh(force: force);
      return;
    }
    final shouldRefresh = MapMarkerHelper.shouldRefreshMarkers(
      newCenter: center,
      lastCenter: _lastMarkerFetchCenter,
      lastFetchTime: _lastMarkerFetchTime,
      distance: _distanceCalculator,
      refreshInterval: _markerRefreshInterval,
      refreshDistanceMeters: _markerRefreshDistanceMeters,
      hasMarkers: _artMarkers.isNotEmpty,
      force: force,
    );

    if (shouldRefresh) {
      await _loadArtMarkers(center: center, force: force);
    }
  }

  void _checkProximityNotifications() {
    if (_currentPosition == null) return;

    final currentLatLng = _currentPosition!;
    final attendanceProvider = context.read<AttendanceProvider>();

    for (final marker in _artMarkers) {
      // Check if already notified
      if (_notifiedMarkers.contains(marker.id)) continue;

      // Calculate distance
      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        currentLatLng,
        marker.position,
      );

      attendanceProvider.updateProximity(
        markerId: marker.id,
        lat: currentLatLng.latitude,
        lng: currentLatLng.longitude,
        distanceMeters: distance,
        activationRadiusMeters: marker.activationRadius,
        requiresProximity: marker.requiresProximity,
        accuracyMeters: _currentPositionAccuracyMeters,
        timestampMs: _currentPositionTimestampMs,
      );

      // Notify if within activation radius (proximity-gated markers only).
      final radius =
          marker.activationRadius > 0 ? marker.activationRadius : 50.0;
      if (marker.requiresProximity && distance <= radius) {
        _showProximityNotification(marker, distance);
        _notifiedMarkers.add(marker.id);
      }
    }

    // Clean up notifications for markers we've moved away from (>2x radius).
    _notifiedMarkers.removeWhere((markerId) {
      final index = _artMarkers.indexWhere((m) => m.id == markerId);
      if (index < 0) return true;
      final marker = _artMarkers[index];

      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        currentLatLng,
        marker.position,
      );

      final radius =
          marker.activationRadius > 0 ? marker.activationRadius : 50.0;
      final resetDistance = math.max(100.0, radius * 2);
      return distance > resetDistance; // Reset notification if moved far away
    });
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

  Future<void> _openMarkerRadiusDialog() async {
    double tempRadius = _markerRadiusKm;
    final l10n = AppLocalizations.of(context)!;
    final result = await showKubusDialog<double>(
      context: context,
      builder: (context) {
        return KubusAlertDialog(
          title: Text(l10n.mapNearbyRadiusTitle),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.commonDistanceKm(tempRadius.toStringAsFixed(1))),
                  Slider(
                    min: 1,
                    max: 200,
                    divisions: 199,
                    value: tempRadius,
                    onChanged: (v) => setStateDialog(() => tempRadius = v),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(tempRadius),
              child: Text(l10n.commonApply),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() => _markerRadiusKm = result);
      await _loadArtMarkers(force: true);
    }
  }

  void _showProximityNotification(ArtMarker marker, double distance) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    // On web the push channel requires a service worker; skip if unsupported to avoid console spam.
    if (!kIsWeb) {
      _pushNotificationService
          .showARProximityNotification(
        marker: marker,
        distance: distance,
      )
          .catchError((e) {
        AppConfig.debugPrint(
            'MapScreen: showARProximityNotification failed: $e');
      });
    }

    // Also show in-app SnackBar
    final messenger = ScaffoldMessenger.of(context);
    messenger.showKubusSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mapArArtworkNearbyTitle,
              style: KubusTypography.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.mapArArtworkNearbySubtitle(marker.name, distance.round()),
              style: KubusTypography.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.commonView,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            if (marker.isExhibitionMarker) {
              unawaited(_openExhibitionFromMarker(marker, null, null));
              return;
            }
            final artworkId = marker.artworkId;
            if (artworkId != null && artworkId.trim().isNotEmpty) {
              unawaited(
                openArtwork(
                  context,
                  artworkId,
                  source: 'map_proximity_snackbar',
                  attendanceMarkerId: marker.id,
                ),
              );
              return;
            }
            unawaited(_showMarkerInfoFallback(marker));
          },
        ),
      ),
      tone: KubusSnackBarTone.neutral,
    );
  }

  void _handleMarkerTap(ArtMarker marker,
      {List<ArtMarker> stackedMarkers = const []}) {
    _markerInteractionController.handleMarkerTap(
      marker,
      stackedMarkers: stackedMarkers,
      beforeSelect: () {
        // Keep debug instrumentation local to the screen.
        if (kDebugMode) {
          _debugMarkerTapCount += 1;
          if (_debugMarkerTapCount % 30 == 0) {
            AppConfig.debugPrint(
              'MapScreen: marker taps=$_debugMarkerTapCount',
            );
          }
        }
      },
    );
  }

  void _setSheetInteracting(bool value) {
    if (_isSheetInteracting == value) return;
    _safeSetState(() => _isSheetInteracting = value);
  }

  void _setSheetBlocking(bool value, double extent) {
    if (_isSheetBlocking == value && _nearbySheetExtent == extent) return;
    _safeSetState(() {
      _isSheetBlocking = value;
      _nearbySheetExtent = extent;
    });
  }

  void _dismissSelectedMarker() {
    _kubusMapController.dismissSelection();
  }

  void _syncMarkerStackPager(int selectionToken) {
    // Ensure the PageView shows the first marker in the stack when a new marker
    // is selected (or when the overlay is dismissed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectionToken != _kubusMapController.selectionState.selectionToken) {
        return;
      }
      if (!_markerStackPageController.hasClients) return;
      final targetPage = (_kubusMapController.selectedMarkerData == null)
          ? 0
          : _kubusMapController.selectedMarkerStackIndex;
      try {
        _markerStackPageController.jumpToPage(targetPage);
      } catch (_) {
        // Best-effort; controller may not be attached during transitions.
      }
    });
  }

  void _requestFocusSelectedMarker(int selectionToken) {
    // Never call camera movement from build(). Instead, schedule a controlled
    // focus effect that runs at most once per selection token.
    if (_kubusMapController.selectedMarkerData == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectionToken != _kubusMapController.selectionState.selectionToken) {
        return;
      }
      if (_kubusMapController.selectedMarkerData == null) return;
      if (_lastFocusedSelectionToken == selectionToken) return;
      if (_styleInitializationInProgress || !_styleInitialized) return;

      final marker = _kubusMapController.selectedMarkerData!;

      // Compute a deterministic vertical offset based on the last computed
      // overlay height. This avoids the visible two-step recenter.
      final media = MediaQuery.of(context);
      final size = _mapViewportSize() ?? media.size;
      final overlayHeight = _lastComputedMarkerOverlayHeightPx;
      final topSafe = media.padding.top;
      final double minMarkerY =
          (topSafe + overlayHeight + 24).clamp(0.0, size.height).toDouble();

      final double desiredY = math
          .max(size.height * (2 / 3), minMarkerY)
          .clamp(0.0, size.height)
          .toDouble();
      final double dy = desiredY - (size.height / 2);

      // If the required offset is negligible, just center at the target zoom.
      final Offset offset = dy.abs() < 1.0 ? Offset.zero : Offset(0, -dy);

      _lastFocusedSelectionToken = selectionToken;
      final targetZoom = math.max(_lastZoom, 15.5);
      unawaited(
        _animateMapTo(
          marker.position,
          zoom: targetZoom,
          rotation: _lastBearing,
          offset: offset,
          duration: const Duration(milliseconds: 420),
        ),
      );
    });
  }

  void _handleMarkerStackPageChanged(int index) {
    if (!mounted) return;
    if (index == _kubusMapController.selectedMarkerStackIndex) return;
    if (index < 0 || index >= _kubusMapController.selectedMarkerStack.length) {
      return;
    }

    // Keep shared controller selection state in sync without bumping the
    // selection token.
    _kubusMapController.setSelectedStackIndex(index);
  }

  void _nextStackedMarker() {
    final stack = _kubusMapController.selectedMarkerStack;
    if (stack.length <= 1) return;
    final next =
        (_kubusMapController.selectedMarkerStackIndex + 1) % stack.length;
    if (_markerStackPageController.hasClients) {
      unawaited(_markerStackPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ));
      return;
    }
    _handleMarkerStackPageChanged(next);
  }

  void _previousStackedMarker() {
    final stack = _kubusMapController.selectedMarkerStack;
    if (stack.length <= 1) return;
    final prev =
        (_kubusMapController.selectedMarkerStackIndex - 1 + stack.length) %
            stack.length;
    if (_markerStackPageController.hasClients) {
      unawaited(_markerStackPageController.animateToPage(
        prev,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ));
      return;
    }
    _handleMarkerStackPageChanged(prev);
  }

  Future<void> _playMarkerSelectionFeedback(ArtMarker marker) async {
    if (AppConfig.enableHapticFeedback && !kIsWeb) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }

    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;

    final baseColor =
        _resolveArtMarkerColor(marker, context.read<ThemeProvider>());

    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final Size viewport = _mapViewportSize() ?? MediaQuery.sizeOf(context);

    try {
      final point = await controller.toScreenLocation(
        ml.LatLng(marker.position.latitude, marker.position.longitude),
      );
      if (!mounted) return;
      final raw = Offset(point.x.toDouble(), point.y.toDouble());
      final normalized = _normalizeMapScreenOffset(
        raw,
        viewport: viewport,
        devicePixelRatio: dpr,
      );
      setState(() {
        _markerTapRippleOffset = normalized;
        _markerTapRippleAt = DateTime.now();
        _markerTapRippleColor = baseColor;
      });
    } catch (_) {
      // Best-effort: ripple feedback depends on projection availability.
    }
  }

  void _maybeRecordPresenceVisitForMarker(ArtMarker marker) {
    if (!AppConfig.isFeatureEnabled('presence')) return;
    if (!AppConfig.isFeatureEnabled('presenceLastVisitedLocation')) return;
    final visit = presenceVisitFromMarker(marker);
    if (visit == null) return;

    final userLocation = _currentPosition;
    if (!shouldRecordPresenceVisitForMarker(
      marker: marker,
      userLocation: userLocation,
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

  Future<void> _ensureLinkedArtworkLoaded(ArtMarker marker) async {
    if (marker.isExhibitionMarker) return;
    final artworkId = marker.artworkId;
    if (artworkId == null || artworkId.isEmpty) return;

    final artworkProvider = context.read<ArtworkProvider>();
    if (artworkProvider.getArtworkById(artworkId) != null) return;

    try {
      await artworkProvider.fetchArtworkIfNeeded(artworkId);
      if (!mounted) return;
      // Trigger overlay rebuild if the same marker is still active.
      if (_kubusMapController.selectedMarkerId == marker.id) {
        setState(() {});
      }
    } catch (e) {
      AppConfig.debugPrint(
          'MapScreen: failed to load linked artwork $artworkId for marker ${marker.id}: $e');
    }
  }

  void _showArtMarkerDialog(ArtMarker marker) {
    // For compatibility with legacy calls: center and show inline overlay
    _handleMarkerTap(marker);
  }

  Color _resolveArtMarkerColor(ArtMarker marker, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    // Delegate to centralized marker color utility for consistency with desktop
    return AppColorUtils.markerSubjectColor(
      markerType: marker.type.name,
      metadata: marker.metadata,
      scheme: scheme,
      roles: roles,
    );
  }

  // Isometric overlay removed - grid is now integrated in tile provider

  Future<void> _handleCurrentLocationTap() async {
    if (_currentPosition == null) {
      await _promptForLocationThenCenter(reason: 'create_marker');
      if (!mounted) return;
      if (_currentPosition == null) return;
    }

    final currentPosition = _currentPosition!;

    // Check if there's a nearby marker (within 30 meters)
    ArtMarker? nearbyMarker;
    double minDistance = double.infinity;

    for (final marker in _artMarkers) {
      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        currentPosition,
        marker.position,
      );

      if (distance < 30 && distance < minDistance) {
        nearbyMarker = marker;
        minDistance = distance;
      }
    }

    if (nearbyMarker != null) {
      // Show marker info
      _showArtMarkerDialog(nearbyMarker);
    } else {
      // Show create marker dialog
      await _startMarkerCreationFlow();
    }
  }

  MarkerSubjectData _snapshotMarkerSubjectData() {
    if (!mounted) {
      return const MarkerSubjectData(
        artworks: [],
        exhibitions: [],
        institutions: [],
        events: [],
        delegates: [],
      );
    }
    return _createSubjectLoader().snapshot();
  }

  Future<MarkerSubjectData?> _refreshMarkerSubjectData({bool force = false}) {
    if (!mounted) return Future<MarkerSubjectData?>.value(null);
    return _createSubjectLoader().refresh(force: force);
  }

  Future<void> _startMarkerCreationFlow() async {
    if (_currentPosition == null) {
      await _promptForLocationThenCenter(reason: 'marker_creation');
      if (!mounted) return;
      if (_currentPosition == null) return;
    }
    final refreshed = await _refreshMarkerSubjectData(force: true);
    if (!mounted) return;
    final subjectData = refreshed ?? _snapshotMarkerSubjectData();

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
      initialPosition: _currentPosition!,
      allowManualPosition: false,
      initialSubjectType: initialSubjectType,
      allowedSubjectTypes: allowedSubjectTypes,
      blockedArtworkIds: _artMarkers
          .where((m) => (m.artworkId ?? '').isNotEmpty)
          .map((m) => m.artworkId!)
          .toSet(),
    );

    if (!mounted || result == null) return;

    final success = await _createMarkerAtCurrentLocation(result);

    if (!mounted) return;

    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerCreatedToast)),
        tone: KubusSnackBarTone.success,
      );
      await _loadArtMarkers(force: true);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerCreateFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Future<bool> _createMarkerAtCurrentLocation(MapMarkerFormResult form) async {
    if (_currentPosition == null) return false;

    try {
      final exhibitionsProvider = context.read<ExhibitionsProvider>();
      final markerManagementProvider = context.read<MarkerManagementProvider>();

      // Snap to the nearest grid cell center at the current zoom level
      // We use the current camera zoom to determine which grid level is most relevant
      final double currentZoom = _lastZoom;
      final gridCell =
          GridUtils.gridCellForZoom(_currentPosition!, currentZoom);
      // Snap to the grid level that is closest to the current zoom
      // This ensures we snap to the grid lines the user is likely seeing
      final tileProviders = Provider.of<TileProviders?>(context, listen: false);
      final LatLng snappedPosition = tileProviders?.snapToVisibleGrid(
            form.positionOverride ?? _currentPosition!,
            currentZoom,
          ) ??
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
          'createdFrom': 'map_screen',
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
        AppConfig.debugPrint(
            'MapScreen: marker created and saved: ${marker.id}');

        // Keep the management surface in sync even when markers are created
        // outside of ManageMarkersScreen.
        markerManagementProvider.ingestMarker(marker);

        if (form.subjectType == MarkerSubjectType.exhibition) {
          final exhibitionId = (form.subject?.id ?? '').trim();
          if (exhibitionId.isNotEmpty) {
            try {
              await exhibitionsProvider
                  .linkExhibitionMarkers(exhibitionId, [marker.id]);
            } catch (_) {
              // Non-fatal: endpoint may be disabled or user may not have permissions.
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
        // Update local markers list
        setState(() {
          _artMarkers.add(marker);
        });
        _kubusMapController.setMarkers(_artMarkers);
        return true;
      } else {
        AppConfig.debugPrint(
            'MapScreen: failed to create marker (returned null)');
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
      AppConfig.debugPrint('MapScreen: duplicate marker prevented: $e');
      return false;
    } catch (e) {
      AppConfig.debugPrint(
          'MapScreen: Error creating marker at current location: $e');
      return false;
    }
  }

  Future<void> _getLocation(
      {bool fromTimer = false, bool promptForPermission = true}) async {
    try {
      LatLng? resolvedPosition;
      double? resolvedAccuracyMeters;
      int? resolvedTimestampMs;
      final prefs = await SharedPreferences.getInstance();

      if (kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          AppConfig.debugPrint('MapScreen: location services disabled on web');
          resolvedPosition = _loadFallbackPosition(prefs);
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          if (!promptForPermission) {
            AppConfig.debugPrint(
                'MapScreen: location permission denied on web; using fallback if available');
            resolvedPosition ??= _loadFallbackPosition(prefs);
          } else {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              AppConfig.debugPrint(
                  'MapScreen: location permission denied on web');
              resolvedPosition ??= _loadFallbackPosition(prefs);
            }
          }
        }

        if (permission == LocationPermission.deniedForever) {
          AppConfig.debugPrint(
              'MapScreen: location permission permanently denied on web');
          resolvedPosition ??= _loadFallbackPosition(prefs);
        }

        if (resolvedPosition == null) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
            ),
          );
          resolvedAccuracyMeters = position.accuracy;
          resolvedTimestampMs = position.timestamp.millisecondsSinceEpoch;
          resolvedPosition = LatLng(position.latitude, position.longitude);
        }
      } else {
        _mobileLocation ??= Location();

        // Avoid requesting service repeatedly: only request once while in-memory flag is false
        bool serviceEnabled = await _mobileLocation!.serviceEnabled();
        if (!serviceEnabled) {
          if (!promptForPermission) {
            AppConfig.debugPrint(
                'MapScreen: location service disabled; skipping prompt (promptForPermission=false)');
            resolvedPosition ??= _loadFallbackPosition(prefs);
            if (resolvedPosition == null) return;
          } else {
            if (!_locationServiceRequested) {
              _locationServiceRequested = true;
              try {
                await prefs.setBool(_kPrefLocationServiceRequested, true);
              } catch (e) {
                AppConfig.debugPrint(
                    'MapScreen: failed to persist location service requested flag: $e');
              }

              serviceEnabled = await _mobileLocation!.requestService();

              // Persist the result (reset the requested flag when enabled)
              if (serviceEnabled) {
                try {
                  await prefs.setBool(_kPrefLocationServiceRequested, false);
                } catch (_) {}
                _locationServiceRequested = false;
              }
            } else {
              // already requested before and still disabled - don't prompt again
              AppConfig.debugPrint(
                  'MapScreen: location service disabled (previously requested)');
              resolvedPosition ??= _loadFallbackPosition(prefs);
              if (resolvedPosition == null) return;
            }
          }

          if (!serviceEnabled) {
            resolvedPosition ??= _loadFallbackPosition(prefs);
            if (resolvedPosition == null) return;
          }
        } else {
          // reset flag if enabled
          _locationServiceRequested = false;
          try {
            await prefs.setBool(_kPrefLocationServiceRequested, false);
          } catch (_) {}
        }

        // Permission handling: request once and avoid spamming the dialog on subsequent timer ticks
        PermissionStatus permissionGranted =
            await _mobileLocation!.hasPermission();
        if (permissionGranted == PermissionStatus.denied) {
          if (!promptForPermission) {
            AppConfig.debugPrint(
                'MapScreen: location permission denied; skipping request (promptForPermission=false)');
            resolvedPosition ??= _loadFallbackPosition(prefs);
            if (resolvedPosition == null) return;
          }

          if (!_locationPermissionRequested) {
            _locationPermissionRequested = true;
            try {
              await prefs.setBool(_kPrefLocationPermissionRequested, true);
            } catch (e) {
              AppConfig.debugPrint(
                  'MapScreen: failed to persist permission-requested flag: $e');
            }

            permissionGranted = await _mobileLocation!.requestPermission();

            if (permissionGranted == PermissionStatus.granted) {
              try {
                await prefs.setBool(_kPrefLocationPermissionRequested, false);
              } catch (_) {}
              _locationPermissionRequested = false;
            }
          } else {
            // already requested permission once â€” don't re-request repeatedly
            AppConfig.debugPrint(
                'MapScreen: location permission denied and previously requested; skipping further requests');
            resolvedPosition ??= _loadFallbackPosition(prefs);
            if (resolvedPosition == null) return;
          }
          if (permissionGranted != PermissionStatus.granted) {
            resolvedPosition ??= _loadFallbackPosition(prefs);
            if (resolvedPosition == null) return;
          }
        } else if (permissionGranted == PermissionStatus.granted) {
          // reset flag once permission is granted
          _locationPermissionRequested = false;
          try {
            await prefs.setBool(_kPrefLocationPermissionRequested, false);
          } catch (_) {}
        }

        final locationData = await _mobileLocation!.getLocation();
        if (locationData.latitude != null && locationData.longitude != null) {
          resolvedPosition =
              LatLng(locationData.latitude!, locationData.longitude!);
          resolvedAccuracyMeters = locationData.accuracy;
          final rawTime = locationData.time;
          if (rawTime != null) {
            resolvedTimestampMs = rawTime.round();
          }
        }

        // Start the continuous stream only once we have a working service +
        // granted permission. Starting it too early can crash certain OEM
        // builds / emulators (plugin-side EventSink not ready).
        if (!_mobileLocationStreamStarted && !_mobileLocationStreamFailed) {
          _mobileLocationStreamStarted = true;
          try {
            _subscribeToMobileLocationStream();
          } catch (e) {
            _mobileLocationStreamFailed = true;
            _mobileLocationStreamStarted = false;
            AppConfig.debugPrint(
              'MapScreen: failed to start mobile location stream: $e',
            );
          }
        }
      }

      if (resolvedPosition != null) {
        try {
          await prefs.setDouble('last_known_lat', resolvedPosition.latitude);
          await prefs.setDouble('last_known_lng', resolvedPosition.longitude);
        } catch (_) {}
        final shouldCenter = !fromTimer;
        _updateCurrentPosition(
          resolvedPosition,
          shouldCenter: shouldCenter,
          accuracyMeters: resolvedAccuracyMeters,
          timestampMs:
              resolvedTimestampMs ?? DateTime.now().millisecondsSinceEpoch,
        );
        // Only force refresh on initial load (when no markers exist)
        // Timer-based calls should respect the cache/throttling logic
        if (!fromTimer || _artMarkers.isEmpty) {
          await _maybeRefreshMarkers(
            resolvedPosition,
            force: false, // Let _maybeRefreshMarkers handle the logic
          );
        }
      }
    } catch (e) {
      AppConfig.debugPrint('MapScreen: failed to get location: $e');
    }
  }

  void _startLocationTimer() {
    _timer?.cancel();
    _perf.timerStopped('location_timer');
    // Only start when app is in foreground
    if (_lastLifecycleState == AppLifecycleState.paused ||
        _lastLifecycleState == AppLifecycleState.inactive) {
      return;
    }
    if (!_pollingEnabled) return;
    if (_isLocationStreamActive) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _getLocation(fromTimer: true, promptForPermission: false);
    });
    _perf.timerStarted('location_timer');
  }

  bool get _isLocationStreamActive {
    if (kIsWeb) {
      return _webPositionSubscription != null &&
          !(_webPositionSubscription?.isPaused ?? false);
    }
    return _mobileLocationSubscription != null &&
        !(_mobileLocationSubscription?.isPaused ?? false);
  }

  void _subscribeToMobileLocationStream() {
    if (kIsWeb || _mobileLocation == null) {
      return;
    }
    if (_mobileLocationSubscription != null) {
      _perf.subscriptionStopped('mobile_location_stream');
      unawaited(
        _mobileLocationSubscription!.cancel().catchError((_) {/* ignore */}),
      );
    }
    try {
      _mobileLocationSubscription = _mobileLocation!.onLocationChanged.listen(
        (event) {
          if (event.latitude != null && event.longitude != null) {
            _updateCurrentPosition(
              LatLng(event.latitude!, event.longitude!),
              accuracyMeters: event.accuracy,
              timestampMs:
                  (event.time is num) ? (event.time as num).round() : null,
            );
          }
        },
        onError: (Object error, StackTrace st) {
          AppConfig.debugPrint(
            'MapScreen: mobile location stream error: $error',
          );
          _mobileLocationStreamFailed = true;
          _mobileLocationStreamStarted = false;
          try {
            if (_mobileLocationSubscription != null) {
              _perf.subscriptionStopped('mobile_location_stream');
              unawaited(
                _mobileLocationSubscription!
                    .cancel()
                    .catchError((_) {/* ignore */}),
              );
            }
          } catch (_) {}
          _startLocationTimer();
        },
      );
      _perf.subscriptionStarted('mobile_location_stream');
      _timer?.cancel();
      _timer = null;
      _perf.timerStopped('location_timer');
    } catch (e) {
      AppConfig.debugPrint(
          'MapScreen: failed to subscribe to mobile location stream: $e');
    }
  }

  void _startWebLocationStream() {
    if (!kIsWeb) {
      return;
    }
    _webPositionSubscription?.cancel();
    _perf.subscriptionStopped('web_location_stream');
    try {
      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 4,
        ),
      );
      _webPositionSubscription = stream.listen((position) {
        _updateCurrentPosition(
          LatLng(position.latitude, position.longitude),
          accuracyMeters: position.accuracy,
          timestampMs: position.timestamp.millisecondsSinceEpoch,
        );
      });
      _perf.subscriptionStarted('web_location_stream');
      _timer?.cancel();
      _timer = null;
      _perf.timerStopped('location_timer');
    } catch (e) {
      AppConfig.debugPrint(
          'MapScreen: unable to start web location stream: $e');
      _webPositionSubscription = null;
      _startLocationTimer();
    }
  }

  double _desiredPitch() {
    if (!_isometricViewEnabled) return 0.0;
    if (!AppConfig.isFeatureEnabled('mapIsometricView')) return 0.0;
    return 54.736;
  }

  Future<void> _animateMapTo(
    LatLng center, {
    double? zoom,
    double? rotation,
    Offset offset = Offset.zero,
    Duration duration = const Duration(milliseconds: 420),
  }) async {
    final double targetZoom = zoom ?? _lastZoom;
    final double targetRotation = rotation ?? _lastBearing;
    final double targetPitch = _desiredPitch();

    // MapScreen currently uses vertical-only composition offsets.
    assert(
      offset.dx.abs() < 0.5,
      'MapScreen: horizontal camera composition is not supported',
    );
    final compositionYOffsetPx = -offset.dy;

    await _mapCameraController.animateTo(
      center,
      zoom: targetZoom,
      rotation: targetRotation,
      tilt: targetPitch,
      duration: duration,
      compositionYOffsetPx: compositionYOffsetPx,
      queueIfNotReady: false,
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

  Offset _normalizeMapScreenOffset(
    Offset raw, {
    required Size viewport,
    required double devicePixelRatio,
  }) {
    if (kIsWeb) return raw;
    if (devicePixelRatio <= 1.01) return raw;

    final bool looksLikePhysicalPixels = raw.dx > viewport.width * 1.2 ||
        raw.dy > viewport.height * 1.2 ||
        raw.dx < -viewport.width * 0.2 ||
        raw.dy < -viewport.height * 0.2;
    if (!looksLikePhysicalPixels) return raw;

    final scaled = Offset(
      raw.dx / devicePixelRatio,
      raw.dy / devicePixelRatio,
    );
    final bool scaledLooksReasonable = scaled.dx <= viewport.width * 1.2 &&
        scaled.dy <= viewport.height * 1.2 &&
        scaled.dx >= -viewport.width * 0.2 &&
        scaled.dy >= -viewport.height * 0.2;
    return scaledLooksReasonable ? scaled : raw;
  }

  Future<void> _promptForLocationThenCenter({required String reason}) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context)!;

    final bool previousAutoFollow = _autoFollow;

    if (!_autoFollow) {
      setState(() {
        _autoFollow = true;
      });
      _kubusMapController.setAutoFollow(true);
    }

    await _getLocation(promptForPermission: true);
    if (!mounted) return;

    if (_currentPosition == null) {
      if (_autoFollow != previousAutoFollow) {
        setState(() {
          _autoFollow = previousAutoFollow;
        });
      }
      messenger?.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapLocationUnavailableToast)),
        tone: KubusSnackBarTone.warning,
      );
      if (kDebugMode) {
        AppConfig.debugPrint(
          'MapScreen: location unavailable after user request (reason=$reason)',
        );
      }
      return;
    }

    // Best-effort: center immediately so UI doesn't feel "stuck" while waiting
    // for a periodic timer/stream tick.
    unawaited(
      _animateMapTo(
        _currentPosition!,
        zoom: math.max(_lastZoom, 16),
        rotation: _autoFollow ? _direction : null,
      ),
    );
  }

  Future<void> _handleCenterOnMeTap() async {
    if (_currentPosition == null) {
      await _promptForLocationThenCenter(reason: 'center_on_me');
      return;
    }

    final enable = !_autoFollow;
    setState(() => _autoFollow = enable);
    _kubusMapController.setAutoFollow(enable);
    if (enable) {
      unawaited(
        _animateMapTo(
          _currentPosition!,
          zoom: math.max(_lastZoom, 16),
        ),
      );
    }
  }

  void _updateCurrentPosition(
    LatLng position, {
    bool shouldCenter = false,
    double? accuracyMeters,
    int? timestampMs,
  }) {
    if (!mounted) return;
    final bool isInitial = _currentPosition == null;
    final bool allowCenter = shouldCenter || _autoFollow || isInitial;

    setState(() {
      _currentPosition = position;
      _currentPositionAccuracyMeters = accuracyMeters;
      _currentPositionTimestampMs = timestampMs;
    });
    unawaited(_syncUserLocation(themeProvider: context.read<ThemeProvider>()));

    if (allowCenter) {
      final double targetZoom = isInitial ? 18.0 : _lastZoom;
      final double? rotation = _autoFollow ? _direction : null;
      unawaited(_animateMapTo(position, zoom: targetZoom, rotation: rotation));
    }

    // Only load markers on initial position, not every update
    // Subsequent refreshes are handled by _queueMarkerRefresh
    if (isInitial && _artMarkers.isEmpty && !_isLoadingMarkers) {
      _loadArtMarkers();
    }
  }

  LatLng? _loadFallbackPosition(SharedPreferences prefs) {
    try {
      final lat = prefs.getDouble('last_known_lat');
      final lng = prefs.getDouble('last_known_lng');
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    } catch (_) {}
    return null;
  }

  void _updateDirection(double? heading) {
    if (mounted && heading != null) {
      setState(() {
        _direction = heading;
      });
      // Animate to navigation icon when moving
      _locationIndicatorController?.forward();

      if (_autoFollow && _currentPosition != null) {
        unawaited(
          _animateMapTo(
            _currentPosition!,
            zoom: _lastZoom,
            rotation: heading,
          ),
        );
      } else if (_autoFollow) {
        unawaited(
          _animateMapTo(
            _cameraCenter,
            zoom: _lastZoom,
            rotation: heading,
          ),
        );
      }
    } else if (mounted && heading == null) {
      // Animate back to dot when stationary
      _locationIndicatorController?.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    _perf.recordBuild();
    assert(_renderCoordinator.assertMarkerModeInvariant());
    assert(_renderCoordinator.assertRenderModeInvariant());
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    _maybeScheduleThemeResync(themeProvider);
    final artworkProvider = Provider.of<ArtworkProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);

    final artworks = artworkProvider.artworks;
    final filteredArtworks = _filterArtworks(
      artworks,
      basePosition: _currentPosition ?? _cameraCenter,
    );
    final discoveryProgress = taskProvider.getOverallProgress();
    final isLoadingArtworks = artworkProvider.isLoading('load_artworks');

    final stack = ValueListenableBuilder<MapUiStateSnapshot>(
      valueListenable: _mapUiStateCoordinator.state,
      builder: (context, ui, _) {
        final showMapTutorial = ui.tutorial.show;
        final mapTutorialIndex = ui.tutorial.index;

        return LayoutBuilder(
          builder: (context, constraints) {
            final sheetHeight = constraints.maxHeight * _nearbySheetExtent;
            final double attributionBottomMargin =
                ((sheetHeight + 8.0) / 12.0).ceilToDouble() * 12.0;
            if (kIsWeb &&
                _mapViewMounted &&
                (_lastWebAttributionBottomPx - attributionBottomMargin).abs() >
                    0.5) {
              _lastWebAttributionBottomPx = attributionBottomMargin;
              MapAttributionHelper.setMobileMapAttributionBottomPx(
                attributionBottomMargin,
              );
            }
            return Stack(
              children: [
                KeyedSubtree(
                  key: _tutorialMapKey,
                  child: IgnorePointer(
                    // In tutorial mode, prevent map gestures so the overlay can
                    // guide the user without accidental pans/zooms.
                    ignoring: showMapTutorial || _isSheetInteracting,
                    child: _mapViewMounted
                        ? _buildMap(
                            themeProvider,
                            attributionBottomMargin: attributionBottomMargin,
                            tutorialActive: showMapTutorial,
                          )
                        : const SizedBox.expand(
                            child: ColoredBox(color: Colors.transparent),
                          ),
                  ),
                ),
                if (_isSheetBlocking || _isSheetInteracting)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: sheetHeight,
                    child: const AbsorbPointer(
                      absorbing: true,
                      child: SizedBox.expand(),
                    ),
                  ),
                _buildTopOverlays(theme, taskProvider),
                _buildPrimaryControls(),
                _buildBottomSheet(
                  // This will likely be refactored into _buildDraggablePanel()
                  theme,
                  filteredArtworks,
                  discoveryProgress,
                  isLoadingArtworks,
                ),
                _buildMarkerOverlay(themeProvider, ui.markerSelection),
                ListenableBuilder(
                  listenable: _mapSearchController,
                  builder: (context, _) {
                    final s = _mapSearchController.state;
                    if (!s.isOverlayVisible) return const SizedBox.shrink();

                    final l10n = AppLocalizations.of(context)!;
                    final accent = context.read<ThemeProvider>().accentColor;

                    return KubusSearchSuggestionsOverlay(
                      link: _mapSearchController.fieldLink,
                      query: s.query,
                      isFetching: s.isFetching,
                      suggestions: s.suggestions,
                      accentColor: accent,
                      minCharsHint: l10n.mapSearchMinCharsHint,
                      // Preserve mobile copy for parity.
                      noResultsText: l10n.mapNoSuggestions,
                      onDismiss: () => _mapSearchController.dismissOverlay(),
                      onSuggestionTap: (suggestion) {
                        unawaited(_handleSuggestionTap(suggestion));
                      },
                    );
                  },
                ),
                if (showMapTutorial)
                  Positioned.fill(
                    child: KubusMapWebPointerInterceptor.wrap(
                      child: const ModalBarrier(
                        dismissible: false,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                if (showMapTutorial)
                  Positioned.fill(
                    child: KubusMapWebPointerInterceptor.wrap(
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          final steps = _buildMapTutorialSteps(l10n);
                          final idx =
                              mapTutorialIndex.clamp(0, steps.length - 1);
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
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      // On web the map is implemented via MapLibre GL JS (a platform view).
      // Avoid painting a full-screen opaque background behind it so it remains
      // visible regardless of composition order.
      body: kIsWeb ? stack : AnimatedGradientBackground(child: stack),
    );
  }

  Widget _buildMap(
    ThemeProvider themeProvider, {
    required double attributionBottomMargin,
    required bool tutorialActive,
  }) {
    final isDark = themeProvider.isDarkMode;
    final tileProviders = Provider.of<TileProviders?>(context, listen: false);
    final styleAsset = tileProviders?.mapStyleAsset(isDarkMode: isDark) ??
        MapStyleService.primaryStyleRef(isDarkMode: isDark);
    // Keep map gestures enabled during normal operation. We block drag-through
    // from the Nearby Art sheet using an AbsorbPointer overlay over the sheet
    // area, rather than disabling map gestures globally.
    final disableGesturesForOverlays = tutorialActive || _isSheetInteracting;

    return KeyedSubtree(
      key: _mapViewKey,
      child: ArtMapView(
        initialCenter: (_autoFollow && _currentPosition != null)
            ? _currentPosition!
            : _cameraCenter,
        initialZoom: _lastZoom,
        minZoom: 3.0,
        maxZoom: 24.0,
        isDarkMode: isDark,
        styleAsset: styleAsset,
        attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
        attributionButtonMargins: kIsWeb
            ? null
            : math.Point<double>(
                12.0,
                math.max(12.0, attributionBottomMargin),
              ),
        rotateGesturesEnabled: !disableGesturesForOverlays,
        scrollGesturesEnabled: !disableGesturesForOverlays,
        zoomGesturesEnabled: !disableGesturesForOverlays,
        tiltGesturesEnabled: !disableGesturesForOverlays,
        compassEnabled: false,
        onCameraMove: _handleCameraMove,
        onCameraIdle: _handleCameraIdle,
        onMapClick: (point, latLng) {
          unawaited(_handleMapTap(point));
        },
        onMapCreated: (controller) {
          _mapController = controller;

          _kubusMapController.attachMapController(controller);
          _layersManager = _kubusMapController.layersManager;

          // Mirror controller state into legacy screen guards while migration is incremental.
          _styleInitialized = _kubusMapController.styleInitialized;
          _styleInitializationInProgress =
              _kubusMapController.styleInitializationInProgress;
          _hitboxLayerReady = _kubusMapController.styleInitialized;
          _styleEpoch = _kubusMapController.styleEpoch;
          AppConfig.debugPrint(
            'MapScreen: map created (dark=$isDark, style="$styleAsset")',
          );
          _perf.logEvent(
            'mapCreated',
            extra: <String, Object?>{
              'dark': isDark,
            },
          );
        },
        onStyleLoaded: () {
          AppConfig.debugPrint('MapScreen: onStyleLoadedCallback');
          _perf.logEvent('styleLoadedCallback');
          unawaited(_handleMapStyleLoaded(themeProvider).catchError((e) {
            if (kDebugMode) {
              debugPrint('MapScreen: style loaded error: $e');
            }
          }));

          // Travel mode must start with a bounds query once the map is ready,
          // otherwise the first load may be anchored to the default center.
          if (_travelModeEnabled) {
            unawaited(
              _loadMarkersForCurrentView(force: true)
                  .then((_) => _maybeOpenInitialMarker())
                  .catchError((e) {
                if (kDebugMode) {
                  debugPrint('MapScreen: initial marker load error: $e');
                }
              }),
            );
          } else if (_artMarkers.isEmpty && !_isLoadingMarkers) {
            unawaited(
              _loadMarkersForCurrentView(force: true)
                  .then((_) => _maybeOpenInitialMarker())
                  .catchError((e) {
                if (kDebugMode) {
                  debugPrint('MapScreen: initial marker load error: $e');
                }
              }),
            );
          } else {
            unawaited(_maybeOpenInitialMarker().catchError((e) {
              if (kDebugMode) {
                debugPrint('MapScreen: open initial marker error: $e');
              }
            }));
          }
        },
      ),
    );
  }

  double _markerPixelRatio() {
    if (kIsWeb) return 1.0;
    final dpr = WidgetsBinding
            .instance.platformDispatcher.implicitView?.devicePixelRatio ??
        1.0;
    return dpr.clamp(1.0, 2.5);
  }

  /// Generate a transparent square image for the hitbox layer.
  /// Returns bytes for a 1x1 transparent PNG which MapLibre will scale to the icon-size.
  /// This allows us to use a symbol layer for square-based tap detection.
  // ignore: unused_element
  Uint8List _createTransparentSquareImage() {
    // 1x1 transparent PNG (base64 decoded)
    const String base64Png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    return Uint8List.fromList(base64Decode(base64Png));
  }

  Future<void> _applyIsometricCamera(
      {required bool enabled, bool adjustZoomForScale = false}) async {
    final nextZoom = await _mapCameraController.applyIsometricCamera(
      enabled: enabled,
      center: _cameraCenter,
      zoom: _lastZoom,
      bearing: _lastBearing,
      adjustZoomForScale: adjustZoomForScale,
      duration: const Duration(milliseconds: 320),
      queueIfNotReady: false,
    );

    if (adjustZoomForScale) {
      _lastZoom = nextZoom;
    }

    if (!mounted) return;
    unawaited(_renderCoordinator.updateRenderMode());
  }

  void _handleCameraMove(ml.CameraPosition position) {
    if (!mounted) return;
    _kubusMapController.handleCameraMove(position);
    _cameraIsMoving = _kubusMapController.cameraIsMoving;

    final now = DateTime.now();
    if (now.difference(_lastCameraUpdateTime) < _cameraUpdateThrottle) return;
    _lastCameraUpdateTime = now;

    final nextCenter = LatLng(
      position.target.latitude,
      position.target.longitude,
    );
    final nextZoom = position.zoom;
    final nextBearing = position.bearing;
    final nextPitch = position.tilt;

    final bool zoomChanged = (nextZoom - _lastZoom).abs() > 0.001;
    // Bearing changes are tracked by the shared controller.

    // Camera moves are high-frequency; avoid rebuilding the entire screen on
    // every frame. Store camera state locally and only notify tiny, isolated
    // widgets via ValueNotifiers when needed.
    _cameraCenter = nextCenter;
    _lastZoom = nextZoom;
    _lastBearing = nextBearing;
    _lastPitch = nextPitch;
    // Bearing + overlay anchor are handled by the shared controller.

    if (_styleInitialized && zoomChanged) {
      _queueMarkerVisualRefreshForZoom(nextZoom);
    }
  }

  void _handleCameraIdle() {
    if (!mounted) return;
    final wasProgrammatic = _kubusMapController.programmaticCameraMove;
    _kubusMapController.handleCameraIdle(fromProgrammaticMove: wasProgrammatic);
    _cameraIsMoving = _kubusMapController.cameraIsMoving;

    _queueMarkerRefresh(fromGesture: !wasProgrammatic);
    if (_styleInitialized) {
      _queueMarkerVisualRefreshForZoom(_lastZoom);
      unawaited(_renderCoordinator.updateRenderMode());
    }

    // Nearby list filtering may depend on camera center when precise user
    // location is unavailable.
    _safeSetState(() {});
  }

  int _clusterGridLevelForZoom(double zoom) {
    // Optimized grid levels for smoother cluster transitions during incremental zoom.
    // Fewer jumpy re-organizations = better perceived responsiveness.
    if (zoom < 5) return 2;
    if (zoom < 7) return 3;
    if (zoom < 9) return 4;
    if (zoom < 11) return 5;
    return 6;
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
        AppConfig.debugPrint('MapScreen: _syncMapMarkers failed: $e');
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

  // ignore: unused_element
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
    math.Point<double> point,
  ) async {
    await _markerInteractionController.handleMapClick(point);
  }

  // ignore: unused_element
  Future<ArtMarker?> _fallbackPickMarkerAtPoint(
    math.Point<double> point,
  ) async {
    final controller = _mapController;
    if (controller == null) return null;

    // Tight fallback radius to avoid oversized hitboxes.
    final zoomScale = (_lastZoom / 15.0).clamp(0.7, 1.4);
    final double base =
        _renderCoordinator.is3DModeActive ? (kIsWeb ? 34.0 : 28.0) : (kIsWeb ? 28.0 : 22.0);
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
    if (!_managedSourceIds.contains(_locationSourceId)) return;

    final pos = _currentPosition;
    final data = (pos == null)
        ? const <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <dynamic>[],
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

  Future<void> _syncMapMarkers({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;
    if (!_managedSourceIds.contains(_markerSourceId)) return;
    if (!mounted) return;

    final dev.TimelineTask? timeline = MapPerformanceDebug.isEnabled
        ? (dev.TimelineTask()..start('MapScreen.syncMapMarkers'))
        : null;

    try {
      final scheme = Theme.of(context).colorScheme;
      final roles = KubusColorRoles.of(context);
      final isDark = themeProvider.isDarkMode;

      final zoom = _lastZoom;
      final shouldCluster =
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
      // Collect unique icon IDs that need rendering.
      await _preregisterMarkerIcons(
        markers: visibleMarkers,
        themeProvider: themeProvider,
        scheme: scheme,
        roles: roles,
        isDark: isDark,
        shouldCluster: shouldCluster,
        zoom: zoom,
      );
      if (!mounted) return;

      final features = await kubusBuildMarkerFeatureList(
        markers: geoMarkers,
        useClustering: shouldCluster,
        zoom: zoom,
        clusterGridLevelForZoom: _clusterGridLevelForZoom,
        sortClustersBySizeDesc: true,
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
    } finally {
      timeline?.finish();
    }
  }

  /// Pre-registers marker icons in batched parallel to avoid waterfall.
  /// This renders icons concurrently (up to a batch limit) before the main
  /// feature loop, so _markerFeatureFor() finds them already cached.
  Future<void> _preregisterMarkerIcons({
    required List<ArtMarker> markers,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    required bool shouldCluster,
    required double zoom,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    await kubusPreregisterMarkerIcons(
      controller: controller,
      registeredMapImages: _registeredMapImages,
      markers: markers,
      isDark: isDark,
      useClustering: shouldCluster,
      zoom: zoom,
      clusterGridLevelForZoom: _clusterGridLevelForZoom,
      sortClustersBySizeDesc: true,
      scheme: scheme,
      roles: roles,
      pixelRatio: _markerPixelRatio(),
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      resolveMarkerBaseColor: (marker) =>
          _resolveArtMarkerColor(marker, themeProvider),
    );
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
    final zoom = _lastZoom;
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
      // Compute cube dimensions in map meters so the 3D extrusion aligns
      // with the 2D marker icon at any zoom.  Uses the same formula as desktop.
      final cubeSizeMeters = MarkerCubeGeometry.cubeBaseSizeMeters(
        zoom: zoom,
        latitude: marker.position.latitude,
      );
      final heightMeters = cubeSizeMeters * 0.90;
      final colorHex = MarkerCubeGeometry.toHex(baseColor);

      cubeFeatures.add(
        MarkerCubeGeometry.cubeFeatureForMarkerWithMeters(
          marker: marker,
          colorHex: colorHex,
          sizeMeters: cubeSizeMeters,
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

  Widget _buildMarkerOverlay(
    ThemeProvider themeProvider,
    MapMarkerSelectionState selection,
  ) {
    final marker = selection.selectedMarker;
    final selectionKey = selection.selectedAt?.millisecondsSinceEpoch ?? 0;
    final animationKey = marker == null
        ? const ValueKey<String>('marker_overlay_empty')
        : ValueKey<String>('marker_overlay:${marker.id}:$selectionKey');
    return KubusMapMarkerOverlayLayer(
      content: marker == null
          ? null
          : _buildAnchoredMarkerOverlay(themeProvider, selection),
      contentKey: animationKey,
      onDismiss: _dismissSelectedMarker,
      underlay: _buildMarkerTapRipple(),
      // Do not block map gestures with a full-screen backdrop; it feels like
      // the map "freezes" on marker tap. The card itself uses MapOverlayBlocker.
      blockMapGestures: false,
      dismissOnBackdropTap: false,
    );
  }

  Widget _buildMarkerTapRipple() {
    final offset = _markerTapRippleOffset;
    final at = _markerTapRippleAt;
    final color = _markerTapRippleColor;
    if (offset == null || at == null || color == null) {
      return const SizedBox.shrink();
    }

    const maxRadius = 46.0;
    return Positioned(
      left: offset.dx - maxRadius,
      top: offset.dy - maxRadius,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey<int>(at.millisecondsSinceEpoch),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            // Ensure minimum size to prevent 0x0 SizedBox layout issues on web
            final radius = math.max(1.0, maxRadius * t);
            final alpha = (1.0 - t) * 0.26;
            return SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: alpha * 0.18),
                  border: Border.all(
                    color: color.withValues(alpha: alpha * 0.65),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: alpha),
                      blurRadius: 30 * t + 8,
                      spreadRadius: 4 * t,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnchoredMarkerOverlay(
    ThemeProvider themeProvider,
    MapMarkerSelectionState selection,
  ) {
    final marker = selection.selectedMarker;
    if (marker == null) return const SizedBox.shrink();

    final artwork = marker.isExhibitionMarker
        ? null
        : context
            .read<ArtworkProvider>()
            .getArtworkById(marker.artworkId ?? '');

    final l10n = AppLocalizations.of(context)!;

    final primaryExhibition = marker.resolvedExhibitionSummary;
    final exhibitionsFeatureEnabled = AppConfig.isFeatureEnabled('exhibitions');
    final exhibitionsApiAvailable = BackendApiService().exhibitionsApiAvailable;
    final canPresentExhibition = exhibitionsFeatureEnabled &&
        primaryExhibition != null &&
        primaryExhibition.id.isNotEmpty &&
        exhibitionsApiAvailable != false;

    final exhibitionTitle = (primaryExhibition?.title ?? '').trim();
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

    final distanceText = () {
      if (_currentPosition == null) return null;
      final meters = _distanceCalculator.as(
        LengthUnit.Meter,
        _currentPosition!,
        marker.position,
      );
      if (meters >= 1000) {
        return l10n.commonDistanceKm((meters / 1000).toStringAsFixed(1));
      }
      return l10n.commonDistanceM(meters.round().toString());
    }();

    final showChips =
        _hasMetadataChips(marker, artwork) || canPresentExhibition;
    final buttonLabel = l10n.commonViewDetails;

    final estimatedHeight = _computeMobileMarkerHeight(
      title: displayTitle,
      distanceText: distanceText,
      description: visibleDescription,
      hasChips: showChips,
      buttonLabel: buttonLabel,
      showTypeLabel: canPresentExhibition,
    );

    return ValueListenableBuilder<Offset?>(
      valueListenable: _selectedMarkerAnchorNotifier,
      builder: (context, anchorValue, _) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final Offset? anchor = (anchorValue != null &&
                        anchorValue.dx.isFinite &&
                        anchorValue.dy.isFinite)
                    ? anchorValue
                    : null;
                const double cardWidth = 360;
                final double maxWidth =
                    math.min(cardWidth, constraints.maxWidth - 32);
                // Clamp maxHeight to the available viewport (safe-area aware).
                final double safeVerticalPadding =
                    MediaQuery.of(context).padding.vertical;
                final double maxCardHeight = math
                    .max(
                      200.0,
                      constraints.maxHeight - safeVerticalPadding - 24,
                    )
                    .toDouble();
                final double minExpandedHeight =
                    constraints.maxWidth < 600 ? 320.0 : 260.0;
                final double cardHeight = math.min(
                  math.max(estimatedHeight, minExpandedHeight),
                  maxCardHeight,
                );

                // Cache the last computed overlay height so camera focus can
                // compute an offset deterministically (without measuring/looping
                // from build).
                if ((_lastComputedMarkerOverlayHeightPx - cardHeight).abs() >
                    1.0) {
                  _lastComputedMarkerOverlayHeightPx = cardHeight;
                }
                final double topSafe = MediaQuery.of(context).padding.top + 12;
                final double bottomSafe =
                    constraints.maxHeight - cardHeight - 12;

                // Account for marker height (flat square markers).
                const double markerOffset = 32.0;

                double left = (constraints.maxWidth - maxWidth) / 2;

                final bool isCompact = constraints.maxWidth < 600;

                final bool anchorLooksUsable = anchor != null &&
                    anchor.dx >= -constraints.maxWidth * 0.5 &&
                    anchor.dx <= constraints.maxWidth * 1.5 &&
                    anchor.dy >= -constraints.maxHeight * 0.5 &&
                    anchor.dy <= constraints.maxHeight * 1.5;
                final Offset? safeAnchor = anchorLooksUsable ? anchor : null;

                // Prefer anchoring above the marker. If the anchor isn't ready yet,
                // fall back to a stable heuristic so the first frame looks good.
                final markerY = safeAnchor?.dy ??
                    (constraints.maxHeight * (isCompact ? 0.72 : 0.66));
                double top = markerY - cardHeight - markerOffset;
                if (top < topSafe) {
                  top = topSafe;
                }
                top = top.clamp(topSafe, math.max(topSafe, bottomSafe));

                if (kDebugMode) {
                  AppConfig.debugPrint(
                    'MapScreen: card anchor=(${safeAnchor?.dx.toStringAsFixed(0)}, ${safeAnchor?.dy.toStringAsFixed(0)}) '
                    'pos=(${left.toStringAsFixed(0)}, ${top.toStringAsFixed(0)}) '
                    'maxH=${maxCardHeight.toStringAsFixed(0)} estH=${estimatedHeight.toStringAsFixed(0)} cardH=${cardHeight.toStringAsFixed(0)}',
                  );
                }

                final stack = selection.stackedMarkers.isNotEmpty
                    ? selection.stackedMarkers
                    : <ArtMarker>[marker];
                final int stackIndex = selection.stackIndex
                    .clamp(0, math.max(0, stack.length - 1));

                void goToStackIndex(int index) {
                  if (index < 0 || index >= stack.length) return;
                  if (_markerStackPageController.hasClients) {
                    unawaited(
                      _markerStackPageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return;
                  }
                  _handleMarkerStackPageChanged(index);
                }

                MarkerOverlayCard buildCardForMarker(ArtMarker pageMarker) {
                  final pageArtwork = pageMarker.isExhibitionMarker
                      ? null
                      : context
                          .read<ArtworkProvider>()
                          .getArtworkById(pageMarker.artworkId ?? '');

                  final pagePrimaryExhibition =
                      pageMarker.resolvedExhibitionSummary;
                  final exhibitionsFeatureEnabled =
                      AppConfig.isFeatureEnabled('exhibitions');
                  final exhibitionsApiAvailable =
                      BackendApiService().exhibitionsApiAvailable;
                  final canPresentExhibition = exhibitionsFeatureEnabled &&
                      pagePrimaryExhibition != null &&
                      pagePrimaryExhibition.id.isNotEmpty &&
                      exhibitionsApiAvailable != false;

                  final exhibitionTitle =
                      (pagePrimaryExhibition?.title ?? '').trim();
                  final pageDisplayTitle =
                      canPresentExhibition && exhibitionTitle.isNotEmpty
                          ? exhibitionTitle
                          : (pageArtwork?.title.isNotEmpty == true
                              ? pageArtwork!.title
                              : pageMarker.name);

                  final pageDistanceText = () {
                    if (_currentPosition == null) return null;
                    final meters = _distanceCalculator.as(
                      LengthUnit.Meter,
                      _currentPosition!,
                      pageMarker.position,
                    );
                    if (meters >= 1000) {
                      return l10n
                          .commonDistanceKm((meters / 1000).toStringAsFixed(1));
                    }
                    return l10n.commonDistanceM(meters.round().toString());
                  }();

                  final pageBaseColor =
                      _resolveArtMarkerColor(pageMarker, themeProvider);

                  return MarkerOverlayCard(
                    marker: pageMarker,
                    artwork: pageArtwork,
                    baseColor: pageBaseColor,
                    displayTitle: pageDisplayTitle,
                    canPresentExhibition: canPresentExhibition,
                    distanceText: pageDistanceText,
                    description: pageMarker.description.isNotEmpty
                        ? pageMarker.description
                        : (pageArtwork?.description ?? ''),
                    onClose: _dismissSelectedMarker,
                    onPrimaryAction: canPresentExhibition
                        ? () => _openExhibitionFromMarker(
                              pageMarker,
                              pagePrimaryExhibition,
                              pageArtwork,
                            )
                        : () => _openMarkerDetail(pageMarker, pageArtwork),
                    primaryActionIcon: canPresentExhibition
                        ? Icons.museum_outlined
                        : Icons.arrow_forward,
                    primaryActionLabel: l10n.commonViewDetails,
                    stackCount: stack.length,
                    stackIndex: stackIndex,
                    onNextStacked: stack.length > 1 ? _nextStackedMarker : null,
                    onPreviousStacked:
                        stack.length > 1 ? _previousStackedMarker : null,
                    onSelectStackIndex:
                        stack.length > 1 ? (i) => goToStackIndex(i) : null,
                  );
                }

                final Widget cardDeck = RepaintBoundary(
                  child: stack.length <= 1
                      ? buildCardForMarker(marker)
                      : PageView.builder(
                          controller: _markerStackPageController,
                          itemCount: stack.length,
                          onPageChanged: _handleMarkerStackPageChanged,
                          itemBuilder: (context, index) {
                            return buildCardForMarker(stack[index]);
                          },
                        ),
                );

                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: top,
                      width: maxWidth,
                      child: MapOverlayBlocker(
                        enabled: true,
                        cursor: SystemMouseCursors.basic,
                        interceptPlatformViews: true,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxCardHeight,
                          ),
                          child: SizedBox(
                            height: cardHeight,
                            child: cardDeck,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = scheme.surface.withValues(alpha: isDark ? 0.46 : 0.52);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LiquidGlassPanel(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(999),
              showBorder: false,
              backgroundColor: bg,
              child: Center(
                child: Icon(icon, size: 18, color: scheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlays(ThemeData theme, TaskProvider? taskProvider) {
    final topPadding = MediaQuery.of(context).padding.top + 10;
    return Positioned(
      top: topPadding,
      left: 12,
      right: 12,
      child: MapOverlayBlocker(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchCard(theme),
                const SizedBox(height: 10),
                if (_filtersExpanded) ...[
                  _buildFilterPanel(theme),
                  const SizedBox(height: 10),
                ],
                _buildDiscoveryCard(theme, taskProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _computeMobileMarkerHeight({
    required String title,
    required String? distanceText,
    required String description,
    required bool hasChips,
    required String buttonLabel,
    bool showTypeLabel = false,
  }) {
    // Use the same width as the actual card render.
    const double cardWidth = 360;
    const double horizontalPadding = 12;
    const double verticalPadding = 12;
    final double contentWidth = cardWidth - (horizontalPadding * 2);

    // Optional type label height (e.g. "Razstava")
    double typeLabelHeight = 0;
    if (showTypeLabel) {
      final typeLabelPainter = TextPainter(
        text: TextSpan(
          text: 'Razstava',
          style: KubusTypography.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentWidth);
      typeLabelHeight = typeLabelPainter.size.height + 2;
    }

    // Title height (max 2 lines)
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: KubusTypography.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: contentWidth);
    final double titleHeight = titlePainter.size.height;

    // Distance badge height
    double distanceBadgeHeight = 0;
    if (distanceText != null && distanceText.isNotEmpty) {
      final distancePainter = TextPainter(
        text: TextSpan(
          text: distanceText,
          style: KubusTypography.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentWidth);
      distanceBadgeHeight = (distancePainter.size.height).clamp(10, 20) + 4;
    }

    // Close icon button is 36x36 in the UI.
    const double closeIconHeight = 36;
    final double headerContentHeight = typeLabelHeight + titleHeight;
    final double headerHeight = [
      headerContentHeight,
      distanceBadgeHeight,
      closeIconHeight
    ].reduce((a, b) => a > b ? a : b);

    // Description height
    double descriptionHeight = 0;
    if (description.isNotEmpty) {
      final descriptionPainter = TextPainter(
        text: TextSpan(
          text: description,
          style: KubusTypography.textTheme.bodySmall?.copyWith(
            height: 1.4,
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: contentWidth);
      descriptionHeight = descriptionPainter.size.height;
    }

    // Chips height (single row; wrap may grow, but this is used as a
    // best-effort expansion hint and safe camera offset).
    final double chipsHeight = hasChips ? 24.0 : 0.0;

    // Button height (content + padding * 2)
    final buttonTextPainter = TextPainter(
      text: TextSpan(
        text: buttonLabel,
        style: KubusTypography.textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const double buttonIconSize = 18;
    const double buttonPaddingV = 10;
    final buttonContentHeight =
        math.max(buttonTextPainter.size.height, buttonIconSize);
    final double buttonHeight = buttonContentHeight + (buttonPaddingV * 2);

    // Spacing between sections
    double spacing = 0;
    spacing += 10; // after header
    spacing += 10; // after image
    if (descriptionHeight > 0) spacing += 10;
    if (chipsHeight > 0) spacing += 10;
    spacing += 12; // before button

    final double containerHeight = verticalPadding * 2 +
        headerHeight +
        120 +
        descriptionHeight +
        chipsHeight +
        buttonHeight +
        spacing;

    return containerHeight;
  }

  /// Check if marker has any metadata chips to display
  bool _hasMetadataChips(ArtMarker marker, Artwork? artwork) {
    return (artwork != null &&
            artwork.category.isNotEmpty &&
            artwork.category != 'General') ||
        marker.metadata?['subjectCategory'] != null ||
        marker.metadata?['subject_category'] != null ||
        (artwork != null && artwork.rewards > 0);
  }

  Future<void> _openExhibitionFromMarker(
    ArtMarker marker,
    ExhibitionSummaryDto? exhibition,
    Artwork? artwork,
  ) async {
    final navigator = Navigator.of(context);
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

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ExhibitionDetailScreen(
          exhibitionId: resolved.id,
          attendanceMarkerId: marker.id,
        ),
      ),
    );
  }

  Future<void> _openMarkerDetail(ArtMarker marker, Artwork? artwork) async {
    Artwork? resolvedArtwork = artwork;
    final artworkId = marker.isExhibitionMarker ? null : marker.artworkId;
    if (resolvedArtwork == null && artworkId != null && artworkId.isNotEmpty) {
      try {
        final artworkProvider = context.read<ArtworkProvider>();
        await artworkProvider.fetchArtworkIfNeeded(artworkId);
        resolvedArtwork = artworkProvider.getArtworkById(artworkId);
      } catch (e) {
        AppConfig.debugPrint(
            'MapScreen: failed to fetch artwork $artworkId for marker ${marker.id}: $e');
      }
    }

    if (!mounted) return;

    if (resolvedArtwork == null) {
      await _showMarkerInfoFallback(marker);
      return;
    }

    final artworkToOpen = resolvedArtwork;
    await openArtwork(
      context,
      artworkToOpen.id,
      source: 'map_marker',
      attendanceMarkerId: marker.id,
    );
  }

  Future<void> _showMarkerInfoFallback(ArtMarker marker) async {
    final l10n = AppLocalizations.of(context)!;
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
          style: GoogleFonts.outfit(
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
                      KubusMapMarkerHelpers.markerImageFallback(
                    baseColor: _resolveArtMarkerColor(
                        marker, context.read<ThemeProvider>()),
                    scheme: scheme,
                    marker: marker,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              marker.description.isNotEmpty
                  ? marker.description
                  : l10n.mapNoLinkedArtworkForMarker,
              style: GoogleFonts.outfit(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final radius = KubusRadius.circular(KubusRadius.lg);
    final isDark = theme.brightness == Brightness.dark;
    final accent = context.read<ThemeProvider>().accentColor;
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.46 : 0.58);
    final hintColor = scheme.onSurfaceVariant;

    return ListenableBuilder(
      listenable: _mapSearchController,
      builder: (context, _) {
        final query = _mapSearchController.state.query;
        final hasText = query.trim().isNotEmpty;

        return CompositedTransformTarget(
          link: _mapSearchController.fieldLink,
          child: SizedBox(
            height: 48,
            child: KubusSearchBar(
              semanticsLabel: 'map_search_input',
              hintText: l10n.mapSearchHint,
              controller: _mapSearchController.textController,
              focusNode: _mapSearchController.focusNode,
              onChanged: (value) => _mapSearchController.onQueryChanged(
                context,
                value,
              ),
              onSubmitted: (_) {
                _mapSearchController.onSubmitted();
              },
              trailingBuilder: (context, _) {
                if (hasText) {
                  return IconButton(
                    tooltip: l10n.mapClearSearchTooltip,
                    icon: Icon(Icons.close, color: hintColor),
                    onPressed: () {
                      _mapSearchController.clearQueryWithContext(context);
                    },
                  );
                }

                return Tooltip(
                  message: _filtersExpanded
                      ? l10n.mapHideFiltersTooltip
                      : l10n.mapShowFiltersTooltip,
                  preferBelow: false,
                  verticalOffset: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: IconButton(
                    key: _tutorialFilterButtonKey,
                    icon: Icon(
                      _filtersExpanded
                          ? Icons.filter_alt_off
                          : Icons.filter_alt,
                      color: hintColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _filtersExpanded = !_filtersExpanded;
                      });
                    },
                  ),
                );
              },
              style: KubusSearchBarStyle(
                borderRadius: radius,
                backgroundColor: glassTint,
                borderColor: accent.withValues(alpha: 0.22),
                focusedBorderColor: accent,
                borderWidth: 1,
                focusedBorderWidth: 2,
                blurSigma: null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                boxShadow: [
                  BoxShadow(
                    color:
                        scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                focusedBoxShadow: [
                  BoxShadow(
                    color:
                        scheme.shadow.withValues(alpha: isDark ? 0.26 : 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 44),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 44),
                textStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                hintStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: hintColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSuggestionTap(MapSearchSuggestion suggestion) async {
    // Update the shared controller (keeps mobile + desktop consistent).
    _mapSearchController.textController.text = suggestion.label;
    _mapSearchController.textController.selection =
        TextSelection.collapsed(offset: suggestion.label.length);
    _mapSearchController.onQueryChanged(context, suggestion.label);
    _mapSearchController.dismissOverlay(unfocus: true);

    if (suggestion.position != null) {
      unawaited(
        _kubusMapController.animateTo(
          suggestion.position!,
          zoom: math.max(_lastZoom, 16.0),
        ),
      );
    }

    if (!mounted) return;
    if (suggestion.type == 'artwork' && suggestion.id != null) {
      // Find an existing marker for this artwork, or create a temporary one
      // so the floating info card can be shown instead of immediately navigating.
      final marker = _findOrCreateMarkerForArtwork(
        suggestion.id!,
        suggestion.position,
        suggestion.label,
      );
      if (marker != null) {
        _handleMarkerTap(marker);
        return;
      }
      // Fallback: open detail screen directly if no marker found
      await openArtwork(context, suggestion.id!, source: 'map_search');
    } else if (suggestion.type == 'profile' && suggestion.id != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: suggestion.id!),
        ),
      );
    }
  }

  /// Finds an existing marker for the artwork, or creates a temporary one
  /// using artwork data from the provider (if available).
  ArtMarker? _findOrCreateMarkerForArtwork(
    String artworkId,
    LatLng? suggestionPosition,
    String? fallbackName,
  ) {
    // Check if marker already exists in loaded markers
    final existing =
        _artMarkers.where((m) => m.artworkId == artworkId).firstOrNull;
    if (existing != null) return existing;

    // Try to get artwork from provider to create a temporary marker
    final artworkProvider = context.read<ArtworkProvider>();
    final artwork = artworkProvider.getArtworkById(artworkId);

    final position = suggestionPosition ??
        (artwork?.hasValidLocation == true ? artwork!.position : null);
    if (position == null) return null;

    // Create a temporary marker that will be replaced when real markers load
    final tempMarker = ArtMarker(
      id: 'search_temp_$artworkId',
      artworkId: artworkId,
      position: position,
      name: artwork?.title ?? fallbackName ?? '',
      description: artwork?.description ?? '',
      type: ArtMarkerType.artwork,
      createdAt: DateTime.now(),
      createdBy: 'search_temp',
      metadata: artwork != null
          ? {
              'artwork': {
                'id': artwork.id,
                'title': artwork.title,
                'artist': artwork.artist,
                'category': artwork.category,
                'imageUrl': artwork.imageUrl,
              },
            }
          : null,
    );

    // Add to the markers list so it can be selected
    setState(() {
      _artMarkers = List<ArtMarker>.from(_artMarkers)..add(tempMarker);
    });
    _kubusMapController.setMarkers(_artMarkers);

    return tempMarker;
  }

  Widget _buildFilterPanel(ThemeData theme) {
    if (!_filtersExpanded) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(18);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.40 : 0.52);
    final filters = <Map<String, String>>[
      {'key': 'all', 'label': l10n.mapFilterAllNearby},
      {'key': 'nearby', 'label': l10n.mapFilterWithin1Km},
      {'key': 'discovered', 'label': l10n.mapFilterDiscovered},
      {'key': 'undiscovered', 'label': l10n.mapFilterUndiscovered},
      {'key': 'ar', 'label': l10n.mapFilterArEnabled},
      {'key': 'favorites', 'label': l10n.mapFilterFavorites},
    ];

    Color filterAccent(String key) {
      switch (key) {
        case 'discovered':
          return roles.positiveAction;
        case 'undiscovered':
          return scheme.outline;
        case 'ar':
          return scheme.secondary;
        case 'favorites':
          return roles.likeAction;
        case 'nearby':
          return scheme.primary;
        case 'all':
        default:
          return scheme.primary;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.all(14),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mapFiltersTitle,
              style: KubusTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filters.map((filter) {
                final key = filter['key']!;
                final selected = _artworkFilter == key;
                return KubusMapGlassChip(
                  label: filter['label']!,
                  icon: Icons.filter_alt_outlined,
                  selected: selected,
                  accent: filterAccent(key),
                  onTap: () {
                    setState(() => _artworkFilter = key);
                    // Reload markers so the nearby panel reflects
                    // the new filter immediately.
                    unawaited(
                      _loadMarkersForCurrentView(force: true),
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.mapLayersTitle,
              style: KubusTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            KubusMapMarkerLayerChips(
              l10n: l10n,
              visibility: _markerLayerVisibility,
              onToggle: (type, nextSelected) {
                setState(() => _markerLayerVisibility[type] = nextSelected);
                _kubusMapController
                    .setMarkerTypeVisibility(_markerLayerVisibility);
                _renderCoordinator.requestStyleUpdate(force: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryCard(ThemeData theme, TaskProvider? taskProvider) {
    if (taskProvider == null) return const SizedBox.shrink();
    final activeProgress = taskProvider.getActiveTaskProgress();
    if (activeProgress.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final showTasks = _isDiscoveryExpanded;
    final tasksToRender = showTasks ? activeProgress : const <TaskProgress>[];
    final scheme = theme.colorScheme;
    final overall = taskProvider.getOverallProgress();
    return KubusDiscoveryPathCard(
      overallProgress: overall,
      expanded: _isDiscoveryExpanded,
      taskRows: [
        for (final progress in tasksToRender) _buildTaskProgressRow(progress),
      ],
      toggleButton: _glassIconButton(
        icon: _isDiscoveryExpanded
            ? Icons.keyboard_arrow_up
            : Icons.keyboard_arrow_down,
        tooltip: _isDiscoveryExpanded ? l10n.commonCollapse : l10n.commonExpand,
        onTap: () =>
            setState(() => _isDiscoveryExpanded = !_isDiscoveryExpanded),
      ),
      titleStyle: KubusTypography.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      percentStyle: KubusTypography.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      glassPadding: const EdgeInsets.all(14),
      badgeGap: 10,
      tasksTopGap: 10,
    );
  }

  Widget _buildTaskProgressRow(TaskProgress progress) {
    return KubusMapTaskProgressRow.build(context: context, progress: progress);
  }

  Widget _buildPrimaryControls() {
    final l10n = AppLocalizations.of(context)!;
    // Keep controls clear of the discovery module and the nearby sheet.
    // Smaller bottom offset moves controls slightly down.
    final bottomOffset = 90.0 + KubusLayout.mainBottomNavBarHeight;
    return Positioned(
      right: 12,
      bottom: bottomOffset,
      child: MapOverlayBlocker(
        child: KubusMapPrimaryControls(
          controller: _kubusMapController,
          layout: KubusMapPrimaryControlsLayout.mobileRightRail,
          onCenterOnMe: () => unawaited(_handleCenterOnMeTap()),
          onCreateMarker: () => unawaited(_handleCurrentLocationTap()),
          centerOnMeActive: _autoFollow,
          resetBearingTooltip: l10n.mapResetBearingTooltip,
          zoomInTooltip: 'Zoom in',
          zoomOutTooltip: l10n.mapEmptyZoomOutAction,
          centerOnMeKey: _tutorialCenterButtonKey,
          centerOnMeTooltip: l10n.mapCenterOnMeTooltip,
          createMarkerKey: _tutorialAddMarkerButtonKey,
          createMarkerTooltip: l10n.mapAddMapMarkerTooltip,
          showTravelModeToggle: AppConfig.isFeatureEnabled('mapTravelMode'),
          travelModeKey: _tutorialTravelButtonKey,
          travelModeActive: _travelModeEnabled,
          onToggleTravelMode: () {
            unawaited(_setTravelModeEnabled(!_travelModeEnabled));
          },
          travelModeTooltipWhenActive: l10n.mapTravelModeDisableTooltip,
          travelModeTooltipWhenInactive: l10n.mapTravelModeEnableTooltip,
          showIsometricViewToggle:
              AppConfig.isFeatureEnabled('mapIsometricView'),
          isometricViewActive: _isometricViewEnabled,
          onToggleIsometricView: () {
            unawaited(_setIsometricViewEnabled(!_isometricViewEnabled));
          },
          isometricViewTooltipWhenActive: l10n.mapIsometricViewDisableTooltip,
          isometricViewTooltipWhenInactive: l10n.mapIsometricViewEnableTooltip,
        ),
      ),
    );
  }

  Widget _buildBottomSheet(
    ThemeData theme,
    List<Artwork> artworks,
    double discoveryProgress,
    bool isLoading,
  ) {
    final sheet = Align(
      alignment: Alignment.bottomCenter,
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          final blocking = notification.extent > (_nearbySheetMin + 0.01);
          _setSheetBlocking(blocking, notification.extent);
          return false;
        },
        child: DraggableScrollableSheet(
          controller: _sheetController,
          // Keep the collapsed state slightly more visible while still letting it sit
          // behind the glass navbar.
          initialChildSize: _nearbySheetMin,
          minChildSize: _nearbySheetMin,
          maxChildSize: _nearbySheetMax,
          snap: true,
          snapSizes: const [_nearbySheetMin, 0.24, 0.50, _nearbySheetMax],
          builder: (context, scrollController) {
            final base = _currentPosition ?? _cameraCenter;
            return KubusNearbyArtPanel(
              controller: _nearbyArtController,
              layout: KubusNearbyArtPanelLayout.mobileBottomSheet,
              artworks: artworks,
              markers: _artMarkers,
              basePosition: base,
              isLoading: isLoading,
              travelModeEnabled: _travelModeEnabled,
              radiusKm: _effectiveMarkerRadiusKm,
              titleKey: _tutorialNearbyTitleKey,
              discoveryProgress: discoveryProgress,
              onRadiusTap: _openMarkerRadiusDialog,
              scrollController: scrollController,
              onInteractingChanged: _setSheetInteracting,
            );
          },
        ),
      ),
    );
    return sheet;
  }

  String _markerQueryFiltersKey() {
    final query = _mapSearchController.state.query.trim().toLowerCase();
    return 'filter=$_artworkFilter|query=$query|travel=${_travelModeEnabled ? 1 : 0}';
  }

  List<Artwork> _filterArtworks(
    List<Artwork> artworks, {
    LatLng? basePosition,
  }) {
    var filtered = artworks.where((a) => a.hasValidLocation).toList();
    final query = _mapSearchController.state.query.trim().toLowerCase();

    if (query.isNotEmpty) {
      filtered = filtered.where((artwork) {
        return artwork.title.toLowerCase().contains(query) ||
            artwork.artist.toLowerCase().contains(query) ||
            artwork.category.toLowerCase().contains(query) ||
            artwork.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    switch (_artworkFilter) {
      case 'nearby':
        if (basePosition != null) {
          filtered = filtered
              .where((artwork) =>
                  artwork.getDistanceFrom(basePosition) <=
                  _markerRadiusKm * 1000)
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

  bool _markersEquivalent(List<ArtMarker> current, List<ArtMarker> next) {
    return KubusMapMarkerHelpers.markersEquivalent(current, next);
  }
}

// (Marker clustering and icon pre-registration helpers moved to
// `lib/widgets/map/kubus_map_marker_rendering.dart`.)
