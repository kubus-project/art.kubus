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
import '../features/map/shared/map_screen_shared_helpers.dart';
import '../features/map/shared/map_artwork_filtering.dart';
import '../features/map/shared/map_marker_filtering.dart';
import '../features/map/shared/map_marker_collision_config.dart';
import '../features/map/filters/map_filter_state.dart';
import '../features/map/shared/map_marker_overlay_actions.dart';
import '../features/map/shared/map_marker_overlay_presentation.dart';
import '../features/map/shared/map_marker_selection_resolver.dart';
import '../features/map/shared/map_overlay_sizing.dart';
import '../features/map/shared/map_search_filter_assembly.dart';
import '../providers/artwork_provider.dart';
import '../providers/task_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/themeprovider.dart';
import '../providers/map_deep_link_provider.dart';
import '../providers/public_entity_takeover_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/main_tab_provider.dart';
import '../providers/exhibitions_provider.dart';
import '../providers/events_provider.dart';
import '../providers/marker_management_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/presence_provider.dart';
import '../models/artwork.dart';
import '../models/task.dart';
import '../models/map_marker_subject.dart';
import '../services/ar_integration_service.dart';
import '../services/guest_session_service.dart';
import '../services/telemetry/telemetry_service.dart';
import '../services/map_marker_service.dart';
import '../services/share/share_types.dart';
import '../services/push_notification_service.dart';
import '../services/map_attribution_helper.dart';
import '../core/app_route_observer.dart';
import '../core/startup_trace.dart';
import '../models/art_marker.dart';
import '../models/event.dart';
import '../widgets/map_marker_style_config.dart';
import '../utils/app_animations.dart';
import '../utils/artwork_navigation.dart';
import '../utils/grid_utils.dart';
import '../utils/artwork_media_resolver.dart';
import '../utils/design_tokens.dart';

import '../utils/app_color_utils.dart';
import '../utils/kubus_color_roles.dart';
import '../utils/kubus_map_tokens.dart';
import '../utils/art_marker_list_diff.dart';
import '../utils/debouncer.dart';
import '../utils/map_marker_helper.dart';
import '../utils/map_marker_subject_loader.dart';
import '../utils/map_viewport_utils.dart';
import '../utils/map_perf_tracker.dart';
import '../utils/map_performance_debug.dart';
import '../utils/presence_marker_visit.dart';
import '../utils/geo_bounds.dart';
import '../utils/institution_navigation.dart';
import '../utils/media_url_resolver.dart';
import '../utils/user_profile_navigation.dart';
import '../widgets/map_marker_dialog.dart';
import '../providers/tile_providers.dart';
import '../widgets/art_map_view.dart';
import 'dart:ui' as ui;
import '../services/backend_api_service.dart';
import '../services/map_data_controller.dart';
import '../services/map_style_service.dart';
import '../config/config.dart';
import '../features/map/controller/map_view_preferences_controller.dart';
import '../features/map/shared/map_screen_constants.dart';
import '../features/map/map_layers_manager.dart';
import '../features/map/map_overlay_stack.dart';
import '../features/map/controller/kubus_map_controller.dart';
import '../features/map/controller/map_target_coordinator.dart';
import '../features/map/engine/kubus_map_marker_sync_engine.dart';
import '../features/map/nearby/nearby_art_controller.dart';
import '../features/map/tutorial/map_tutorial_coordinator.dart';
import '../utils/marker_cube_geometry.dart';
import 'events/event_detail_screen.dart';
import 'events/exhibition_detail_screen.dart';
import '../widgets/glass_components.dart';
import '../widgets/kubus_snackbar.dart';
import '../widgets/map_overlay_blocker.dart';
import '../widgets/search/kubus_general_search.dart';
import '../widgets/search/kubus_search_config.dart';
import '../widgets/search/kubus_search_controller.dart';
import '../widgets/search/kubus_search_result.dart';
import '../widgets/map/nearby/kubus_nearby_art_panel.dart';
import '../widgets/tutorial/interactive_tutorial_overlay.dart';
import '../widgets/tutorial/tutorial_overlay_controller.dart';
import '../widgets/tutorial/tutorial_overlay_scope.dart';
import '../widgets/map/filters/kubus_map_filter_content.dart';
import '../widgets/map/controls/kubus_map_primary_controls.dart'
    show KubusMapPrimaryControlsLayout;
import '../widgets/map/dialogs/kubus_map_attribution_dialog.dart';
import '../widgets/map/dialogs/street_art_claims_dialog.dart';
import '../widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import '../widgets/map/kubus_map_glass_surface.dart';
import '../widgets/common/kubus_filter_panel.dart';
import '../widgets/common/kubus_glass_icon_button.dart';
import '../widgets/common/kubus_map_controls.dart';
import '../widgets/common/kubus_cached_image.dart';
import '../widgets/common/kubus_marker_overlay_card.dart';
import '../widgets/common/marker_attribution_section.dart';
import '../widgets/common/kubus_search_overlay_scaffold.dart';
import '../widgets/map/overlays/kubus_marker_overlay_card_wrapper.dart'
    as overlay_wrapper;
import 'map_core/map_marker_interaction_controller.dart';
import 'map_core/map_camera_controller.dart';
import 'map_core/marker_visual_sync_coordinator.dart';
import 'map_core/map_data_coordinator.dart';
import 'map_core/map_ui_state_coordinator.dart';
import 'map_core/map_marker_render_coordinator.dart';

enum _MarkerSocketScope { inScope, outOfScope, unknown }

class _MapTutorialReadiness {
  const _MapTutorialReadiness({
    required this.ready,
    required this.reason,
    required this.signature,
    required this.bindings,
    this.firstTargetRect,
  });

  final bool ready;
  final String reason;
  final String signature;
  final List<MapTutorialStepBinding> bindings;
  final Rect? firstTargetRect;
}

class _MapTutorialTargetRectResult {
  const _MapTutorialTargetRectResult.ready([this.rect])
      : ready = true,
        reason = 'ready';

  const _MapTutorialTargetRectResult.notReady(this.reason)
      : ready = false,
        rect = null;

