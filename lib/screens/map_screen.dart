import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../providers/institution_provider.dart';
import '../providers/dao_provider.dart';
import '../providers/navigation_provider.dart';
import '../models/artwork.dart';
import '../models/task.dart';
import '../models/institution.dart';
import '../models/dao.dart';
import '../models/map_marker_subject.dart';
import '../services/task_service.dart';
import '../services/ar_integration_service.dart';
import '../services/backend_api_service.dart';
import '../services/map_marker_service.dart';
import '../services/push_notification_service.dart';
import '../services/achievement_service.dart';
import '../models/art_marker.dart';
import '../widgets/art_marker_cube.dart';
import 'art/art_detail_screen.dart';
import 'art/ar_screen.dart';
import 'community/user_profile_screen.dart';
import '../utils/grid_utils.dart';
import '../utils/marker_subject_utils.dart';
import '../providers/tile_providers.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MarkerSubjectData {
  final List<Artwork> artworks;
  final List<Institution> institutions;
  final List<Event> events;
  final List<Delegate> delegates;
  final bool wasRefreshed;

  const _MarkerSubjectData({
    required this.artworks,
    required this.institutions,
    required this.events,
    required this.delegates,
    this.wasRefreshed = false,
  });
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const String _kPrefLocationPermissionRequested = 'map_location_permission_requested';
  static const String _kPrefLocationServiceRequested = 'map_location_service_requested';
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

  // AR Integration
  final ARIntegrationService _arIntegrationService = ARIntegrationService();
  final BackendApiService _backendApi = BackendApiService();
  final MapMarkerService _mapMarkerService = MapMarkerService();
  final PushNotificationService _pushNotificationService =
      PushNotificationService();
  List<ArtMarker> _artMarkers = [];
  final Set<String> _notifiedMarkers =
      {}; // Track which markers we've notified about
  Timer? _proximityCheckTimer;
  StreamSubscription<ArtMarker>? _markerSocketSubscription;
  Timer? _markerRefreshDebounce;

  // UI State
  bool _isSearching = false;
  bool _isFetchingSuggestions = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<_SearchSuggestion> _searchSuggestions = [];

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

  // Discovery and Progress
  bool _isDiscoveryExpanded = false;
  bool _filtersExpanded = false;

  // Camera helpers
  LatLng _cameraCenter = const LatLng(46.056946, 14.505751);
  double _lastZoom = 16.0;

  final Distance _distanceCalculator = const Distance();
  LatLng? _lastMarkerFetchCenter;
  DateTime? _lastMarkerFetchTime;
  static const double _markerRefreshDistanceMeters = 1200; // Increased to reduce API calls
  static const Duration _markerRefreshInterval = Duration(minutes: 5); // Increased from 150s to 5 min
  bool _isLoadingMarkers = false; // Prevent concurrent fetches

  @override
  void initState() {
    super.initState();
    // Load persisted permission/service request flags, then initialize map
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Track this screen visit for quick actions
      if (mounted) {
        Provider.of<NavigationProvider>(context, listen: false).trackScreenVisit('map');
      }
      
      await _loadPersistedPermissionFlags();
      if (!mounted) return;
      _initializeMap();

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
    _animationController.dispose();
    _sheetController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    // pause polling/subscriptions while backgrounded to avoid extra prompts and conserve battery
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
      if (_proximityCheckTimer == null || !(_proximityCheckTimer?.isActive ?? false)) {
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
    _showIntroDialogIfNeeded();
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

      // Start proximity checking timer (every 10 seconds)
      _proximityCheckTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkProximityNotifications(),
      );
    } catch (e) {
      debugPrint('Error initializing AR integration: $e');
    }
  }

  Future<void> _loadArtMarkers({LatLng? center, bool forceRefresh = false}) async {
    // Prevent concurrent fetches
    if (_isLoadingMarkers) {
      debugPrint('MapScreen: Skipping marker fetch - already loading');
      return;
    }

    final queryCenter = center ?? _currentPosition ?? _cameraCenter;

    try {
      _isLoadingMarkers = true;
      final markers = await _mapMarkerService.loadMarkers(
        center: queryCenter,
        radiusKm: 5.0,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _artMarkers = markers;
        });
      }
      _lastMarkerFetchCenter = queryCenter;
      _lastMarkerFetchTime = DateTime.now();

      debugPrint('Loaded ${markers.length} art markers from backend');
    } catch (e) {
      debugPrint('Error loading art markers from backend: $e');
    } finally {
      _isLoadingMarkers = false;
    }
  }

  void _handleMarkerCreated(ArtMarker marker) {
    try {
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

    final lastFetch = _lastMarkerFetchTime;
    final lastCenter = _lastMarkerFetchCenter;
    final now = DateTime.now();

    // Check if enough time has passed since last fetch
    final bool timeElapsed = lastFetch == null || 
        now.difference(lastFetch) >= _markerRefreshInterval;
    
    // Check if user moved significantly from last fetch location
    final bool movedEnough = lastCenter == null ||
        _distanceCalculator.as(LengthUnit.Meter, center, lastCenter) >= _markerRefreshDistanceMeters;

    // Only refresh if:
    // 1. Force refresh requested, OR
    // 2. Moved enough AND time elapsed (both conditions must be true), OR
    // 3. No markers loaded yet and no recent attempt
    final bool noMarkersYet = _artMarkers.isEmpty && 
        (lastFetch == null || now.difference(lastFetch) >= const Duration(seconds: 30));

    if (force || (movedEnough && timeElapsed) || noMarkersYet) {
      debugPrint('MapScreen: Refreshing markers (force=$force, moved=$movedEnough, timeElapsed=$timeElapsed, noMarkers=$noMarkersYet)');
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
    // Only queue refresh if markers are empty or it's been a while since last fetch
    // This prevents excessive API calls during map panning
    final lastFetch = _lastMarkerFetchTime;
    final timeSinceLastFetch = lastFetch != null 
        ? DateTime.now().difference(lastFetch) 
        : const Duration(days: 1);
    
    // Skip queuing if we recently fetched and have markers
    if (_artMarkers.isNotEmpty && timeSinceLastFetch < const Duration(minutes: 2)) {
      return;
    }

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

  void _showProximityNotification(ArtMarker marker, double distance) {
    if (!mounted) return;

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
                    'AR Artwork Nearby!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${marker.name} - ${distance.round()}m away',
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
          label: 'View',
          textColor: Colors.white,
          onPressed: () => _launchARExperience(marker),
        ),
      ),
    );
  }

  void _showArtMarkerDialog(ArtMarker marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.view_in_ar,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                marker.name,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (marker.description.isNotEmpty)
              Text(
                marker.description,
                style: GoogleFonts.outfit(),
              ),
            const SizedBox(height: 12),
            if (_currentPosition != null) ...[
              Builder(
                builder: (context) {
                  final distance = _distanceCalculator.as(
                    LengthUnit.Meter,
                    _currentPosition!,
                    marker.position,
                  );
                  return Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.round()}m away',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: GoogleFonts.outfit()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _launchARExperience(marker);
            },
            icon: const Icon(Icons.view_in_ar),
            label: Text('View in AR', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch AR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _resolveArtMarkerColor(ArtMarker marker, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    Color base;
    switch (marker.type) {
      case ArtMarkerType.artwork:
        base = themeProvider.accentColor;
        break;
      case ArtMarkerType.institution:
        base = scheme.secondary;
        break;
      case ArtMarkerType.event:
        base = scheme.tertiary;
        break;
      case ArtMarkerType.residency:
        base = scheme.primaryContainer;
        break;
      case ArtMarkerType.drop:
        base = scheme.secondaryContainer;
        break;
      case ArtMarkerType.experience:
        base = scheme.primary;
        break;
      case ArtMarkerType.other:
        base = scheme.outline;
        break;
    }

    switch (marker.signalTier) {
      case ArtMarkerSignal.legendary:
        return Color.alphaBlend(scheme.error.withValues(alpha: 0.45), base);
      case ArtMarkerSignal.featured:
        return Color.alphaBlend(scheme.tertiary.withValues(alpha: 0.35), base);
      case ArtMarkerSignal.active:
        return base;
      case ArtMarkerSignal.subtle:
        return Color.alphaBlend(
          scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          base,
        );
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

  String _describeMarkerType(ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return 'Artwork';
      case ArtMarkerType.institution:
        return 'Institution';
      case ArtMarkerType.event:
        return 'Event';
      case ArtMarkerType.residency:
        return 'Residency';
      case ArtMarkerType.drop:
        return 'Drop/Reward';
      case ArtMarkerType.experience:
        return 'AR Experience';
      case ArtMarkerType.other:
        return 'Other';
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

  _MarkerSubjectData _snapshotMarkerSubjectData() {
    final artworkProvider = context.read<ArtworkProvider>();
    final institutionProvider = context.read<InstitutionProvider>();
    final daoProvider = context.read<DAOProvider>();
    return _MarkerSubjectData(
      artworks: List<Artwork>.from(artworkProvider.artworks),
      institutions: List<Institution>.from(institutionProvider.institutions),
      events: List<Event>.from(institutionProvider.events),
      delegates: List<Delegate>.from(daoProvider.delegates),
    );
  }

  Future<_MarkerSubjectData?> _refreshMarkerSubjectData({bool force = false}) async {
    final artworkProvider = context.read<ArtworkProvider>();
    final institutionProvider = context.read<InstitutionProvider>();
    final daoProvider = context.read<DAOProvider>();

    final fetches = <Future<void>>[];
    final shouldLoadArtworks = artworkProvider.artworks.isEmpty || force;
    final shouldLoadInstitutions =
        force || institutionProvider.institutions.isEmpty || institutionProvider.events.isEmpty;
    final shouldLoadDelegates = force || daoProvider.delegates.isEmpty;

    final bool needsFetch = shouldLoadArtworks || shouldLoadInstitutions || shouldLoadDelegates;

    if (!needsFetch) {
      return null;
    }

    if (shouldLoadArtworks) {
      fetches.add(artworkProvider.loadArtworks());
    }
    if (shouldLoadInstitutions) {
      fetches.add(institutionProvider.refreshData());
    }
    if (shouldLoadDelegates) {
      fetches.add(daoProvider.refreshData(force: true));
    }

    try {
      await Future.wait(fetches);
      return _MarkerSubjectData(
        artworks: List<Artwork>.from(artworkProvider.artworks),
        institutions: List<Institution>.from(institutionProvider.institutions),
        events: List<Event>.from(institutionProvider.events),
        delegates: List<Delegate>.from(daoProvider.delegates),
        wasRefreshed: true,
      );
    } catch (e) {
      debugPrint('MapScreen: Failed to refresh marker subjects: $e');
      return null;
    }
  }

  Future<void> _startMarkerCreationFlow() async {
    if (_currentPosition == null) return;
    final subjectData = _snapshotMarkerSubjectData();
    if (!mounted) return;
    _showMarkerCreationDialog(subjectData);
  }

  void _showMarkerCreationDialog(_MarkerSubjectData subjectData) {
    if (_currentPosition == null) return;

    List<Artwork> arEnabledArtworks =
        subjectData.artworks.where(artworkSupportsAR).toList();

    Map<MarkerSubjectType, List<MarkerSubjectOption>> subjectOptionsByType =
        <MarkerSubjectType, List<MarkerSubjectOption>>{
      for (final type in MarkerSubjectType.values)
        type: buildSubjectOptions(
          type: type,
          artworks: subjectData.artworks,
          institutions: subjectData.institutions,
          events: subjectData.events,
          delegates: subjectData.delegates,
        ),
    };

    MarkerSubjectType selectedSubjectType = MarkerSubjectType.artwork;
    MarkerSubjectOption? selectedSubject =
        (subjectOptionsByType[selectedSubjectType] ?? []).isNotEmpty
            ? subjectOptionsByType[selectedSubjectType]!.first
            : null;
    bool subjectSelectionRequired(MarkerSubjectType type) =>
        type != MarkerSubjectType.misc;
    bool arAssetRequired(MarkerSubjectType type) =>
        type != MarkerSubjectType.artwork && type != MarkerSubjectType.misc;

    Artwork? resolveDefaultAsset(
      MarkerSubjectType type,
      MarkerSubjectOption? subjectOption,
    ) {
      if (type == MarkerSubjectType.artwork) {
        return findArtworkById(arEnabledArtworks, subjectOption?.id);
      }
      if (arAssetRequired(type) && arEnabledArtworks.isNotEmpty) {
        return arEnabledArtworks.first;
      }
      return null;
    }

    Artwork? selectedArAsset = resolveDefaultAsset(
      selectedSubjectType,
      selectedSubject,
    );
    ArtMarkerType selectedMarkerType = selectedSubjectType.defaultMarkerType;
    bool isPublic = true;

    final titleController =
        TextEditingController(text: selectedSubject?.title ?? '');
    final descriptionController = TextEditingController(
      text: selectedSubject != null && selectedSubject.subtitle.isNotEmpty
          ? selectedSubject.subtitle
          : '',
    );
    final categoryController =
        TextEditingController(text: selectedSubjectType.defaultCategory);
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;

    void applySubjectType(MarkerSubjectType type, StateSetter refresh) {
      final options = subjectOptionsByType[type] ?? [];
      final nextSubject = options.isNotEmpty ? options.first : null;

      refresh(() {
        selectedSubjectType = type;
        selectedMarkerType = type.defaultMarkerType;
        selectedSubject = nextSubject;
        categoryController.text = type.defaultCategory;
        if (nextSubject != null) {
          titleController.text = nextSubject.title;
          descriptionController.text = nextSubject.subtitle.isNotEmpty
              ? nextSubject.subtitle
              : 'Marker for ${nextSubject.title}';
        } else if (subjectSelectionRequired(type)) {
          titleController.clear();
          descriptionController.clear();
        }
        selectedArAsset = resolveDefaultAsset(type, nextSubject);
      });
    }

    Future<void> maybeRefreshSubjectsInDialog(StateSetter refresh) async {
      // Force a refresh when opening the dialog to ensure options are populated.
      final fresh = await _refreshMarkerSubjectData(force: true);
      if (fresh == null || !mounted) return;
      refresh(() {
        subjectOptionsByType = {
          for (final type in MarkerSubjectType.values)
            type: buildSubjectOptions(
              type: type,
              artworks: fresh.artworks,
              institutions: fresh.institutions,
              events: fresh.events,
              delegates: fresh.delegates,
            ),
        };
        arEnabledArtworks =
            fresh.artworks.where(artworkSupportsAR).toList();
        // Preserve current selections when possible
        final updatedOptions = subjectOptionsByType[selectedSubjectType] ?? [];
        MarkerSubjectOption? preserved;
        if (selectedSubject != null) {
          try {
            preserved = updatedOptions
                .firstWhere((option) => option.id == selectedSubject!.id);
          } catch (_) {}
        }
        selectedSubject =
            preserved ?? (updatedOptions.isNotEmpty ? updatedOptions.first : null);
        selectedArAsset = resolveDefaultAsset(selectedSubjectType, selectedSubject);
      });
    }

    bool refreshScheduled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!refreshScheduled) {
            refreshScheduled = true;
            unawaited(maybeRefreshSubjectsInDialog(setDialogState));
          }
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                Icon(
                  Icons.add_location_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create Art Marker',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attach an existing subject and AR asset to this location.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Subject Type',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MarkerSubjectType>(
                    initialValue: selectedSubjectType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: MarkerSubjectType.values
                        .map(
                          (type) => DropdownMenuItem<MarkerSubjectType>(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        applySubjectType(value, setDialogState);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (subjectSelectionRequired(selectedSubjectType))
                    if ((subjectOptionsByType[selectedSubjectType] ?? [])
                        .isNotEmpty)
                      DropdownButtonFormField<MarkerSubjectOption>(
                        initialValue: selectedSubject,
                        decoration: InputDecoration(
                          labelText: '${selectedSubjectType.label} *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: (subjectOptionsByType[selectedSubjectType] ?? [])
                            .map(
                              (option) => DropdownMenuItem<MarkerSubjectOption>(
                                value: option,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(option.title,
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600)),
                                    if (option.subtitle.isNotEmpty)
                                      Text(
                                        option.subtitle,
                                        style: GoogleFonts.outfit(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedSubject = value;
                              titleController.text = value.title;
                              descriptionController.text =
                                  value.subtitle.isNotEmpty
                                      ? value.subtitle
                                      : 'Marker for ${value.title}';
                              if (selectedSubjectType ==
                                  MarkerSubjectType.artwork) {
                                selectedArAsset = findArtworkById(
                                    arEnabledArtworks, value.id);
                              }
                            });
                          }
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'No ${selectedSubjectType.label.toLowerCase()}s available. Use the respective module to create one first.',
                          style: GoogleFonts.outfit(fontSize: 13),
                        ),
                      )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Misc markers do not need a linked subject. Provide a custom title and description below.',
                        style: GoogleFonts.outfit(fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (arAssetRequired(selectedSubjectType)) ...[
                    Text(
                      'Linked AR Asset',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (arEnabledArtworks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'No AR-enabled artworks available. Create one from the AR screen (Create tab) first.',
                          style: GoogleFonts.outfit(fontSize: 13),
                        ),
                      )
                    else
                      DropdownButtonFormField<Artwork>(
                        initialValue: selectedArAsset,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: arEnabledArtworks
                            .map(
                              (artwork) => DropdownMenuItem<Artwork>(
                                value: artwork,
                                child: Text(artwork.title),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedArAsset = value);
                        },
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (selectedArAsset != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AR Asset: ${selectedArAsset!.title}',
                            style:
                                GoogleFonts.outfit(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            selectedArAsset!.model3DCID != null
                                ? 'IPFS CID linked'
                                : 'HTTP Model linked',
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Marker Title *',
                      hintText: 'Enter marker name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      if (value.trim().length < 3) {
                        return 'Title must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      hintText:
                          'Describe this location and what visitors will experience',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      if (value.trim().length < 10) {
                        return 'Description must be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g., Residency, Gallery, Experience',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ArtMarkerType>(
                    initialValue: selectedMarkerType,
                    decoration: InputDecoration(
                      labelText: 'Marker Layer',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: ArtMarkerType.values
                        .map(
                          (type) => DropdownMenuItem<ArtMarkerType>(
                            value: type,
                            child: Text(_describeMarkerType(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedMarkerType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Public marker',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    subtitle: Text('Visible to all explorers on the map',
                        style: GoogleFonts.outfit(fontSize: 12)),
                    value: isPublic,
                    onChanged: (value) =>
                        setDialogState(() => isPublic = value),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Location',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCreating) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      titleController.dispose();
                      descriptionController.dispose();
                      categoryController.dispose();
                    },
              child: Text('Cancel', style: GoogleFonts.outfit()),
            ),
            ElevatedButton.icon(
              onPressed: isCreating
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      if (subjectSelectionRequired(selectedSubjectType) &&
                          selectedSubject == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Select a subject to continue'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (arAssetRequired(selectedSubjectType) &&
                          selectedArAsset == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Select an AR-enabled artwork to link to this marker'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      final success = await _createMarkerAtCurrentLocation(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        type: selectedMarkerType,
                        category: categoryController.text.trim(),
                        subjectType: selectedSubjectType,
                        subject: selectedSubject,
                        linkedArtwork: selectedArAsset,
                        isPublic: isPublic,
                      );

                      if (!dialogContext.mounted) {
                        titleController.dispose();
                        descriptionController.dispose();
                        categoryController.dispose();
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      titleController.dispose();
                      descriptionController.dispose();
                      categoryController.dispose();

                      if (!mounted) {
                        return;
                      }

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Marker created successfully!',
                                    style:
                                        GoogleFonts.outfit(color: Colors.white),
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
                              'Failed to create marker. Please try again.',
                              style: GoogleFonts.outfit(color: Colors.white),
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.add_location_alt),
              label: Text('Create Marker', style: GoogleFonts.outfit()),
            ),
          ],
        );
       }
      ),
    );
  }

  Future<bool> _createMarkerAtCurrentLocation({
    required String title,
    required String description,
    required ArtMarkerType type,
    required String category,
    required MarkerSubjectType subjectType,
    MarkerSubjectOption? subject,
    Artwork? linkedArtwork,
    required bool isPublic,
  }) async {
    if (_currentPosition == null) return false;

    try {
      if (linkedArtwork != null) {
        final hasCid = linkedArtwork.model3DCID?.isNotEmpty ?? false;
        final hasUrl = linkedArtwork.model3DURL?.isNotEmpty ?? false;
        if (!hasCid && !hasUrl) {
          debugPrint('Selected AR asset is missing model metadata');
          return false;
        }
      }

      // Snap to the nearest grid cell center at the current zoom level
      // We use the current camera zoom to determine which grid level is most relevant
      final double currentZoom = _mapController.camera.zoom;
      final gridCell = GridUtils.gridCellForZoom(_currentPosition!, currentZoom);
      // Snap to the grid level that is closest to the current zoom
      // This ensures we snap to the grid lines the user is likely seeing
      final tileProviders = Provider.of<TileProviders?>(context, listen: false);
      final LatLng snappedPosition = tileProviders?.snapToVisibleGrid(
            _currentPosition!,
            currentZoom,
          ) ??
          gridCell.center;

      final resolvedCategory = category.isNotEmpty
          ? category
          : subject?.type.defaultCategory ?? subjectType.defaultCategory;
      final marker = await _mapMarkerService.createMarker(
        location: snappedPosition,
        title: title,
        description: description,
        type: type,
        category: resolvedCategory,
        artworkId: linkedArtwork?.id,
        modelCID: linkedArtwork?.model3DCID,
        modelURL: linkedArtwork?.model3DURL,
        isPublic: isPublic,
        metadata: {
          'snapZoom': currentZoom,
          'gridAnchor': gridCell.anchorKey,
          'gridLevel': gridCell.gridLevel,
          'gridIndices': {
            'u': gridCell.uIndex,
            'v': gridCell.vIndex,
          },
          'createdFrom': 'map_screen',
          'subjectType': subjectType.name,
          'subjectLabel': subjectType.label,
          if (subject != null) ...{
            'subjectId': subject.id,
            'subjectTitle': subject.title,
            'subjectSubtitle': subject.subtitle,
          },
          if (linkedArtwork != null) ...{
            'linkedArtworkId': linkedArtwork.id,
            'linkedArtworkTitle': linkedArtwork.title,
          },
          'visibility': isPublic ? 'public' : 'private',
          if (subject?.metadata != null) ...subject!.metadata!,
        },
      );

      if (marker != null) {
        debugPrint('Marker created and saved: ${marker.id}');
        // Update local markers list
        setState(() {
          _artMarkers.add(marker);
        });
        return true;
      } else {
        debugPrint('Failed to create marker: returned null');
      }

      return false;
    } catch (e) {
      debugPrint('Error creating marker at current location: $e');
      return false;
    }
  }

  Future<void> _getLocation({bool fromTimer = false, bool promptForPermission = true}) async {
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
            debugPrint('MapScreen: Location permission denied on web; using fallback if available');
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
          debugPrint('MapScreen: Location permission permanently denied on web');
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
            debugPrint('MapScreen: Location service disabled; skipping prompt due to promptForPermission=false');
            resolvedPosition ??= _loadFallbackPosition(prefs);
            if (resolvedPosition == null) return;
          } else {
            if (!_locationServiceRequested) {
              _locationServiceRequested = true;
              try {
                await prefs.setBool(_kPrefLocationServiceRequested, true);
              } catch (e) {
                debugPrint('Failed to persist location service requested flag: ');
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
              debugPrint('MapScreen: Location service disabled (previously requested).');
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
        PermissionStatus permissionGranted = await _mobileLocation!.hasPermission();
        if (permissionGranted == PermissionStatus.denied) {
          if (!promptForPermission) {
            debugPrint('MapScreen: Location permission denied; skipping request due to promptForPermission=false');
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
            debugPrint('MapScreen: Permission denied and previously requested; skipping further requests.');
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
          resolvedPosition = LatLng(locationData.latitude!, locationData.longitude!);
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
      {double? zoom, double? rotation, Duration duration = const Duration(milliseconds: 420)}) {
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
      if (_autoFollow && _currentPosition != null) {
        _animateMapTo(_currentPosition!,
            zoom: _mapController.camera.zoom, rotation: heading);
      } else if (_autoFollow) {
        _mapController.rotate(heading);
      }
    }
  }

  Future<void> _showIntroDialogIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenIntro = prefs.getBool('has_seen_map_intro') ?? false;

    if (!hasSeenIntro && mounted) {
      await prefs.setBool('has_seen_map_intro', true);
      _showMapIntroDialog();
    }
  }

  void _showMapIntroDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => AlertDialog(
          title: Text(
            'Welcome to AR Art Discovery!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map,
                size: 48,
                color: themeProvider.accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Explore art around you in augmented reality. Get close to artworks to discover them and earn rewards!',
                style: GoogleFonts.outfit(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: themeProvider.accentColor,
              ),
              child: Text('Got it!', style: GoogleFonts.outfit()),
            ),
          ],
        ),
      ),
    );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Art Discovered!',
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
                color: Color(Artwork.getRarityColor(artwork.rarity)),
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
            Text(
              'by ${artwork.artist}',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
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
                    '+${artwork.rewards} KUB8',
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
            child: Text('Continue Exploring', style: GoogleFonts.outfit()),
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
            child: Text('View Details', style: GoogleFonts.outfit()),
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
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition ?? _cameraCenter,
        initialZoom: _lastZoom,
        minZoom: 3.0,
        maxZoom: 20.0,
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
      ),
      children: [
        // Prefer the shared TileProviders tile layer when registered.
        if (tileProviders != null)
          (isRetina
              ? tileProviders.getTileLayer()
              : tileProviders.getNonRetinaTileLayer())
        else
          // Fall back to the previous inline tile layer if TileProviders isn't registered yet.
          TileLayer(
            urlTemplate: isDark
                ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
                : 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.art.kubus',
          ),
        MarkerLayer(markers: _buildMarkers(themeProvider)),
      ],
    );
  }

  List<Marker> _buildMarkers(ThemeProvider themeProvider) {
    final markers = <Marker>[];

    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => unawaited(_handleCurrentLocationTap()),
            child: Container(
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.18),
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
                      color: themeProvider.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (_direction != null)
                    Transform.rotate(
                      angle: (_direction! * math.pi) / 180,
                      child: Icon(
                        Icons.navigation,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    markers.addAll(
      _artMarkers.where((marker) {
        return _markerLayerVisibility[marker.type] ?? true;
      }).map(
        (marker) => Marker(
          point: marker.position,
          width: 54,
          height: 58,
          child: GestureDetector(
            onTap: () => _showArtMarkerDialog(marker),
            child: ArtMarkerCube(
              marker: marker,
              size: 44,
              baseColor: _resolveArtMarkerColor(marker, themeProvider),
              icon: _resolveArtMarkerIcon(marker.type),
            ),
          ),
        ),
      ),
    );

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

  

  Widget _buildSearchCard(ThemeData theme) {
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
          hintText: 'Search artworks, artists, institutions…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
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
                  tooltip:
                      _filtersExpanded ? 'Hide filters' : 'Show filters',
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
        final dynamic rr = await _backendApi.getSearchSuggestions(
          query: value.trim(),
          limit: 8,
        );

        // Use centralized normalizer to convert backend response to stable items
        final List<Map<String, dynamic>> items = _backendApi.normalizeSearchSuggestions(rr);

        final suggestions = <_SearchSuggestion>[];
        for (final m in items) {
          try {
            final suggestion = _SearchSuggestion.fromMap(m);
            if (suggestion.label.isNotEmpty) suggestions.add(suggestion);
          } catch (e) {
            // skip malformed entries
          }
        }

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
                  'Type at least 2 characters to search',
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
                  'No suggestions',
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
                    backgroundColor: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
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

  Future<void> _handleSuggestionTap(_SearchSuggestion suggestion) async {
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
    final scheme = theme.colorScheme;
    const filters = <Map<String, String>>[
      {'key': 'all', 'label': 'All nearby'},
      {'key': 'nearby', 'label': 'Within 1km'},
      {'key': 'discovered', 'label': 'Discovered'},
      {'key': 'undiscovered', 'label': 'Undiscovered'},
      {'key': 'ar', 'label': 'AR enabled'},
      {'key': 'favorites', 'label': 'Favorites'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Filters',
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
          'Map layers',
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
              label: Text(_markerTypeLabel(type)),
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

    final showTasks = _isDiscoveryExpanded;
    final tasksToRender =
      showTasks ? activeProgress : const <TaskProgress>[];
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
                      'Discovery path',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${(overall * 100).round()}% complete',
                      style: GoogleFonts.outfit(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isDiscoveryExpanded ? 'Collapse' : 'Expand',
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
            crossFadeState:
                showTasks ? CrossFadeState.showFirst : CrossFadeState.showSecond,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: task.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(task.icon, color: task.color, size: 20),
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
                    valueColor: AlwaysStoppedAnimation<Color>(task.color),
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
    return Positioned(
      right: 16,
      bottom: 150,
      child: Column(
        children: [
          _MapIconButton(
            icon: Icons.my_location,
            tooltip: 'Center on me',
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
            tooltip: 'Add map marker',
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
                                  'Nearby art',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${artworks.length} results · ${(discoveryProgress * 100).round()}% discovered',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: _useGridLayout
                                  ? 'Show list view'
                                  : 'Show grid view',
                              onPressed: () => setState(
                                  () => _useGridLayout = !_useGridLayout),
                              icon: Icon(
                                _useGridLayout
                                    ? Icons.view_list
                                    : Icons.grid_view,
                              ),
                            ),
                            PopupMenuButton<_ArtworkSort>(
                              tooltip: 'Sort results',
                              onSelected: (value) =>
                                  setState(() => _sort = value),
                              itemBuilder: (context) => [
                                for (final sort in _ArtworkSort.values)
                                  PopupMenuItem(
                                    value: sort,
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(sort.label)),
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
    final scheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
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
                  color: themeProvider.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore_outlined,
                  size: 40,
                  color: themeProvider.accentColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No artworks nearby',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Explore different areas or adjust your filters to discover art around you.',
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
                    label: 'Zoom out',
                    color: themeProvider.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _EmptyStateChip(
                    icon: Icons.filter_alt_outlined,
                    label: 'Adjust filters',
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
    var filtered = List<Artwork>.from(artworks);
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
                  artwork.getDistanceFrom(_currentPosition!) <= 1000)
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

  String _markerTypeLabel(ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return 'Artworks';
      case ArtMarkerType.institution:
        return 'Institutions';
      case ArtMarkerType.event:
        return 'Events';
      case ArtMarkerType.residency:
        return 'Residencies';
      case ArtMarkerType.drop:
        return 'Drops';
      case ArtMarkerType.experience:
        return 'Experiences';
      case ArtMarkerType.other:
        return 'Misc';
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

    // Build a friendly label/subtitle: prefer displayName + @username
    final label = (map['label'] ?? map['displayName'] ?? map['display_name'] ?? map['title'] ?? '').toString();
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
      label: label,
      type: map['type']?.toString() ?? 'artwork',
      subtitle: subtitle,
      id: map['id']?.toString() ?? (map['wallet']?.toString()),
      position: position,
    );
  }
}

enum _ArtworkSort {
  nearest('Nearest'),
  newest('Newest'),
  rarity('Rarity'),
  rewards('Highest rewards'),
  popular('Most viewed');

  const _ArtworkSort(this.label);
  final String label;
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
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(22);
    final previewHeight = dense ? 120.0 : 150.0;
    final distanceLabel = _distanceLabel();
    final isDiscovered = artwork.isDiscovered;

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
                imageUrl: artwork.imageUrl,
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
                'by ${artwork.artist}',
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
                        Color(Artwork.getRarityColor(artwork.rarity))
                            .withValues(alpha: 0.18),
                    foregroundColor:
                        Color(Artwork.getRarityColor(artwork.rarity)),
                  ),
                  if (artwork.arEnabled)
                    _InfoChip(
                      icon: Icons.view_in_ar,
                      label: 'AR ready',
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
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.token, size: 18, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '+${artwork.rewards} KUB8',
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
                      child: const Text('View details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: isDiscovered
                        ? 'Already discovered'
                        : 'Mark as discovered',
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

  String? _distanceLabel() {
    if (currentPosition == null) return null;
    final meters = artwork.getDistanceFrom(currentPosition!);
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
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
