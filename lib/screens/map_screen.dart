import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/inline_progress.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/artwork_provider.dart';
import '../providers/task_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/themeprovider.dart';
import '../providers/navigation_provider.dart';
import '../providers/exhibitions_provider.dart';
import '../providers/presence_provider.dart';
import '../models/artwork.dart';
import '../models/task.dart';
import '../models/map_marker_subject.dart';
import '../services/task_service.dart';
import '../services/ar_integration_service.dart';
import '../services/map_marker_service.dart';
import '../services/push_notification_service.dart';
import '../services/achievement_service.dart';
import '../models/art_marker.dart';
import '../widgets/art_marker_cube.dart';
import '../widgets/artwork_creator_byline.dart';
import 'art/art_detail_screen.dart';
import 'art/ar_screen.dart';
import 'community/user_profile_screen.dart';
import '../utils/grid_utils.dart';
import '../utils/artwork_media_resolver.dart';
import '../utils/category_accent_color.dart';
import '../utils/rarity_ui.dart';
import '../utils/app_color_utils.dart';
import '../utils/map_marker_helper.dart';
import '../utils/map_marker_subject_loader.dart';
import '../utils/map_search_suggestion.dart';
import '../utils/presence_marker_visit.dart';
import '../widgets/map_marker_dialog.dart';
import '../providers/tile_providers.dart';
import '../widgets/art_map_view.dart';
import 'dart:ui' as ui;
import '../services/search_service.dart';
import '../services/backend_api_service.dart';
import '../config/config.dart';
import 'events/exhibition_detail_screen.dart';

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
    // Cone dimensions: 60° spread angle
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

  const MapScreen({
    super.key,
    this.initialCenter,
    this.initialZoom,
    this.autoFollow = true,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const String _kPrefLocationPermissionRequested =
      'map_location_permission_requested';
  static const String _kPrefLocationServiceRequested =
      'map_location_service_requested';
  // Location and Map State
  LatLng? _currentPosition;
  Location? _mobileLocation;
  Timer? _timer;
  final MapController _mapController = MapController();
  bool _autoFollow = true;
  double? _direction; // Compass direction
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<LocationData>? _mobileLocationSubscription;
  StreamSubscription<Position>? _webPositionSubscription;

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
  ArtMarker? _activeMarker;
  Timer? _proximityCheckTimer;
  StreamSubscription<ArtMarker>? _markerSocketSubscription;
  StreamSubscription<String>? _markerDeletedSubscription;
  Timer? _markerRefreshDebounce;

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
  double _markerRadiusKm = 5.0;

  // Discovery and Progress
  bool _isDiscoveryExpanded = false;
  bool _filtersExpanded = false;

  // Camera helpers
  LatLng _cameraCenter = const LatLng(46.056946, 14.505751);
  double _lastZoom = 16.0;

  final Distance _distanceCalculator = const Distance();
  LatLng? _lastMarkerFetchCenter;
  DateTime? _lastMarkerFetchTime;
  static const double _markerRefreshDistanceMeters =
      1200; // Increased to reduce API calls
  static const Duration _markerRefreshInterval =
      Duration(minutes: 5); // Increased from 150s to 5 min
  bool _isLoadingMarkers = false; // Prevent concurrent fetches

  MarkerSubjectLoader get _subjectLoader => MarkerSubjectLoader(context);

  @override
  void initState() {
    super.initState();
    _autoFollow = widget.autoFollow;
    // Load persisted permission/service request flags, then initialize map
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Track this screen visit for quick actions
      if (mounted) {
        Provider.of<NavigationProvider>(context, listen: false)
            .trackScreenVisit('map');
      }

      await _loadPersistedPermissionFlags();
      if (!mounted) return;
      _initializeMap();

      if (!mounted) return;
      if (widget.initialCenter != null) {
        _autoFollow = widget.autoFollow;
        _mapController.move(
            widget.initialCenter!, widget.initialZoom ?? _lastZoom);
      }

      // Initialize providers and calculate progress after build completes
      if (!mounted) return;
      context.read<ArtworkProvider>().loadArtworks();
      final taskProvider = context.read<TaskProvider>();
      final walletProvider = context.read<WalletProvider>();

      taskProvider.initializeProgress(); // Ensure proper initialization

      // Load real progress from backend if wallet is connected
      if (walletProvider.currentWalletAddress != null &&
          walletProvider.currentWalletAddress!.isNotEmpty) {
        debugPrint(
            'MapScreen: Loading progress from backend for wallet: ${walletProvider.currentWalletAddress}');
        await taskProvider
            .loadProgressFromBackend(walletProvider.currentWalletAddress!);
      } else {
        debugPrint(
            'MapScreen: No wallet connected, using default empty progress');
      }

      if (!mounted) return;
      _calculateProgress(); // Calculate progress after providers are ready
    });
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
      debugPrint('Error loading persisted map permission flags: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _compassSubscription?.cancel();
    _mobileLocationSubscription?.cancel();
    _webPositionSubscription?.cancel();
    _proximityCheckTimer?.cancel();
    _markerRefreshDebounce?.cancel();
    _markerSocketSubscription?.cancel();
    _markerDeletedSubscription?.cancel();
    _animationController.dispose();
    _locationIndicatorController?.dispose();
    _sheetController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    // pause polling/subscriptions while backgrounded to avoid extra prompts and conserve battery
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _timer?.cancel();
      try {
        _mobileLocationSubscription?.pause();
      } catch (_) {}
      try {
        _webPositionSubscription?.pause();
      } catch (_) {}
      _proximityCheckTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // resume polling when app returns to foreground
      _startLocationTimer();
      try {
        _mobileLocationSubscription?.resume();
      } catch (_) {}
      try {
        _webPositionSubscription?.resume();
      } catch (_) {}
      if (_proximityCheckTimer == null ||
          !(_proximityCheckTimer?.isActive ?? false)) {
        _proximityCheckTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => _checkProximityNotifications(),
        );
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  void _calculateProgress() {
    // Update task provider with current discovery progress
    final taskProvider = context.read<TaskProvider>();
    final artworkProvider = context.read<ArtworkProvider>();
    final discoveredCount = artworkProvider.artworks
        .where((artwork) => artwork.status != ArtworkStatus.undiscovered)
        .length;

    // Update local guide achievement with current discovered count
    taskProvider.updateAchievementProgress('local_guide', discoveredCount);
  }

  void _initializeMap() {
    if (!kIsWeb) {
      _mobileLocation = Location();
    }

    _getLocation();
    _startLocationTimer();

    final compassStream = FlutterCompass.events;
    if (compassStream != null) {
      _compassSubscription = compassStream.listen((CompassEvent event) {
        if (mounted) {
          _updateDirection(event.heading);
        }
      });
    }

    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _locationIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    if (!kIsWeb) {
      _subscribeToMobileLocationStream();
    } else {
      _startWebLocationStream();
    }

    // Initialize AR integration
    _initializeARIntegration();
  }

  Future<void> _initializeARIntegration() async {
    try {
      await _arIntegrationService.initialize();
      await _pushNotificationService.initialize();

      // Set up notification tap handler
      _pushNotificationService.onNotificationTap = _handleNotificationTap;

      // Load art markers from backend
      await _loadArtMarkers();
      _markerSocketSubscription =
          _mapMarkerService.onMarkerCreated.listen(_handleMarkerCreated);
      _markerDeletedSubscription =
          _mapMarkerService.onMarkerDeleted.listen(_handleMarkerDeleted);

      // Start proximity checking timer (every 10 seconds)
      _proximityCheckTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkProximityNotifications(),
      );
    } catch (e) {
      debugPrint('Error initializing AR integration: $e');
    }
  }

  Future<void> _loadArtMarkers(
      {LatLng? center, bool forceRefresh = false}) async {
    // Prevent concurrent fetches
    if (_isLoadingMarkers) {
      debugPrint('MapScreen: Skipping marker fetch - already loading');
      return;
    }

    final queryCenter = center ?? _currentPosition ?? _cameraCenter;

    try {
      _isLoadingMarkers = true;
      final result = await MapMarkerHelper.loadAndHydrateMarkers(
        context: context,
        mapMarkerService: _mapMarkerService,
        center: queryCenter,
        radiusKm: _markerRadiusKm,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _artMarkers = result.markers;
        });
      }
      _lastMarkerFetchCenter = result.center;
      _lastMarkerFetchTime = result.fetchedAt;

      debugPrint('Loaded ${result.markers.length} art markers from backend');
    } catch (e) {
      debugPrint('Error loading art markers from backend: $e');
    } finally {
      _isLoadingMarkers = false;
    }
  }

  void _handleMarkerCreated(ArtMarker marker) {
    try {
      if (!marker.hasValidPosition) return;
      if (_currentPosition != null) {
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
      debugPrint('MapScreen: added marker from socket ${marker.id}');
    } catch (e) {
      debugPrint('MapScreen: failed to handle socket marker: $e');
    }
  }

  void _handleMarkerDeleted(String markerId) {
    try {
      setState(() {
        _artMarkers.removeWhere((m) => m.id == markerId);
      });
    } catch (_) {}
  }

  void _handleNotificationTap(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'ar_proximity') {
        final markerId = data['markerId'] as String?;
        if (markerId != null) {
          final marker = _artMarkers.firstWhere(
            (m) => m.id == markerId,
            orElse: () => _artMarkers.first,
          );
          _showArtMarkerDialog(marker);
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  Future<void> _maybeRefreshMarkers(LatLng center, {bool force = false}) async {
    // Skip if already loading
    if (_isLoadingMarkers) return;

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
      debugPrint('MapScreen: Refreshing markers (force=$force)');
      await _loadArtMarkers(center: center, forceRefresh: force);
    }
  }

  void _checkProximityNotifications() {
    if (_currentPosition == null) return;

    final currentLatLng = _currentPosition!;

    for (final marker in _artMarkers) {
      // Check if already notified
      if (_notifiedMarkers.contains(marker.id)) continue;

      // Calculate distance
      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        currentLatLng,
        marker.position,
      );

      // Notify if within 50 meters
      if (distance <= 50) {
        _showProximityNotification(marker, distance);
        _notifiedMarkers.add(marker.id);
      }
    }

    // Clean up notifications for markers we've moved away from (>100m)
    _notifiedMarkers.removeWhere((markerId) {
      final marker = _artMarkers.firstWhere(
        (m) => m.id == markerId,
        orElse: () => _artMarkers.first,
      );

      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        currentLatLng,
        marker.position,
      );

      return distance > 100; // Reset notification if moved far away
    });
  }

  void _queueMarkerRefresh(LatLng center, {required bool fromGesture}) {
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

    _markerRefreshDebounce?.cancel();
    // Use longer debounce for gestures to avoid spam during panning
    final debounceTime = fromGesture
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 800);

    _markerRefreshDebounce = Timer(debounceTime, () {
      _markerRefreshDebounce = null;
      unawaited(_maybeRefreshMarkers(center, force: false));
    });
  }

  Future<void> _openMarkerRadiusDialog() async {
    double tempRadius = _markerRadiusKm;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.mapNearbyRadiusTitle),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.commonDistanceKm(tempRadius.toStringAsFixed(1))),
                  Slider(
                    min: 1,
                    max: 50,
                    divisions: 49,
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

    // On web the push channel requires a service worker; skip if unsupported to avoid console spam.
    if (!kIsWeb) {
      _pushNotificationService
          .showARProximityNotification(
        marker: marker,
        distance: distance,
      )
          .catchError((e) {
        debugPrint('MapScreen: showARProximityNotification failed: $e');
      });
    }

    // Also show in-app SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.view_in_ar,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.mapArArtworkNearbyTitle,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    l10n.mapArArtworkNearbySubtitle(
                        marker.name, distance.round()),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.commonView,
          textColor: Colors.white,
          onPressed: () => _launchARExperience(marker),
        ),
      ),
    );
  }

  void _handleMarkerTap(ArtMarker marker) {
    _maybeRecordPresenceVisitForMarker(marker);
    setState(() => _activeMarker = marker);
    if (marker.isExhibitionMarker) return;
    _ensureLinkedArtworkLoaded(marker);
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
      context.read<PresenceProvider>().recordVisit(type: visit.type, id: visit.id);
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
      if (_activeMarker?.id == marker.id) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
          'MapScreen: failed to load linked artwork $artworkId for marker ${marker.id}: $e');
    }
  }

  void _showArtMarkerDialog(ArtMarker marker) {
    // For compatibility with legacy calls: center and show inline overlay
    _handleMarkerTap(marker);
    _mapController.move(
        marker.position, math.max(_mapController.camera.zoom, 15));
  }

  Future<void> _launchARExperience(ArtMarker marker) async {
    try {
      // Navigate to AR screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ARScreen(),
        ),
      );
    } catch (e) {
      debugPrint('Error launching AR experience: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.mapFailedToLaunchAr),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _resolveArtMarkerColor(ArtMarker marker, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    // Delegate to centralized marker color utility for consistency with desktop
    return AppColorUtils.markerSubjectColor(
      markerType: marker.type.name,
      metadata: marker.metadata,
      scheme: scheme,
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
    return _subjectLoader.snapshot();
  }

  Future<MarkerSubjectData?> _refreshMarkerSubjectData({bool force = false}) {
    return _subjectLoader.refresh(force: force);
  }

  Future<void> _startMarkerCreationFlow() async {
    if (_currentPosition == null) return;
    final refreshed = await _refreshMarkerSubjectData(force: true);
    if (!mounted) return;
    final subjectData = refreshed ?? _snapshotMarkerSubjectData();

    final l10n = AppLocalizations.of(context)!;
    final wallet = context.read<WalletProvider>().currentWalletAddress;
    if (wallet == null || wallet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.mapMarkerCreateWalletRequired,
            style: GoogleFonts.outfit(),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.mapMarkerCreatedToast,
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadArtMarkers(forceRefresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.mapMarkerCreateFailedToast,
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _createMarkerAtCurrentLocation(MapMarkerFormResult form) async {
    if (_currentPosition == null) return false;

    try {
      final exhibitionsProvider = context.read<ExhibitionsProvider>();

      // Snap to the nearest grid cell center at the current zoom level
      // We use the current camera zoom to determine which grid level is most relevant
      final double currentZoom = _mapController.camera.zoom;
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
        debugPrint('Marker created and saved: ${marker.id}');

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
        debugPrint('Failed to create marker: returned null');
      }

      return false;
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message,
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      debugPrint('MapScreen: duplicate marker prevented: $e');
      return false;
    } catch (e) {
      debugPrint('Error creating marker at current location: $e');
      return false;
    }
  }

  Future<void> _getLocation(
      {bool fromTimer = false, bool promptForPermission = true}) async {
    try {
      LatLng? resolvedPosition;
      final prefs = await SharedPreferences.getInstance();

      if (kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('MapScreen: Location services disabled on web');
          resolvedPosition = _loadFallbackPosition(prefs);
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          if (!promptForPermission) {
            debugPrint(
                'MapScreen: Location permission denied on web; using fallback if available');
            resolvedPosition ??= _loadFallbackPosition(prefs);
          } else {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              debugPrint('MapScreen: Location permission denied on web');
              resolvedPosition ??= _loadFallbackPosition(prefs);
            }
          }
        }

        if (permission == LocationPermission.deniedForever) {
          debugPrint(
              'MapScreen: Location permission permanently denied on web');
          resolvedPosition ??= _loadFallbackPosition(prefs);
        }

        if (resolvedPosition == null) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
          );
          resolvedPosition = LatLng(position.latitude, position.longitude);
        }
      } else {
        _mobileLocation ??= Location();

        // Avoid requesting service repeatedly: only request once while in-memory flag is false
        bool serviceEnabled = await _mobileLocation!.serviceEnabled();
        if (!serviceEnabled) {
          if (!promptForPermission) {
            debugPrint(
                'MapScreen: Location service disabled; skipping prompt due to promptForPermission=false');
            resolvedPosition ??= _loadFallbackPosition(prefs);
            if (resolvedPosition == null) return;
          } else {
            if (!_locationServiceRequested) {
              _locationServiceRequested = true;
              try {
                await prefs.setBool(_kPrefLocationServiceRequested, true);
              } catch (e) {
                debugPrint(
                    'Failed to persist location service requested flag: ');
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
              debugPrint(
                  'MapScreen: Location service disabled (previously requested).');
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
            debugPrint(
                'MapScreen: Location permission denied; skipping request due to promptForPermission=false');
            resolvedPosition ??= _loadFallbackPosition(prefs);
            if (resolvedPosition == null) return;
          }

          if (!_locationPermissionRequested) {
            _locationPermissionRequested = true;
            try {
              await prefs.setBool(_kPrefLocationPermissionRequested, true);
            } catch (e) {
              debugPrint('Failed to persist permission-requested flag: $e');
            }

            permissionGranted = await _mobileLocation!.requestPermission();

            if (permissionGranted == PermissionStatus.granted) {
              try {
                await prefs.setBool(_kPrefLocationPermissionRequested, false);
              } catch (_) {}
              _locationPermissionRequested = false;
            }
          } else {
            // already requested permission once — don't re-request repeatedly
            debugPrint(
                'MapScreen: Permission denied and previously requested; skipping further requests.');
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
        }
      }

      if (resolvedPosition != null) {
        try {
          await prefs.setDouble('last_known_lat', resolvedPosition.latitude);
          await prefs.setDouble('last_known_lng', resolvedPosition.longitude);
        } catch (_) {}
        final shouldCenter = !fromTimer;
        _updateCurrentPosition(resolvedPosition, shouldCenter: shouldCenter);
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
      debugPrint('Error getting location: $e');
    }
  }

  void _startLocationTimer() {
    _timer?.cancel();
    // Only start when app is in foreground
    if (_lastLifecycleState == AppLifecycleState.paused ||
        _lastLifecycleState == AppLifecycleState.inactive) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _getLocation(fromTimer: true, promptForPermission: false);
    });
  }

  void _subscribeToMobileLocationStream() {
    if (kIsWeb || _mobileLocation == null) {
      return;
    }
    _mobileLocationSubscription?.cancel();
    try {
      _mobileLocationSubscription =
          _mobileLocation!.onLocationChanged.listen((event) {
        if (event.latitude != null && event.longitude != null) {
          _updateCurrentPosition(
            LatLng(event.latitude!, event.longitude!),
          );
        }
      });
    } catch (e) {
      debugPrint(
          'MapScreen: Failed to subscribe to mobile location stream: $e');
    }
  }

  void _startWebLocationStream() {
    if (!kIsWeb) {
      return;
    }
    _webPositionSubscription?.cancel();
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
        );
      });
    } catch (e) {
      debugPrint('MapScreen: Unable to start web location stream: $e');
    }
  }

  void _animateMapTo(LatLng center,
      {double? zoom,
      double? rotation,
      Duration duration = const Duration(milliseconds: 420)}) {
    final double targetZoom = zoom ?? _mapController.camera.zoom;
    final double targetRotation = rotation ?? _mapController.camera.rotation;
    try {
      final dynamic controller = _mapController;
      controller.moveAndRotateAnimatedRaw(
        center,
        targetZoom,
        targetRotation,
        offset: Offset.zero,
        duration: duration,
        curve: Curves.easeOutCubic,
        hasGesture: false,
        source: MapEventSource.mapController,
      );
    } catch (_) {
      _mapController.move(center, targetZoom);
      if (rotation != null) {
        _mapController.rotate(targetRotation);
      }
    }
  }

  void _updateCurrentPosition(LatLng position, {bool shouldCenter = false}) {
    if (!mounted) return;
    final bool isInitial = _currentPosition == null;
    final bool allowCenter = shouldCenter || _autoFollow || isInitial;

    setState(() {
      _currentPosition = position;
    });

    if (allowCenter) {
      final double targetZoom = isInitial ? 18.0 : _mapController.camera.zoom;
      final double? rotation = _autoFollow ? _direction : null;
      _animateMapTo(position, zoom: targetZoom, rotation: rotation);
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
        _animateMapTo(_currentPosition!,
            zoom: _mapController.camera.zoom, rotation: heading);
      } else if (_autoFollow) {
        _mapController.rotate(heading);
      }
    } else if (mounted && heading == null) {
      // Animate back to dot when stationary
      _locationIndicatorController?.reverse();
    }
  }

  Future<void> _markAsDiscovered(Artwork artwork) async {
    context
        .read<ArtworkProvider>()
        .discoverArtwork(artwork.id, 'current_user_id');

    // Get user ID
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'demo_user';
    if (!mounted) return;

    // Get discovered artwork count
    final artworkProvider = context.read<ArtworkProvider>();
    final discoveredCount =
        artworkProvider.artworks.where((a) => a.isDiscovered).length;

    // Check achievements with new service
    await AchievementService().checkAchievements(
      userId: userId,
      action: 'artwork_discovered',
      data: {'discoverCount': discoveredCount},
    );

    // If AR artwork, also check AR view achievements
    if (artwork.arEnabled) {
      await AchievementService().checkAchievements(
        userId: userId,
        action: 'ar_viewed',
        data: {'viewCount': discoveredCount},
      );
    }
    if (!mounted) return;

    // Legacy achievement system (for backward compatibility)
    final taskProvider = context.read<TaskProvider>();
    taskProvider.incrementAchievementProgress('local_guide');
    if (artwork.arEnabled) {
      taskProvider.incrementAchievementProgress('first_ar_visit');
      taskProvider.incrementAchievementProgress('ar_collector');
    }

    setState(() {
      _calculateProgress();
    });

    _showDiscoveryRewardForArtwork(artwork);
  }

  void _showDiscoveryRewardForArtwork(Artwork artwork) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              l10n.mapArtDiscoveredTitle,
              style:
                  GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
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
                color: RarityUi.artworkColor(context, artwork.rarity),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                artwork.arEnabled ? Icons.view_in_ar : Icons.palette,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              artwork.title,
              style:
                  GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: ArtworkCreatorByline(
                artwork: artwork,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    l10n.commonKub8PointsReward(artwork.rewards),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
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
            child:
                Text(l10n.commonContinueExploring, style: GoogleFonts.outfit()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtDetailScreen(artworkId: artwork.id),
                ),
              );
            },
            child: Text(l10n.commonViewDetails, style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final artworkProvider = Provider.of<ArtworkProvider>(context);
    final taskProvider = Provider.of<TaskProvider?>(context);

    final artworks = artworkProvider.artworks;
    final filteredArtworks = _sortArtworks(_filterArtworks(artworks));
    final discoveryProgress = taskProvider?.getOverallProgress() ?? 0.0;
    final isLoadingArtworks = artworkProvider.isLoading('load_artworks');

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(themeProvider),
          _buildTopOverlays(theme, taskProvider),
          _buildPrimaryControls(theme),
          _buildBottomSheet(
            theme,
            filteredArtworks,
            discoveryProgress,
            isLoadingArtworks,
          ),
          if (_isSearching) _buildSuggestionSheet(theme),
        ],
      ),
    );
  }

  Widget _buildMap(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    // TileProviders centralizes tile logic (tiles + optional grid overlay).
    // Use devicePixelRatio to determine retina vs non-retina tile streams.
    final tileProviders = Provider.of<TileProviders?>(context, listen: false);
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final bool isRetina = devicePixelRatio >= 2.0;
    return ArtMapView(
      mapController: _mapController,
      initialCenter: _currentPosition ?? _cameraCenter,
      initialZoom: _lastZoom,
      minZoom: 3.0,
      maxZoom: 20.0,
      isDarkMode: isDark,
      isRetina: isRetina,
      tileProviders: tileProviders,
      markers: _buildMarkers(themeProvider),
      onMapReady: () {
        if (_currentPosition != null) {
          _mapController.move(_currentPosition!, _lastZoom);
        }
      },
      onPositionChanged: (camera, hasGesture) {
        _cameraCenter = camera.center;
        _lastZoom = camera.zoom;
        if (hasGesture && _autoFollow) {
          setState(() => _autoFollow = false);
        }
        if (hasGesture && _activeMarker != null) {
          setState(() => _activeMarker = null);
        }
        _queueMarkerRefresh(camera.center, fromGesture: hasGesture);
      },
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.pinchZoom |
            InteractiveFlag.drag |
            InteractiveFlag.doubleTapZoom |
            InteractiveFlag.flingAnimation |
            InteractiveFlag.pinchMove |
            InteractiveFlag.scrollWheelZoom |
            InteractiveFlag.rotate,
      ),
    );
  }

  List<Marker> _buildMarkers(ThemeProvider themeProvider) {
    final markers = <Marker>[];
    final locationController = _locationIndicatorController;

    if (_currentPosition != null) {
      // If controller is initialized, use animated version; otherwise show static dot
      if (locationController != null) {
        markers.add(
          Marker(
            point: _currentPosition!,
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => unawaited(_handleCurrentLocationTap()),
              child: AnimatedBuilder(
                animation: locationController,
                builder: (context, child) {
                  final animValue = locationController.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Direction cone (visible when stationary, fades out when moving)
                      if (_direction != null)
                        Opacity(
                          opacity: (1.0 - animValue) * 0.6,
                          child: Transform.rotate(
                            angle: (_direction! * math.pi) / 180,
                            child: CustomPaint(
                              size: const Size(60, 80),
                              painter: DirectionConePainter(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ),
                        ),
                      // Stationary dot (fades out as we move)
                      Opacity(
                        opacity: 1.0 - animValue,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColorUtils.greenAccent
                                .withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColorUtils.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Navigation icon (fades in as we move, rotates with heading)
                      Opacity(
                        opacity: animValue,
                        child: _direction != null
                            ? Transform.rotate(
                                angle: (_direction! * math.pi) / 180,
                                child: Icon(
                                  Icons.navigation,
                                  size: 24,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      } else {
        // Fallback: show static dot while controller initializes
        markers.add(
          Marker(
            point: _currentPosition!,
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => unawaited(_handleCurrentLocationTap()),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColorUtils.greenAccent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColorUtils.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    // Group markers for clustering when zoomed out
    final zoom = _lastZoom;
    final shouldCluster = zoom < 12.0;
    final List<Marker> markerWidgets = [];

    if (shouldCluster) {
      // Cluster markers when zoomed out
      final clusters = _clusterMarkers(
          _artMarkers
              .where((m) => _markerLayerVisibility[m.type] ?? true)
              .toList(),
          zoom);
      for (final cluster in clusters) {
        if (cluster.markers.length == 1) {
          final marker = cluster.markers.first;
          markerWidgets.add(_buildSingleMarker(marker, themeProvider, zoom));
        } else {
          markerWidgets.add(_buildClusterMarker(cluster, themeProvider, zoom));
        }
      }
    } else {
      // Show individual markers when zoomed in
      markerWidgets.addAll(
        _artMarkers.where((marker) {
          return _markerLayerVisibility[marker.type] ?? true;
        }).map((marker) => _buildSingleMarker(marker, themeProvider, zoom)),
      );
    }

    markers.addAll(markerWidgets);

    if (_activeMarker != null) {
      final marker = _activeMarker!;
      final artwork = marker.isExhibitionMarker
          ? null
          : context
              .read<ArtworkProvider>()
              .getArtworkById(marker.artworkId ?? '');

      final l10n = AppLocalizations.of(context)!;
      final primaryExhibition = marker.resolvedExhibitionSummary;
      final exhibitionsFeatureEnabled =
          AppConfig.isFeatureEnabled('exhibitions');
      final exhibitionsApiAvailable =
          BackendApiService().exhibitionsApiAvailable;
      final canPresentExhibition = exhibitionsFeatureEnabled &&
          primaryExhibition != null &&
          primaryExhibition.id.isNotEmpty &&
          exhibitionsApiAvailable != false;

      final exhibitionTitle = (primaryExhibition?.title ?? '').trim();
      final effectiveTitle = canPresentExhibition && exhibitionTitle.isNotEmpty
          ? exhibitionTitle
          : (artwork?.title.isNotEmpty == true ? artwork!.title : marker.name);

      final description = marker.description.isNotEmpty
          ? marker.description
          : (artwork?.description ?? '');

      final hasChips =
          _hasMetadataChips(marker, artwork) || canPresentExhibition;
      final buttonLabel =
          canPresentExhibition ? 'Odpri razstavo' : l10n.commonViewDetails;

      final containerHeight = _computeMobileMarkerHeight(
        title: effectiveTitle,
        distanceText: () {
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
        }(),
        description: description,
        hasChips: hasChips,
        buttonLabel: buttonLabel,
        showTypeLabel: canPresentExhibition,
      );

      // Include small buffer for translate and to avoid clipping shadows
      final markerHeight = containerHeight + 32;

      markers.add(
        Marker(
          point: marker.position,
          width: 260,
          height: markerHeight,
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(0, -containerHeight / 2),
            child: _buildMarkerOverlay(marker, artwork, themeProvider),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildTopOverlays(ThemeData theme, TaskProvider? taskProvider) {
    final topPadding = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchCard(theme),
                const SizedBox(height: 12),
                if (_filtersExpanded) ...[
                  _buildFilterPanel(theme),
                  const SizedBox(height: 12),
                ],
                _buildDiscoveryCard(theme, taskProvider),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMarkerOverlay(
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
    final imageUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: marker.metadata,
    );

    // Use artwork title if available, otherwise marker name
    final displayTitle = canPresentExhibition && exhibitionTitle.isNotEmpty
        ? exhibitionTitle
        : (artwork?.title.isNotEmpty == true ? artwork!.title : marker.name);
    final description = marker.description.isNotEmpty
        ? marker.description
        : (artwork?.description ?? '');

    final showChips =
        _hasMetadataChips(marker, artwork) || canPresentExhibition;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: baseColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
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
                          'Razstava',
                          style: GoogleFonts.outfit(
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
                        style: GoogleFonts.outfit(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me, size: 10, color: baseColor),
                        const SizedBox(width: 3),
                        Text(
                          distanceText,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: baseColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                InkWell(
                  onTap: () => setState(() => _activeMarker = null),
                  borderRadius: BorderRadius.circular(4),
                  child: Icon(Icons.close,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 100,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      )
                    : _markerImageFallback(baseColor, scheme, marker),
              ),
            ),
            // Description (only if available)
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description.length > 150
                    ? '${description.substring(0, 150)}...'
                    : description,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            // Metadata chips
            if (showChips) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (canPresentExhibition)
                    _attendanceProofChip(scheme, baseColor),
                  if (artwork != null &&
                      artwork.category.isNotEmpty &&
                      artwork.category != 'General')
                    _overlayChip(
                        scheme, Icons.palette, artwork.category, baseColor),
                  if (marker.metadata?['subjectCategory'] != null ||
                      marker.metadata?['subject_category'] != null)
                    _overlayChip(
                      scheme,
                      Icons.category_outlined,
                      (marker.metadata!['subjectCategory'] ??
                              marker.metadata!['subject_category'])
                          .toString(),
                      baseColor,
                    ),
                  if (artwork != null && artwork.rewards > 0)
                    _overlayChip(
                      scheme,
                      Icons.card_giftcard,
                      '+${artwork.rewards}',
                      baseColor,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            // Action button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: baseColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: canPresentExhibition
                    ? () => _openExhibitionFromMarker(
                        marker, primaryExhibition, artwork)
                    : () => _openMarkerDetail(marker, artwork),
                icon: Icon(
                  canPresentExhibition
                      ? Icons.museum_outlined
                      : Icons.arrow_forward,
                  size: 16,
                ),
                label: Text(
                  canPresentExhibition
                      ? 'Odpri razstavo'
                      : l10n.commonViewDetails,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
          ],
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
    const double cardWidth = 240;
    const double horizontalPadding = 12;
    const double verticalPadding = 12;
    final double contentWidth = cardWidth - (horizontalPadding * 2);

    // Optional type label height (e.g. "Razstava")
    double typeLabelHeight = 0;
    if (showTypeLabel) {
      final typeLabelPainter = TextPainter(
        text: TextSpan(
          text: 'Razstava',
          style: GoogleFonts.outfit(
            fontSize: 10,
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
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 14,
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
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentWidth);
      distanceBadgeHeight = (distancePainter.size.height).clamp(10, 20) + 4;
    }

    // Close icon height (18)
    const double closeIconHeight = 18;
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
          style: GoogleFonts.outfit(
            fontSize: 11,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: contentWidth);
      descriptionHeight = descriptionPainter.size.height;
    }

    // Chips height
    final double chipsHeight = hasChips ? 24.0 : 0.0;

    // Button height (text + padding *2)
    final buttonTextPainter = TextPainter(
      text: TextSpan(
        text: buttonLabel,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double buttonHeight = buttonTextPainter.size.height + (8 * 2);

    // Spacing between sections
    double spacing = 0;
    spacing += 10; // after header
    spacing += 10; // after image
    if (descriptionHeight > 0) spacing += 10;
    if (chipsHeight > 0) spacing += 10;
    spacing += 10; // before button

    final double containerHeight = verticalPadding * 2 +
        headerHeight +
        100 +
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

  Widget _overlayChip(
      ColorScheme scheme, IconData icon, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.outfit(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _attendanceProofChip(ColorScheme scheme, Color accent) {
    return Tooltip(
      message:
          'POAP (Proof of Attendance Protocol) je zbirateljski digitalni dokaz obiska.',
      child: _overlayChip(
          scheme, Icons.verified_outlined, 'digitalni dokaz obiska', accent),
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

  Future<void> _openExhibitionFromMarker(
    ArtMarker marker,
    ExhibitionSummaryDto? exhibition,
    Artwork? artwork,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
          const SnackBar(content: Text('Razstave trenutno niso na voljo.')),
        );
        setState(() {});
        return;
      }
      await _openMarkerDetail(marker, artwork);
      return;
    }

    final fetched = await (() async {
      try {
        return await exhibitionsProvider.fetchExhibition(resolved.id, force: true);
      } catch (_) {
        return null;
      }
    })();

    if (!mounted) return;

    if (fetched == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Razstave trenutno niso na voljo.')),
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
        builder: (_) => ExhibitionDetailScreen(exhibitionId: resolved.id),
      ),
    );
  }

  Future<void> _openMarkerDetail(ArtMarker marker, Artwork? artwork) async {
    setState(() => _activeMarker = marker);

    Artwork? resolvedArtwork = artwork;
    final artworkId = marker.isExhibitionMarker ? null : marker.artworkId;
    if (resolvedArtwork == null && artworkId != null && artworkId.isNotEmpty) {
      try {
        final artworkProvider = context.read<ArtworkProvider>();
        await artworkProvider.fetchArtworkIfNeeded(artworkId);
        resolvedArtwork = artworkProvider.getArtworkById(artworkId);
      } catch (e) {
        debugPrint(
            'MapScreen: failed to fetch artwork $artworkId for marker ${marker.id}: $e');
      }
    }

    if (!mounted) return;

    if (resolvedArtwork == null) {
      await _showMarkerInfoFallback(marker);
      return;
    }

    final artworkToOpen = resolvedArtwork;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtDetailScreen(artworkId: artworkToOpen.id),
      ),
    );
  }

  Future<void> _showMarkerInfoFallback(ArtMarker marker) async {
    final l10n = AppLocalizations.of(context)!;
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

  Marker _buildSingleMarker(
      ArtMarker marker, ThemeProvider themeProvider, double zoom) {
    final double scale = (zoom / 15.0).clamp(0.5, 1.5);
    final double cubeSize = 46 * scale;
    final double markerWidth = 56 * scale;
    final double markerHeight = 72 * scale;
    return Marker(
      point: marker.position,
      width: markerWidth,
      height: markerHeight,
      child: GestureDetector(
        onTap: () => _handleMarkerTap(marker),
        child: ArtMarkerCube(
          marker: marker,
          size: cubeSize,
          baseColor: _resolveArtMarkerColor(marker, themeProvider),
          icon: _resolveArtMarkerIcon(marker.type),
        ),
      ),
    );
  }

  Marker _buildClusterMarker(
      _ClusterBucket cluster, ThemeProvider themeProvider, double zoom) {
    final double scale = (zoom / 15.0).clamp(0.5, 1.5);
    final double clusterSize = 60 * scale;
    final Color dominantColor =
        _resolveArtMarkerColor(cluster.markers.first, themeProvider);

    return Marker(
      point: cluster.center,
      width: clusterSize,
      height: clusterSize,
      child: GestureDetector(
        onTap: () {
          _mapController.move(cluster.center, math.min(zoom + 2, 18.0));
        },
        child: Container(
          decoration: BoxDecoration(
            color: dominantColor.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              cluster.markers.length.toString(),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_ClusterBucket> _clusterMarkers(List<ArtMarker> markers, double zoom) {
    if (markers.isEmpty) return [];

    // Clustering distance in degrees (larger distance for lower zoom levels)
    final clusterDistance = 0.01 * math.pow(2, 15 - zoom);
    final List<_ClusterBucket> clusters = [];

    for (final marker in markers) {
      bool addedToCluster = false;
      for (final cluster in clusters) {
        final distance = _distanceCalculator.as(
          LengthUnit.Meter,
          marker.position,
          cluster.center,
        );
        if (distance < clusterDistance * 111000) {
          // Convert degrees to meters
          cluster.markers.add(marker);
          // Recalculate center
          double sumLat = 0;
          double sumLng = 0;
          for (final m in cluster.markers) {
            sumLat += m.position.latitude;
            sumLng += m.position.longitude;
          }
          cluster.center = LatLng(
            sumLat / cluster.markers.length,
            sumLng / cluster.markers.length,
          );
          addedToCluster = true;
          break;
        }
      }
      if (!addedToCluster) {
        clusters.add(_ClusterBucket(
          marker.position,
          [marker],
        ));
      }
    }
    return clusters;
  }

  Widget _buildSearchCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.outfit(),
        decoration: InputDecoration(
          hintText: l10n.mapSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: l10n.mapClearSearchTooltip,
                  icon: const Icon(Icons.close),
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
              : IconButton(
                  icon: Icon(
                    _filtersExpanded ? Icons.filter_alt_off : Icons.filter_alt,
                  ),
                  tooltip: _filtersExpanded
                      ? l10n.mapHideFiltersTooltip
                      : l10n.mapShowFiltersTooltip,
                  onPressed: () {
                    setState(() {
                      _filtersExpanded = !_filtersExpanded;
                    });
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        ),
        onTap: () {
          setState(() => _isSearching = true);
        },
        onChanged: _handleSearchChange,
      ),
    );
  }

  void _handleSearchChange(String value) {
    setState(() {
      _searchQuery = value;
      _isSearching = value.isNotEmpty;
    });

    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchSuggestions = [];
        _isFetchingSuggestions = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 275), () async {
      setState(() => _isFetchingSuggestions = true);

      try {
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
        debugPrint('Search suggestions failed: $e');
        if (!mounted) return;
        setState(() {
          _searchSuggestions = [];
          _isFetchingSuggestions = false;
        });
      }
    });
  }

  Widget _buildSuggestionSheet(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final double top = MediaQuery.of(context).padding.top + 86;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        color: scheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: Builder(builder: (context) {
            if (_searchQuery.trim().length < 2) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.mapSearchMinCharsHint,
                  style: GoogleFonts.outfit(
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
                  style: GoogleFonts.outfit(
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
                color: scheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final suggestion = _searchSuggestions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    child: Icon(
                      suggestion.icon,
                      color: scheme.primary,
                    ),
                  ),
                  title: Text(
                    suggestion.label,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  subtitle: suggestion.subtitle == null
                      ? null
                      : Text(
                          suggestion.subtitle!,
                          style: GoogleFonts.outfit(
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
      _mapController.move(suggestion.position!, math.max(_lastZoom, 16.0));
    }

    if (!mounted) return;
    if (suggestion.type == 'artwork' && suggestion.id != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArtDetailScreen(artworkId: suggestion.id!),
        ),
      );
    } else if (suggestion.type == 'profile' && suggestion.id != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: suggestion.id!),
        ),
      );
    }
  }

  Widget _buildFilterPanel(ThemeData theme) {
    if (!_filtersExpanded) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final filters = <Map<String, String>>[
      {'key': 'all', 'label': l10n.mapFilterAllNearby},
      {'key': 'nearby', 'label': l10n.mapFilterWithin1Km},
      {'key': 'discovered', 'label': l10n.mapFilterDiscovered},
      {'key': 'undiscovered', 'label': l10n.mapFilterUndiscovered},
      {'key': 'ar', 'label': l10n.mapFilterArEnabled},
      {'key': 'favorites', 'label': l10n.mapFilterFavorites},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.mapFiltersTitle,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((filter) {
            final key = filter['key']!;
            final selected = _artworkFilter == key;
            return ChoiceChip(
              label: Text(filter['label']!),
              selected: selected,
              onSelected: (_) {
                setState(() => _artworkFilter = key);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.mapLayersTitle,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ArtMarkerType.values.map((type) {
            final selected = _markerLayerVisibility[type] ?? true;
            return FilterChip(
              label: Text(_markerTypeLabel(l10n, type)),
              selected: selected,
              onSelected: (value) {
                setState(() => _markerLayerVisibility[type] = value);
              },
            );
          }).toList(),
        ),
      ],
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InlineProgress(
                progress: overall,
                rows: 3,
                cols: 5,
                color: scheme.primary,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mapDiscoveryPathTitle,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      l10n.commonPercentComplete((overall * 100).round()),
                      style: GoogleFonts.outfit(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isDiscoveryExpanded
                    ? l10n.commonCollapse
                    : l10n.commonExpand,
                onPressed: () => setState(
                    () => _isDiscoveryExpanded = !_isDiscoveryExpanded),
                icon: Icon(
                  _isDiscoveryExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
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
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
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
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
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
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryControls(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      right: 16,
      bottom: 150,
      child: Column(
        children: [
          _MapIconButton(
            icon: Icons.my_location,
            tooltip: l10n.mapCenterOnMeTooltip,
            active: _autoFollow,
            onTap: _currentPosition == null
                ? null
                : () {
                    setState(() => _autoFollow = true);
                    _mapController.move(
                      _currentPosition!,
                      math.max(_lastZoom, 16),
                    );
                  },
          ),
          const SizedBox(height: 12),
          _MapIconButton(
            icon: Icons.add_location_alt,
            tooltip: l10n.mapAddMapMarkerTooltip,
            onTap: () => unawaited(_startMarkerCreationFlow()),
          ),
        ],
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
    return Align(
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.1,
        minChildSize: 0.1,
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.2, 0.45, 0.85],
        builder: (context, scrollController) {
          final l10n = AppLocalizations.of(context)!;
          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 4,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.mapNearbyArtTitle,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  l10n.mapResultsDiscoveredLabel(
                                    artworks.length,
                                    (discoveryProgress * 100).round(),
                                  ),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: l10n.mapNearbyRadiusTooltip(
                                  _markerRadiusKm.toInt()),
                              onPressed: _openMarkerRadiusDialog,
                              icon: const Icon(Icons.radar),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: _useGridLayout
                                  ? l10n.mapShowListViewTooltip
                                  : l10n.mapShowGridViewTooltip,
                              onPressed: () => setState(
                                  () => _useGridLayout = !_useGridLayout),
                              icon: Icon(
                                _useGridLayout
                                    ? Icons.view_list
                                    : Icons.grid_view,
                              ),
                            ),
                            PopupMenuButton<_ArtworkSort>(
                              tooltip: l10n.mapSortResultsTooltip,
                              onSelected: (value) =>
                                  setState(() => _sort = value),
                              itemBuilder: (context) => [
                                for (final sort in _ArtworkSort.values)
                                  PopupMenuItem(
                                    value: sort,
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(sort.label(l10n))),
                                        if (sort == _sort)
                                          Icon(Icons.check,
                                              color: scheme.primary),
                                      ],
                                    ),
                                  ),
                              ],
                              icon: const Icon(Icons.sort),
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
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (artworks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(theme),
                  )
                else if (_useGridLayout)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final artwork = artworks[index];
                          return _ArtworkListTile(
                            artwork: artwork,
                            currentPosition: _currentPosition,
                            onOpenDetails: () => _openArtwork(artwork),
                            onMarkDiscovered: () => _markAsDiscovered(artwork),
                            dense: true,
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final artwork = artworks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ArtworkListTile(
                              artwork: artwork,
                              currentPosition: _currentPosition,
                              onOpenDetails: () => _openArtwork(artwork),
                              onMarkDiscovered: () =>
                                  _markAsDiscovered(artwork),
                            ),
                          );
                        },
                        childCount: artworks.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
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
                  color: AppColorUtils.tealAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore_outlined,
                  size: 40,
                  color: AppColorUtils.tealAccent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.mapEmptyNoArtworksTitle,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.mapEmptyNoArtworksDescription,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
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
                    color: AppColorUtils.tealAccent,
                  ),
                  const SizedBox(width: 8),
                  _EmptyStateChip(
                    icon: Icons.filter_alt_outlined,
                    label: l10n.mapEmptyAdjustFiltersAction,
                    color: scheme.tertiary,
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
      case _ArtworkSort.rarity:
        const rarityRank = {
          ArtworkRarity.legendary: 3,
          ArtworkRarity.epic: 2,
          ArtworkRarity.rare: 1,
          ArtworkRarity.common: 0,
        };
        sorted.sort((a, b) {
          final aRank = rarityRank[a.rarity] ?? 0;
          final bRank = rarityRank[b.rarity] ?? 0;
          return bRank.compareTo(aRank);
        });
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtDetailScreen(artworkId: artwork.id),
      ),
    );
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
  rarity,
  rewards,
  popular;

  String label(AppLocalizations l10n) {
    switch (this) {
      case _ArtworkSort.nearest:
        return l10n.mapSortNearest;
      case _ArtworkSort.newest:
        return l10n.mapSortNewest;
      case _ArtworkSort.rarity:
        return l10n.mapSortRarity;
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
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = active ? scheme.primary : scheme.surface;
    final iconColor = active ? scheme.onPrimary : scheme.onSurface;
    final borderColor = active ? scheme.primary : scheme.outlineVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        shape: const CircleBorder(),
        color: background,
        elevation: active ? 6 : 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor),
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

  const _ArtworkListTile({
    required this.artwork,
    required this.currentPosition,
    required this.onOpenDetails,
    required this.onMarkDiscovered,
    this.dense = false,
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

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                style: GoogleFonts.outfit(
                  fontSize: dense ? 15 : 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.commonByArtist(artwork.artist),
                style: GoogleFonts.outfit(
                  color: scheme.onSurfaceVariant,
                  fontSize: dense ? 12 : 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.auto_awesome,
                    label: artwork.rarity.name.toUpperCase(),
                    backgroundColor:
                        RarityUi.artworkColor(context, artwork.rarity)
                            .withValues(alpha: 0.18),
                    foregroundColor:
                        RarityUi.artworkColor(context, artwork.rarity),
                  ),
                  if (artwork.arEnabled)
                    _InfoChip(
                      icon: Icons.view_in_ar,
                      label: l10n.mapArReadyChipLabel,
                      backgroundColor:
                          scheme.primaryContainer.withValues(alpha: 0.35),
                      foregroundColor: scheme.primary,
                    ),
                  if (distanceLabel != null)
                    _InfoChip(
                      icon: Icons.place_outlined,
                      label: distanceLabel,
                      backgroundColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                  if (artwork.category.isNotEmpty)
                    _InfoChip(
                      icon: Icons.category_outlined,
                      label: artwork.category,
                      backgroundColor:
                          scheme.tertiaryContainer.withValues(alpha: 0.4),
                      foregroundColor: scheme.tertiary,
                    ),
                  if (artwork.metadata != null &&
                      (artwork.metadata!['subjectLabel'] != null ||
                          artwork.metadata!['subject_type'] != null))
                    _InfoChip(
                      icon: Icons.palette_outlined,
                      label: artwork.metadata!['subjectLabel']?.toString() ??
                          artwork.metadata!['subject_type']?.toString() ??
                          '',
                      backgroundColor:
                          scheme.secondaryContainer.withValues(alpha: 0.4),
                      foregroundColor: scheme.secondary,
                    ),
                  if (artwork.metadata != null &&
                      (artwork.metadata!['locationName'] != null ||
                          artwork.metadata!['location'] != null))
                    _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: artwork.metadata!['locationName']?.toString() ??
                          artwork.metadata!['location']?.toString() ??
                          '',
                      backgroundColor:
                          scheme.primaryContainer.withValues(alpha: 0.25),
                      foregroundColor: scheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.token, size: 18, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.commonKub8PointsReward(artwork.rewards),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.visibility,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${artwork.viewsCount}',
                    style: GoogleFonts.outfit(
                      color: scheme.onSurfaceVariant,
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
                      onPressed: onOpenDetails,
                      child: Text(l10n.commonViewDetails),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: isDiscovered
                        ? l10n.mapAlreadyDiscoveredTooltip
                        : l10n.mapMarkAsDiscoveredTooltip,
                    onPressed: isDiscovered ? null : onMarkDiscovered,
                    icon: Icon(
                      isDiscovered ? Icons.check_circle : Icons.flag_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
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
        borderRadius: BorderRadius.circular(20),
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
            style: GoogleFonts.outfit(
              fontSize: 12,
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

class _ClusterBucket {
  LatLng center;
  List<ArtMarker> markers;
  _ClusterBucket(this.center, this.markers);
}