  final bool ready;
  final String reason;
  final Rect? rect;
}

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
    // Cone dimensions: 60-degree spread angle.
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
  final String? initialArtworkId;
  final String? initialSubjectId;
  final String? initialSubjectType;
  final String? initialTargetLabel;

  const MapScreen({
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
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin, RouteAware
    implements KubusMapMarkerSyncHost {
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
  ml.MapLibreMapController? _deactivateDetachedMapController;
  MapLayersManager? _layersManager;
  late final KubusMapController _kubusMapController;
  late final MapMarkerInteractionController _markerInteractionController;
  late final MapCameraController _mapCameraController;
  late final MarkerVisualSyncCoordinator _markerVisualSyncCoordinator;
  late final NearbyArtController _nearbyArtController;
  late final MapUiStateCoordinator _mapUiStateCoordinator;
  late final MapMarkerRenderCoordinator _renderCoordinator;
  final KubusMapBackdropHostController _mapBackdropHostController =
      KubusMapBackdropHostController();
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
  int _styleEpoch = 0;
  final Set<String> _registeredMapImages = <String>{};
  final Set<String> _managedLayerIds = <String>{};
  final Set<String> _managedSourceIds = <String>{};
  double _lastWebAttributionBottomPx = -1;
  // Shared constants – canonical values live in MapScreenConstants.
  static const String _markerSourceId = MapScreenConstants.markerSourceId;
  static const String _markerLayerId = MapScreenConstants.markerLayerId;
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
  Offset? _markerTapRippleOffset;
  DateTime? _markerTapRippleAt;
  Color? _markerTapRippleColor;
  late final ValueNotifier<Offset?> _selectedMarkerAnchorNotifier;
  final Debouncer _cubeSyncDebouncer = Debouncer();
  final Debouncer _radiusChangeDebouncer = Debouncer();
  late final MapTargetCoordinator _mapTargetCoordinator;
  String? _directTargetMarkerId;
  MapDeepLinkProvider? _mapDeepLinkProvider;
  MapDeepLinkClaim? _mapDeepLinkClaim;
  MainTabProvider? _tabProvider;
  Timer? _proximityCheckTimer;
  bool _proximityChecksEnabled = false;
  StreamSubscription<ArtMarker>? _markerSocketSubscription;
  StreamSubscription<String>? _markerDeletedSubscription;
  bool _isMapTabVisible = true;
  bool _isAppForeground = true;
  bool _isRouteVisible = true;
  bool _mapViewMounted = true;
  PageRoute<dynamic>? _subscribedRoute;
  int _markerOpenRequestId = 0;
  bool _pendingMarkerRefresh = false;
  bool _pendingMarkerRefreshForce = false;

  late final MapDataCoordinator _mapDataCoordinator;
  late final MapViewPreferencesController _mapViewPreferencesController;
  late final MapTutorialCoordinator _mapTutorialCoordinator;
  TutorialOverlayController? _tutorialOverlayController;
  bool _mapTutorialConfigureScheduled = false;
  bool _mapTutorialStartScheduled = false;
  String? _lastMapTutorialBindingSignature;
  int _mapTutorialOwnerGeneration = 0;
  int _mapTutorialStartAttempts = 0;
  Timer? _mapTutorialStartRetryTimer;
  static const int _maxMapTutorialStartAttempts = 20;
  static const Duration _mapTutorialStartRetryDelay =
      Duration(milliseconds: 100);

  // Map search (shared controller + UI)
  late final KubusSearchController _mapSearchController;

  KubusMapFilterState _filterState = KubusMapFilterState.defaults();
  Map<ArtMarkerType, bool> get _markerLayerVisibility => <ArtMarkerType, bool>{
        for (final type in ArtMarkerType.values)
          type: _filterState.visibleContentLayers.contains(type),
      };
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _nearbySheetExtentNotifier =
      ValueNotifier<double>(_nearbySheetMin);
  bool _isSheetInteracting = false;
  // Prevent intermediate extent notifications from reopening Nearby while a
  // dominant surface is deliberately collapsing the sheet.
  bool _suppressNearbySurfaceSync = false;
  // Only block map gestures in the sheet area when the sheet is expanded.
  // The default collapsed extent should not disable map interactions.
  bool _isSheetBlocking = false;
  bool _travelModeEnabled = false;
  bool _isometricViewEnabled = false;

  static const double _nearbySheetMin = 0.16;
  static const double _nearbySheetMax = 0.85;
  static const double _nearbySheetBlockingOnThreshold = _nearbySheetMin + 0.02;
  static const double _nearbySheetBlockingOffThreshold =
      _nearbySheetMin + 0.008;

  // Travel mode is viewport-based (bounds query), not huge-radius.
  double get _effectiveMarkerRadiusKm => _filterState.nearMeRadiusKm;

  // Interactive onboarding tutorial (coach marks)
  final GlobalKey _tutorialMapKey = GlobalKey();
  final GlobalKey _tutorialFilterButtonKey = GlobalKey();
  final GlobalKey _tutorialNearbyTitleKey = GlobalKey();
  final GlobalKey _tutorialTravelButtonKey = GlobalKey();
  final GlobalKey _tutorialCenterButtonKey = GlobalKey();
  final GlobalKey _tutorialAddMarkerButtonKey = GlobalKey();

  // Discovery and Progress
  final GlobalKey _discoveryCardKey = GlobalKey();
  double _markerOverlayTopPadding = MapOverlaySizing.defaultVerticalPadding;
  bool _markerOverlayTopPaddingMeasurePending = false;
  String? _pendingMarkerOverlayTopPaddingLayoutKey;
  String? _lastMarkerOverlayTopPaddingLayoutKey;

  bool _pendingSafeSetState = false;
  int _debugMarkerTapCount = 0;
  late final KubusMapMarkerSyncEngine _markerSyncEngine =
      KubusMapMarkerSyncEngine(this);

  // --- KubusMapMarkerSyncHost ---------------------------------------------
  @override
  ml.MapLibreMapController? get mapController => _mapController;
  @override
  bool get styleInitialized => _styleInitialized;
  @override
  bool get hostMounted => mounted;
  @override
  BuildContext get hostContext => context;
  @override
  Set<String> get managedSourceIds => _managedSourceIds;
  @override
  String get markerSourceId => _markerSourceId;
  @override
  KubusMapController get kubusMapController => _kubusMapController;
  @override
  Set<String> get registeredMapImages => _registeredMapImages;
  @override
  double get syncZoom => _lastZoom;
  @override
  double get clusterMaxZoom => _clusterMaxZoom;
  @override
  bool get sortClustersBySizeDesc => true;
  @override
  String get debugLabel => 'MapScreen';
  @override
  int clusterGridLevelForZoom(double zoom) => _clusterGridLevelForZoom(zoom);
  @override
  double markerPixelRatio() => _markerPixelRatio();
  @override
  Color resolveArtMarkerBaseColor(
          ArtMarker marker, ThemeProvider themeProvider) =>
      _resolveArtMarkerColor(marker, themeProvider);
  @override
  void onMarkerSourceWrite() => _debugMarkerSourceWriteCount += 1;
  @override
  Future<void> afterMarkerSync(ThemeProvider themeProvider) async {
    if (_renderCoordinator.is3DModeActive) {
      await _syncMarkerCubes(themeProvider: themeProvider);
    }
  }
  // -------------------------------------------------------------------------

  int _debugMarkerSourceWriteCount = 0;
  int _webResizeRecoveryToken = 0;
  int _debugSheetExtentEventCount = 0;
  DateTime _debugSheetExtentWindowStart = DateTime.now();

  late AnimationController _cubeIconSpinController;

  final GlobalKey _mapViewKey = GlobalKey();
  bool? _lastAppliedMapThemeDark;
  bool _themeResyncScheduled = false;

  static const double _clusterMaxZoom = MapScreenConstants.clusterMaxZoom;
  static const int _markerVisualSyncThrottleMs =
      MapScreenConstants.markerVisualSyncThrottleMs;
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
    final scheme = Theme.of(context).colorScheme;
    final layersManager = _layersManager;
    if (layersManager == null) {
      return;
    }

    await KubusMapStyleInitHelpers.handleStyleLoaded(
      controller: _mapController,
      mounted: mounted,
      styleInitializationInProgress:
          _kubusMapController.styleInitializationInProgress,
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
      ),
      debugLabel: 'MapScreen',
      onStyleReady: () async {
        if (!mounted) return;
        await _applyThemeToMapStyle(themeProvider: themeProvider);
        await _applyIsometricCamera(enabled: _isometricViewEnabled);
        await _syncUserLocation();
        await _syncMapMarkers(themeProvider: themeProvider);
        await _renderCoordinator.updateRenderMode();
        // Start the ambient dot-pulse / floating-badge bob ticker.
        _renderCoordinator.updateAmbientTicker();
      },
    );
    if (mounted) {
      _mapTargetCoordinator.setStyleReady(_styleInitialized);
    }
  }

  @override
  void initState() {
    super.initState();
    StartupTrace.mark('map screen init');
    MapAttributionHelper.setMobileMapEnabled(true);
    _autoFollow = widget.autoFollow;

    // Guest-first funnel: record that a guest reached the map (campaign
    // attribution is attached automatically by the telemetry layer).
    unawaited(_trackGuestMapEntry());

    // Shared dominant-surface and selection state for the mobile composition.
    _mapUiStateCoordinator = MapUiStateCoordinator();
    _mapViewPreferencesController = MapViewPreferencesController();
    _mapViewPreferencesController.addListener(_handleMapViewPreferencesChanged);
    _mapTutorialCoordinator = MapTutorialCoordinator(
      seenPreferenceKey: PreferenceKeys.mapOnboardingMobileSeenV2,
    );
    _mapTutorialCoordinator.addListener(_handleMapTutorialStateChanged);

    _mapSearchController = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.map,
        limit: 8,
        showOverlayOnFocus: true,
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
        layers: MapScreenConstants.mobileLayerIds,
      ),
      debugTracing: kDebugMode && MapPerformanceDebug.isEnabled,
      tapConfig: KubusMapTapConfig(
        clusterTapZoomDelta: 1.5,
        clusterGridLevelForZoom: MapScreenConstants.clusterGridLevelForZoom,
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

        // Marker taps must not interrupt the isolated create-marker context.
        // Keep the MapLibre/controller selection in sync with the coordinator's
        // rejected selection instead of allowing a hidden marker selection to
        // surface after the dialog closes.
        if (_mapUiStateCoordinator.value.contextSurface ==
                MapContextSurface.createMarker &&
            state.selectedMarker != null) {
          _kubusMapController.dismissSelection();
          return;
        }

        final prevSelection = _mapUiStateCoordinator.value.markerSelection;
        final prevToken = prevSelection.selectionToken;
        final prevId = prevSelection.selectedMarkerId;
        final tokenChanged = state.selectionToken != prevToken;
        final idChanged = state.selectedMarkerId != prevId;
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
        final stackIndexChanged = state.stackIndex != prevSelection.stackIndex;

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

        if (marker != null &&
            _mapUiStateCoordinator.value.contextSurface ==
                MapContextSurface.markerPreview) {
          unawaited(_collapseNearbySheetForSurfaceTransition());
        }

        if (marker != null) {
          if (tokenChanged) {
            _renderCoordinator.startSelectionPopAnimation();
            _renderCoordinator.requestStyleUpdate(force: true);
            unawaited(_playMarkerSelectionFeedback(marker));
            _syncMarkerStackPager(state.selectionToken);
            if (!marker.isExhibitionMarker) {
              _ensureLinkedArtworkLoaded(marker);
            }
          } else if (idChanged) {
            // Paged within a stacked selection.
            _renderCoordinator.requestStyleUpdate(force: true);
            if (!marker.isExhibitionMarker) {
              _ensureLinkedArtworkLoaded(marker);
            }
          } else if (stackChanged || stackIndexChanged) {
            // Marker payload refresh can update stack order/size without a new
            // selection token. Keep pager + UI in sync to avoid snap-back.
            _renderCoordinator.requestStyleUpdate(force: true);
            _syncMarkerStackPager(state.selectionToken);
          } else {
            // Selection is unchanged; marker instances may have refreshed.
            _renderCoordinator.requestStyleUpdate(force: true);
          }
        } else {
          // Selection dismissed.
          _syncMarkerStackPager(state.selectionToken);
          _renderCoordinator.requestStyleUpdate(force: true);
        }
        _mapTargetCoordinator.selectionChanged(state.selectedMarkerId);
      },
      onBackgroundTap: () {
        _dismissMapContext();
      },
      onRequestMarkerLayerStyleUpdate: () {
        _renderCoordinator.requestStyleUpdate(force: true);
      },
      onRequestMarkerDataSync: () {
        _requestMarkerVisualSync();
      },
    );

    _mapTargetCoordinator = MapTargetCoordinator(
      loadedMarkers: () => _artMarkers,
      fetchMarkerById: MapDataController().getArtMarkerById,
      fetchMarkersByArtwork: MapDataController().getArtMarkersByArtwork,
      loadMarkersAround: (position) =>
          _loadArtMarkers(center: position, force: true),
      mergeMarkers: _mergeDirectTargetMarkers,
      moveCamera: (position, zoom) => _animateMapTo(position, zoom: zoom),
      selectMarker: _showArtMarkerDialog,
      setPinnedMarker: (markerId) {
        if (_directTargetMarkerId == markerId) return;
        _directTargetMarkerId = markerId;
        if (mounted) _applyVisibleMarkers();
      },
      showFallback: _showMapTargetFallback,
      onTerminal: _handleMapTargetTerminal,
    );

    final initialTarget = MapTargetIntent(
      exactMarkerId: widget.initialMarkerId,
      artworkId: widget.initialArtworkId,
      subjectId: widget.initialSubjectId,
      subjectType: widget.initialSubjectType,
      preferredPosition: widget.initialCenter,
      preferredLabel: widget.initialTargetLabel,
      minZoom: widget.initialZoom ?? 16,
    );
    if (initialTarget.hasIdentity) {
      unawaited(_mapTargetCoordinator.submit(initialTarget));
    }

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
      pulseLayerId: MapScreenConstants.markerPulseLayerId,
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

      await _loadMapViewPreferences();
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

      _scheduleMapTutorialStartIfEligible(reason: 'initial-layout');
    });
  }

  void _handleMapSearchControllerChanged() {
    if (!mounted) return;
    final searchState = _mapSearchController.state;
    final trimmedQuery = searchState.query.trim();
    final searchVisible = searchState.isOverlayVisible &&
        (searchState.isFetching ||
            searchState.results.isNotEmpty ||
            trimmedQuery.length >= _mapSearchController.config.minChars);
    final activeSurface = _mapUiStateCoordinator.value.contextSurface;
    if (searchVisible) {
      if (activeSurface != MapContextSurface.searchResults &&
          activeSurface != MapContextSurface.createMarker) {
        if (activeSurface == MapContextSurface.nearby) {
          _closeTemporarySurface(MapContextSurface.nearby);
        }
        _mapUiStateCoordinator.openSurface(
          MapContextSurface.searchResults,
          intent: MapSurfaceTransitionIntent.suspendCurrent,
        );
        unawaited(_collapseNearbySheetForSurfaceTransition());
      }
    } else if (activeSurface == MapContextSurface.searchResults) {
      if (!_mapUiStateCoordinator.restoreSuspendedSurface()) {
        _mapUiStateCoordinator.closeSurface(MapContextSurface.searchResults);
      }
    }

    // Keep legacy behaviors that rely on widget rebuilds (e.g. filtering the
    // nearby panel list by query) without reintroducing screen-local search
    // state.
    _safeSetState(() {});
    // Compose the search query with the active quick filter on the actual map
    // markers + clusters, not just the nearby list.
    _applyVisibleMarkers();
    _requestMarkerVisualSync(force: true);
  }

  void _handleMapTutorialStateChanged() {
    final tutorial = _mapTutorialCoordinator.state;
    _mapUiStateCoordinator.setTutorial(
      show: tutorial.show,
      index: tutorial.index,
    );
  }

  void _dismissSearchResults() {
    _mapSearchController.dismissOverlay();
  }

  void _openTemporarySurface(
    MapContextSurface surface, {
    bool collapseNearby = true,
  }) {
    if (surface != MapContextSurface.nearby &&
        _mapUiStateCoordinator.value.contextSurface ==
            MapContextSurface.nearby) {
      _closeTemporarySurface(MapContextSurface.nearby);
    }
    if (surface != MapContextSurface.searchResults &&
        _mapSearchController.state.isOverlayVisible) {
      _mapSearchController.dismissOverlay();
    }
    _mapUiStateCoordinator.openSurface(
      surface,
      intent: MapSurfaceTransitionIntent.suspendCurrent,
    );
    if (collapseNearby && surface != MapContextSurface.nearby) {
      unawaited(_collapseNearbySheetForSurfaceTransition());
    }
  }

  void _closeTemporarySurface(MapContextSurface surface) {
    if (_mapUiStateCoordinator.value.contextSurface != surface) return;
    if (!_mapUiStateCoordinator.restoreSuspendedSurface()) {
      _mapUiStateCoordinator.closeSurface(surface);
    }
  }

  void _dismissMapContext() {
    if (_mapSearchController.state.isOverlayVisible) {
      _mapSearchController.dismissOverlay();
    }
    _mapUiStateCoordinator.dismissToMap(
      nextSelectionToken: _kubusMapController.selectionState.selectionToken,
    );
    _kubusMapController.dismissSelection();
    unawaited(_collapseNearbySheetForSurfaceTransition());
  }

  bool _handleMapContextBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    switch (_mapUiStateCoordinator.value.contextSurface) {
      case MapContextSurface.none:
        return false;
      case MapContextSurface.searchResults:
        _mapSearchController.dismissOverlay();
      case MapContextSurface.filters:
        _closeTemporarySurface(MapContextSurface.filters);
      case MapContextSurface.nearby:
        _closeTemporarySurface(MapContextSurface.nearby);
        unawaited(_collapseNearbySheetForSurfaceTransition());
      case MapContextSurface.markerPreview:
        _dismissMapContext();
      case MapContextSurface.markerDetails:
        _mapUiStateCoordinator.backFromMarkerDetails();
      case MapContextSurface.discovery:
        _closeTemporarySurface(MapContextSurface.discovery);
      case MapContextSurface.createMarker:
        // Mobile creation is hosted by a dialog route, which owns Back.
        return false;
    }
    return true;
  }

  Future<void> _collapseNearbySheetForSurfaceTransition() async {
    if (_suppressNearbySurfaceSync ||
        _nearbySheetExtentNotifier.value <= _nearbySheetBlockingOffThreshold) {
      return;
    }
    _suppressNearbySurfaceSync = true;
    try {
      if (_sheetController.isAttached) {
        final motion = KubusMapMotion.fromMediaQuery(
          animationTheme: context.animationTheme,
          mediaQuery: MediaQuery.of(context),
        ).panelEnter;
        await _sheetController.animateTo(
          _nearbySheetMin,
          duration: motion.duration,
          curve: motion.curve,
        );
      }
      _setSheetBlocking(false, _nearbySheetMin);
    } catch (_) {
      // The sheet can detach during route changes; its next mount starts at
      // the compact extent, so no recovery mutation is needed.
    } finally {
      _suppressNearbySurfaceSync = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _kubusMapController.setReduceMotion(
      media.disableAnimations || media.accessibleNavigation,
    );

    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      if (_subscribedRoute != route) {
        if (_subscribedRoute != null) {
          _unsubscribeRouteObserver(source: 'didChangeDependencies');
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

    final overlayController = TutorialOverlayScope.maybeOf(context);
    if (_tutorialOverlayController != overlayController) {
      _debugMapTutorialBindingLog('scope changed; unbinding previous driver');
      _deactivateRootTutorialOwner(reason: 'mobile-map-scope-changed');
      _tutorialOverlayController = overlayController;
    }
    _syncRootTutorialBinding();

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

  void _syncRootTutorialBinding() {
    final controller = _tutorialOverlayController;
    if (controller == null) {
      _debugMapTutorialBindingLog(
          'skip bind: TutorialOverlayScope unavailable');
      return;
    }

    final shouldBind = _isMapTabVisible && _isRouteVisible;
    if (!shouldBind) {
      _debugMapTutorialBindingLog(
        'unbind: inactive tab=$_isMapTabVisible route=$_isRouteVisible '
        'visible=${_mapTutorialCoordinator.visible} '
        'index=${_mapTutorialCoordinator.currentIndex} '
        'steps=${_mapTutorialCoordinator.steps.length}',
      );
      _deactivateRootTutorialOwner(reason: 'mobile-map-inactive');
      return;
    }

    _debugMapTutorialBindingLog(
      'bind owner=mobile-map visible=${_mapTutorialCoordinator.visible} '
      'index=${_mapTutorialCoordinator.currentIndex} '
      'steps=${_mapTutorialCoordinator.steps.length}',
    );
    controller.bindDriver(
      tutorialId: 'map',
      ownerRoute: 'mobile-map',
      driver: _mapTutorialCoordinator,
    );
  }

  void _scheduleMapTutorialConfigure({
    required String reason,
    required List<MapTutorialStepBinding> bindings,
  }) {
    if (_mapTutorialConfigureScheduled) return;
    _mapTutorialConfigureScheduled = true;
    final generation = _mapTutorialOwnerGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapTutorialConfigureScheduled = false;
      if (!_isMapTutorialOwnerActive(generation)) {
        _deactivateRootTutorialOwner(
          reason: 'mobile-map-configure-inactive-$reason',
        );
        return;
      }

      final readiness = _resolveMapTutorialReadiness(bindings);
      final previousSignature = _lastMapTutorialBindingSignature;
      _lastMapTutorialBindingSignature = readiness.signature;
      if (!readiness.ready) {
        _scheduleMapTutorialStartRetry(reason: readiness.reason);
        return;
      }
      if (readiness.signature == previousSignature &&
          readiness.bindings.isEmpty) {
        return;
      }

      _mapTutorialCoordinator.configure(bindings: readiness.bindings);
      _syncRootTutorialBinding();
    });
  }

  void _scheduleMapTutorialStartIfEligible({required String reason}) {
    // A direct target must remain the only foreground task until its exact
    // marker card is visible. The tutorial remains manually launchable.
    if (_hasInitialDirectTarget) return;
    if (_mapTutorialStartScheduled) return;
    if (_mapTutorialCoordinator.visible) return;
    if (_mapTutorialStartAttempts >= _maxMapTutorialStartAttempts) return;
    _debugMapTutorialBindingLog('start gate scheduled reason=$reason');
    _mapTutorialStartScheduled = true;
    final generation = _mapTutorialOwnerGeneration;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _mapTutorialStartScheduled = false;
      if (!_isMapTutorialOwnerActive(generation)) return;

      final l10n = AppLocalizations.of(context)!;
      final first = _resolveMapTutorialReadiness(
        _buildMapTutorialStepBindings(l10n),
      );
      if (!first.ready) {
        _scheduleMapTutorialStartRetry(reason: first.reason);
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      if (!_isMapTutorialOwnerActive(generation)) return;

      final second = _resolveMapTutorialReadiness(
        _buildMapTutorialStepBindings(l10n),
      );
      if (!second.ready ||
          second.signature != first.signature ||
          !_isMapTutorialFirstRectStable(
              first.firstTargetRect, second.firstTargetRect)) {
        _scheduleMapTutorialStartRetry(reason: second.reason);
        return;
      }

      if (await _mapTutorialCoordinator.hasPersistedSeen()) return;
      if (!_isMapTutorialOwnerActive(generation)) return;

      _mapTutorialCoordinator.configure(bindings: second.bindings);
      _lastMapTutorialBindingSignature = second.signature;
      _syncRootTutorialBinding();

      if (!_isMapTutorialOwnerActive(generation)) return;
      if (_tutorialOverlayController?.driver != _mapTutorialCoordinator) {
        return;
      }

      _mapTutorialStartAttempts = 0;
      // Guest-first: bindings are configured (so the tutorial stays launchable),
      // but we don't auto-pop it for cold visitors who came to explore.
      if (await GuestSessionService.isGuestActive()) return;
      unawaited(_mapTutorialCoordinator.maybeStart());
    });
  }

  bool get _hasInitialDirectTarget => <String?>[
        widget.initialMarkerId,
        widget.initialArtworkId,
        widget.initialSubjectId,
      ].any((value) => value?.trim().isNotEmpty ?? false);

  Future<void> _trackGuestMapEntry() async {
    try {
      if (await GuestSessionService.isGuestActive()) {
        await TelemetryService().trackGuestMapLoaded();
      }
    } catch (_) {
      // Analytics must never affect the map.
    }
  }

  void _scheduleMapTutorialStartRetry({required String reason}) {
    if (!_isMapTutorialOwnerActive()) return;
    if (_mapTutorialStartAttempts >= _maxMapTutorialStartAttempts) return;
    if (_mapTutorialStartRetryTimer != null) return;
    _mapTutorialStartAttempts += 1;
    final generation = _mapTutorialOwnerGeneration;
    _mapTutorialStartRetryTimer = Timer(_mapTutorialStartRetryDelay, () {
      _mapTutorialStartRetryTimer = null;
      if (!_isMapTutorialOwnerActive(generation)) return;
      _scheduleMapTutorialStartIfEligible(reason: 'retry-$reason');
    });
  }

  void _cancelMapTutorialStartRetry() {
    _mapTutorialStartRetryTimer?.cancel();
    _mapTutorialStartRetryTimer = null;
    _mapTutorialStartScheduled = false;
    _mapTutorialConfigureScheduled = false;
  }

  bool _isMapTutorialOwnerActive([int? generation]) {
    if (!mounted) return false;
    if (generation != null && generation != _mapTutorialOwnerGeneration) {
      return false;
    }
    if (!_isRouteVisible) return false;
    if (!_isMapTabVisible) return false;
    if (_tutorialOverlayController == null) return false;
    return true;
  }

  _MapTutorialReadiness _resolveMapTutorialReadiness(
    List<MapTutorialStepBinding> bindings,
  ) {
    final resolved = <MapTutorialStepBinding>[];
    final ids = <String>[];
    Rect? firstRect;

    for (final binding in bindings) {
      if (!binding.enabled) continue;
      if (binding.isAnchorAvailable?.call() == false) continue;
      final rectResult = _mapTutorialTargetRect(binding.step.targetKey);
      if (!rectResult.ready) {
        return _MapTutorialReadiness(
          ready: false,
          reason: rectResult.reason,
          signature: ids.join('|'),
          bindings: resolved,
        );
      }
      resolved.add(binding);
      ids.add(binding.id);
      firstRect ??= rectResult.rect;
    }

    final signature = ids.join('|');
    if (resolved.isEmpty) {
      return _MapTutorialReadiness(
        ready: false,
        reason: 'no-ready-bindings',
        signature: signature,
        bindings: resolved,
      );
    }

    return _MapTutorialReadiness(
      ready: true,
      reason: 'ready',
      signature: signature,
      bindings: resolved,
      firstTargetRect: firstRect,
    );
  }

  _MapTutorialTargetRectResult _mapTutorialTargetRect(GlobalKey? key) {
    if (key == null) {
      return const _MapTutorialTargetRectResult.ready();
    }
    final ctx = key.currentContext;
    if (ctx == null || !ctx.mounted) {
      return const _MapTutorialTargetRectResult.notReady('missing-context');
    }
    final RenderObject? render;
    try {
      render = ctx.findRenderObject();
    } catch (_) {
      return const _MapTutorialTargetRectResult.notReady('inactive-context');
    }
    if (render is! RenderBox) {
      return const _MapTutorialTargetRectResult.notReady('not-render-box');
    }
    if (!render.attached || !render.hasSize) {
      return const _MapTutorialTargetRectResult.notReady('invalid-render-box');
    }
    final size = render.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return const _MapTutorialTargetRectResult.notReady('invalid-size');
    }
    final Offset offset;
    try {
      offset = render.localToGlobal(Offset.zero);
    } catch (_) {
      return const _MapTutorialTargetRectResult.notReady('invalid-transform');
    }
    final rect = offset & size;
    if (!_isMapTutorialRectUsable(rect)) {
      return const _MapTutorialTargetRectResult.notReady('invalid-rect');
    }
    return _MapTutorialTargetRectResult.ready(rect);
  }

  bool _isMapTutorialRectUsable(Rect rect) {
    return rect.left.isFinite &&
        rect.top.isFinite &&
        rect.right.isFinite &&
        rect.bottom.isFinite &&
        rect.width > 0 &&
        rect.height > 0;
  }

  bool _isMapTutorialFirstRectStable(Rect? first, Rect? second) {
    if (first == null || second == null) return first == null && second == null;
    const tolerance = 1.0;
    return (first.left - second.left).abs() <= tolerance &&
        (first.top - second.top).abs() <= tolerance &&
        (first.width - second.width).abs() <= tolerance &&
        (first.height - second.height).abs() <= tolerance;
  }

  void _debugMapTutorialBindingLog(String message) {
    if (!kDebugMode) return;
    debugPrint('MapScreen tutorial: $message');
  }

  void _deactivateRootTutorialOwner({required String reason}) {
    _mapTutorialOwnerGeneration += 1;
    _cancelMapTutorialStartRetry();
    _lastMapTutorialBindingSignature = null;
    _mapTutorialStartAttempts = 0;
    _mapTutorialCoordinator.deactivateForOwnerExit(reason: reason);
    _tutorialOverlayController?.unbindDriver(_mapTutorialCoordinator);
  }

  bool get _pollingEnabled =>
      _isAppForeground && _isMapTabVisible && _isRouteVisible;

  void _handleTabProviderChanged() {
    final isVisible = (_tabProvider?.currentIndex ?? 0) == 0;
    _setMapTabVisible(isVisible);
  }

  void _setMapTabVisible(bool isVisible) {
    if (_isMapTabVisible == isVisible) return;
    if (!isVisible) {
      _deactivateRootTutorialOwner(reason: 'mobile-map-tab-hidden');
    }
    _isMapTabVisible = isVisible;
    _handleActiveStateChanged();
    _syncRootTutorialBinding();
    if (isVisible) {
      _scheduleWebMapResizeRecovery(reason: 'tabVisible');
    }
  }

  void _unsubscribeRouteObserver({required String source}) {
    final route = _subscribedRoute;
    if (route == null) return;
    _subscribedRoute = null;
    try {
      appRouteObserver.unsubscribe(this);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint(
          'MapScreen: route observer unsubscribe failed ($source): $error',
        );
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  void _setRouteVisible(bool isVisible) {
    if (_isRouteVisible == isVisible) return;
    if (!isVisible) {
      _deactivateRootTutorialOwner(reason: 'mobile-map-route-hidden');
    }
    _isRouteVisible = isVisible;
    _handleActiveStateChanged();
    _syncRootTutorialBinding();
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
      _setMapViewMounted(true);
      _resumePolling();
    } else {
      _pausePolling();
      // Web: avoid tearing down/recreating the platform view during brief
      // tab/route visibility transitions. Frequent remove/create cycles can
      // trigger avoidable WebGL context loss bursts in Firefox.
      if (!kIsWeb) {
        _setMapViewMounted(false);
      }
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
    final detachedController = KubusMapLifecycleHelpers.detachMapController(
      controller: _mapController,
      kubusMapController: _kubusMapController,
      setMapController: (controller) => _mapController = controller,
      setLayersManager: (manager) => _layersManager = manager,
    );
    if (detachedController == null) return;
    _styleInitialized = false;
    _styleInitializationInProgress = false;
    _styleEpoch = _kubusMapController.styleEpoch;
    _perf.logEvent('mapDetached');
  }

  @override
  void didPushNext() {
    KubusMapRouteAwareHelpers.didPushNext(setRouteVisible: _setRouteVisible);
  }

  @override
  void didPop() {
    _setRouteVisible(false);
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
    _radiusChangeDebouncer.cancel();

    _renderCoordinator.updateAmbientTicker();
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

    _renderCoordinator.updateAmbientTicker();
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

  void _handleMapViewPreferencesChanged() {
    if (!mounted) return;
    final next = _mapViewPreferencesController.value;
    if (_travelModeEnabled == next.travelModeEnabled &&
        _isometricViewEnabled == next.isometricViewEnabled) {
      return;
    }
    _safeSetState(() {
      _travelModeEnabled = next.travelModeEnabled;
      if (next.travelModeEnabled) {
        _filterState = _filterState.withScope(KubusMapScope.travel);
      } else if (_filterState.scope == KubusMapScope.travel) {
        _filterState = _filterState.withScope(KubusMapScope.currentViewport);
      }
      _isometricViewEnabled = next.isometricViewEnabled;
    });
  }

  Future<void> _loadMapViewPreferences() async {
    final prefs = await _mapViewPreferencesController.load();
    if (!mounted) return;
    setState(() {
      _travelModeEnabled = prefs.travelModeEnabled;
      if (prefs.travelModeEnabled) {
        _filterState = _filterState.withScope(KubusMapScope.travel);
      }
      _isometricViewEnabled = prefs.isometricViewEnabled;
    });
  }

  Future<void> _setTravelModeEnabled(
    bool enabled, {
    KubusMapScope scopeWhenDisabled = KubusMapScope.currentViewport,
  }) async {
    if (!mounted) return;

    setState(() {
      _travelModeEnabled = enabled;
      _filterState = _filterState.withScope(
        enabled ? KubusMapScope.travel : scopeWhenDisabled,
      );
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

    // In travel mode we want an immediate viewport refresh (bounds-based).
    unawaited(_loadMarkersForCurrentView(force: true));
  }

  void _handleFilterStateChanged(KubusMapFilterState next) {
    final previous = _filterState;
    final travelChanged =
        (next.scope == KubusMapScope.travel) != _travelModeEnabled;
    final requiresDataReload = previous.scope != next.scope ||
        (next.scope == KubusMapScope.nearMe &&
            previous.nearMeRadiusKm != next.nearMeRadiusKm);
    final layersChanged = !setEquals(
      previous.visibleContentLayers,
      next.visibleContentLayers,
    );
    setState(() => _filterState = next);
    if (layersChanged) {
      _kubusMapController.setMarkerTypeVisibility(_markerLayerVisibility);
      _renderCoordinator.requestStyleUpdate(force: true);
    }
    _applyVisibleMarkers();
    _requestMarkerVisualSync(force: true);
    if (travelChanged) {
      unawaited(
        _setTravelModeEnabled(
          next.scope == KubusMapScope.travel,
          scopeWhenDisabled: next.scope,
        ),
      );
    }
    if (requiresDataReload && !travelChanged) {
      _radiusChangeDebouncer(
        const Duration(
          milliseconds: MapMarkerCollisionConfig.nearbyRadiusDebounceMs,
        ),
        () {
          if (!mounted) return;
          unawaited(_loadMarkersForCurrentView(force: true).then((_) {
            if (!mounted) return;
            _applyVisibleMarkers();
            _requestMarkerVisualSync(force: true);
          }));
        },
      );
    }
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
          advanceOnTargetTap: false,
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
          advanceOnTargetTap: false,
        ),
      ),
      MapTutorialStepBinding(
        id: 'create_marker',
        isAnchorAvailable: () =>
            _tutorialAddMarkerButtonKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialAddMarkerButtonKey,
          icon: Icons.add_location_alt,
          title: l10n.mapTutorialStepCreateMarkerTitle,
          body: l10n.mapTutorialStepCreateMarkerBody,
          advanceOnTargetTap: false,
          onTargetTap: () => unawaited(_handleCurrentLocationTap()),
        ),
      ),
      MapTutorialStepBinding(
        id: 'nearby',
        isAnchorAvailable: () => _tutorialNearbyTitleKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialNearbyTitleKey,
          icon: Icons.view_list,
          title: l10n.mapTutorialStepNearbyTitle,
          body: l10n.mapTutorialStepNearbyBody,
          advanceOnTargetTap: false,
          onTargetTap: () {
            // Expand the sheet a bit so users see the list.
            _openTemporarySurface(
              MapContextSurface.nearby,
              collapseNearby: false,
            );
            try {
              _sheetController.animateTo(
                0.50,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            } catch (_) {}
          },
        ),
      ),
      MapTutorialStepBinding(
        id: 'filters',
        isAnchorAvailable: () =>
            _tutorialFilterButtonKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialFilterButtonKey,
          icon: Icons.filter_alt_outlined,
          title: l10n.mapTutorialStepFiltersTitle,
          body: l10n.mapTutorialStepFiltersBody,
          advanceOnTargetTap: false,
          onTargetTap: () {
            if (!mounted) return;
            _openTemporarySurface(MapContextSurface.filters);
            _scheduleFilterPanelBackdropSync();
          },
        ),
      ),
      MapTutorialStepBinding(
        id: 'recenter',
        isAnchorAvailable: () =>
            _tutorialCenterButtonKey.currentContext != null,
        step: TutorialStepDefinition(
          targetKey: _tutorialCenterButtonKey,
          icon: Icons.my_location,
          title: l10n.mapTutorialStepRecenterTitle,
          body: l10n.mapTutorialStepRecenterBody,
          advanceOnTargetTap: false,
          onTargetTap: () => unawaited(_handleCenterOnMeTap()),
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
            advanceOnTargetTap: false,
            onTargetTap: () => unawaited(_setTravelModeEnabled(true)),
          ),
        ),
      );
    }

    return bindings;
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
  void deactivate() {
    _deactivateRootTutorialOwner(reason: 'mobile-map-deactivate');
    // Detach the controller early (deactivate runs top-down, before children
    // dispose). This removes feature tap/hover listeners before the MapLibre
    // plugin disposes the controller, preventing "used after being disposed".
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
    _syncRootTutorialBinding();
  }

  @override
  void dispose() {
    _unsubscribeRouteObserver(source: 'dispose');
    MapAttributionHelper.setMobileMapEnabled(false);
    final mapDeepLinkProvider = _mapDeepLinkProvider;
    mapDeepLinkProvider?.removeListener(_handleMapDeepLinkProviderChanged);
    final mapDeepLinkClaim = _mapDeepLinkClaim;
    if (mapDeepLinkClaim != null) {
      mapDeepLinkProvider?.release(mapDeepLinkClaim.token);
    }
    _mapDeepLinkClaim = null;
    _mapDeepLinkProvider = null;
    _tabProvider?.removeListener(_handleTabProviderChanged);
    _tabProvider = null;
    _mapViewPreferencesController
        .removeListener(_handleMapViewPreferencesChanged);
    _mapViewPreferencesController.dispose();
    _deactivateRootTutorialOwner(reason: 'mobile-map-dispose');
    _tutorialOverlayController = null;
    _mapTutorialCoordinator.removeListener(_handleMapTutorialStateChanged);
    _mapTutorialCoordinator.dispose();
    _mapCameraController.dispose();
    _markerVisualSyncCoordinator.dispose();
    _mapDataCoordinator.dispose();
    _mapUiStateCoordinator.dispose();
    _mapTargetCoordinator.dispose();
    _kubusMapController.dispose();
    _deactivateDetachedMapController = null;
    _mapController = null;
    _layersManager = null;
    _styleInitialized = false;
    _registeredMapImages.clear();
    _managedLayerIds.clear();
    _managedSourceIds.clear();
    _timer?.cancel();
    _perf.timerStopped('location_timer');
    _mapSearchController.dispose();
    final compassSubscription = _compassSubscription;
    _compassSubscription = null;
    if (compassSubscription != null) {
      _perf.subscriptionStopped('compass');
      unawaited(compassSubscription.cancel().catchError((_) {/* ignore */}));
    }
    final mobileLocationSubscription = _mobileLocationSubscription;
    _mobileLocationSubscription = null;
    if (mobileLocationSubscription != null) {
      _perf.subscriptionStopped('mobile_location_stream');
      unawaited(
        mobileLocationSubscription.cancel().catchError((_) {/* ignore */}),
      );
    }
    final webPositionSubscription = _webPositionSubscription;
    _webPositionSubscription = null;
    if (webPositionSubscription != null) {
      _perf.subscriptionStopped('web_location_stream');
      unawaited(
          webPositionSubscription.cancel().catchError((_) {/* ignore */}));
    }
    _proximityCheckTimer?.cancel();
    _perf.timerStopped('proximity_timer');
    _pushNotificationService.onNotificationTap = null;
    _pushNotificationService.dispose();
    _arIntegrationService.dispose();
    final markerSocketSubscription = _markerSocketSubscription;
    _markerSocketSubscription = null;
    if (markerSocketSubscription != null) {
      _perf.subscriptionStopped('marker_socket_created');
      unawaited(
        markerSocketSubscription.cancel().catchError((_) {/* ignore */}),
      );
    }
    final markerDeletedSubscription = _markerDeletedSubscription;
    _markerDeletedSubscription = null;
    if (markerDeletedSubscription != null) {
      _perf.subscriptionStopped('marker_socket_deleted');
      unawaited(
        markerDeletedSubscription.cancel().catchError((_) {/* ignore */}),
      );
    }
    _cubeSyncDebouncer.dispose();
    _radiusChangeDebouncer.dispose();
    _animationController.dispose();
    _perf.controllerDisposed('selection_pop');
    _cubeIconSpinController.dispose();
    _perf.controllerDisposed('cube_spin');
    _locationIndicatorController?.dispose();
    _perf.controllerDisposed('location_indicator');
    _markerStackPageController.dispose();
    _sheetController.dispose();
    _nearbySheetExtentNotifier.dispose();
    _mapBackdropHostController.dispose();
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

    final useBoundsQuery = _filterState.scope != KubusMapScope.nearMe;
    center = _filterState.scope == KubusMapScope.nearMe
        ? (_currentPosition ?? _cameraCenter)
        : _cameraCenter;
    if (useBoundsQuery) {
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

  void _handleMapDeepLinkProviderChanged() {
    final provider = _mapDeepLinkProvider;
    if (provider == null) return;
    final claim = provider.claimPending();
    if (claim == null || claim.token == _mapDeepLinkClaim?.token) return;
    _mapDeepLinkClaim = claim;
    unawaited(_mapTargetCoordinator.submit(claim.intent));
  }

  Future<bool> _openMarkerById(String markerId) async {
    final id = markerId.trim();
    if (id.isEmpty) return false;
    _perf.recordFetch('marker:get');
    final result = await _mapTargetCoordinator.submit(
      MapTargetIntent(exactMarkerId: id, minZoom: math.max(_lastZoom, 16)),
    );
    return result == MapTargetResult.overlayOpened;
  }

  Future<bool> _openMarkerBySelection({
    String? exactMarkerId,
    String? artworkId,
    String? subjectId,
    String? subjectType,
    String? preferredLabel,
    LatLng? preferredPosition,
  }) async {
    final target = MapTargetIntent(
      exactMarkerId: exactMarkerId,
      artworkId: artworkId,
      subjectId: subjectId,
      subjectType: subjectType,
      preferredLabel: preferredLabel,
      preferredPosition: preferredPosition ?? widget.initialCenter,
      minZoom: math.max(_lastZoom, 16),
    );
    if (!target.hasIdentity) return false;
    final result = await _mapTargetCoordinator.submit(target);
    return result == MapTargetResult.overlayOpened;
  }

  void _mergeDirectTargetMarkers(List<ArtMarker> markers) {
    if (!mounted || markers.isEmpty) return;
    final merged = ArtMarkerListDiff.upsertById(
      current: _artMarkers,
      updates: markers,
    );
    if (_markersEquivalent(_artMarkers, merged)) return;
    setState(() => _artMarkers = merged);
    _applyVisibleMarkers();
    _mapTargetCoordinator.notifyMarkersChanged();
  }

  void _showMapTargetFallback(
    MapTargetIntent intent,
    MapTargetResult result,
  ) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    if (messenger == null || l10n == null) return;
    final message = result == MapTargetResult.coordinatesOnly
        ? l10n.mapTargetMarkerUnavailableToast
        : l10n.mapTargetNotFoundToast;
    messenger.showKubusSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleMapTargetTerminal(
    MapTargetIntent intent,
    MapTargetResult result,
  ) {
    _markCanonicalMarkerTakeoverReady(intent, result);
    final provider = _mapDeepLinkProvider;
    final claim = _mapDeepLinkClaim;
    if (provider == null || claim == null || !identical(claim.intent, intent)) {
      return;
    }
    _mapDeepLinkClaim = null;
    provider.removeListener(_handleMapDeepLinkProviderChanged);
    provider.acknowledge(claim.token);
    provider.addListener(_handleMapDeepLinkProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleMapDeepLinkProviderChanged();
    });
  }

  void _markCanonicalMarkerTakeoverReady(
    MapTargetIntent intent,
    MapTargetResult result,
  ) {
    final markerId = intent.exactMarkerId?.trim() ?? '';
    if (result != MapTargetResult.overlayOpened || markerId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(
          context.read<PublicEntityTakeoverProvider>().markEntityReady(
                ShareEntityType.marker,
                markerId,
              ),
        );
      } catch (_) {}
    });
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
    final useBoundsQuery = _filterState.scope != KubusMapScope.nearMe;
    if (useBoundsQuery && bucket == null) {
      bucket = MapViewportUtils.zoomBucket(_lastZoom);
    }

    GeoBounds? queryBounds = bounds;
    if (useBoundsQuery && queryBounds == null) {
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
        (useBoundsQuery && queryBounds != null)
            ? 'markers:bounds'
            : 'markers:radius',
      );
      final result = (useBoundsQuery && queryBounds != null)
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
              limit: useBoundsQuery ? travelLimit : null,
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
        _applyVisibleMarkers();
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
        final working = List<ArtMarker>.from(_artMarkers, growable: true);
        if (scope == _MarkerSocketScope.outOfScope) {
          if (existingIndex >= 0) {
            working.removeAt(existingIndex);
            changed = true;
          }
        } else if (existingIndex >= 0) {
          working[existingIndex] = marker;
          changed = true;
        } else if (scope == _MarkerSocketScope.inScope) {
          working.add(marker);
          changed = true;
        }
        if (changed) {
          _artMarkers = working;
        }
      });
      if (!changed) return;
      _applyVisibleMarkers();
      unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
      AppConfig.debugPrint('MapScreen: added marker from socket ${marker.id}');
    } catch (e) {
      AppConfig.debugPrint('MapScreen: failed to handle socket marker: $e');
    }
  }

  _MarkerSocketScope _resolveMarkerScope(ArtMarker marker) {
    if (_travelModeEnabled) {
      final bounds = _loadedTravelBounds;
      if (bounds == null) {
        return _MarkerSocketScope.unknown;
      }
      return MapViewportUtils.containsPoint(bounds, marker.position)
          ? _MarkerSocketScope.inScope
          : _MarkerSocketScope.outOfScope;
    }

    if (_currentPosition == null) {
      return _MarkerSocketScope.inScope;
    }

    final distanceKm = _distanceCalculator.as(
      LengthUnit.Kilometer,
      _currentPosition!,
      marker.position,
    );
    return distanceKm <= _mapMarkerService.lastQueryRadiusKm + 1
        ? _MarkerSocketScope.inScope
        : _MarkerSocketScope.outOfScope;
  }

  void _handleMarkerDeleted(String markerId) {
    try {
      if (_artMarkers.indexWhere((m) => m.id == markerId) < 0) {
        return;
      }
      setState(() {
        _artMarkers.removeWhere((m) => m.id == markerId);
      });
      _applyVisibleMarkers();
      unawaited(_syncMapMarkers(themeProvider: context.read<ThemeProvider>()));
    } catch (_) {}
  }

  bool _markersHaveEquivalentVisibleState(ArtMarker current, ArtMarker next) {
    try {
      return jsonEncode(current.toMap()) == jsonEncode(next.toMap());
    } catch (_) {
      return false;
    }
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
        unawaited(_handleMarkerPrimaryAction(marker));
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
    double tempRadius = _filterState.nearMeRadiusKm;
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
      _handleFilterStateChanged(
        _filterState.withScope(KubusMapScope.nearMe).withNearMeRadiusKm(result),
      );
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
            unawaited(_handleMarkerPrimaryAction(marker));
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

  void _handleSheetExtentNotification(double extent) {
    if (kDebugMode && MapPerformanceDebug.isEnabled) {
      _debugSheetExtentEventCount += 1;
      final now = DateTime.now();
      final elapsedMs =
          now.difference(_debugSheetExtentWindowStart).inMilliseconds;
      if (elapsedMs >= 1000) {
        AppConfig.debugPrint(
          'MapScreen: nearby sheet extent events/s=$_debugSheetExtentEventCount',
        );
        _debugSheetExtentEventCount = 0;
        _debugSheetExtentWindowStart = now;
      }
    }

    final clampedExtent = extent.clamp(_nearbySheetMin, _nearbySheetMax);
    final blocking = _isSheetBlocking
        ? clampedExtent > _nearbySheetBlockingOffThreshold
        : clampedExtent > _nearbySheetBlockingOnThreshold;
    _setSheetBlocking(blocking, clampedExtent);

    if (_suppressNearbySurfaceSync) return;
    final activeSurface = _mapUiStateCoordinator.value.contextSurface;
    if (blocking &&
        activeSurface != MapContextSurface.nearby &&
        activeSurface != MapContextSurface.createMarker) {
      if (_mapSearchController.state.isOverlayVisible) {
        _mapSearchController.dismissOverlay();
      }
      _mapUiStateCoordinator.openSurface(
        MapContextSurface.nearby,
        intent: MapSurfaceTransitionIntent.suspendCurrent,
      );
    } else if (!blocking && activeSurface == MapContextSurface.nearby) {
      _closeTemporarySurface(MapContextSurface.nearby);
    }
  }

  void _setSheetBlocking(bool value, double extent) {
    final normalizedExtent = extent.clamp(_nearbySheetMin, _nearbySheetMax);
    final previousExtent = _nearbySheetExtentNotifier.value;
    if ((previousExtent - normalizedExtent).abs() > 0.0001) {
      _nearbySheetExtentNotifier.value = normalizedExtent;
      _syncWebAttributionBottomForSheet(normalizedExtent);
    }

    if (_isSheetBlocking == value) return;
    _safeSetState(() => _isSheetBlocking = value);
  }

  void _syncWebAttributionBottomForSheet(double sheetExtent) {
    if (!kIsWeb || !_mapViewMounted || !mounted) return;
    final media = MediaQuery.maybeOf(context);
    if (media == null) return;
    final viewportHeight = media.size.height;
    if (!viewportHeight.isFinite || viewportHeight <= 1) return;

    final safeBottom = MapOverlaySizing.bottomSafeInset(media);
    final sheetHeight = viewportHeight * sheetExtent;
    final bottomMargin = math
        .max(
          sheetHeight + 12.0,
          safeBottom + 12.0,
        )
        .clamp(12.0, math.max(12.0, viewportHeight - 12.0))
        .toDouble();
    if ((_lastWebAttributionBottomPx - bottomMargin).abs() <= 1.0) return;

    _lastWebAttributionBottomPx = bottomMargin;
    MapAttributionHelper.setMobileMapAttributionBottomPx(bottomMargin);
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

  void _scheduleMarkerOverlayTopPaddingMeasure({
    required bool hasDiscovery,
    required int discoveryTaskCount,
  }) {
    final layoutKey = [
      hasDiscovery ? '1' : '0',
      _mapUiStateCoordinator.value.contextSurface == MapContextSurface.discovery
          ? '1'
          : '0',
      discoveryTaskCount,
      _mapUiStateCoordinator.value.contextSurface == MapContextSurface.filters
          ? '1'
          : '0',
      _mapSearchController.state.isOverlayVisible ? '1' : '0',
      _mapSearchController.state.results.length,
    ].join(':');
    if (_markerOverlayTopPaddingMeasurePending &&
        _pendingMarkerOverlayTopPaddingLayoutKey == layoutKey) {
      return;
    }
    if (!_markerOverlayTopPaddingMeasurePending &&
        _lastMarkerOverlayTopPaddingLayoutKey == layoutKey) {
      return;
    }
    _markerOverlayTopPaddingMeasurePending = true;
    _pendingMarkerOverlayTopPaddingLayoutKey = layoutKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markerOverlayTopPaddingMeasurePending = false;
      _lastMarkerOverlayTopPaddingLayoutKey =
          _pendingMarkerOverlayTopPaddingLayoutKey ?? layoutKey;
      _pendingMarkerOverlayTopPaddingLayoutKey = null;
      if (!mounted) return;

      if (!hasDiscovery) {
        if ((_markerOverlayTopPadding - MapOverlaySizing.defaultVerticalPadding)
                .abs() >
            1.0) {
          _safeSetState(() {
            _markerOverlayTopPadding = MapOverlaySizing.defaultVerticalPadding;
          });
        }
        return;
      }

      final discoveryContext = _discoveryCardKey.currentContext;
      final renderObject = discoveryContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return;
      }

      final media = MediaQuery.of(context);
      final origin = renderObject.localToGlobal(Offset.zero);
      final cardBottom = origin.dy + renderObject.size.height;
      final desiredTopPadding = math.max(
        MapOverlaySizing.defaultVerticalPadding,
        cardBottom - media.padding.top + 8.0,
      );

      if ((_markerOverlayTopPadding - desiredTopPadding).abs() > 1.0) {
        _safeSetState(() {
          _markerOverlayTopPadding = desiredTopPadding;
        });
      }
    });
  }

  void _nextStackedMarker() {
    final stack = _kubusMapController.selectedMarkerStack;
    if (stack.length <= 1) return;
    final next =
        (_kubusMapController.selectedMarkerStackIndex + 1) % stack.length;
    if (_markerStackPageController.hasClients) {
      final motion = KubusMapMotion.fromMediaQuery(
        animationTheme: context.animationTheme,
        mediaQuery: MediaQuery.of(context),
      ).overlayReposition;
      unawaited(_markerStackPageController.animateToPage(
        next,
        duration: motion.duration,
        curve: motion.curve,
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
      final motion = KubusMapMotion.fromMediaQuery(
        animationTheme: context.animationTheme,
        mediaQuery: MediaQuery.of(context),
      ).overlayReposition;
      unawaited(_markerStackPageController.animateToPage(
        prev,
        duration: motion.duration,
        curve: motion.curve,
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

  Future<void> _startMarkerCreationFlow({LatLng? position}) async {
    LatLng? targetPosition = position;
    if (targetPosition == null && _currentPosition == null) {
      await _promptForLocationThenCenter(reason: 'marker_creation');
      if (!mounted) return;
      if (_currentPosition == null) return;
    }
    targetPosition ??= _currentPosition;
    if (targetPosition == null) return;

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

    if (!_mapUiStateCoordinator.beginCreateMarker()) return;
    _kubusMapController.dismissSelection();
    unawaited(_collapseNearbySheetForSurfaceTransition());
    final MapMarkerFormResult? result;
    try {
      result = await MapMarkerDialog.show(
        context: context,
        subjectData: subjectData,
        onRefreshSubjects: ({bool force = false}) =>
            _refreshMarkerSubjectData(force: force),
        initialPosition: targetPosition,
        allowManualPosition: false,
        initialSubjectType: initialSubjectType,
        allowedSubjectTypes: allowedSubjectTypes,
        blockedArtworkIds: _artMarkers
            .where((marker) => (marker.artworkId ?? '').trim().isNotEmpty)
            .map((marker) => marker.artworkId!.trim())
            .toSet(),
      );
    } finally {
      // MapMarkerDialog.show completes only after its route has closed. Keep
      // creation dominant until that point on cancel, success, or failure.
      if (mounted) {
        _mapUiStateCoordinator.closeSurface(MapContextSurface.createMarker);
      }
    }

    if (!mounted || result == null) return;

    final success = await _createMarkerAtPosition(targetPosition, result);

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

  Future<bool> _createMarkerAtPosition(
      LatLng position, MapMarkerFormResult form) async {
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
          source: 'map_screen_create_marker',
          debugLabel: 'MapScreen',
        );
        if (coverImageUrl == null) return false;
      }

      // Snap to the nearest grid cell center at the current zoom level
      // We use the current camera zoom to determine which grid level is most relevant
      final double currentZoom = _lastZoom;
      final requestedPosition = form.positionOverride ?? position;
      final gridCell =
          GridUtils.gridCellForZoom(requestedPosition, currentZoom);
      // Snap to the grid level that is closest to the current zoom
      // This ensures we snap to the grid lines the user is likely seeing
      final LatLng snappedPosition = tileProviders?.snapToVisibleGrid(
            requestedPosition,
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
          if (coverImageUrl != null && coverImageUrl.isNotEmpty)
            'coverImageUrl': coverImageUrl,
          // Attribution (shown in the marker info card below the description).
          if ((form.artistName ?? '').isNotEmpty) 'artistName': form.artistName,
          if ((form.imageAuthor ?? '').isNotEmpty)
            'imageAuthor': form.imageAuthor,
          if ((form.imageLicense ?? '').isNotEmpty)
            'imageLicense': form.imageLicense,
          if ((form.imageAuthor ?? '').isNotEmpty ||
              (form.imageLicense ?? '').isNotEmpty)
            'coverImageAttribution': [
              if ((form.imageAuthor ?? '').isNotEmpty) form.imageAuthor,
              if ((form.imageLicense ?? '').isNotEmpty) form.imageLicense,
            ].join(' / '),
          if (form.isCommunity) ...{
            'isCommunity': true,
            'community': 'community',
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
        _applyVisibleMarkers();
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
      AppConfig.debugPrint('MapScreen: marker creation rejected: $e');
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
            // Already requested permission once; do not re-request repeatedly.
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
    Duration? duration,
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

    final cameraMotion = KubusMapMotion.fromMediaQuery(
      animationTheme: context.animationTheme,
      mediaQuery: MediaQuery.of(context),
    ).clusterExpand;
    await _mapCameraController.animateTo(
      center,
      zoom: targetZoom,
      rotation: targetRotation,
      tilt: targetPitch,
      duration: duration ?? cameraMotion.duration,
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
    unawaited(_syncUserLocation());

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
      basePosition: _currentPosition,
    );
    final discoveryProgress = taskProvider.getOverallProgress();
    final isLoadingArtworks = artworkProvider.isLoading('load_artworks');
    final l10n = AppLocalizations.of(context)!;
    final tutorialBindings = _buildMapTutorialStepBindings(l10n);
    _scheduleMapTutorialConfigure(
      reason: 'build',
      bindings: tutorialBindings,
    );
    _scheduleMapTutorialStartIfEligible(reason: 'build');
    final stack = ValueListenableBuilder<MapUiStateSnapshot>(
      valueListenable: _mapUiStateCoordinator.state,
      builder: (context, ui, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.of(context);
            final sheetExtent = _nearbySheetExtentNotifier.value;
            final sheetHeight = constraints.maxHeight * sheetExtent;
            final safeBottom = MapOverlaySizing.bottomSafeInset(media);
            final double attributionBottomMargin = math
                .max(
                  sheetHeight + 12.0,
                  safeBottom + 12.0,
                )
                .clamp(12.0, math.max(12.0, constraints.maxHeight - 12.0))
                .toDouble();
            _syncWebAttributionBottomForSheet(sheetExtent);
            // Use the strict real-blur policy so the platform backdrop host is
            // mounted on compact/mobile web too (allowCompactWeb disables the
            // host below 700px, which left mobile-web overlays flat).
            final backdropDecision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.forceRealBlur,
              overMapPlatformView: true,
            );
            // Mount the region-sync host for BOTH platform-backed strategies:
            // the web DOM/CSS host and the native iOS Liquid Glass host share
            // the same region tracking + sync widget.
            final platformBackdropHostEnabled = backdropDecision.enabled &&
                (backdropDecision.strategy ==
                        KubusMapBackdropStrategy.platformViewBackdropHost ||
                    backdropDecision.strategy ==
                        KubusMapBackdropStrategy.nativeBackdropHost);
            return PopScope(
              canPop: ui.contextSurface == MapContextSurface.none,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _handleMapContextBack();
              },
              child: KubusMapBackdropScope(
                controller: _mapBackdropHostController,
                child: Stack(
                  children: [
                    KeyedSubtree(
                      key: _tutorialMapKey,
                      child: IgnorePointer(
                        ignoring: _isSheetInteracting,
                        child: _mapViewMounted
                            ? _buildMap(
                                themeProvider,
                                attributionBottomMargin:
                                    attributionBottomMargin,
                              )
                            : const SizedBox.expand(
                                child: ColoredBox(color: Colors.transparent),
                              ),
                      ),
                    ),
                    if (platformBackdropHostEnabled)
                      KubusMapPlatformBackdropHost(
                        controller: _mapBackdropHostController,
                        enabled: true,
                      ),
                    if (_isSheetBlocking || _isSheetInteracting)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ValueListenableBuilder<double>(
                          valueListenable: _nearbySheetExtentNotifier,
                          builder: (context, extent, _) {
                            final blockerHeight =
                                constraints.maxHeight * extent;
                            return SizedBox(
                              height: blockerHeight,
                              child: const AbsorbPointer(
                                absorbing: true,
                                child: SizedBox.expand(),
                              ),
                            );
                          },
                        ),
                      ),
                    if (ui.contextSurface == MapContextSurface.none)
                      _buildPrimaryControls(ui),
                    if (ui.contextSurface == MapContextSurface.none ||
                        ui.contextSurface == MapContextSurface.nearby)
                      _buildBottomSheet(
                        theme,
                        filteredArtworks,
                        discoveryProgress,
                        isLoadingArtworks,
                      ),
                    _buildMobileAttributionButton(),
                    _buildTopOverlays(theme, themeProvider, taskProvider),
                    // Keep marker overlay above map UI chrome (controls/search/sheet)
                    // so the selected marker card remains the top interactive layer.
                    if (ui.contextSurface == MapContextSurface.markerPreview)
                      _buildMarkerOverlay(themeProvider, ui.markerSelection),
                  ],
                ),
              ),
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
  }) {
    final isDark = themeProvider.isDarkMode;
    final tileProviders = Provider.of<TileProviders?>(context, listen: false);
    final styleAsset = tileProviders?.mapStyleAsset(isDarkMode: isDark) ??
        MapStyleService.primaryStyleRef(isDarkMode: isDark);
    // Keep map gestures enabled during normal operation. We block drag-through
    // from the Nearby Art sheet using an AbsorbPointer overlay over the sheet
    // area, rather than disabling map gestures globally.
    final disableGesturesForOverlays = _isSheetInteracting;

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
        rotateGesturesEnabled: !disableGesturesForOverlays,
        scrollGesturesEnabled: !disableGesturesForOverlays,
        zoomGesturesEnabled: !disableGesturesForOverlays,
        tiltGesturesEnabled: !disableGesturesForOverlays,
        compassEnabled: false,
        attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
        attributionButtonMargins: math.Point<double>(
          12.0,
          attributionBottomMargin,
        ),
        webResizeRecoveryToken: _webResizeRecoveryToken,
        onCameraMove: _handleCameraMove,
        onCameraIdle: _handleCameraIdle,
        onMapClick: (dynamic point, _) {
          unawaited(_handleMapTap(point));
        },
        onMapLongClick: (_, point) {
          unawaited(_startMarkerCreationFlow(position: point));
        },
        onMapCreated: (controller) {
          KubusMapLifecycleHelpers.handleMapCreated(
            controller: controller,
            kubusMapController: _kubusMapController,
            setMapController: (value) => _mapController = value,
            setLayersManager: (manager) => _layersManager = manager,
          );

          // Mirror controller state into legacy screen guards while migration is incremental.
          _styleInitialized = _kubusMapController.styleInitialized;
          _styleInitializationInProgress =
              _kubusMapController.styleInitializationInProgress;
          _styleEpoch = _kubusMapController.styleEpoch;
          _mapTargetCoordinator.setMapControllerReady(true);
          _mapTargetCoordinator.setStyleReady(false);
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
              _loadMarkersForCurrentView(force: true).catchError((e) {
                if (kDebugMode) {
                  debugPrint('MapScreen: initial marker load error: $e');
                }
              }),
            );
          } else if (_artMarkers.isEmpty && !_isLoadingMarkers) {
            unawaited(
              _loadMarkersForCurrentView(force: true).catchError((e) {
                if (kDebugMode) {
                  debugPrint('MapScreen: initial marker load error: $e');
                }
              }),
            );
          } else {
            _mapTargetCoordinator.notifyMarkersChanged();
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

  Future<void> _applyIsometricCamera(
      {required bool enabled, bool adjustZoomForScale = false}) async {
    final cameraMotion = KubusMapMotion.fromMediaQuery(
      animationTheme: context.animationTheme,
      mediaQuery: MediaQuery.of(context),
    ).clusterExpand;
    final nextZoom = await _mapCameraController.applyIsometricCamera(
      enabled: enabled,
      center: _cameraCenter,
      zoom: _lastZoom,
      bearing: _lastBearing,
      adjustZoomForScale: adjustZoomForScale,
      duration: cameraMotion.duration,
      queueIfNotReady: false,
    );

    if (adjustZoomForScale) {
      _lastZoom = nextZoom;
    }

    if (!mounted) return;
    unawaited(_renderCoordinator.updateRenderMode());
  }

  void _handleCameraMove(ml.CameraPosition position) {
    if (!mounted || _mapController == null) return;
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
    if (!mounted || _mapController == null) return;
    final wasProgrammatic = _kubusMapController.programmaticCameraMove;
    _kubusMapController.handleCameraIdle(fromProgrammaticMove: wasProgrammatic);
    _cameraIsMoving = _kubusMapController.cameraIsMoving;

    _queueMarkerRefresh(fromGesture: !wasProgrammatic);
    if (_styleInitialized) {
      _queueMarkerVisualRefreshForZoom(_lastZoom);
      unawaited(_renderCoordinator.updateRenderMode());
    }

    // Nearby list filtering may depend on camera center when precise user
    // location is unavailable. When the nearby quick filter is anchored to the
    // camera (no GPS fix), re-apply it so the visible markers track the
    // viewport instead of a stale center.
    if (_filterState.scope == KubusMapScope.nearMe &&
        _currentPosition == null) {
      _applyVisibleMarkers();
      _requestMarkerVisualSync();
    }
    _safeSetState(() {});
  }

  int _clusterGridLevelForZoom(double zoom) =>
      MapScreenConstants.clusterGridLevelForZoom(zoom);

  void _queueMarkerVisualRefreshForZoom(double zoom) {
    final shouldCluster = zoom < _clusterMaxZoom;
    final gridLevel = shouldCluster ? _clusterGridLevelForZoom(zoom) : -1;
    if (shouldCluster == _lastClusterEnabled &&
        gridLevel == _lastClusterGridLevel) {
      return;
    }
    _lastClusterEnabled = shouldCluster;
    _lastClusterGridLevel = gridLevel;
    // The grouping changed: ease the new marker/cluster arrangement in with a
    // soft scale/opacity pop instead of snapping between layouts.
    _kubusMapController.animateMarkerRegroup();
    _requestMarkerVisualSync();
  }

  void _requestMarkerVisualSync({bool force = false}) {
    _markerVisualSyncCoordinator.request(force: force);
  }

  Future<void> _syncMapMarkersSafe({required ThemeProvider themeProvider}) =>
      _markerSyncEngine.syncMarkersSafe(themeProvider: themeProvider);

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

  Future<void> _handleMapTap(
    Object? point,
  ) async {
    await _markerInteractionController.handleMapClick(point);
  }

  Future<void> _syncUserLocation() async {
    await KubusMapSourceSyncHelpers.syncPointSource(
      controller: _mapController,
      styleInitialized: _styleInitialized,
      managedSourceIds: _managedSourceIds,
      sourceId: _locationSourceId,
      featureId: 'me',
      position: _currentPosition,
    );
  }

  Future<void> _syncMapMarkers({required ThemeProvider themeProvider}) =>
      _markerSyncEngine.syncMarkers(themeProvider: themeProvider);

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

  Widget _buildMarkerOverlay(
    ThemeProvider themeProvider,
    MapMarkerSelectionState selection,
  ) {
    final marker = selection.selectedMarker;
    final animationKey = marker == null
        ? const ValueKey<String>('marker_overlay_empty')
        : ValueKey<String>(
            'marker_overlay:selection:${selection.selectionToken}');
    final media = MediaQuery.of(context);
    final mapMotion = KubusMapMotion.fromMediaQuery(
      animationTheme: context.animationTheme,
      mediaQuery: media,
    );
    final dockBottomInset = KubusMapMetrics.resolveMobileMarkerDockBottomInset(
      viewportHeight: media.size.height,
      safeBottom: media.padding.bottom,
      nearbyPeekVisible: false,
    );
    return KubusMapMarkerOverlayShell.build(
      isVisible: marker != null,
      anchorListenable: _selectedMarkerAnchorNotifier,
      contentKey: animationKey,
      onDismiss: _dismissSelectedMarker,
      underlay: _buildMarkerTapRipple(),
      // Do not block map gestures with a full-screen backdrop; it feels like
      // the map "freezes" on marker tap. The card itself uses MapOverlayBlocker.
      blockMapGestures: false,
      dismissOnBackdropTap: false,
      placementStrategy:
          overlay_wrapper.KubusMarkerOverlayPlacementStrategy.bottomDocked,
      widthResolver: (constraints, mediaQuery) {
        return KubusMapMetrics.resolveMarkerPreviewWidth(constraints.maxWidth);
      },
      maxHeightResolver: (constraints, mediaQuery) {
        final available = math.max(
          1.0,
          constraints.maxHeight - dockBottomInset - mediaQuery.padding.top,
        );
        return math.min(
          KubusMapMetrics.resolveMobileMarkerPreviewMaxHeight(mediaQuery),
          available,
        );
      },
      heightResolver: (_, __, maxCardHeight) => maxCardHeight,
      markerOffset: KubusMapMetrics.markerPreviewGap,
      horizontalPadding: KubusMapMetrics.mobileMarkerPreviewInset,
      topPadding: KubusMapMetrics.compactChromeInset,
      bottomPadding: dockBottomInset,
      animation: overlay_wrapper.KubusMarkerOverlayAnimationConfig.fromMotion(
        mapMotion.overlayReposition,
      ),
      transitionMotion: mapMotion.overlayEnter,
      onLayoutResolved: (_) {
        final selectedMarker = selection.selectedMarker;
        if (selectedMarker == null) return;
        if (selection.selectionToken !=
            _kubusMapController.selectionState.selectionToken) {
          return;
        }
        _mapTargetCoordinator.acknowledgeOverlay(selectedMarker.id);
      },
      cardBuilder: (context, layout) {
        return _buildCompactMarkerOverlay(themeProvider, selection, layout);
      },
    );
  }

  Widget _buildMarkerTapRipple() {
    final offset = _markerTapRippleOffset;
    final at = _markerTapRippleAt;
    final color = _markerTapRippleColor;
    if (offset == null || at == null || color == null) {
      return const SizedBox.shrink();
    }
    final selectionMotion = KubusMapMotion.fromMediaQuery(
      animationTheme: context.animationTheme,
      mediaQuery: MediaQuery.of(context),
    ).markerSelect;
    if (!selectionMotion.allowsSpatialTransform) {
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
          duration: selectionMotion.duration,
          curve: selectionMotion.curve,
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

  Widget _buildCompactMarkerOverlay(
    ThemeProvider themeProvider,
    MapMarkerSelectionState selection,
    overlay_wrapper.KubusMarkerOverlayLayoutState layout,
  ) {
    final marker = selection.selectedMarker;
    if (marker == null) return const SizedBox.shrink();

    final stack = selection.stackedMarkers.isNotEmpty
        ? selection.stackedMarkers
        : <ArtMarker>[marker];
    final int stackIndex =
        selection.stackIndex.clamp(0, math.max(0, stack.length - 1));

    void goToStackIndex(int index) {
      if (index < 0 || index >= stack.length) return;
      _handleMarkerStackPageChanged(index);
    }

    KubusMarkerOverlayCard buildCardForMarker(
      ArtMarker pageMarker, {
      required double maxCardHeight,
    }) {
      final pageArtwork = pageMarker.isExhibitionMarker
          ? null
          : context
              .read<ArtworkProvider>()
              .getArtworkById(pageMarker.artworkId ?? '');

      final pagePrimaryExhibition = pageMarker.resolvedExhibitionSummary;
      final pageEvent = KubusMarkerOverlayHelpers.resolveLinkedEvent(
        marker: pageMarker,
        events: context.read<EventsProvider>().events,
      );
      final presentation = resolveMarkerOverlayPresentation(
        marker: pageMarker,
        artwork: pageArtwork,
        event: pageEvent,
      );
      final exhibitionsFeatureEnabled =
          AppConfig.isFeatureEnabled('exhibitions');
      // A stale exhibitionsApiAvailable=false flag must not suppress a marker
      // that carries a valid exhibition id; the open flow retries the fetch
      // and falls back to marker info on a real failure.
      final canPresentExhibition = presentation.primaryTarget ==
              MapMarkerOverlayPrimaryTarget.exhibition &&
          exhibitionsFeatureEnabled &&
          pagePrimaryExhibition != null &&
          pagePrimaryExhibition.id.isNotEmpty;

      final pageDistanceText = KubusMarkerOverlayHelpers.resolveDistanceText(
        userLocation: _currentPosition,
        marker: pageMarker,
        distance: _distanceCalculator,
      );

      final pageBaseColor = _resolveArtMarkerColor(pageMarker, themeProvider);
      final overlayActions = buildMarkerOverlayActions(
        context: context,
        marker: pageMarker,
        artwork: pageArtwork,
        canPresentExhibition: canPresentExhibition,
        baseColor: pageBaseColor,
        sourceScreen: 'map_marker',
        onClaimTap: KubusMarkerOverlayHelpers.canOpenStreetArtClaims(pageMarker)
            ? () {
                unawaited(_openStreetArtClaimsDialog(pageMarker));
              }
            : null,
      );

      void openDetails() {
        unawaited(
          _handleMarkerPrimaryAction(
            pageMarker,
            artwork: pageArtwork,
            exhibition: pagePrimaryExhibition,
            event: pageEvent,
          ),
        );
      }

      return KubusMarkerOverlayHelpers.buildOverlayCard(
        context: context,
        marker: pageMarker,
        artwork: pageArtwork,
        event: pageEvent,
        baseColor: pageBaseColor,
        canPresentExhibition: canPresentExhibition,
        distanceText: pageDistanceText,
        onClose: _dismissSelectedMarker,
        onOpenDetails: openDetails,
        actions: overlayActions,
        stackCount: stack.length,
        stackIndex: stackIndex,
        onNextStacked: stack.length > 1 ? _nextStackedMarker : null,
        onPreviousStacked: stack.length > 1 ? _previousStackedMarker : null,
        onSelectStackIndex: stack.length > 1 ? (i) => goToStackIndex(i) : null,
        onHorizontalDragEnd: stack.length > 1
            ? (details) {
                final velocityX = details.primaryVelocity ??
                    details.velocity.pixelsPerSecond.dx;
                if (!velocityX.isFinite || velocityX.abs() < 120) return;
                if (velocityX < 0) {
                  _nextStackedMarker();
                } else {
                  _previousStackedMarker();
                }
              }
            : null,
        maxCardHeight: maxCardHeight,
        cardPresentation: KubusMarkerOverlayCardPresentation.compactMobile,
      );
    }

    final visibleMarker = stack[stackIndex];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: layout.maxCardHeight,
      ),
      child: RepaintBoundary(
        child: buildCardForMarker(
          visibleMarker,
          maxCardHeight: layout.maxCardHeight,
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

  bool _isCurrentMarkerOpenRequest(ArtMarker marker, int? requestId) {
    if (!mounted) return false;
    if (requestId == null) return true;
    if (requestId != _markerOpenRequestId) return false;
    final selectedMarkerId = _kubusMapController.selectedMarkerId;
    return selectedMarkerId == null || selectedMarkerId == marker.id;
  }

  Future<void> _handleMarkerPrimaryAction(
    ArtMarker marker, {
    Artwork? artwork,
    ExhibitionSummaryDto? exhibition,
    KubusEvent? event,
  }) async {
    final requestId = ++_markerOpenRequestId;
    if (kDebugMode) {
      debugPrint('[marker.tap] start id=${marker.id} type=${marker.type.name}');
    }

    try {
      if (!_isCurrentMarkerOpenRequest(marker, requestId)) return;
      await _openMarkerPrimaryTarget(
        marker,
        artwork: artwork,
        exhibition: exhibition,
        event: event,
        requestId: requestId,
      );
      if (!_isCurrentMarkerOpenRequest(marker, requestId)) return;
      if (kDebugMode) {
        debugPrint('[marker.tap] opened id=${marker.id}');
      }
    } on ProviderNotFoundException catch (error, stack) {
      if (kDebugMode) {
        debugPrint('[marker.tap] ProviderNotFound id=${marker.id}: $error');
        debugPrintStack(stackTrace: stack);
      }
      if (_isCurrentMarkerOpenRequest(marker, requestId)) {
        _showMarkerOpenError();
      }
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('[marker.tap] failed id=${marker.id}: $error');
        debugPrintStack(stackTrace: stack);
      }
      if (_isCurrentMarkerOpenRequest(marker, requestId)) {
        _showMarkerOpenError();
      }
    }
  }

  void _showMarkerOpenError() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = l10n?.commonActionFailedToast ??
        'Could not open marker details. Please try again.';
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(content: Text(message)),
      tone: KubusSnackBarTone.error,
    );
  }

  Widget _buildTopOverlays(
    ThemeData theme,
    ThemeProvider themeProvider,
    TaskProvider? taskProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final discoveryTaskCount =
        taskProvider?.getActiveTaskProgress().length ?? 0;
    final hasDiscovery = discoveryTaskCount > 0;
    final activeSurface = _mapUiStateCoordinator.value.contextSurface;
    final showDiscovery =
        hasDiscovery && mapContextAllowsDiscoveryChrome(activeSurface);
    _scheduleMarkerOverlayTopPaddingMeasure(
      hasDiscovery: showDiscovery,
      discoveryTaskCount: discoveryTaskCount,
    );

    return KubusMapSearchOverlayAssembly(
      controller: _mapSearchController,
      layout: KubusSearchOverlayLayout.topOverlay,
      searchField: _buildSearchCard(),
      accentColor: themeProvider.accentColor,
      minCharsHint: l10n.mapSearchMinCharsHint,
      noResultsText: l10n.mapNoSuggestions,
      onDismiss: _dismissSearchResults,
      onResultTap: (result) {
        unawaited(_handleSearchResultTap(result));
      },
      // The extra content host is ALWAYS mounted so the filter panel keeps a
      // stable parent (matching the nearby art panel / marker info card
      // lifecycle). The panel's own keyed AnimatedSwitcher (see
      // [_buildFilterPanel]) is the single open/close mechanism, so the parent
      // never tears the whole subtree down on close — which previously left the
      // glass/backdrop region to initialize late (looking unblurred) and could
      // leave a ghost sheen/backdrop when the subtree was yanked mid-animation.
      // Section gap is owned here (the scaffold gap is suppressed via
      // sectionGap: 0) so a collapsed panel adds zero height.
      sectionGap: 0,
      extraContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterPanel(theme),
          if (showDiscovery) ...[
            const SizedBox(height: KubusSpacing.sm),
            KeyedSubtree(
              key: _discoveryCardKey,
              child: _buildDiscoveryCard(theme, taskProvider),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMarkerPrimaryTarget(
    ArtMarker marker, {
    Artwork? artwork,
    ExhibitionSummaryDto? exhibition,
    KubusEvent? event,
    required int requestId,
  }) async {
    if (!_isCurrentMarkerOpenRequest(marker, requestId)) return;
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
        await _openExhibitionFromMarker(
          marker,
          exhibition,
          artwork,
          requestId: requestId,
        );
        return;
      case MapMarkerOverlayPrimaryTarget.event:
        await _openEventFromMarker(
          marker,
          resolvedEvent,
          requestId: requestId,
        );
        return;
      case MapMarkerOverlayPrimaryTarget.institution:
        await _openInstitutionFromMarker(
          marker,
          presentation.linkedSubject.id,
          requestId: requestId,
        );
        return;
      case MapMarkerOverlayPrimaryTarget.artwork:
        await _openMarkerDetail(marker, artwork, requestId: requestId);
        return;
      case MapMarkerOverlayPrimaryTarget.markerInfo:
        await _showMarkerInfoFallback(marker, requestId: requestId);
        return;
    }
  }

  Future<void> _openEventFromMarker(
    ArtMarker marker,
    KubusEvent? event, {
    required int requestId,
  }) async {
    final eventId = (event?.id ?? marker.subjectId ?? '').trim();
    if (eventId.isEmpty ||
        !AppConfig.isFeatureEnabled('events') ||
        BackendApiService().eventsApiAvailable == false) {
      await _showMarkerInfoFallback(marker, requestId: requestId);
      return;
    }

    final eventsProvider = context.read<EventsProvider>();
    final navigator = Navigator.of(context);
    final fetched = event ??
        await (() async {
          try {
            return await eventsProvider.fetchEvent(eventId, force: true);
          } catch (_) {
            return null;
          }
        })();

    if (!_isCurrentMarkerOpenRequest(marker, requestId)) return;
    if (fetched == null) {
      await _showMarkerInfoFallback(marker, requestId: requestId);
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(eventId: fetched.id),
      ),
    );
  }

  Future<void> _openInstitutionFromMarker(
    ArtMarker marker,
    String? linkedInstitutionId, {
    required int requestId,
  }) async {
    final institutionId =
        (linkedInstitutionId ?? marker.subjectId ?? '').trim();
    final profileTargetId = InstitutionNavigation.resolveProfileTargetId(
      institutionId: institutionId,
      data: marker.metadata,
    );
    if (institutionId.isEmpty && profileTargetId == null) {
      await _showMarkerInfoFallback(marker, requestId: requestId);
      return;
    }

    if (!_isCurrentMarkerOpenRequest(marker, requestId)) return;
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

  Future<void> _openExhibitionFromMarker(
    ArtMarker marker,
    ExhibitionSummaryDto? exhibition,
    Artwork? artwork, {
    required int requestId,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final exhibitionsProvider = context.read<ExhibitionsProvider>();

    final resolved = exhibition ?? marker.resolvedExhibitionSummary;
    final isExhibitionMarker = marker.isExhibitionMarker;

    if (resolved == null || resolved.id.isEmpty) {
      if (isExhibitionMarker) {
        await _showMarkerInfoFallback(marker, requestId: requestId);
        return;
      }
      await _openMarkerDetail(marker, artwork, requestId: requestId);
      return;
    }

    if (!AppConfig.isFeatureEnabled('exhibitions')) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapExhibitionsUnavailableToast)),
        tone: KubusSnackBarTone.warning,
      );
      setState(() {});
      return;
    }

    if (BackendApiService().exhibitionsApiAvailable == false &&
        !isExhibitionMarker) {
      await _openMarkerDetail(marker, artwork, requestId: requestId);
      return;
    }

    Object? fetchError;
    final fetched = await (() async {
      try {
        return await exhibitionsProvider.fetchExhibition(resolved.id,
            force: true);
      } catch (e) {
        fetchError = e;
        return null;
      }
    })();

    if (!_isCurrentMarkerOpenRequest(marker, requestId)) return;

    if (fetched == null) {
      final serviceUnavailable = fetchError is BackendApiRequestException &&
          ((fetchError as BackendApiRequestException).statusCode == 503 ||
              (fetchError as BackendApiRequestException).statusCode == 502 ||
              (fetchError as BackendApiRequestException).statusCode == 522 ||
              (fetchError as BackendApiRequestException).statusCode == 523 ||
              (fetchError as BackendApiRequestException).statusCode == 524 ||
              (fetchError as BackendApiRequestException).statusCode == 530);
      if (serviceUnavailable) {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.mapExhibitionsUnavailableToast)),
          tone: KubusSnackBarTone.warning,
        );
        setState(() {});
      }
      await _showMarkerInfoFallback(marker, requestId: requestId);
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ExhibitionDetailScreen(
          exhibitionId: resolved.id,
          attendanceMarkerId: marker.id,
          initialExhibition: fetched,
        ),
      ),
    );
  }

  Future<void> _openMarkerDetail(
    ArtMarker marker,
    Artwork? artwork, {
    required int requestId,
  }) async {
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

    if (!_isCurrentMarkerOpenRequest(marker, requestId)) return;

    if (resolvedArtwork == null) {
      await _showMarkerInfoFallback(marker, requestId: requestId);
      return;
    }

    final artworkToOpen = resolvedArtwork;
    if (!mounted) return;
    await openArtwork(
      context,
      artworkToOpen.id,
      source: 'map_marker',
      attendanceMarkerId: marker.id,
    );
  }

  Future<void> _showMarkerInfoFallback(
    ArtMarker marker, {
    int? requestId,
  }) async {
    if (!_isCurrentMarkerOpenRequest(marker, requestId)) return;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.read<ThemeProvider>();
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheWidth = (640 * dpr).clamp(256.0, 1600.0).round();
    final cacheHeight = (360 * dpr).clamp(144.0, 1200.0).round();
    final coverUrl = MediaUrlResolver.resolveDisplayUrl(
      ArtworkMediaResolver.resolveCover(
        metadata: marker.metadata,
      ),
      maxWidth: cacheWidth,
    );

    if (!_mapUiStateCoordinator.openMarkerDetails()) return;
    try {
      final overlayExitMotion = KubusMapMotion.fromMediaQuery(
        animationTheme: context.animationTheme,
        mediaQuery: MediaQuery.of(context),
      ).overlayEnter;
      await KubusMapSurfaceTransitionHelpers.awaitOverlayExit(
        overlayExitMotion,
      );
      if (!mounted ||
          _mapUiStateCoordinator.value.contextSurface !=
              MapContextSurface.markerDetails) {
        return;
      }
      await showKubusDialog<void>(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => KubusAlertDialog(
          backgroundColor: scheme.surface,
          title: Text(
            marker.subjectTitle?.trim().isNotEmpty == true
                ? marker.subjectTitle!.trim()
                : marker.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KubusTypography.outfit(
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
                          marker,
                          themeProvider,
                        ),
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
                        : l10n.mapNoLinkedArtworkForMarker,
                    maxLines: 12,
                    overflow: TextOverflow.ellipsis,
                    style:
                        KubusTypography.outfit(color: scheme.onSurfaceVariant),
                  ),
                ),
                // Artist / photo / source attribution, below the description.
                MarkerAttributionSection.fromMarker(marker),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      );
    } finally {
      if (mounted &&
          _mapUiStateCoordinator.value.contextSurface ==
              MapContextSurface.markerDetails) {
        _mapUiStateCoordinator.backFromMarkerDetails();
      }
    }
  }

  Widget _buildSearchCard() {
    final l10n = AppLocalizations.of(context)!;
    final hintColor = Theme.of(context).colorScheme.onSurfaceVariant;
    // Slightly taller, more tappable search bar on small screens.
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final fieldHeight =
        isCompact ? KubusHeaderMetrics.searchBarHeight + 6 : null;
    return KubusGeneralSearch(
      controller: _mapSearchController,
      hintText: l10n.mapSearchHint,
      semanticsLabel: l10n.mapSearchHint,
      enableBlur: kubusMapBlurEnabled(context),
      useMapGlassSurface: true,
      height: fieldHeight,
      onSubmitted: (_) => _mapSearchController.onSubmitted(),
      trailingBuilder: (context, query) {
        if (query.trim().isNotEmpty) {
          return IconButton(
            tooltip: l10n.mapClearSearchTooltip,
            icon: Icon(Icons.close, color: hintColor),
            onPressed: () =>
                _mapSearchController.clearQueryWithContext(context),
          );
        }

        return _buildSearchFilterToggle(l10n, hintColor);
      },
    );
  }

  /// Compact filter toggle for the search bar: a small visual glass button
  /// (~34px) inside an accessible 44px tap target, with a clear active state.
  /// The visible button no longer fills the whole hit area, so it stops
  /// dominating the search field while staying easy to tap.
  Widget _buildSearchFilterToggle(AppLocalizations l10n, Color hintColor) {
    final scheme = Theme.of(context).colorScheme;
    final accent = context.read<ThemeProvider>().accentColor;
    final active = _mapUiStateCoordinator.value.contextSurface ==
        MapContextSurface.filters;
    const double hit = KubusHeaderMetrics.actionHitArea; // 44 — tap target
    const double visual = 34; // smaller visible button
    final radius = BorderRadius.circular(KubusRadius.sm);
    final activeFilterCount = _filterState.activeFilterCount;

    return Tooltip(
      message: active ? l10n.mapHideFiltersTooltip : l10n.mapShowFiltersTooltip,
      preferBelow: false,
      verticalOffset: 18,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Semantics(
        button: true,
        selected: active,
        label: activeFilterCount == 0
            ? l10n.mapFiltersTitle
            : l10n.mapFilterActiveCountLabel(activeFilterCount),
        child: SizedBox(
          width: hit,
          height: hit,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: _tutorialFilterButtonKey,
              borderRadius: BorderRadius.circular(hit / 2),
              onTap: () {
                if (active) {
                  _closeTemporarySurface(MapContextSurface.filters);
                } else {
                  _openTemporarySurface(MapContextSurface.filters);
                  _scheduleFilterPanelBackdropSync();
                }
              },
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    SizedBox(
                      width: visual,
                      height: visual,
                      child: buildKubusMapGlassSurface(
                        context: context,
                        kind: KubusMapGlassSurfaceKind.button,
                        overlayName: 'map-filter-toggle',
                        borderRadius: radius,
                        tintBase:
                            active ? accent : scheme.surfaceContainerHighest,
                        padding: EdgeInsets.zero,
                        child: Center(
                          child: Icon(
                            active ? Icons.filter_alt_off : Icons.filter_alt,
                            size: KubusHeaderMetrics.actionIcon - 2,
                            color: active ? accent : hintColor,
                          ),
                        ),
                      ),
                    ),
                    if (activeFilterCount > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: ExcludeSemantics(
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$activeFilterCount',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.onPrimary),
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
      ),
    );
  }

  Future<void> _handleSearchResultTap(KubusSearchResult result) async {
    _mapSearchController.commitSelection(result.label);
    FocusScope.of(context).unfocus();

    if (result.position != null) {
      unawaited(
        _kubusMapController.animateTo(
          result.position!,
          zoom: math.max(_lastZoom, 16.0),
        ),
      );
    }

    if (!mounted) return;
    if (result.kind == KubusSearchResultKind.artwork && result.id != null) {
      // Find an existing marker for this artwork, or create a temporary one
      // so the floating info card can be shown instead of immediately navigating.
      final marker = _findOrCreateMarkerForArtwork(
        result.id!,
        result.position,
        result.label,
      );
      if (marker != null) {
        _handleMarkerTap(marker);
        return;
      }
      // Fallback: open detail screen directly if no marker found
      await openArtwork(context, result.id!, source: 'map_search');
      return;
    }

    if (result.kind == KubusSearchResultKind.profile && result.id != null) {
      await UserProfileNavigation.open(context, userId: result.id!);
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
        result.kind == KubusSearchResultKind.event ||
        result.kind == KubusSearchResultKind.exhibition;
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

  /// Finds an existing marker for the artwork, or creates a temporary one
  /// using artwork data from the provider (if available).
  ArtMarker? _findOrCreateMarkerForArtwork(
    String artworkId,
    LatLng? suggestionPosition,
    String? fallbackName,
  ) {
    final artworkProvider = context.read<ArtworkProvider>();
    final artwork = artworkProvider.getArtworkById(artworkId);
    final existing = resolveBestMarkerCandidate(
      _artMarkers,
      artworkId: artworkId,
      preferredPosition: suggestionPosition ??
          (artwork?.hasValidLocation == true ? artwork!.position : null),
    );
    if (existing != null) return existing;

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

    // Add to the markers list so it can be selected. Route through the shared
    // filter pipeline (not raw setMarkers) so the active quick filter / search
    // keeps applying; the temp marker itself is pinned by _computeVisibleMarkers
    // so a restrictive filter cannot hide it before selection completes.
    setState(() {
      _artMarkers = List<ArtMarker>.from(_artMarkers)..add(tempMarker);
    });
    _applyVisibleMarkers();

    return tempMarker;
  }

  /// Stable map-overlay filter panel.
  ///
  /// This shares the lifecycle and glass language of the working nearby art
  /// panel and marker info cards:
  /// - it is always present in the layout and animates its own open/close via a
  ///   keyed [AnimatedSwitcher], so toggling never leaves stale glass/sheen and
  ///   the panel is torn down cleanly on close;
  /// - it routes through [KubusFilterPanel.useMapGlassSurface] with the default
  ///   blur policy and platform backdrop region enabled, letting the centralized
  ///   [resolveKubusMapBlurDecision] decide the surface (mobile native MapLibre
  ///   gets the safe sheen/tint fallback, desktop/web get real/platform blur
  ///   where safe, unsafe WebGL/Firefox falls back). The call site no longer
  ///   hard-disables blur.
  Widget _buildFilterPanel(ThemeData theme) {
    final animation = context.animationTheme;
    final panelMotion = KubusMapMotion.fromMediaQuery(
      animationTheme: animation,
      mediaQuery: MediaQuery.of(context),
    ).panelEnter;
    return AnimatedSwitcher(
      duration: panelMotion.duration,
      switchInCurve: panelMotion.curve,
      switchOutCurve: panelMotion.curve,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(
          sizeFactor: anim,
          // Anchor the reveal to the top edge so the panel grows downward from
          // the search bar for a vertical size transition.
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
      child: _mapUiStateCoordinator.value.contextSurface ==
              MapContextSurface.filters
          ? KeyedSubtree(
              key: const ValueKey<String>('map_filter_panel_open'),
              // The gap to the search bar lives inside the animated child so the
              // collapsed state contributes zero height (no permanent gap below
              // the search bar) while the open state animates gap + card as one.
              child: Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.sm),
                child: _buildFilterPanelCard(theme),
              ),
            )
          : const SizedBox.shrink(
              key: ValueKey<String>('map_filter_panel_closed'),
            ),
    );
  }

  /// Forces the platform backdrop region tracker to re-measure the filter panel
  /// after its open animation settles.
  ///
  /// The web platform backdrop host syncs DOM regions from a post-frame
  /// callback during widget build. While the panel is animating in via the
  /// [AnimatedSwitcher]'s [SizeTransition], the panel's render box is not yet at
  /// its final size and the subtree is not rebuilt, so the region would
  /// otherwise stay stale (looking unblurred) until an unrelated interaction
  /// triggered a rebuild. A short post-animation rebuild re-runs the tracker at
  /// the final size. No-op on mobile/desktop, where the panel uses the
  /// sheen/tint fallback (no DOM backdrop region).
  void _scheduleFilterPanelBackdropSync() {
    if (!kIsWeb) return;
    final settle =
        context.animationTheme.medium + const Duration(milliseconds: 32);
    Future.delayed(settle, () {
      if (!mounted ||
          _mapUiStateCoordinator.value.contextSurface !=
              MapContextSurface.filters) {
        return;
      }
      setState(() {});
    });
  }

  /// Re-measures the Discovery Path card's platform backdrop region across its
  /// open/close size animation so the web DOM blur tracks the card instead of
  /// lagging behind. No-op off web (native uses a real BackdropFilter that
  /// follows the size automatically).
  void _scheduleDiscoveryBackdropSync() {
    if (!kIsWeb) return;
    final medium = context.animationTheme.medium;
    void resync() {
      if (!mounted) return;
      setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => resync());
    Future.delayed(medium ~/ 2, resync);
    Future.delayed(medium + const Duration(milliseconds: 32), resync);
  }

  Widget _buildFilterPanelCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    // The mobile filter panel lives in the top-overlay column, which sits in a
    // `Positioned` with only top/left/right — i.e. it has no bounded height. Cap
    // the panel so its internal SingleChildScrollView actually scrolls (by touch
    // drag / wheel) instead of growing past the viewport. Room is reserved above
    // for the search field + quick-filter chips and below for the nearby sheet.
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.padding.top - media.padding.bottom;
    final maxAllowed = math.max(1.0, available * 0.7);
    final minAllowed = math.min(220.0, maxAllowed);
    final maxPanelHeight =
        (available - 220).clamp(minAllowed, maxAllowed).toDouble();

    return KubusFilterPanel(
      title: l10n.mapFiltersTitle,
      onClose: () => _closeTemporarySurface(MapContextSurface.filters),
      closeTooltip: l10n.commonClose,
      margin: EdgeInsets.zero,
      maxHeight: maxPanelHeight,
      contentPadding: const EdgeInsets.all(KubusSpacing.md),
      headerPadding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.md,
        0,
      ),
      borderRadius: KubusRadius.lg,
      showHeaderDivider: false,
      titleStyle: KubusTypography.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      useMapGlassSurface: true,
      backdropRegionId: 'map-filter-panel',
      child: KubusMapFilterContent(
        state: _filterState,
        onChanged: _handleFilterStateChanged,
        travelScopeEnabled: AppConfig.isFeatureEnabled('mapTravelMode'),
      ),
    );
  }

  Widget _buildDiscoveryCard(ThemeData theme, TaskProvider? taskProvider) {
    if (taskProvider == null) return const SizedBox.shrink();
    final activeProgress = taskProvider.getActiveTaskProgress();
    final scheme = theme.colorScheme;
    final overall = taskProvider.getOverallProgress();
    return KubusMapDiscoveryCardHelpers.build(
      activeProgress: activeProgress,
      overallProgress: overall,
      expanded: _mapUiStateCoordinator.value.contextSurface ==
          MapContextSurface.discovery,
      onToggleExpanded: () {
        if (_mapUiStateCoordinator.value.contextSurface ==
            MapContextSurface.discovery) {
          _closeTemporarySurface(MapContextSurface.discovery);
        } else {
          _openTemporarySurface(MapContextSurface.discovery);
        }
        // The card keeps a constant-radius blur mounted and only animates its
        // size. On web the DOM backdrop region otherwise lags the size
        // animation (blur fades in/out late), so re-measure it across the
        // open/close. No-op off web.
        _scheduleDiscoveryBackdropSync();
      },
      buildTaskRow: _buildTaskProgressRow,
      titleStyle: KubusTypography.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      percentStyle: KubusTextStyles.sectionSubtitle.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      glassPadding: _mapUiStateCoordinator.value.contextSurface ==
              MapContextSurface.discovery
          ? const EdgeInsets.all(KubusSpacing.md)
          : const EdgeInsets.symmetric(
              horizontal: KubusSpacing.md,
              vertical: KubusSpacing.xs,
            ),
      expandButtonSize: KubusHeaderMetrics.actionHitArea,
      badgeGap: KubusSpacing.sm + KubusSpacing.xxs,
      tasksTopGap: KubusSpacing.sm + KubusSpacing.xxs,
      compactWhenCollapsed: true,
    );
  }

  Widget _buildTaskProgressRow(TaskProgress progress) {
    return KubusMapTaskProgressRow.build(context: context, progress: progress);
  }

  Widget _buildPrimaryControls(MapUiStateSnapshot ui) {
    final l10n = AppLocalizations.of(context)!;
    final hasSecondaryTools = AppConfig.isFeatureEnabled('mapTravelMode') ||
        AppConfig.isFeatureEnabled('mapIsometricView');
    // Keep controls clear of the discovery module and the nearby sheet.
    // Smaller bottom offset moves controls slightly down.
    final bottomOffset = KubusMapMetrics.resolveMobileNearbyPeekHeight(
          MediaQuery.sizeOf(context).height,
        ) +
        KubusLayout.mainBottomNavBarHeight;
    return Positioned(
      right: KubusSpacing.md - KubusSpacing.xxs,
      bottom: bottomOffset,
      child: MapOverlayBlocker(
        child: KubusMapControls(
          controller: _kubusMapController,
          layout: KubusMapPrimaryControlsLayout.mobileRightRail,
          onCenterOnMe: () => unawaited(_handleCenterOnMeTap()),
          onCreateMarker: () => unawaited(_handleCurrentLocationTap()),
          centerOnMeActive: _autoFollow,
          resetBearingTooltip: l10n.mapResetBearingTooltip,
          centerOnMeKey: _tutorialCenterButtonKey,
          centerOnMeTooltip: l10n.mapCenterOnMeTooltip,
          createMarkerKey: _tutorialAddMarkerButtonKey,
          createMarkerTooltip: l10n.mapAddMapMarkerTooltip,
          createMarkerHighlighted:
              ui.contextSurface == MapContextSurface.createMarker,
          buttonSize: KubusMapMetrics.mobileControlSize,
          showZoomControls: false,
          showSecondaryTools: hasSecondaryTools,
          onOpenSecondaryTools: _openMobileMapTools,
          secondaryToolsKey: _tutorialTravelButtonKey,
          secondaryToolsTooltip: l10n.mapToolsTitle,
          showTravelModeToggle: false,
          travelModeKey: _tutorialTravelButtonKey,
          travelModeActive: _travelModeEnabled,
          onToggleTravelMode: () {
            unawaited(_setTravelModeEnabled(!_travelModeEnabled));
          },
          travelModeTooltipWhenActive: l10n.mapTravelModeDisableTooltip,
          travelModeTooltipWhenInactive: l10n.mapTravelModeEnableTooltip,
          showIsometricViewToggle: false,
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

  void _openMobileMapTools() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final showTravel = AppConfig.isFeatureEnabled('mapTravelMode');
    final showIsometric = AppConfig.isFeatureEnabled('mapIsometricView');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.md),
            child: buildKubusMapGlassSurface(
              context: sheetContext,
              kind: KubusMapGlassSurfaceKind.panel,
              borderRadius: BorderRadius.circular(KubusRadius.lg),
              tintBase: scheme.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.sm,
                vertical: KubusSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.sm,
                    ),
                    child: Text(
                      l10n.mapToolsTitle,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  if (showTravel)
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.travel_explore),
                      title: Text(l10n.mapTravelModeTooltip),
                      value: _travelModeEnabled,
                      onChanged: (enabled) {
                        unawaited(_setTravelModeEnabled(enabled));
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  if (showIsometric)
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.view_in_ar_outlined),
                      title: Text(
                        _isometricViewEnabled
                            ? l10n.mapIsometricViewDisableTooltip
                            : l10n.mapIsometricViewEnableTooltip,
                      ),
                      value: _isometricViewEnabled,
                      onChanged: (enabled) {
                        unawaited(_setIsometricViewEnabled(enabled));
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileAttributionButton() {
    return Positioned(
      left: KubusSpacing.md - KubusSpacing.xxs,
      bottom: 0,
      child: ValueListenableBuilder<double>(
        valueListenable: _nearbySheetExtentNotifier,
        builder: (context, sheetExtent, _) {
          final media = MediaQuery.of(context);
          final viewportHeight = media.size.height;
          final safeBottom = MapOverlaySizing.bottomSafeInset(media);
          final sheetHeight = viewportHeight * sheetExtent;
          final bottomInset = math
              .max(
                sheetHeight + 12.0,
                safeBottom + 12.0,
              )
              .clamp(12.0, math.max(12.0, viewportHeight - 12.0))
              .toDouble();

          return AnimatedPadding(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            // Tuck the attribution button just above the Nearby Art sheet edge
            // (it tracks the sheet's extent) instead of floating a full
            // button-height above it.
            padding: EdgeInsets.only(
              bottom: bottomInset + KubusSpacing.sm,
            ),
            child: MapOverlayBlocker(
              child: KubusGlassIconButton(
                icon: Icons.info_outline,
                tooltip: 'Map attributions',
                borderRadius: KubusRadius.sm,
                iconColor: Theme.of(context).colorScheme.primary,
                enableBlur: kubusMapBlurEnabled(context),
                onPressed: () =>
                    unawaited(showKubusMapAttributionDialog(context)),
              ),
            ),
          );
        },
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
      child: Padding(
        // Nearby remains a peek above the persistent mobile navigation rather
        // than being partially covered by it at short heights.
        padding: const EdgeInsets.only(
          bottom: KubusLayout.mainBottomNavBarHeight,
        ),
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            _handleSheetExtentNotification(notification.extent);
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            // The collapsed sheet is deliberately compact; its outer padding
            // keeps the peek fully above the persistent navigation bar.
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
                onExpand: () {
                  if (!_sheetController.isAttached) return;
                  final motion = KubusMapMotion.fromMediaQuery(
                    animationTheme: context.animationTheme,
                    mediaQuery: MediaQuery.of(context),
                  ).panelEnter;
                  _openTemporarySurface(
                    MapContextSurface.nearby,
                    collapseNearby: false,
                  );
                  unawaited(
                    _sheetController.animateTo(
                      0.50,
                      duration: motion.duration,
                      curve: motion.curve,
                    ),
                  );
                },
                scrollController: scrollController,
                onInteractingChanged: _setSheetInteracting,
              );
            },
          ),
        ),
      ),
    );
    return sheet;
  }

  String _markerQueryFiltersKey() {
    final query = _mapSearchController.state.query.trim().toLowerCase();
    return '${_filterState.queryFingerprint}|query=$query';
  }

  /// Applies the active quick filter / search / radius to the raw loaded marker
  /// set and pushes the resulting visible markers into the shared controller.
  ///
  /// The controller drives both the rendered marker icons and clustering, so
  /// filtering here is what actually changes the visible map (and therefore the
  /// clusters built from the filtered set).
  void _applyVisibleMarkers() {
    _kubusMapController.setMarkers(_computeVisibleMarkers());
  }

  List<ArtMarker> _computeVisibleMarkers() {
    final artworkProvider = context.read<ArtworkProvider>();
    Artwork? artworkFor(ArtMarker marker) {
      final id = marker.artworkId;
      if (id == null || id.isEmpty) return null;
      return artworkProvider.getArtworkById(id);
    }

    final selectedId = _kubusMapController.selectedMarkerId;
    // Pin the selection and any temporary search-navigation markers so an
    // active quick filter can never hide the marker the user just asked for.
    final pinnedIds = <String>{
      if (selectedId != null) selectedId,
      if (_directTargetMarkerId != null) _directTargetMarkerId!,
      for (final marker in _artMarkers)
        if (marker.id.startsWith('search_temp_')) marker.id,
    };
    return filterVisibleMapMarkers(
      markers: _artMarkers,
      context: KubusMapFilterContext(
        state: _filterState,
        query: _mapSearchController.state.query,
        basePosition: _currentPosition,
      ),
      isDiscovered: (marker) => artworkFor(marker)?.isDiscovered ?? false,
      isFavorite: (marker) {
        final artwork = artworkFor(marker);
        if (artwork == null) return false;
        return artwork.isFavoriteByCurrentUser || artwork.isFavorite;
      },
      isArCapable: (marker) =>
          defaultMarkerIsArCapable(marker) ||
          (artworkFor(marker)?.arEnabled ?? false),
      alwaysIncludeMarkerIds: pinnedIds.isEmpty ? null : pinnedIds,
    );
  }

  List<Artwork> _filterArtworks(
    List<Artwork> artworks, {
    LatLng? basePosition,
  }) {
    return MapArtworkFiltering.filter(
      artworks: artworks,
      markers: _artMarkers,
      context: KubusMapFilterContext(
        state: _filterState,
        query: _mapSearchController.state.query,
        basePosition: basePosition,
      ),
    );
  }

  bool _markersEquivalent(List<ArtMarker> current, List<ArtMarker> next) {
    return KubusMapMarkerHelpers.markersEquivalent(current, next);
  }
}

// (Marker clustering and icon pre-registration helpers moved to
// `lib/widgets/map/kubus_map_marker_rendering.dart`.)
