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
import '../widgets/inline_progress.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
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
import '../services/task_service.dart';
import '../services/ar_integration_service.dart';
import '../services/map_marker_service.dart';
import '../services/push_notification_service.dart';
import '../services/map_attribution_helper.dart';
import '../core/app_route_observer.dart';
import '../models/art_marker.dart';
import '../widgets/art_marker_cube.dart';
import '../widgets/map_marker_style_config.dart';
import '../widgets/artwork_creator_byline.dart';
import '../utils/artwork_navigation.dart';
import 'community/user_profile_screen.dart';
import '../utils/grid_utils.dart';
import '../utils/artwork_media_resolver.dart';
import '../utils/category_accent_color.dart';
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
import '../utils/map_marker_icon_ids.dart';
import '../utils/map_tap_gating.dart';
import '../utils/presence_marker_visit.dart';
import '../utils/geo_bounds.dart';
import '../widgets/map_marker_dialog.dart';
import '../providers/tile_providers.dart';
import '../widgets/art_map_view.dart';
import 'dart:ui' as ui;
import '../services/search_service.dart';
import '../services/backend_api_service.dart';
import '../services/map_data_controller.dart';
import '../services/map_style_service.dart';
import '../config/config.dart';
import '../utils/maplibre_style_utils.dart';
import '../utils/marker_cube_geometry.dart';
import 'events/exhibition_detail_screen.dart';
import '../widgets/glass_components.dart';
import '../widgets/kubus_snackbar.dart';
import '../widgets/map_overlay_blocker.dart';
import '../widgets/tutorial/interactive_tutorial_overlay.dart';
import '../widgets/marker_overlay_card.dart';

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
  bool _autoFollow = true;
  double? _direction; // Compass direction
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<LocationData>? _mobileLocationSubscription;
  StreamSubscription<Position>? _webPositionSubscription;
  bool _mobileLocationStreamStarted = false;
  bool _mobileLocationStreamFailed = false;
  bool _programmaticCameraMove = false;
  double _lastBearing = 0.0;
  double _lastPitch = 0.0;
  final ValueNotifier<double> _bearingDegrees = ValueNotifier<double>(0.0);
  DateTime _lastCameraUpdateTime = DateTime.now();
  static const Duration _cameraUpdateThrottle =
      Duration(milliseconds: 16); // ~60fps
  bool _styleInitialized = false;
  bool _styleInitializationInProgress = false;
  bool _hitboxLayerReady = false;
  int _styleEpoch = 0;
  int _hitboxLayerEpoch = -1;
  final Set<String> _registeredMapImages = <String>{};
  final Set<String> _managedLayerIds = <String>{};
  final Set<String> _managedSourceIds = <String>{};
  double _lastWebAttributionBottomPx = -1;
  static const String _markerSourceId = 'kubus_markers';
  static const String _markerLayerId = 'kubus_marker_layer';
  static const String _markerHitboxLayerId = 'kubus_marker_hitbox_layer';
  static const String _markerHitboxImageId = 'kubus_hitbox_square_transparent'; // Transparent square for hitbox
  static const String _cubeSourceId = 'kubus_marker_cubes';
  static const String _cubeLayerId = 'kubus_marker_cubes_layer';
  static const String _cubeIconLayerId = 'kubus_marker_cubes_icon_layer';
  static const String _locationSourceId = 'kubus_user_location';
  static const String _locationLayerId = 'kubus_user_location_layer';
  static const double _cubePitchThreshold = 5.0;
  bool _cubeLayerVisible = false;

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
  String? _selectedMarkerId;
  ArtMarker? _selectedMarkerData;
  List<ArtMarker> _selectedMarkerStack = []; // All markers at the same coordinate
  int _selectedMarkerStackIndex = 0; // Current index in the stack
  DateTime? _selectedMarkerAt;
  String? _selectedMarkerViewportSignature;
  Offset? _markerTapRippleOffset;
  DateTime? _markerTapRippleAt;
  Color? _markerTapRippleColor;
  final ValueNotifier<Offset?> _selectedMarkerAnchorNotifier =
      ValueNotifier<Offset?>(null);
  final Debouncer _overlayAnchorDebouncer = Debouncer();
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
  final Debouncer _markerRefreshDebouncer = Debouncer();
  bool _isMapTabVisible = true;
  bool _isAppForeground = true;
  bool _isRouteVisible = true;
  bool _mapViewMounted = true;
  PageRoute<dynamic>? _subscribedRoute;
  bool _pendingMarkerRefresh = false;
  bool _pendingMarkerRefreshForce = false;

  // UI State
  bool _isSearching = false;
  bool _isFetchingSuggestions = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<MapSearchSuggestion> _searchSuggestions = [];
  final SearchService _searchService = SearchService();

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
  _ArtworkSort _sort = _ArtworkSort.nearest;
  bool _useGridLayout = false;
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

  bool _showMapTutorial = false;
  int _mapTutorialIndex = 0;

  // Discovery and Progress
  bool _isDiscoveryExpanded = false;
  bool _filtersExpanded = false;

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
  double _cubeIconBobOffsetEm = 0.0;
  int _lastMarkerLayerStyleUpdateMs = 0;
  bool _markerLayerStyleUpdateInFlight = false;
  bool _markerLayerStyleUpdateQueued = false;

  final GlobalKey _mapViewKey = GlobalKey();
  bool? _lastAppliedMapThemeDark;
  bool _themeResyncScheduled = false;

  static const double _clusterMaxZoom = 12.0;
  static const int _markerVisualSyncThrottleMs = 60;
  int _lastClusterGridLevel = -1;
  bool _lastClusterEnabled = false;
  bool _markerVisualSyncInFlight = false;
  bool _markerVisualSyncQueued = false;
  int _lastMarkerVisualSyncMs = 0;

  // Camera helpers
  LatLng _cameraCenter = const LatLng(46.056946, 14.505751);
  double _lastZoom = 16.0;

  final Distance _distanceCalculator = const Distance();
  LatLng? _lastMarkerFetchCenter;
  DateTime? _lastMarkerFetchTime;
  GeoBounds? _loadedTravelBounds;
  int? _loadedTravelZoomBucket;
  static const double _markerRefreshDistanceMeters =
      1200; // Increased to reduce API calls
  static const Duration _markerRefreshInterval =
      Duration(minutes: 5); // Increased from 150s to 5 min
  bool _isLoadingMarkers = false; // Tracks the latest marker request
  int _markerRequestId = 0;

  /// NOTE: Do not cache a BuildContext-backed loader as a field/getter.
  /// Timer/async callbacks can outlive this State, and reading providers via a
  /// deactivated context triggers "Looking up a deactivated widget's ancestor".
  MarkerSubjectLoader _createSubjectLoader() => MarkerSubjectLoader(context);

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (_isBuilding) {
      if (_pendingSafeSetState) return;
      _pendingSafeSetState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingSafeSetState = false;
        if (!mounted || _isBuilding) return;
        _perf.recordSetState('safeSetState(postFrame)');
        setState(fn);
      });
      return;
    }
    _perf.recordSetState('safeSetState');
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
      final nextZoom = math.min(_lastZoom + 2.0, 18.0);
      unawaited(
        _animateMapTo(
          LatLng(coordinates.latitude, coordinates.longitude),
          zoom: nextZoom,
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
    _managedLayerIds.clear();
    _managedSourceIds.clear();

    AppConfig.debugPrint('MapScreen: style init start');

    try {
      final Set<String> existingLayerIds = <String>{};
      try {
        final raw = await controller.getLayerIds();
        for (final id in raw) {
          if (id is String) existingLayerIds.add(id);
        }
      } catch (_) {}

      Future<void> safeRemoveLayer(String id) async {
        if (!existingLayerIds.contains(id)) return;
        try {
          await controller.removeLayer(id);
        } catch (_) {}
        existingLayerIds.remove(id);
      }

      Future<void> safeRemoveSource(String id) async {
        try {
          await controller.removeSource(id);
        } catch (_) {}
      }

      await safeRemoveLayer(_markerLayerId);
      await safeRemoveLayer(_markerHitboxLayerId);
      await safeRemoveLayer(_cubeLayerId);
      await safeRemoveLayer(_cubeIconLayerId);
      await safeRemoveSource(_markerSourceId);
      await safeRemoveSource(_cubeSourceId);
      await safeRemoveLayer(_locationLayerId);
      await safeRemoveSource(_locationSourceId);

      await controller.addGeoJsonSource(
        _markerSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[],
        },
        promoteId: 'id',
      );
      _managedSourceIds.add(_markerSourceId);

      await controller.addGeoJsonSource(
        _cubeSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[],
        },
        promoteId: 'id',
      );
      _managedSourceIds.add(_cubeSourceId);

      // Layer order (bottom to top):
      // 1. Fill-extrusion (3D cube)
      // 2. Marker symbol layer (2D icons)
      // 3. Cube icon layer (3D mode floating icons)
      // 4. Hitbox circle layer (TOPMOST for click detection)

      // 1. Fill-extrusion layer for 3D cube (solid, no bevel/inset styling)
      await controller.addFillExtrusionLayer(
        _cubeSourceId,
        _cubeLayerId,
        ml.FillExtrusionLayerProperties(
          fillExtrusionColor: <Object>['get', 'color'],
          fillExtrusionHeight: <Object>['get', 'height'],
          fillExtrusionBase: 0.0,
          fillExtrusionOpacity: 0.95,
          fillExtrusionVerticalGradient: false,
          visibility: 'none',
        ),
      );
      _managedLayerIds.add(_cubeLayerId);

      // 2. Main marker symbol layer for 2D icons
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
      _managedLayerIds.add(_markerLayerId);

      // 3. Cube floating icon layer (above fill-extrusion, same icons as marker layer)
      await controller.addSymbolLayer(
        _markerSourceId,
        _cubeIconLayerId,
        ml.SymbolLayerProperties(
          iconImage: <Object>['get', 'icon'],
          iconSize:
              MapMarkerStyleConfig.iconSizeExpression(constantScale: 0.92),
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
      _managedLayerIds.add(_cubeIconLayerId);

      // 4. Invisible square hitbox layer (topmost) for consistent tap detection.
      // Uses a transparent square image with zoom-dependent scaling.
      // Square hitbox is more reliable than circles for UI interaction.
      try {
        // Register the transparent square image if not already done
        final hitboxImageBytes = _createTransparentSquareImage();
        await controller.addImage(_markerHitboxImageId, hitboxImageBytes);
        _registeredMapImages.add(_markerHitboxImageId);
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint('MapScreen: hitbox image registration failed: $e');
        }
      }

      // Define zoom-dependent icon sizes for the hitbox square (in pixels).
      // Clusters get larger hitbox; individual markers smaller.
      final Object hitboxIconSize = kIsWeb
          ? 60.0
          : <Object>[
              'interpolate',
              <Object>['linear'],
              <Object>['zoom'],
              3,
              <Object>[
                'case',
                <Object>[
                  '==',
                  <Object>['get', 'kind'],
                  'cluster'
                ],
                50,
                36,
              ],
              12,
              <Object>[
                'case',
                <Object>[
                  '==',
                  <Object>['get', 'kind'],
                  'cluster'
                ],
                64,
                44,
              ],
              15,
              <Object>[
                'case',
                <Object>[
                  '==',
                  <Object>['get', 'kind'],
                  'cluster'
                ],
                76,
                56,
              ],
              24,
              <Object>[
                'case',
                <Object>[
                  '==',
                  <Object>['get', 'kind'],
                  'cluster'
                ],
                84,
                76,
              ],
            ];

      try {
        await controller.addSymbolLayer(
          _markerSourceId,
          _markerHitboxLayerId,
          ml.SymbolLayerProperties(
            iconImage: _markerHitboxImageId,
            iconSize: hitboxIconSize,
            iconOpacity: 0.0, // Invisible hitbox
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconAnchor: 'center',
            iconPitchAlignment: 'map',
            iconRotationAlignment: 'map',
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint('MapScreen: square hitbox layer add failed: $e');
        }
        // Fallback: use circle hitbox if symbol layer fails
        final Object hitboxRadius = kIsWeb
            ? 32.0
            : <Object>[
                'interpolate',
                <Object>['linear'],
                <Object>['zoom'],
                3,
                <Object>[
                  'case',
                  <Object>[
                    '==',
                    <Object>['get', 'kind'],
                    'cluster'
                  ],
                  25,
                  18,
                ],
                12,
                <Object>[
                  'case',
                  <Object>[
                    '==',
                    <Object>['get', 'kind'],
                    'cluster'
                  ],
                  32,
                  22,
                ],
                15,
                <Object>[
                  'case',
                  <Object>[
                    '==',
                    <Object>['get', 'kind'],
                    'cluster'
                  ],
                  38,
                  28,
                ],
                24,
                <Object>[
                  'case',
                  <Object>[
                    '==',
                    <Object>['get', 'kind'],
                    'cluster'
                  ],
                  42,
                  38,
                ],
              ];
        await controller.addCircleLayer(
          _markerSourceId,
          _markerHitboxLayerId,
          ml.CircleLayerProperties(
            circleColor: '#000000',
            circleOpacity: 0.0,
            circleStrokeOpacity: 0.0,
            circleStrokeWidth: 0.0,
            circleRadius: hitboxRadius,
          ),
        );
      }
      _managedLayerIds.add(_markerHitboxLayerId);

      await controller.addGeoJsonSource(
        _locationSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[],
        },
        promoteId: 'id',
      );
      _managedSourceIds.add(_locationSourceId);
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
      _managedLayerIds.add(_locationLayerId);

      if (!mounted) return;
      _styleInitialized = true;
      _hitboxLayerReady = true;
      _hitboxLayerEpoch = _styleEpoch;
      _lastAppliedMapThemeDark = themeProvider.isDarkMode;

      await _applyThemeToMapStyle(themeProvider: themeProvider);
      await _applyIsometricCamera(enabled: _isometricViewEnabled);
      await _syncUserLocation(themeProvider: themeProvider);
      await _syncMapMarkers(themeProvider: themeProvider);
      await _updateMarkerRenderMode();

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

    _animationController = AnimationController(
      duration: MapMarkerStyleConfig.selectionPopDuration,
      vsync: this,
    );
    _animationController.addListener(_handleMarkerLayerAnimationTick);
    _locationIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _cubeIconSpinController = AnimationController(
      duration: MapMarkerStyleConfig.cubeIconSpinPeriod,
      vsync: this,
    )..addListener(_handleMarkerLayerAnimationTick);
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
  }

  void _setRouteVisible(bool isVisible) {
    if (_isRouteVisible == isVisible) return;
    _isRouteVisible = isVisible;
    _handleActiveStateChanged();
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

    try {
      controller.onFeatureTapped.remove(_handleMapFeatureTapped);
      controller.onFeatureHover.remove(_handleMapFeatureHover);
    } catch (_) {}

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

    _mapController = null;
    _styleInitialized = false;
    _styleInitializationInProgress = false;
    _hitboxLayerReady = false;
    _styleEpoch += 1;
    _registeredMapImages.clear();
    _managedLayerIds.clear();
    _managedSourceIds.clear();
    _perf.logEvent('mapDetached');
  }

  @override
  void didPushNext() {
    _setRouteVisible(false);
  }

  @override
  void didPopNext() {
    _setRouteVisible(true);
  }

  void _pausePolling() {
    _timer?.cancel();
    _perf.timerStopped('location_timer');
    _proximityCheckTimer?.cancel();
    _perf.timerStopped('proximity_timer');
    _pressedClearTimer?.cancel();
    _perf.timerStopped('pressed_clear');
    _pressedClearTimer = null;
    _pressedMarkerId = null;
    _searchDebounce?.cancel();
    _perf.timerStopped('search_debounce');
    _searchDebounce = null;
    _markerRefreshDebouncer.cancel();
    _overlayAnchorDebouncer.cancel();
    _cubeSyncDebouncer.cancel();

    _updateCubeSpinTicker();
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

    _updateCubeSpinTicker();
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
    unawaited(_loadMarkersForCurrentView(forceRefresh: shouldForce));
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

    // In travel mode we want an immediate viewport refresh (bounds-based).
    unawaited(_loadMarkersForCurrentView(forceRefresh: true));
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
          prefs.getBool(PreferenceKeys.mapOnboardingMobileSeenV2) ?? false;
      if (seen) return;

      // Wait until the UI is laid out so we can compute highlight rects.
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
      await prefs.setBool(PreferenceKeys.mapOnboardingMobileSeenV2, true);
    } catch (_) {
      // Best-effort.
    }
  }

  void _dismissMapTutorial() {
    if (!mounted) return;
    setState(() {
      _showMapTutorial = false;
    });
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
    _managedLayerIds.clear();
    _managedSourceIds.clear();
    _timer?.cancel();
    _perf.timerStopped('location_timer');
    _pressedClearTimer?.cancel();
    _perf.timerStopped('pressed_clear');
    _pressedClearTimer = null;
    _searchDebounce?.cancel();
    _perf.timerStopped('search_debounce');
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    _overlayAnchorDebouncer.dispose();
    _markerRefreshDebouncer.dispose();
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
    _sheetController.dispose();
    _bearingDegrees.dispose();
    _selectedMarkerAnchorNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _perf.logSummary(
      'dispose',
      extra: <String, Object?>{
        'featureTapListeners': _debugFeatureTapListenerCount,
        'featureHoverListeners': _debugFeatureHoverListenerCount,
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

  void _refreshDiscoveryProgress() {
    final wallet = context.read<WalletProvider>().currentWalletAddress?.trim();
    if (wallet == null || wallet.isEmpty) return;
    unawaited(context.read<TaskProvider>().loadProgressFromBackend(wallet));
  }

  void _initializeMap() {
    if (!kIsWeb) {
      _mobileLocation = Location();
    }

    _getLocation();
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

  Future<void> _loadMarkersForCurrentView({bool forceRefresh = false}) async {
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh(force: forceRefresh);
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
      forceRefresh: forceRefresh,
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

    if (_selectedMarkerId == id) {
      final marker = _selectedMarkerData;
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
      _showArtMarkerDialog(marker);
    } catch (_) {
      // Best-effort: keep user on the map screen if marker fetch fails.
    }
  }

  Future<void> _loadArtMarkers(
      {LatLng? center,
      GeoBounds? bounds,
      bool forceRefresh = false,
      int? zoomBucket}) async {
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh(force: forceRefresh);
      return;
    }

    if (_isLoadingMarkers) {
      _queuePendingMarkerRefresh(force: forceRefresh);
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
              forceRefresh: forceRefresh,
              zoomBucket: bucket,
            )
          : await MapMarkerHelper.loadAndHydrateMarkers(
              artworkProvider: artworkProvider,
              mapMarkerService: _mapMarkerService,
              center: queryCenter,
              radiusKm: _effectiveMarkerRadiusKm,
              limit: _travelModeEnabled ? travelLimit : null,
              forceRefresh: forceRefresh,
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
            _selectedMarkerAnchorNotifier.value = null;
            return;
          }

          _selectedMarkerId = null;
          _selectedMarkerData = null;
          _selectedMarkerAt = null;
          _selectedMarkerViewportSignature = null;
          _selectedMarkerAnchorNotifier.value = null;
        });
        if (markersChanged) {
          unawaited(_syncMapMarkers(themeProvider: themeProvider));
        }
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
        // Clear selection if the deleted marker was selected
        if (_selectedMarkerId == markerId) {
          _selectedMarkerId = null;
          _selectedMarkerData = null;
          _selectedMarkerAt = null;
          _selectedMarkerAnchorNotifier.value = null;
          _selectedMarkerViewportSignature = null;
        }
      });
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
      await _loadArtMarkers(center: center, forceRefresh: force);
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
    if (!_pollingEnabled) {
      _queuePendingMarkerRefresh();
      return;
    }
    final controller = _mapController;
    if (controller == null) return;

    final center = _cameraCenter;
    final zoom = _lastZoom;

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

          await _loadArtMarkers(
            center: center,
            bounds: queryBounds,
            forceRefresh: false,
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
      distance: _distanceCalculator,
      refreshInterval: _markerRefreshInterval,
      refreshDistanceMeters: _markerRefreshDistanceMeters,
      hasMarkers: _artMarkers.isNotEmpty,
    );

    if (!shouldRefresh) return;

    final debounceTime = fromGesture
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 800);

    _markerRefreshDebouncer(debounceTime, () {
      unawaited(_maybeRefreshMarkers(center, force: false));
    });
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
      await _loadArtMarkers(forceRefresh: true);
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

  void _handleMarkerTap(ArtMarker marker, {List<ArtMarker> stackedMarkers = const []}) {
    // Guard against rapid repeated taps on the same marker
    if (_selectedMarkerId == marker.id && _selectedMarkerAt != null) {
      final elapsed = DateTime.now().difference(_selectedMarkerAt!);
      if (elapsed.inMilliseconds < 300) return;
    }
    if (kDebugMode) {
      _debugMarkerTapCount += 1;
      if (_debugMarkerTapCount % 30 == 0) {
        AppConfig.debugPrint(
          'MapScreen: marker taps=$_debugMarkerTapCount '
          'featureTapListeners=$_debugFeatureTapListenerCount '
          'featureHoverListeners=$_debugFeatureHoverListenerCount',
        );
      }
    }
    _maybeRecordPresenceVisitForMarker(marker);
    _perf.recordSetState('markerTap');
    setState(() {
      _selectedMarkerId = marker.id;
      _selectedMarkerData = marker;
      _selectedMarkerStack = stackedMarkers.isEmpty ? [marker] : stackedMarkers;
      _selectedMarkerStackIndex = 0; // Start at first marker in stack
      _selectedMarkerAt = DateTime.now();
      _selectedMarkerAnchorNotifier.value = null;
      // Selecting an item implies exploration; stop snapping back to user.
      _autoFollow = false;
      _selectedMarkerViewportSignature = null;
    });
    _startPressedMarkerFeedback(marker.id);
    _startSelectionPopAnimation();
    _requestMarkerLayerStyleUpdate(force: true);
    unawaited(_playMarkerSelectionFeedback(marker));
    _queueOverlayAnchorRefresh();
    if (marker.isExhibitionMarker) return;
    _ensureLinkedArtworkLoaded(marker);
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
    if (_selectedMarkerId == null && _selectedMarkerData == null) return;
    _perf.recordSetState('markerDismiss');
    setState(() {
      _selectedMarkerId = null;
      _selectedMarkerData = null;
      _selectedMarkerStack = [];
      _selectedMarkerStackIndex = 0;
      _selectedMarkerAt = null;
      _selectedMarkerAnchorNotifier.value = null;
      _selectedMarkerViewportSignature = null;
    });
    _pressedClearTimer?.cancel();
    _perf.timerStopped('pressed_clear');
    _pressedClearTimer = null;
    _pressedMarkerId = null;
    _requestMarkerLayerStyleUpdate(force: true);
  }

  /// Navigate to the next marker in the stacked markers list (swipe left).
  void _nextStackedMarker() {
    if (_selectedMarkerStack.length <= 1) return;
    setState(() {
      _selectedMarkerStackIndex = (_selectedMarkerStackIndex + 1) % _selectedMarkerStack.length;
      _selectedMarkerData = _selectedMarkerStack[_selectedMarkerStackIndex];
      _selectedMarkerId = _selectedMarkerData?.id;
    });
  }

  /// Navigate to the previous marker in the stacked markers list (swipe right).
  void _previousStackedMarker() {
    if (_selectedMarkerStack.length <= 1) return;
    setState(() {
      _selectedMarkerStackIndex = (_selectedMarkerStackIndex - 1 + _selectedMarkerStack.length) % _selectedMarkerStack.length;
      _selectedMarkerData = _selectedMarkerStack[_selectedMarkerStackIndex];
      _selectedMarkerId = _selectedMarkerData?.id;
    });
  }

  void _startPressedMarkerFeedback(String markerId) {
    _pressedClearTimer?.cancel();
    _perf.timerStopped('pressed_clear');
    _pressedClearTimer = null;
    _pressedMarkerId = markerId;
    _requestMarkerLayerStyleUpdate();

    _pressedClearTimer = Timer(const Duration(milliseconds: 120), () {
      _perf.timerStopped('pressed_clear');
      if (!mounted) return;
      if (_pressedMarkerId != markerId) return;
      _safeSetState(() => _pressedMarkerId = null);
      _requestMarkerLayerStyleUpdate();
    });
    _perf.timerStarted('pressed_clear');
  }

  void _startSelectionPopAnimation() {
    if (!_styleInitialized) return;
    _animationController.forward(from: 0.0);
    _requestMarkerLayerStyleUpdate();
  }

  void _updateCubeSpinTicker() {
    final shouldSpin = _pollingEnabled &&
        _styleInitialized &&
        _mapController != null &&
        _cubeLayerVisible &&
        _is3DMarkerModeActive;
    if (shouldSpin) {
      if (!_cubeIconSpinController.isAnimating) {
        _cubeIconSpinController.repeat();
      }
      return;
    }

    if (_cubeIconSpinController.isAnimating) {
      _cubeIconSpinController.stop();
    }
  }

  void _handleMarkerLayerAnimationTick() {
    if (!mounted) return;
    if (!_styleInitialized) return;

    final shouldSpin = _cubeLayerVisible && _is3DMarkerModeActive;
    final shouldPop = _animationController.isAnimating;
    if (!shouldSpin && !shouldPop) return;

    if (shouldSpin) {
      _cubeIconSpinDegrees = _cubeIconSpinController.value * 360.0;
      final bobMs = MapMarkerStyleConfig.cubeIconBobPeriod.inMilliseconds;
      final t = (DateTime.now().millisecondsSinceEpoch % bobMs) / bobMs;
      _cubeIconBobOffsetEm = math.sin(t * 2 * math.pi) *
          MapMarkerStyleConfig.cubeIconBobAmplitudeEm;
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
    final epoch = _styleEpoch;
    unawaited(_applyMarkerLayerStyle(controller, epoch).whenComplete(() {
      _markerLayerStyleUpdateInFlight = false;
      if (_markerLayerStyleUpdateQueued) {
        _markerLayerStyleUpdateQueued = false;
        _requestMarkerLayerStyleUpdate(force: true);
      }
    }));
  }

  Future<void> _applyMarkerLayerStyle(
    ml.MapLibreMapController controller,
    int styleEpoch,
  ) async {
    if (!_styleInitialized) return;
    if (styleEpoch != _styleEpoch) return;
    final canStyleMarkerLayer = _managedLayerIds.contains(_markerLayerId);
    final canStyleCubeIconLayer = _managedLayerIds.contains(_cubeIconLayerId);
    if (!canStyleMarkerLayer && !canStyleCubeIconLayer) return;

    final iconImage = _interactiveIconImageExpression();
    final iconSize = _interactiveIconSizeExpression();
    final cubeIconSize = _interactiveIconSizeExpression(constantScale: 0.92);
    final iconOpacity = <Object>[
      'case',
      <Object>[
        '==',
        <Object>['get', 'kind'],
        'cluster'
      ],
      1.0,
      1.0,
    ];

    final markerVisible = !_cubeLayerVisible;
    final cubeIconVisible = _cubeLayerVisible;

    try {
      if (canStyleMarkerLayer) {
        if (!_styleInitialized || styleEpoch != _styleEpoch) return;
        await controller.setLayerProperties(
          _markerLayerId,
          ml.SymbolLayerProperties(
            iconImage: iconImage,
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
      }
      if (canStyleCubeIconLayer) {
        if (!_styleInitialized || styleEpoch != _styleEpoch) return;
        await controller.setLayerProperties(
          _cubeIconLayerId,
          ml.SymbolLayerProperties(
            iconImage: iconImage,
            iconSize: cubeIconSize,
            iconOpacity: iconOpacity,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconAnchor: 'center',
            iconPitchAlignment: 'viewport',
            iconRotationAlignment: 'viewport',
            iconOffset: MapMarkerStyleConfig.cubeFloatingIconOffsetEmWithBob(
              _cubeIconBobOffsetEm,
            ),
            iconRotate: _cubeIconSpinDegrees,
            visibility: cubeIconVisible ? 'visible' : 'none',
          ),
        );
      }
    } catch (_) {
      // Best-effort: style swaps or platform limitations can reject updates.
    }
  }

  Object _interactiveIconSizeExpression({double constantScale = 1.0}) {
    final pressedId = _pressedMarkerId;
    final hoveredId = _hoveredMarkerId;
    final selectedId = _selectedMarkerId;
    final any = pressedId != null || hoveredId != null || selectedId != null;
    if (!any) {
      return MapMarkerStyleConfig.iconSizeExpression(
          constantScale: constantScale);
    }

    final double pop = selectedId == null
        ? 1.0
        : (1.0 +
            (MapMarkerStyleConfig.selectedPopScaleFactor - 1.0) *
                math.sin(_animationController.value * math.pi));

    // On MapLibre GL JS, `['zoom']` must be the input to a top-level
    // "step"/"interpolate". Encode interaction multipliers inside the stop
    // outputs so we never wrap the zoom expression.
    final multiplier = <Object>['case'];
    if (pressedId != null) {
      multiplier.addAll(<Object>[
        <Object>[
          '==',
          <Object>['id'],
          pressedId
        ],
        MapMarkerStyleConfig.pressedScaleFactor,
      ]);
    }
    if (selectedId != null) {
      multiplier.addAll(<Object>[
        <Object>[
          '==',
          <Object>['id'],
          selectedId
        ],
        pop,
      ]);
    }
    if (hoveredId != null) {
      multiplier.addAll(<Object>[
        <Object>[
          '==',
          <Object>['id'],
          hoveredId
        ],
        MapMarkerStyleConfig.hoverScaleFactor,
      ]);
    }
    multiplier.add(1.0);
    return MapMarkerStyleConfig.iconSizeExpression(
      constantScale: constantScale,
      multiplier: multiplier,
    );
  }

  Object _interactiveIconImageExpression() {
    final selectedId = _selectedMarkerId;
    if (selectedId == null || selectedId.isEmpty) {
      return const <Object>['get', 'icon'];
    }
    return <Object>[
      'case',
      <Object>[
        '==',
        <Object>['id'],
        selectedId
      ],
      const <Object>['get', 'iconSelected'],
      const <Object>['get', 'icon'],
    ];
  }

  bool _assertMarkerModeInvariant() {
    if (_selectedMarkerId == null && _selectedMarkerData != null) return false;
    if (_selectedMarkerId != null && _selectedMarkerData == null) return false;
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

    if (kDebugMode) {
      AppConfig.debugPrint(
        'MapScreen: marker render mode -> cubes=$shouldShowCubes '
        'layers(marker=${_managedLayerIds.contains(_markerLayerId)} '
        'cubeIcon=${_managedLayerIds.contains(_cubeIconLayerId)} '
        'cube=${_managedLayerIds.contains(_cubeLayerId)})',
      );
    }

    try {
      if (_managedLayerIds.contains(_cubeLayerId)) {
        await controller.setLayerVisibility(_cubeLayerId, shouldShowCubes);
      }
      if (_managedLayerIds.contains(_cubeIconLayerId)) {
        await controller.setLayerVisibility(_cubeIconLayerId, shouldShowCubes);
      }
      if (_managedLayerIds.contains(_markerLayerId)) {
        await controller.setLayerVisibility(_markerLayerId, !shouldShowCubes);
      }
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
        if (_managedSourceIds.contains(_cubeSourceId)) {
          await controller.setGeoJsonSource(
            _cubeSourceId,
            const <String, dynamic>{
              'type': 'FeatureCollection',
              'features': <dynamic>[],
            },
          );
        }
      } catch (_) {
        // Ignore source update failures during transitions.
      }
    }

    _updateCubeSpinTicker();
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

    try {
      final point = await controller.toScreenLocation(
        ml.LatLng(marker.position.latitude, marker.position.longitude),
      );
      if (!mounted) return;
      setState(() {
        _markerTapRippleOffset = Offset(point.x.toDouble(), point.y.toDouble());
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
      if (_selectedMarkerId == marker.id) {
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
    unawaited(_animateMapTo(marker.position, zoom: math.max(_lastZoom, 15)));
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

  // Isometric overlay removed - grid is now integrated in tile provider

  Future<void> _handleCurrentLocationTap() async {
    if (_currentPosition == null) return;

    // Check if there's a nearby marker (within 30 meters)
    ArtMarker? nearbyMarker;
    double minDistance = double.infinity;

    for (final marker in _artMarkers) {
      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        _currentPosition!,
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
    if (_currentPosition == null) return;
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
      await _loadArtMarkers(forceRefresh: true);
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
    final controller = _mapController;
    if (controller == null) return;

    final double targetZoom = zoom ?? _lastZoom;
    final double targetRotation = rotation ?? _lastBearing;
    final double targetPitch = _desiredPitch();

    ml.LatLng target = ml.LatLng(center.latitude, center.longitude);
    if (offset != Offset.zero) {
      try {
        final screen = await controller.toScreenLocation(target);
        final shifted = math.Point<double>(
          screen.x.toDouble() + offset.dx,
          screen.y.toDouble() + offset.dy,
        );
        target = await controller.toLatLng(shifted);
      } catch (_) {
        // If projection isn't available yet, fall back to centering on the marker.
      }
    }

    _programmaticCameraMove = true;
    try {
      await controller.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: target,
            zoom: targetZoom,
            bearing: targetRotation,
            tilt: targetPitch,
          ),
        ),
        duration: duration,
      );
    } catch (e, st) {
      AppConfig.debugPrint('MapScreen: animateCamera failed: $e');
      if (kDebugMode) {
        AppConfig.debugPrint('MapScreen: animateCamera stack: $st');
      }
    }
  }

  Size? _mapViewportSize() {
    final context = _mapViewKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return null;
  }

  Future<void> _focusMarkerWithCardOffset(
    LatLng markerPosition, {
    required double targetZoom,
    double desiredMarkerYFraction = 2 / 3,
    required double minMarkerY,
  }) async {
    final controller = _mapController;
    if (controller == null) return;
    final fallbackSize = MediaQuery.of(context).size;

    // Step 1: fly directly to the marker coordinate at the desired zoom.
    final bearing = _lastBearing;
    await _animateMapTo(
      markerPosition,
      zoom: targetZoom,
      rotation: bearing,
      offset: Offset.zero,
      duration: const Duration(milliseconds: 360),
    );
    if (!mounted) return;
    if (!_styleInitialized) return;

    // Step 2: after the camera settles, offset the camera center so the marker
    // ends up around 2/3 down the viewport (below the floating card).
    await SchedulerBinding.instance.endOfFrame;
    final size = _mapViewportSize() ?? fallbackSize;

    final desiredY = math
        .max(size.height * desiredMarkerYFraction, minMarkerY)
        .clamp(0.0, size.height)
        .toDouble();
    final dy = desiredY - (size.height / 2);
    if (dy.abs() < 1.0) return;

    try {
      final screenTarget = math.Point<double>(
        size.width / 2,
        (size.height / 2) - dy,
      );
      final center = await controller.toLatLng(screenTarget);
      if (!mounted) return;
      await _animateMapTo(
        LatLng(center.latitude, center.longitude),
        zoom: targetZoom,
        rotation: bearing,
        offset: Offset.zero,
        duration: const Duration(milliseconds: 260),
      );
    } catch (_) {
      // Best-effort: projection may fail during style swaps.
    }
  }

  void _scheduleEnsureActiveMarkerOverlayInView({
    required ArtMarker marker,
    required double overlayHeight,
  }) {
    final screen = MediaQuery.of(context);
    final topSafe = screen.padding.top;
    final size = screen.size;

    final double minMarkerY =
        (topSafe + overlayHeight + 24).clamp(0.0, size.height).toDouble();

    final signature =
        '${marker.id}|${overlayHeight.round()}|${_lastZoom.toStringAsFixed(2)}|${_lastBearing.toStringAsFixed(3)}|${minMarkerY.round()}';
    if (signature == _selectedMarkerViewportSignature) return;
    _selectedMarkerViewportSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedMarkerId != marker.id) return;

      final targetZoom = math.max(_lastZoom, 15.5);
      unawaited(
        _focusMarkerWithCardOffset(
          marker.position,
          targetZoom: targetZoom,
          minMarkerY: minMarkerY,
        ),
      );
    });
  }

  void _queueOverlayAnchorRefresh() {
    if (_selectedMarkerData == null) return;
    if (!_styleInitialized) return;
    _overlayAnchorDebouncer(const Duration(milliseconds: 66), () {
      unawaited(_refreshSelectedMarkerAnchor());
    });
  }

  Future<void> _refreshSelectedMarkerAnchor() async {
    final controller = _mapController;
    final marker = _selectedMarkerData;
    if (controller == null || marker == null) return;
    if (!_styleInitialized) return;

    try {
      final screen = await controller.toScreenLocation(
        ml.LatLng(marker.position.latitude, marker.position.longitude),
      );
      if (!mounted) return;
      final next = Offset(screen.x.toDouble(), screen.y.toDouble());
      if (_selectedMarkerAnchorNotifier.value == next) return;
      _selectedMarkerAnchorNotifier.value = next;
    } catch (_) {
      // Ignore projection failures during style transitions.
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

  Future<void> _markAsDiscovered(Artwork artwork) async {
    context.read<ArtworkProvider>().discoverArtwork(artwork.id);

    if (!mounted) return;
    _refreshDiscoveryProgress();

    _showDiscoveryRewardForArtwork(artwork);
  }

  void _showDiscoveryRewardForArtwork(Artwork artwork) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final rewardAccent = roles.achievementGold;
    final rewardTextColor = AppColorUtils.shiftLightness(
      rewardAccent,
      Theme.of(context).brightness == Brightness.dark ? 0.05 : -0.15,
    );
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: rewardAccent),
            const SizedBox(width: 8),
            Text(
              l10n.mapArtDiscoveredTitle,
              style: KubusTypography.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                  width: 3,
                ),
              ),
              child: Icon(
                artwork.arEnabled ? Icons.view_in_ar : Icons.palette,
                color: scheme.onPrimary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              artwork.title,
              style: KubusTypography.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: ArtworkCreatorByline(
                artwork: artwork,
                style: KubusTypography.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rewardAccent.withValues(alpha: 0.16),
                borderRadius: KubusRadius.circular(KubusRadius.xl),
                border: Border.all(color: rewardAccent.withValues(alpha: 0.9)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars, color: rewardAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    l10n.commonKub8PointsReward(artwork.rewards),
                    style: KubusTypography.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: rewardTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonContinueExploring,
                style: KubusTypography.textTheme.labelLarge),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openArtwork(context, artwork.id, source: 'map_discovery_dialog');
            },
            child: Text(l10n.commonViewDetails,
                style: KubusTypography.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _perf.recordBuild();
    _isBuilding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isBuilding = false;
    });
    assert(_assertMarkerModeInvariant());
    assert(_assertMarkerRenderModeInvariant());
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    _maybeScheduleThemeResync(themeProvider);
    final artworkProvider = Provider.of<ArtworkProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);

    final artworks = artworkProvider.artworks;
    final filteredArtworks = _sortArtworks(_filterArtworks(artworks));
    final discoveryProgress = taskProvider.getOverallProgress();
    final isLoadingArtworks = artworkProvider.isLoading('load_artworks');

    final stack = LayoutBuilder(
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
                ignoring: _showMapTutorial || _isSheetInteracting,
                child: _mapViewMounted
                    ? _buildMap(
                        themeProvider,
                        attributionBottomMargin: attributionBottomMargin,
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
            _buildTopOverlays(theme,
                taskProvider), // This will likely be refactored into _buildSearchAndFilters()
            _buildPrimaryControls(
                theme), // This will likely be refactored into _buildSearchAndFilters()
            _buildBottomSheet(
              // This will likely be refactored into _buildDraggablePanel()
              theme,
              filteredArtworks,
              discoveryProgress,
              isLoadingArtworks,
            ),
            _buildMarkerOverlay(themeProvider),
            if (_isSearching)
              _buildSuggestionSheet(
                  theme), // This will likely be refactored into _buildSearchAndFilters()
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
    final disableGesturesForOverlays = _showMapTutorial || _isSheetInteracting;

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
          unawaited(_handleMapTap(point, themeProvider, latLng));
        },
        onMapCreated: (controller) {
          _mapController = controller;
          _bindFeatureTapController(controller);
          _styleInitialized = false;
          _hitboxLayerReady = false;
          _registeredMapImages.clear();
          _managedLayerIds.clear();
          _managedSourceIds.clear();
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
              _loadMarkersForCurrentView(forceRefresh: true)
                  .then((_) => _maybeOpenInitialMarker())
                  .catchError((e) {
                if (kDebugMode) {
                  debugPrint('MapScreen: initial marker load error: $e');
                }
              }),
            );
          } else if (_artMarkers.isEmpty && !_isLoadingMarkers) {
            unawaited(
              _loadMarkersForCurrentView(forceRefresh: true)
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

  /// Generate a transparent square image for the hitbox layer.
  /// Returns bytes for a 1x1 transparent PNG which MapLibre will scale to the icon-size.
  /// This allows us to use a symbol layer for square-based tap detection.
  Uint8List _createTransparentSquareImage() {
    // 1x1 transparent PNG (base64 decoded)
    const String base64Png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    return Uint8List.fromList(base64Decode(base64Png));
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
    double targetZoom = _lastZoom;
    if (adjustZoomForScale) {
      const scale = 1.2;
      final delta = math.log(scale) / math.ln2;
      targetZoom = shouldEnable ? (_lastZoom + delta) : (_lastZoom - delta);
      targetZoom = targetZoom.clamp(3.0, 24.0).toDouble();
      _lastZoom = targetZoom;
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

    if (!mounted) return;
    unawaited(_updateMarkerRenderMode());
  }

  /// Reset map bearing to 0 (north up) while preserving zoom and pitch.
  Future<void> _resetBearing() async {
    final controller = _mapController;
    if (controller == null) return;

    // Skip if already pointing north
    if (_lastBearing.abs() < 0.5) return;

    _programmaticCameraMove = true;
    await controller.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(_cameraCenter.latitude, _cameraCenter.longitude),
          zoom: _lastZoom,
          bearing: 0.0,
          tilt: _lastPitch,
        ),
      ),
      duration: const Duration(milliseconds: 320),
    );
  }

  void _handleCameraMove(ml.CameraPosition position) {
    if (!mounted) return;
    // Any user gesture should immediately cancel auto-follow so we don't fight
    // the user. This must run before the throttle early-return.
    final bool hasGesture = !_programmaticCameraMove;
    if (hasGesture && _autoFollow) {
      setState(() => _autoFollow = false);
    }

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
    final bool bearingChanged = (nextBearing - _lastBearing).abs() > 0.1;

    // Camera moves are high-frequency; avoid rebuilding the entire screen on
    // every frame. Store camera state locally and only notify tiny, isolated
    // widgets via ValueNotifiers when needed.
    _cameraCenter = nextCenter;
    _lastZoom = nextZoom;
    _lastBearing = nextBearing;
    _lastPitch = nextPitch;
    if (bearingChanged) {
      _bearingDegrees.value = nextBearing;
    }

    if (_selectedMarkerData != null) {
      _queueOverlayAnchorRefresh();
    }

    if (_styleInitialized && zoomChanged) {
      _queueMarkerVisualRefreshForZoom(nextZoom);
    }
  }

  void _handleCameraIdle() {
    if (!mounted) return;
    final wasProgrammatic = _programmaticCameraMove;
    _programmaticCameraMove = false;

    _queueMarkerRefresh(fromGesture: !wasProgrammatic);
    if (_styleInitialized) {
      _queueMarkerVisualRefreshForZoom(_lastZoom);
      unawaited(_updateMarkerRenderMode());
    }
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
    if (!_styleInitialized) return;
    if (_mapController == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        nowMs - _lastMarkerVisualSyncMs < _markerVisualSyncThrottleMs) {
      _markerVisualSyncQueued = true;
      return;
    }
    if (_markerVisualSyncInFlight) {
      _markerVisualSyncQueued = true;
      return;
    }
    _lastMarkerVisualSyncMs = nowMs;
    _markerVisualSyncInFlight = true;

    final themeProvider = context.read<ThemeProvider>();
    unawaited(
        _syncMapMarkersSafe(themeProvider: themeProvider).whenComplete(() {
      _markerVisualSyncInFlight = false;
      if (_markerVisualSyncQueued) {
        _markerVisualSyncQueued = false;
        _requestMarkerVisualSync(force: true);
      }
    }));
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
      if (_managedLayerIds.contains(_locationLayerId)) {
        await controller.setLayerProperties(
          _locationLayerId,
          ml.CircleLayerProperties(
            circleRadius: 6,
            circleColor: _hexRgb(scheme.secondary),
            circleOpacity: 1.0,
            circleStrokeWidth: 2,
            circleStrokeColor: _hexRgb(scheme.surface),
          ),
        );
      }
    } catch (_) {
      // Best-effort: style swaps or platform limitations can reject updates.
    }

    if (!mounted) return;
    _requestMarkerLayerStyleUpdate(force: true);
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
    ThemeProvider themeProvider,
    LatLng latLng,
  ) async {
    final controller = _mapController;
    if (controller == null) return;
    final double? debugDpr =
        kDebugMode ? MediaQuery.of(context).devicePixelRatio : null;

    final lastAt = _lastFeatureTapAt;
    final lastPoint = _lastFeatureTapPoint;
    if (MapTapGating.shouldIgnoreMapClickAfterFeatureTap(
      lastFeatureTapAt: lastAt,
      lastFeatureTapPoint: lastPoint,
      clickPoint: point,
    )) {
      return;
    }

    // On web, taps that hit interactive style layers are delivered via
    // `controller.onFeatureTapped`. Treat `onMapClick` as a background tap.
    if (kIsWeb) {
      _dismissSelectedMarker();
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
        'MapScreen: tap at (${point.x.toStringAsFixed(1)}, ${point.y.toStringAsFixed(1)}) '
        'pitch=${_lastPitch.toStringAsFixed(1)} bearing=${_lastBearing.toStringAsFixed(1)} '
        'zoom=${_lastZoom.toStringAsFixed(2)} dpr=$debugDpr 3D=$_is3DMarkerModeActive',
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
          'MapScreen: queryRenderedFeaturesInRect hits=${features.length} '
          'first.markerId=${props['markerId'] ?? props['id']} kind=${props['kind']}',
        );
      }

      if (features.isEmpty) {
        if (kDebugMode) {
          AppConfig.debugPrint('MapScreen: no features in rect');
        }
        _dismissSelectedMarker();
        return;
      }

      final dynamic first = features.first;
      final propsRaw = first is Map ? first['properties'] : null;
      final Map props = propsRaw is Map ? propsRaw : const <String, dynamic>{};
      final kind = props['kind']?.toString();
      if (kDebugMode) {
        AppConfig.debugPrint(
          'MapScreen: tap query hits=${features.length} kind=${kind ?? 'marker'}',
        );
      }
      if (kind == 'cluster') {
        final lng = (props['lng'] as num?)?.toDouble();
        final lat = (props['lat'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        // Incremental zoom: step by 1.5 instead of 2.0 to reduce re-clustering lag
        // and avoid overshooting the cluster-breakdown zoom level.
        final nextZoom = math.min(_lastZoom + 1.5, 18.0);
        if (kDebugMode) {
          AppConfig.debugPrint(
            'MapScreen: cluster tap → zoom=${nextZoom.toStringAsFixed(1)} from ${_lastZoom.toStringAsFixed(1)}',
          );
        }
        await _animateMapTo(
          LatLng(lat, lng),
          zoom: nextZoom,
          rotation: _lastBearing,
        );
        return;
      }

      final markerId = (props['markerId'] ?? props['id'])?.toString() ?? '';
      if (markerId.isEmpty) return;
      if (kDebugMode) {
        AppConfig.debugPrint('MapScreen: marker tap id=$markerId');
      }
      ArtMarker? selected;
      for (final marker in _artMarkers) {
        if (marker.id == markerId) {
          selected = marker;
          break;
        }
      }
      if (selected == null) return;
      
      // Check for other markers at the exact same coordinates (stacked markers).
      // This allows swiping through multiple markers in the overlay card.
      final stackedMarkers = <ArtMarker>[];
      for (final marker in _artMarkers) {
        if ((marker.position.latitude - selected.position.latitude).abs() < 0.0001 &&
            (marker.position.longitude - selected.position.longitude).abs() < 0.0001) {
          stackedMarkers.add(marker);
        }
      }
      
      _handleMarkerTap(selected, stackedMarkers: stackedMarkers);
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint('MapScreen: queryRenderedFeatures failed: $e');
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
    final zoomScale = (_lastZoom / 15.0).clamp(0.7, 1.4);
    final double base =
        _is3DMarkerModeActive ? (kIsWeb ? 34.0 : 28.0) : (kIsWeb ? 28.0 : 22.0);
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
      final shouldCluster = zoom < _clusterMaxZoom;
      final visibleMarkers = _artMarkers
          .where((m) => (_markerLayerVisibility[m.type] ?? true))
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

      final features = <Map<String, dynamic>>[];

      if (shouldCluster) {
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
      try {
        await controller.setGeoJsonSource(_markerSourceId, collection);
      } catch (_) {
        // Best-effort: style swaps can temporarily invalidate sources.
      }

      if (_is3DMarkerModeActive) {
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

    // Collect icon IDs that need rendering (not yet in _registeredMapImages).
    final toRender = <_IconRenderTask>[];

    if (shouldCluster) {
      final clusters = _clusterMarkers(markers, zoom);
      for (final cluster in clusters) {
        if (cluster.markers.length == 1) {
          final marker = cluster.markers.first;
          final typeName = marker.type.name;
          final tier = marker.signalTier;
          final baseIconId = MapMarkerIconIds.markerBase(
            typeName: typeName,
            tierName: tier.name,
            isDark: isDark,
          );
          final selectedIconId = MapMarkerIconIds.markerSelected(
            typeName: typeName,
            tierName: tier.name,
            isDark: isDark,
          );

          if (!_registeredMapImages.contains(baseIconId)) {
            toRender.add(_IconRenderTask(
              iconId: baseIconId,
              marker: marker,
              cluster: null,
              isCluster: false,
              selected: false,
            ));
          }
          if (!_registeredMapImages.contains(selectedIconId)) {
            toRender.add(_IconRenderTask(
              iconId: selectedIconId,
              marker: marker,
              cluster: null,
              isCluster: false,
              selected: true,
            ));
          }
        } else {
          final first = cluster.markers.first;
          final typeName = first.type.name;
          final label =
              cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
          final iconId = MapMarkerIconIds.cluster(
            typeName: typeName,
            label: label,
            isDark: isDark,
          );
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
        final typeName = marker.type.name;
        final tier = marker.signalTier;
        final baseIconId = MapMarkerIconIds.markerBase(
          typeName: typeName,
          tierName: tier.name,
          isDark: isDark,
        );
        final selectedIconId = MapMarkerIconIds.markerSelected(
          typeName: typeName,
          tierName: tier.name,
          isDark: isDark,
        );
        if (!_registeredMapImages.contains(baseIconId)) {
          toRender.add(_IconRenderTask(
            iconId: baseIconId,
            marker: marker,
            cluster: null,
            isCluster: false,
            selected: false,
          ));
        }
        if (!_registeredMapImages.contains(selectedIconId)) {
          toRender.add(_IconRenderTask(
            iconId: selectedIconId,
            marker: marker,
            cluster: null,
            isCluster: false,
            selected: true,
          ));
        }
      }
    }

    if (toRender.isEmpty) return;

    // Deduplicate by iconId (multiple markers may share the same icon).
    final uniqueTasks = <String, _IconRenderTask>{};
    for (final task in toRender) {
      uniqueTasks.putIfAbsent(task.iconId, () => task);
    }

    // Render in parallel batches (limit concurrency to avoid GPU overload).
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
                'MapScreen: preregister icon failed (${task.iconId}): $e');
          }
        }
      }));
    }
  }

  Future<void> _syncMarkerCubes({required ThemeProvider themeProvider}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;
    if (!_managedSourceIds.contains(_cubeSourceId)) return;
    if (!mounted) return;
    if (!_is3DMarkerModeActive) return;

    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final zoom = _lastZoom;
    final visibleMarkers = _artMarkers
        .where((m) => (_markerLayerVisibility[m.type] ?? true))
        .where((m) => m.hasValidPosition)
        .toList(growable: false);

    final cubeFeatures = <Map<String, dynamic>>[];
    for (final marker in visibleMarkers) {
      final baseColor = AppColorUtils.markerSubjectColor(
        markerType: marker.type.name,
        metadata: marker.metadata,
        scheme: scheme,
        roles: roles,
      );
      // CONSTANT SCREEN SIZE: Cube appears same size on screen across all zoom levels.
      // Formula: pixel_size × meters_per_pixel = constant_map_units
      // This ensures the visual 2D icon and 3D cube are always aligned.
      final cubePixelSize = MarkerCubeGeometry.markerPixelSize(zoom);
      final mpp = MarkerCubeGeometry.metersPerPixel(zoom, marker.position.latitude);
      final cubeSizeMeters = cubePixelSize * mpp;
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
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
  }) async {
    final controller = _mapController;
    if (controller == null) return const <String, dynamic>{};

    final typeName = marker.type.name;
    final tier = marker.signalTier;
    final iconId = MapMarkerIconIds.markerBase(
      typeName: typeName,
      tierName: tier.name,
      isDark: isDark,
    );
    final selectedIconId = MapMarkerIconIds.markerSelected(
      typeName: typeName,
      tierName: tier.name,
      isDark: isDark,
    );

    if (!_registeredMapImages.contains(iconId)) {
      final baseColor = _resolveArtMarkerColor(marker, themeProvider);
      final bytes = await ArtMarkerCubeIconRenderer.renderMarkerPng(
        baseColor: baseColor,
        icon: _resolveArtMarkerIcon(marker.type),
        tier: tier,
        scheme: scheme,
        roles: roles,
        isDark: isDark,
        forceGlow: false,
        pixelRatio: _markerPixelRatio(),
      );
      if (!mounted) return const <String, dynamic>{};
      try {
        await controller.addImage(iconId, bytes);
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint('MapScreen: addImage failed ($iconId): $e');
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
        'iconSelected': selectedIconId,
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
    required bool isDark,
  }) async {
    final controller = _mapController;
    if (controller == null) return const <String, dynamic>{};

    final first = cluster.markers.first;
    final typeName = first.type.name;
    final label =
        cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
    final iconId = MapMarkerIconIds.cluster(
      typeName: typeName,
      label: label,
      isDark: isDark,
    );

    if (!_registeredMapImages.contains(iconId)) {
      final baseColor = AppColorUtils.markerSubjectColor(
        markerType: typeName,
        metadata: first.metadata,
        scheme: scheme,
        roles: KubusColorRoles.of(context),
      );
      final count = cluster.markers.length;
      final bytes = await ArtMarkerCubeIconRenderer.renderClusterPng(
        count: count,
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
          AppConfig.debugPrint('MapScreen: addImage failed ($iconId): $e');
        }
        return const <String, dynamic>{};
      }
      _registeredMapImages.add(iconId);
    }

    final center = cluster.centroid;
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

  Widget _buildMarkerOverlay(ThemeProvider themeProvider) {
    final marker = _selectedMarkerData;
    final selectionKey = _selectedMarkerAt?.millisecondsSinceEpoch ?? 0;
    final animationKey = marker == null
        ? const ValueKey<String>('marker_overlay_empty')
        : ValueKey<String>('marker_overlay:${marker.id}:$selectionKey');
    final shouldIntercept = marker != null;
    final overlayStack = Stack(
      fit: StackFit.expand,
      children: [
        if (marker != null)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {},
              onPointerMove: (_) {},
              onPointerUp: (_) {},
              onPointerSignal: (_) {},
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismissSelectedMarker,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        _buildMarkerTapRipple(),
        Positioned.fill(
          child: AnimatedSwitcher(
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
                    scale:
                        Tween<double>(begin: 0.985, end: 1.0).animate(curved),
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
                      _buildAnchoredMarkerOverlay(themeProvider),
                    ],
                  ),
          ),
        ),
      ],
    );

    return Positioned.fill(
      // Use StackFit.expand to ensure the Stack fills the Positioned.fill
      // and passes bounded constraints to its Positioned.fill children.
      child: _wrapPointerInterceptor(
        child: overlayStack,
        enabled: shouldIntercept,
      ),
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

  Widget _buildAnchoredMarkerOverlay(ThemeProvider themeProvider) {
    final marker = _selectedMarkerData;
    if (marker == null) return const SizedBox.shrink();

    final artwork = marker.isExhibitionMarker
        ? null
        : context
            .read<ArtworkProvider>()
            .getArtworkById(marker.artworkId ?? '');

    final l10n = AppLocalizations.of(context)!;
    final baseColor = _resolveArtMarkerColor(marker, themeProvider);

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
                final anchor = anchorValue;
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
                final double topSafe = MediaQuery.of(context).padding.top + 12;
                final double bottomSafe =
                    constraints.maxHeight - cardHeight - 12;

                // Account for marker height (flat square markers).
                const double markerOffset = 32.0;

                double left = (constraints.maxWidth - maxWidth) / 2;

                final bool isCompact = constraints.maxWidth < 600;

                // Prefer anchoring above the marker. If the anchor isn't ready yet,
                // fall back to a stable heuristic so the first frame looks good.
                final markerY = anchor?.dy ??
                    (constraints.maxHeight * (isCompact ? 0.72 : 0.66));
                double top = markerY - cardHeight - markerOffset;
                if (top < topSafe) {
                  top = topSafe;
                }
                top = top.clamp(topSafe, math.max(topSafe, bottomSafe));

                if (_selectedMarkerViewportSignature == null) {
                  _scheduleEnsureActiveMarkerOverlayInView(
                    marker: marker,
                    overlayHeight: cardHeight,
                  );
                }

                if (kDebugMode) {
                  AppConfig.debugPrint(
                    'MapScreen: card anchor=(${anchor?.dx.toStringAsFixed(0)}, ${anchor?.dy.toStringAsFixed(0)}) '
                    'pos=(${left.toStringAsFixed(0)}, ${top.toStringAsFixed(0)}) '
                    'maxH=${maxCardHeight.toStringAsFixed(0)} estH=${estimatedHeight.toStringAsFixed(0)} cardH=${cardHeight.toStringAsFixed(0)}',
                  );
                }

                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: top,
                      width: maxWidth,
                      // Wrap in Listener to absorb pointer events and prevent
                      // them from passing through to the map underneath.
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) {},
                        onPointerMove: (_) {},
                        onPointerUp: (_) {},
                        onPointerSignal: (_) {},
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: SizedBox(
                            height: cardHeight,
                            child: MarkerOverlayCard(
                              marker: marker,
                              artwork: artwork,
                              baseColor: baseColor,
                              displayTitle: displayTitle,
                              canPresentExhibition: canPresentExhibition,
                              distanceText: distanceText,
                              description: rawDescription,
                              onClose: _dismissSelectedMarker,
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
                              stackCount: _selectedMarkerStack.length,
                              stackIndex: _selectedMarkerStackIndex,
                              onNextStacked: _selectedMarkerStack.length > 1
                                  ? _nextStackedMarker
                                  : null,
                              onPreviousStacked:
                                  _selectedMarkerStack.length > 1
                                      ? _previousStackedMarker
                                      : null,
                              onHorizontalDragEnd: (details) {
                                final velocity = details.primaryVelocity ?? 0;
                                if (velocity > 200) {
                                  _previousStackedMarker();
                                } else if (velocity < -200) {
                                  _nextStackedMarker();
                                }
                              },
                              maxHeight: cardHeight,
                            ),
                          ),
                        ),
                      ), // Close Positioned
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

  Widget _glassChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color accent,
    required VoidCallback? onTap,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
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
                ValueListenableBuilder<double>(
                  valueListenable: _bearingDegrees,
                  builder: (context, bearing, _) {
                    if (bearing.abs() <= 1.0) {
                      return const SizedBox.shrink();
                    }
                    final l10n = AppLocalizations.of(context)!;
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _MapIconButton(
                          icon: Icons.explore,
                          tooltip: l10n.mapResetBearingTooltip,
                          onTap: () => unawaited(_resetBearing()),
                        ),
                      ),
                    );
                  },
                ),
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
    setState(() {
      _selectedMarkerId = marker.id;
      _selectedMarkerData = marker;
      _selectedMarkerAt = DateTime.now();
    });

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

  List<_ClusterBucket> _clusterMarkers(List<ArtMarker> markers, double zoom) {
    if (markers.isEmpty) return const <_ClusterBucket>[];

    final level = _clusterGridLevelForZoom(zoom);
    final Map<String, _ClusterBucket> buckets = {};

    for (final marker in markers) {
      final cell = GridUtils.gridCellForLevel(marker.position, level);
      buckets.putIfAbsent(
          cell.anchorKey, () => _ClusterBucket(cell, <ArtMarker>[]));
      buckets[cell.anchorKey]!.markers.add(marker);
    }

    for (final bucket in buckets.values) {
      double sumLat = 0.0;
      double sumLng = 0.0;
      for (final marker in bucket.markers) {
        sumLat += marker.position.latitude;
        sumLng += marker.position.longitude;
      }
      final count = bucket.markers.length;
      bucket.centroid = LatLng(sumLat / count, sumLng / count);
    }

    // Sort by marker count (descending): largest clusters first.
    // This improves hitbox reliability; queryRenderedFeatures().first will hit
    // the most visually prominent cluster, preventing mis-taps on smaller clusters.
    final sorted = buckets.values.toList(growable: false);
    sorted.sort((a, b) => b.markers.length.compareTo(a.markers.length));
    return sorted;
  }

  Widget _buildSearchCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final radius = KubusRadius.circular(KubusRadius.lg);
    final isDark = theme.brightness == Brightness.dark;
    final accent = context.read<ThemeProvider>().accentColor;
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.46 : 0.58);
    final hintColor = scheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: SizedBox(
          height: 48,
          child: Semantics(
            label: 'map_search_input',
            textField: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.mapSearchHint,
                  hintStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
                    color: hintColor,
                  ),
                  prefixIcon: Icon(Icons.search, color: hintColor),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: l10n.mapClearSearchTooltip,
                          icon: Icon(Icons.close, color: hintColor),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _isSearching = false;
                              _searchSuggestions = [];
                              _isFetchingSuggestions = false;
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                            });
                          },
                        )
                      : Tooltip(
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
                        ),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onTap: () {
                  setState(() => _isSearching = true);
                },
                onChanged: _handleSearchChange,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSearchChange(String value) {
    setState(() {
      _searchQuery = value;
      _isSearching = value.isNotEmpty;
    });

    _searchDebounce?.cancel();
    _perf.timerStopped('search_debounce');
    if (value.trim().length < 2) {
      setState(() {
        _searchSuggestions = [];
        _isFetchingSuggestions = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 275), () async {
      _perf.timerStopped('search_debounce');
      setState(() => _isFetchingSuggestions = true);

      try {
        _perf.recordFetch('search:suggestions');
        final suggestions = await _searchService.fetchSuggestions(
          context: context,
          query: value,
          scope: SearchScope.map,
        );
        if (!mounted) return;
        setState(() {
          _searchSuggestions = suggestions;
          _isFetchingSuggestions = false;
        });
      } catch (e) {
        AppConfig.debugPrint('MapScreen: search suggestions failed: $e');
        if (!mounted) return;
        setState(() {
          _searchSuggestions = [];
          _isFetchingSuggestions = false;
        });
      }
    });
    _perf.timerStarted('search_debounce');
  }

  Widget _buildSuggestionSheet(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final accent = context.read<ThemeProvider>().accentColor;
    final double top = MediaQuery.of(context).padding.top + 86;
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.46 : 0.58);
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: MapOverlayBlocker(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.30),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.28 : 0.16),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: radius,
            showBorder: false,
            backgroundColor: glassTint,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: Builder(builder: (context) {
                if (_searchQuery.trim().length < 2) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.mapSearchMinCharsHint,
                      style: KubusTypography.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                if (_isFetchingSuggestions) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (_searchSuggestions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.mapNoSuggestions,
                      style: KubusTypography.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchSuggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final suggestion = _searchSuggestions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.14),
                        child: Icon(
                          suggestion.icon,
                          color: accent,
                        ),
                      ),
                      title: Text(
                        suggestion.label,
                        style: KubusTypography.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      subtitle: suggestion.subtitle == null
                          ? null
                          : Text(
                              suggestion.subtitle!,
                              style:
                                  KubusTypography.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                      onTap: () => _handleSuggestionTap(suggestion),
                    );
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSuggestionTap(MapSearchSuggestion suggestion) async {
    setState(() {
      _searchQuery = suggestion.label;
      _searchController.text = suggestion.label;
      _searchSuggestions = [];
      _isSearching = false;
    });
    _searchFocusNode.unfocus();

    if (suggestion.position != null) {
      unawaited(
        _animateMapTo(
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

    Color layerAccent(ArtMarkerType type) {
      return AppColorUtils.markerSubjectColor(
        markerType: type.name,
        metadata: null,
        scheme: scheme,
        roles: roles,
      );
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
                return _glassChip(
                  label: filter['label']!,
                  icon: Icons.filter_alt_outlined,
                  selected: selected,
                  accent: filterAccent(key),
                  onTap: () => setState(() => _artworkFilter = key),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ArtMarkerType.values.map((type) {
                final selected = _markerLayerVisibility[type] ?? true;
                return _glassChip(
                  label: _markerTypeLabel(l10n, type),
                  icon: _resolveArtMarkerIcon(type),
                  selected: selected,
                  accent: layerAccent(type),
                  onTap: () =>
                      setState(() => _markerLayerVisibility[type] = !selected),
                );
              }).toList(),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
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
          padding: const EdgeInsets.all(14),
          margin: EdgeInsets.zero,
          borderRadius: radius,
          showBorder: false,
          backgroundColor: glassTint,
          child: Column(
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mapDiscoveryPathTitle,
                          style: KubusTypography.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          l10n.commonPercentComplete((overall * 100).round()),
                          style: KubusTypography.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _glassIconButton(
                    icon: _isDiscoveryExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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
                    const SizedBox(height: 10),
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

  Widget _buildPrimaryControls(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    // Keep controls clear of the discovery module and the nearby sheet.
    // Smaller bottom offset moves controls slightly down.
    final bottomOffset = 90.0 + KubusLayout.mainBottomNavBarHeight;
    return Positioned(
      right: 12,
      bottom: bottomOffset,
      child: MapOverlayBlocker(
        child: Column(
          children: [
            if (AppConfig.isFeatureEnabled('mapTravelMode')) ...[
              _MapIconButton(
                key: _tutorialTravelButtonKey,
                icon: Icons.travel_explore,
                tooltip: _travelModeEnabled
                    ? l10n.mapTravelModeDisableTooltip
                    : l10n.mapTravelModeEnableTooltip,
                active: _travelModeEnabled,
                onTap: () =>
                    unawaited(_setTravelModeEnabled(!_travelModeEnabled)),
              ),
              const SizedBox(height: 10),
            ],
            if (AppConfig.isFeatureEnabled('mapIsometricView')) ...[
              _MapIconButton(
                icon: Icons.filter_tilt_shift,
                tooltip: _isometricViewEnabled
                    ? l10n.mapIsometricViewDisableTooltip
                    : l10n.mapIsometricViewEnableTooltip,
                active: _isometricViewEnabled,
                onTap: () =>
                    unawaited(_setIsometricViewEnabled(!_isometricViewEnabled)),
              ),
              const SizedBox(height: 10),
            ],
            Semantics(
              label: 'map_zoom_in',
              button: true,
              child: _MapIconButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onTap: () {
                  final nextZoom = (_lastZoom + 1).clamp(3.0, 18.0);
                  unawaited(_animateMapTo(_cameraCenter, zoom: nextZoom));
                },
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: 'map_zoom_out',
              button: true,
              child: _MapIconButton(
                icon: Icons.remove,
                tooltip: l10n.mapEmptyZoomOutAction,
                onTap: () {
                  final nextZoom = (_lastZoom - 1).clamp(3.0, 18.0);
                  unawaited(_animateMapTo(_cameraCenter, zoom: nextZoom));
                },
              ),
            ),
            const SizedBox(height: 10),
            _MapIconButton(
              key: _tutorialCenterButtonKey,
              icon: Icons.my_location,
              tooltip: l10n.mapCenterOnMeTooltip,
              active: _autoFollow,
              onTap: _currentPosition == null
                  ? null
                  : () {
                      final enable = !_autoFollow;
                      setState(() => _autoFollow = enable);
                      if (enable) {
                        unawaited(
                          _animateMapTo(
                            _currentPosition!,
                            zoom: math.max(_lastZoom, 16),
                          ),
                        );
                      }
                    },
            ),
            const SizedBox(height: 10),
            Semantics(
              label: 'map_create_marker',
              button: true,
              child: _MapIconButton(
                key: _tutorialAddMarkerButtonKey,
                icon: Icons.add_location_alt,
                tooltip: l10n.mapAddMapMarkerTooltip,
                onTap: () => unawaited(_handleCurrentLocationTap()),
              ),
            ),
          ],
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
    final scheme = theme.colorScheme;
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
            final l10n = AppLocalizations.of(context)!;
            final isDark = theme.brightness == Brightness.dark;
            final radius = const BorderRadius.vertical(
              top: Radius.circular(KubusRadius.xl),
            );
            final glassTint =
                scheme.surface.withValues(alpha: isDark ? 0.46 : 0.56);
            final themeProvider = context.read<ThemeProvider>();
            final roles = KubusColorRoles.of(context);
            final Map<String, ArtMarker> markersById = <String, ArtMarker>{
              for (final marker in _artMarkers) marker.id: marker,
            };
            final Map<String, ArtMarker> markersByArtworkId =
                <String, ArtMarker>{
              for (final marker in _artMarkers)
                if (marker.artworkId != null && marker.artworkId!.isNotEmpty)
                  marker.artworkId!: marker,
            };

            Color subjectColorForArtwork(Artwork artwork) {
              final marker =
                  (artwork.arMarkerId != null && artwork.arMarkerId!.isNotEmpty)
                      ? markersById[artwork.arMarkerId!]
                      : markersByArtworkId[artwork.id];
              if (marker != null) {
                return _resolveArtMarkerColor(marker, themeProvider);
              }

              return AppColorUtils.markerSubjectColor(
                markerType: ArtMarkerType.artwork.name,
                metadata: <String, dynamic>{
                  if (artwork.metadata != null) ...artwork.metadata!,
                  'subjectCategory': artwork.category,
                },
                scheme: scheme,
                roles: roles,
              );
            }

            return MapOverlayBlocker(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _setSheetInteracting(true),
                onPointerUp: (_) => _setSheetInteracting(false),
                onPointerCancel: (_) => _setSheetInteracting(false),
                // Absorb mouse wheel / trackpad scroll to prevent map zoom when
                // scrolling inside the sheet (especially important on web).
                onPointerSignal: (_) {},
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {},
                  onHorizontalDragUpdate: (_) {},
                  onHorizontalDragEnd: (_) {},
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: LiquidGlassPanel(
                        padding: EdgeInsets.zero,
                        margin: EdgeInsets.zero,
                        borderRadius: BorderRadius.zero,
                        showBorder: false,
                        backgroundColor: glassTint,
                        child: CustomScrollView(
                          controller: scrollController,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Semantics(
                                        label: 'nearby_art_handle',
                                        child: Container(
                                          width: 48,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.85),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.mapNearbyArtTitle,
                                                key: _tutorialNearbyTitleKey,
                                                style: KubusTypography
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                _travelModeEnabled
                                                    ? '${l10n.mapResultsDiscoveredLabel(
                                                        artworks.length,
                                                        (discoveryProgress *
                                                                100)
                                                            .round(),
                                                      )} ${l10n.mapTravelModeStatusTravelling}'
                                                    : l10n
                                                        .mapResultsDiscoveredLabel(
                                                        artworks.length,
                                                        (discoveryProgress *
                                                                100)
                                                            .round(),
                                                      ),
                                                style: KubusTypography
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _glassIconButton(
                                          icon: Icons.radar,
                                          tooltip: _travelModeEnabled
                                              ? l10n
                                                  .mapTravelModeStatusTravellingTooltip
                                              : l10n.mapNearbyRadiusTooltip(
                                                  _effectiveMarkerRadiusKm
                                                      .toInt(),
                                                ),
                                          onTap: _travelModeEnabled
                                              ? null
                                              : _openMarkerRadiusDialog,
                                        ),
                                        const SizedBox(width: 8),
                                        _glassIconButton(
                                          icon: _useGridLayout
                                              ? Icons.view_list
                                              : Icons.grid_view,
                                          tooltip: _useGridLayout
                                              ? l10n.mapShowListViewTooltip
                                              : l10n.mapShowGridViewTooltip,
                                          onTap: () => setState(() =>
                                              _useGridLayout = !_useGridLayout),
                                        ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<_ArtworkSort>(
                                          tooltip: l10n.mapSortResultsTooltip,
                                          onSelected: (value) =>
                                              setState(() => _sort = value),
                                          itemBuilder: (context) => [
                                            for (final sort
                                                in _ArtworkSort.values)
                                              PopupMenuItem(
                                                value: sort,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                        child: Text(
                                                            sort.label(l10n))),
                                                    if (sort == _sort)
                                                      Icon(Icons.check,
                                                          color:
                                                              scheme.primary),
                                                  ],
                                                ),
                                              ),
                                          ],
                                          child: _glassIconButton(
                                            icon: Icons.sort,
                                            tooltip: l10n.mapSortResultsTooltip,
                                            onTap: null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                            if (isLoading)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (artworks.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      bottom:
                                          KubusLayout.mainBottomNavBarHeight),
                                  child: _buildEmptyState(theme),
                                ),
                              )
                            else if (_useGridLayout)
                              SliverPadding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverGrid(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final artwork = artworks[index];
                                      final subjectColor =
                                          subjectColorForArtwork(artwork);
                                      return _ArtworkListTile(
                                        artwork: artwork,
                                        currentPosition: _currentPosition,
                                        onOpenDetails: () =>
                                            _openArtwork(artwork),
                                        onMarkDiscovered: () =>
                                            _markAsDiscovered(artwork),
                                        dense: true,
                                        subjectColor: subjectColor,
                                      );
                                    },
                                    childCount: artworks.length,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.92,
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final artwork = artworks[index];
                                      final subjectColor =
                                          subjectColorForArtwork(artwork);
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _ArtworkListTile(
                                          artwork: artwork,
                                          currentPosition: _currentPosition,
                                          onOpenDetails: () =>
                                              _openArtwork(artwork),
                                          onMarkDiscovered: () =>
                                              _markAsDiscovered(artwork),
                                          subjectColor: subjectColor,
                                        ),
                                      );
                                    },
                                    childCount: artworks.length,
                                  ),
                                ),
                              ),
                            // Let content scroll above the navbar when expanded, while still
                            // allowing the sheet itself to sit behind the glass navbar.
                            const SliverToBoxAdapter(
                              child: SizedBox(
                                  height: KubusLayout.mainBottomNavBarHeight),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    return sheet;
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final teal = roles.statTeal;
    final amber = roles.statAmber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: KubusRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore_outlined,
                  size: 40,
                  color: teal,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.mapEmptyNoArtworksTitle,
                style: KubusTypography.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.mapEmptyNoArtworksDescription,
                textAlign: TextAlign.center,
                style: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EmptyStateChip(
                    icon: Icons.zoom_out_map,
                    label: l10n.mapEmptyZoomOutAction,
                    color: teal,
                  ),
                  const SizedBox(width: 8),
                  _EmptyStateChip(
                    icon: Icons.filter_alt_outlined,
                    label: l10n.mapEmptyAdjustFiltersAction,
                    color: amber,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Artwork> _filterArtworks(List<Artwork> artworks) {
    var filtered = artworks.where((a) => a.hasValidLocation).toList();
    final query = _searchQuery.trim().toLowerCase();

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
        if (_currentPosition != null) {
          filtered = filtered
              .where((artwork) =>
                  artwork.getDistanceFrom(_currentPosition!) <=
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

  List<Artwork> _sortArtworks(List<Artwork> artworks) {
    final sorted = List<Artwork>.from(artworks);
    switch (_sort) {
      case _ArtworkSort.nearest:
        if (_currentPosition != null) {
          sorted.sort((a, b) {
            final distanceA = a.getDistanceFrom(_currentPosition!);
            final distanceB = b.getDistanceFrom(_currentPosition!);
            return distanceA.compareTo(distanceB);
          });
        }
        break;
      case _ArtworkSort.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _ArtworkSort.rewards:
        sorted.sort((a, b) => b.rewards.compareTo(a.rewards));
        break;
      case _ArtworkSort.popular:
        sorted.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
    }
    return sorted;
  }

  Future<void> _openArtwork(Artwork artwork) async {
    await openArtwork(context, artwork.id, source: 'map');
  }

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
}

enum _ArtworkSort {
  nearest,
  newest,
  rewards,
  popular;

  String label(AppLocalizations l10n) {
    switch (this) {
      case _ArtworkSort.nearest:
        return l10n.mapSortNearest;
      case _ArtworkSort.newest:
        return l10n.mapSortNewest;
      case _ArtworkSort.rewards:
        return l10n.mapSortHighestRewards;
      case _ArtworkSort.popular:
        return l10n.mapSortMostViewed;
    }
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  const _MapIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = scheme.outlineVariant;
    final iconColor = active ? scheme.onPrimary : scheme.onSurface;
    final background = active
        ? scheme.primary.withValues(alpha: 0.20)
        : scheme.surface.withValues(alpha: 0.46);
    // Use rectangular radius from design tokens to match desktop parity
    final radius = BorderRadius.circular(KubusRadius.md);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: (active ? scheme.primary : borderColor)
                    .withValues(alpha: 0.40),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: isDark ? 0.20 : 0.12),
                  blurRadius: active ? 18 : 14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LiquidGlassPanel(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              borderRadius: radius,
              showBorder: false,
              backgroundColor: background,
              child: Center(
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkListTile extends StatelessWidget {
  final Artwork artwork;
  final LatLng? currentPosition;
  final VoidCallback onOpenDetails;
  final VoidCallback onMarkDiscovered;
  final bool dense;

  /// Optional subject-based accent color. If null, falls back to the shared
  /// marker subject color mapping (still deterministic and consistent).
  final Color? subjectColor;

  const _ArtworkListTile({
    required this.artwork,
    required this.currentPosition,
    required this.onOpenDetails,
    required this.onMarkDiscovered,
    this.dense = false,
    this.subjectColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(22);
    final previewHeight = dense ? 120.0 : 150.0;
    final distanceLabel = _distanceLabel(l10n);
    final isDiscovered = artwork.isDiscovered;
    final previewUrl = ArtworkMediaResolver.resolveCover(artwork: artwork);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentForArtwork(context, scheme);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.42 : 0.54);
    final accentBorder = accent.withValues(alpha: 0.22);
    final attendanceEnabled = AppConfig.isFeatureEnabled('attendance');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onOpenDetails,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: accentBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.18 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.all(14),
            margin: EdgeInsets.zero,
            borderRadius: borderRadius,
            showBorder: false,
            backgroundColor: glassTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ArtworkPreview(
                  imageUrl: previewUrl,
                  height: previewHeight,
                  borderRadius: BorderRadius.circular(18),
                ),
                const SizedBox(height: 12),
                Text(
                  artwork.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTypography.textTheme.titleSmall?.copyWith(
                    fontSize: dense ? 15 : 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.commonByArtist(artwork.artist),
                  style: KubusTypography.textTheme.bodySmall?.copyWith(
                    fontSize: dense ? 12 : 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (distanceLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.near_me,
                              size: 14,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              distanceLabel,
                              style: KubusTypography.textTheme.labelSmall
                                  ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Icon(Icons.visibility,
                        size: 18, color: accent.withValues(alpha: 0.9)),
                    const SizedBox(width: 4),
                    Text(
                      '${artwork.viewsCount}',
                      style: KubusTypography.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent.withValues(alpha: 0.16),
                          foregroundColor: scheme.onSurface,
                        ),
                        onPressed: onOpenDetails,
                        child: Text(l10n.commonViewDetails),
                      ),
                    ),
                    if (!attendanceEnabled) ...[
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        tooltip: isDiscovered
                            ? l10n.mapAlreadyDiscoveredTooltip
                            : l10n.mapMarkAsDiscoveredTooltip,
                        onPressed: isDiscovered ? null : onMarkDiscovered,
                        style: IconButton.styleFrom(
                          backgroundColor: isDiscovered
                              ? scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35)
                              : accent.withValues(alpha: 0.16),
                          foregroundColor:
                              isDiscovered ? scheme.onSurfaceVariant : accent,
                        ),
                        icon: Icon(
                          isDiscovered
                              ? Icons.check_circle
                              : Icons.flag_outlined,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _accentForArtwork(BuildContext context, ColorScheme scheme) {
    if (subjectColor != null) return subjectColor!;

    final roles = KubusColorRoles.of(context);
    return AppColorUtils.markerSubjectColor(
      markerType: ArtMarkerType.artwork.name,
      metadata: <String, dynamic>{
        if (artwork.metadata != null) ...artwork.metadata!,
        'subjectCategory': artwork.category,
      },
      scheme: scheme,
      roles: roles,
    );
  }

  String? _distanceLabel(AppLocalizations l10n) {
    if (currentPosition == null) return null;
    final meters = artwork.getDistanceFrom(currentPosition!);
    if (meters >= 1000) {
      final km = meters / 1000;
      return l10n.commonDistanceKm(km.toStringAsFixed(km >= 10 ? 0 : 1));
    }
    return l10n.commonDistanceM(meters.round().toString());
  }
}

class _EmptyStateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _EmptyStateChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KubusRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: KubusTypography.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkPreview extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final BorderRadius borderRadius;

  const _ArtworkPreview({
    required this.imageUrl,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: scheme.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined,
            size: 28, color: scheme.onSurfaceVariant),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        imageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child:
              Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
        ),
      ),
    );
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
  _ClusterBucket(this.cell, this.markers) : centroid = cell.center;
  final GridCell cell;
  final List<ArtMarker> markers;
  LatLng centroid;
}
