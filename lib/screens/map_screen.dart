import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
// inline_loading no longer used in this file; replaced with inline_progress
import '../widgets/inline_progress.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_loading.dart';

import '../providers/themeprovider.dart';
import '../providers/artwork_provider.dart';
import '../providers/task_provider.dart';
import '../providers/tile_providers.dart';
import '../providers/wallet_provider.dart';
import '../models/artwork.dart';
import '../services/task_service.dart';
import '../services/ar_integration_service.dart';
import '../services/backend_api_service.dart';
import '../services/push_notification_service.dart';
import '../services/achievement_service.dart';
import '../models/ar_marker.dart';
import 'art_detail_screen.dart';
import 'ar_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/avatar_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> 
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  
  // Location and Map State
  LocationData? _currentLocation;
  Location location = Location();
  Timer? _timer;
  final MapController _mapController = MapController();
  bool _autoCenter = true;
  double? _direction; // Compass direction
  StreamSubscription<CompassEvent>? _compassSubscription;
  TileProviders? tileProviders;
  
  // Animation
  late AnimationController _animationController;
  
  // AR Integration
  final ARIntegrationService _arIntegrationService = ARIntegrationService();
  final BackendApiService _backendApi = BackendApiService();
  final PushNotificationService _pushNotificationService = PushNotificationService();
  List<ARMarker> _arMarkers = [];
  final Set<String> _notifiedMarkers = {}; // Track which markers we've notified about
  Timer? _proximityCheckTimer;

  // UI State
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedFilter = 'All';
  String _sortBy = 'distance'; // distance, rarity, name, newest
  bool _showListView = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  // Profile search results for search bar suggestions
  List<Map<String, dynamic>> _profileSearchResults = [];
  bool _isProfileSearchLoading = false;
  
  // Discovery and Progress
  bool _isDiscoveryExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    
    // Initialize providers and calculate progress after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<ArtworkProvider>().loadArtworks();
      final taskProvider = context.read<TaskProvider>();
      final walletProvider = context.read<WalletProvider>();
      
      taskProvider.initializeProgress(); // Ensure proper initialization
      
      // Load real progress from backend if wallet is connected
      if (walletProvider.currentWalletAddress != null && 
          walletProvider.currentWalletAddress!.isNotEmpty) {
        debugPrint('MapScreen: Loading progress from backend for wallet: ${walletProvider.currentWalletAddress}');
        await taskProvider.loadProgressFromBackend(walletProvider.currentWalletAddress!);
      } else {
        debugPrint('MapScreen: No wallet connected, using default empty progress');
      }
      
      _calculateProgress(); // Calculate progress after providers are ready
    });
  }

  void _calculateProgress() {
    // Update task provider with current discovery progress
    final taskProvider = context.read<TaskProvider>();
    final artworkProvider = context.read<ArtworkProvider>();
    final discoveredCount = artworkProvider.artworks.where((artwork) => artwork.status != ArtworkStatus.undiscovered).length;
    
    // Update local guide achievement with current discovered count
    taskProvider.updateAchievementProgress('local_guide', discoveredCount);
  }

  void _initializeMap() {
    _getLocation();
    _showIntroDialogIfNeeded();
    _startLocationTimer();
    
    _compassSubscription = FlutterCompass.events!.listen((CompassEvent event) {
      if (mounted) {
        _updateDirection(event.heading);
      }
    });

    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Initialize AR integration
    _initializeARIntegration();
  }
  
  Future<void> _initializeARIntegration() async {
    try {
      await _arIntegrationService.initialize();
      await _pushNotificationService.initialize();
      
      // Set up notification tap handler
      _pushNotificationService.onNotificationTap = _handleNotificationTap;
      
      // Load AR markers from backend
      await _loadARMarkers();
      
      // Start proximity checking timer (every 10 seconds)
      _proximityCheckTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkProximityNotifications(),
      );
      
    } catch (e) {
      debugPrint('Error initializing AR integration: $e');
    }
  }
  
  Future<void> _loadARMarkers() async {
    if (_currentLocation == null) return;
    
    try {
      // Load from backend API
      final markers = await _backendApi.getNearbyMarkers(
        latitude: _currentLocation!.latitude!,
        longitude: _currentLocation!.longitude!,
        radiusKm: 5.0,
      );
      
      if (mounted) {
        setState(() {
          _arMarkers = markers;
        });
      }
      
      debugPrint('Loaded ${markers.length} AR markers from backend');
    } catch (e) {
      debugPrint('Error loading AR markers from backend: $e');
      // Fallback to local service if backend fails
      try {
        final markers = _arIntegrationService.getActiveMarkers();
        if (mounted) {
          setState(() {
            _arMarkers = markers;
          });
        }
      } catch (e2) {
        debugPrint('Error loading AR markers from local service: $e2');
      }
    }
  }
  
  void _handleNotificationTap(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      if (type == 'ar_proximity') {
        final markerId = data['markerId'] as String?;
        if (markerId != null) {
          final marker = _arMarkers.firstWhere(
            (m) => m.id == markerId,
            orElse: () => _arMarkers.first,
          );
          _showARMarkerDialog(marker);
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }
  
  void _checkProximityNotifications() {
    if (_currentLocation == null) return;
    
    const Distance distanceCalculator = Distance();
    final currentLatLng = LatLng(
      _currentLocation!.latitude!,
      _currentLocation!.longitude!,
    );
    
    for (final marker in _arMarkers) {
      // Check if already notified
      if (_notifiedMarkers.contains(marker.id)) continue;
      
      // Calculate distance
      final distance = distanceCalculator.as(
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
      final marker = _arMarkers.firstWhere(
        (m) => m.id == markerId,
        orElse: () => _arMarkers.first,
      );
      
      final distance = distanceCalculator.as(
        LengthUnit.Meter,
        currentLatLng,
        marker.position,
      );
      
      return distance > 100; // Reset notification if moved far away
    });
  }
  
  void _showProximityNotification(ARMarker marker, double distance) {
    if (!mounted) return;
    
    // Show push notification
    _pushNotificationService.showARProximityNotification(
      marker: marker,
      distance: distance,
    ).catchError((e) {
      debugPrint('MapScreen: showARProximityNotification failed: $e');
    });
    
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
  
  void _showARMarkerDialog(ARMarker marker) {
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
            if (_currentLocation != null) ...[
              Builder(
                builder: (context) {
                  const Distance distanceCalculator = Distance();
                  final distance = distanceCalculator.as(
                    LengthUnit.Meter,
                    LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                    marker.position,
                  );
                  return Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.round()}m away',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
  
  Future<void> _launchARExperience(ARMarker marker) async {
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

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      final locationData = await location.getLocation();
      if (mounted) {
        setState(() {
          _currentLocation = locationData;
        });
        
        if (_autoCenter && _currentLocation != null) {
          _mapController.move(
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            15.0,
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _startLocationTimer() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _getLocation();
    });
  }

  void _updateDirection(double? heading) {
    if (mounted && heading != null) {
      setState(() {
        _direction = heading;
      });
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

  List<Artwork> _getFilteredArtwork(List<Artwork> artworks) {
    List<Artwork> filtered = List.from(artworks);

    if (_isSearching && _searchQuery.isNotEmpty) {
      filtered = filtered.where((artwork) {
        final query = _searchQuery.toLowerCase();
        return artwork.title.toLowerCase().contains(query) ||
               artwork.artist.toLowerCase().contains(query) ||
               artwork.category.toLowerCase().contains(query) ||
               artwork.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    if (_selectedFilter != 'All' && _selectedFilter != 'All Rarities' && _selectedFilter != 'All Status') {
      filtered = filtered.where((artwork) {
        return artwork.category == _selectedFilter || 
               artwork.rarity.name.toLowerCase() == _selectedFilter.toLowerCase() ||
               (_selectedFilter == 'Discovered' && artwork.status != ArtworkStatus.undiscovered) ||
               (_selectedFilter == 'Undiscovered' && artwork.status == ArtworkStatus.undiscovered) ||
               (_selectedFilter == 'AR Enabled' && artwork.arEnabled);
      }).toList();
    }

    return filtered;
  }

  List<Artwork> _getSortedArtwork(List<Artwork> artwork, LocationData? currentLocation) {
    List<Artwork> sorted = List.from(artwork);

    switch (_sortBy) {
      case 'distance':
        if (currentLocation != null) {
          const Distance distanceCalculator = Distance();
          sorted.sort((a, b) {
            final distanceA = distanceCalculator.as(LengthUnit.Meter,
              LatLng(currentLocation.latitude!, currentLocation.longitude!),
              a.position,
            );
            final distanceB = distanceCalculator.as(LengthUnit.Meter,
              LatLng(currentLocation.latitude!, currentLocation.longitude!),
              b.position,
            );
            return distanceA.compareTo(distanceB);
          });
        }
        break;
      case 'rarity':
        final rarityOrder = {
          ArtworkRarity.common: 1, 
          ArtworkRarity.rare: 2, 
          ArtworkRarity.epic: 3, 
          ArtworkRarity.legendary: 4
        };
        sorted.sort((a, b) => (rarityOrder[b.rarity] ?? 0).compareTo(rarityOrder[a.rarity] ?? 0));
        break;
      case 'name':
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'newest':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return sorted;
  }

  Future<void> _markAsDiscoveredFromArtwork(Artwork artwork) async {
    context.read<ArtworkProvider>().discoverArtwork(artwork.id, 'current_user_id');
    
    // Get user ID
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'demo_user';
    if (!mounted) return;
    
    // Get discovered artwork count
    final artworkProvider = context.read<ArtworkProvider>();
    final discoveredCount = artworkProvider.artworks.where((a) => a.isDiscovered).length;
    
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
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
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
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
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
    double rotationRadians = -(_direction ?? 0) * (3.14159 / 180);
    
    return Scaffold(
      body: Consumer2<ThemeProvider, ArtworkProvider>(
        builder: (context, themeProvider, artworkProvider, child) {
          if (!mounted) return const AppLoading();
          
          try {
            tileProviders ??= TileProviders(themeProvider);
          } catch (e) {
            return const AppLoading();
          }

          final filteredArt = _getFilteredArtwork(artworkProvider.artworks);
          final sortedArt = _getSortedArtwork(filteredArt, _currentLocation);
          
          return Stack(
            children: [
              // Map
              Transform.scale(
                scale: 1.5,
                child: Transform.rotate(
                  angle: _autoCenter ? rotationRadians : 0,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation != null
                          ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                          : const LatLng(46.0569, 14.5058),
                      initialZoom: 16.0,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      tileProviders?.getTileLayer() ?? TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        maxZoom: 18,
                      ),
                      MarkerLayer(
                        markers: [
                          // Current location marker
                          if (_currentLocation != null)
                            Marker(
                              point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                              width: 15,
                              height: 15,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Art markers from ArtworkProvider
                          ...artworkProvider.artworks.map((artwork) {
                            double distance = 0;
                            bool isNearby = false;
                            
                            if (_currentLocation != null) {
                              const Distance distanceCalculator = Distance();
                              distance = distanceCalculator.as(LengthUnit.Meter,
                                LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                                artwork.position,
                              );
                              isNearby = distance < 50;
                            }
                            
                            final isDiscovered = artwork.status == ArtworkStatus.discovered;
                            
                            return Marker(
                              point: artwork.position,
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onTap: () {
                                  if (_currentLocation != null && isNearby && !isDiscovered) {
                                    // Only allow discovery if we have location and are actually nearby
                                    _markAsDiscoveredFromArtwork(artwork);
                                  } else {
                                    // Always allow viewing the artwork details
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ArtDetailScreen(artworkId: artwork.id),
                                      ),
                                    );
                                  }
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isNearby && !isDiscovered)
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Color(Artwork.getRarityColor(artwork.rarity)).withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDiscovered 
                                            ? Colors.green 
                                            : Color(Artwork.getRarityColor(artwork.rarity)),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        isDiscovered
                                            ? Icons.check
                                            : (artwork.arEnabled ? Icons.view_in_ar : Icons.palette),
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    if (!isDiscovered)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: const BoxDecoration(
                                            color: Colors.amber,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.star,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          // AR Markers from ARIntegrationService
                          ..._arMarkers.map((arMarker) {
                            double distance = 0;
                            bool isNearby = false;
                            
                            if (_currentLocation != null) {
                              const Distance distanceCalculator = Distance();
                              distance = distanceCalculator.as(LengthUnit.Meter,
                                LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                                arMarker.position,
                              );
                              isNearby = distance < 50;
                            }
                            
                            return Marker(
                              point: arMarker.position,
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onTap: () => _showARMarkerDialog(arMarker),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isNearby)
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Theme.of(context).colorScheme.tertiary,
                                            Theme.of(context).colorScheme.primary,
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.view_in_ar,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    // AR badge
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isNearby ? Colors.green : Colors.orange,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1),
                                        ),
                                        child: Icon(
                                          isNearby ? Icons.wifi_tethering : Icons.location_on,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar (moved to top)
              _buildSearchBar(),

              // Filter and Sort Bar
              if (_isSearching) _buildFilterBar(),

              // Art Discovery Progress (below search)
              _buildArtDiscoveryProgress(),

              // Map Controls
              _buildMapControls(),

              // Bottom Sheet with Artwork List
              _buildBottomSheet(sortedArt),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _isSearching ? 56 : 48,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(_isSearching ? 28 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search artworks, artists...',
                    hintStyle: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    suffixIcon: _isSearching ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _isSearching = false;
                        });
                        _searchFocusNode.unfocus();
                      },
                      icon: Icon(
                        Icons.clear,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ) : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _isSearching = value.isNotEmpty;
                    });
                    if (value.trim().isNotEmpty) _performProfileSearch(value.trim());
                  },
                  onTap: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
              ),
            ),
            if (_isSearching) ...[
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _isSearching = false;
                    });
                    _searchFocusNode.unfocus();
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildFilterChip('All', _selectedFilter == 'All', () {
              setState(() => _selectedFilter = 'All');
            }),
            const SizedBox(width: 8),
            _buildFilterChip('AR Enabled', _selectedFilter == 'AR Enabled', () {
              setState(() => _selectedFilter = 'AR Enabled');
            }),
            const SizedBox(width: 8),
            _buildFilterChip('Common', _selectedFilter == 'Common', () {
              setState(() => _selectedFilter = 'Common');
            }),
            const SizedBox(width: 8),
            _buildFilterChip('Rare', _selectedFilter == 'Rare', () {
              setState(() => _selectedFilter = 'Rare');
            }),
            const SizedBox(width: 8),
            _buildFilterChip('Epic', _selectedFilter == 'Epic', () {
              setState(() => _selectedFilter = 'Epic');
            }),
            const SizedBox(width: 8),
            _buildFilterChip('Legendary', _selectedFilter == 'Legendary', () {
              setState(() => _selectedFilter = 'Legendary');
            }),
          ],
        ),
      ),
          // Inline profile suggestions under search bar (constrained height)
          if (_isSearching && _searchQuery.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                height: 200,
                child: _isProfileSearchLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _profileSearchResults.length,
                        itemBuilder: (ctx, idx) {
                          final s = _profileSearchResults[idx];
                          final username = s['username'] ?? s['wallet_address'] ?? s['wallet'];
                          final display = s['displayName'] ?? s['display_name'] ?? '';
                          final avatar = s['avatar'] ?? s['avatar_url'] ?? s['profileImageUrl'] ?? '';
                          final walletAddr = (s['wallet_address'] ?? s['wallet'] ?? s['walletAddress'])?.toString() ?? '';
                          final title = (display ?? username)?.toString();
                          final subtitle = walletAddr.isNotEmpty ? walletAddr : (username ?? '').toString();
                          return ListTile(
                            leading: AvatarWidget(avatarUrl: (avatar != null && avatar.toString().isNotEmpty) ? avatar.toString() : null, wallet: subtitle, radius: 18, allowFabricatedFallback: false),
                            title: Text(title ?? ''),
                            subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              if (walletAddr.isNotEmpty) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: walletAddr)));
                              }
                            },
                          );
                        },
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _performProfileSearch(String q) async {
    try {
      setState(() => _isProfileSearchLoading = true);
      final resp = await BackendApiService().search(query: q, type: 'profiles', limit: 8);
      final list = <Map<String, dynamic>>[];
      if (resp['success'] == true) {
        if (resp['results'] is Map<String, dynamic>) {
          final data = resp['results'] as Map<String, dynamic>;
          final profiles = (data['profiles'] as List<dynamic>?) ?? (data['results'] as List<dynamic>?) ?? [];
          for (final d in profiles) {
            try { list.add(d as Map<String, dynamic>); } catch (_) {}
          }
        } else if (resp['data'] is List) {
          for (final d in resp['data']) {
            try { list.add(d as Map<String, dynamic>); } catch (_) {}
          }
        } else if (resp['data'] is Map<String, dynamic>) {
          final data = resp['data'] as Map<String, dynamic>;
          final profiles = (data['profiles'] as List<dynamic>?) ?? [];
          for (final d in profiles) {
            try { list.add(d as Map<String, dynamic>); } catch (_) {}
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _profileSearchResults = list;
        _isProfileSearchLoading = false;
      });
    } catch (e) {
      debugPrint('MapScreen profile search failed: $e');
      if (mounted) setState(() => _isProfileSearchLoading = false);
    }
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected 
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(List<Artwork> sortedArt) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      snapSizes: const [0.15, 0.4, 0.8],
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Drag Handle and Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    children: [
                      // Drag Handle
                      Container(
                        width: 60,
                        height: 24,
                        alignment: Alignment.center,
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nearby Art',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '${sortedArt.length} artworks found',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showListView = !_showListView;
                                  });
                                },
                                icon: Icon(
                                  _showListView ? Icons.grid_view_outlined : Icons.list_alt_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.sort,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onSelected: (value) {
                                  setState(() {
                                    _sortBy = value;
                                  });
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'distance',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.near_me, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Distance'),
                                        if (_sortBy == 'distance') ...[
                                          const Spacer(),
                                          Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'rarity',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.diamond, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Rarity'),
                                        if (_sortBy == 'rarity') ...[
                                          const Spacer(),
                                          Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'newest',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Newest'),
                                        if (_sortBy == 'newest') ...[
                                          const Spacer(),
                                          Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'name',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.sort_by_alpha, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Name'),
                                        if (_sortBy == 'name') ...[
                                          const Spacer(),
                                          Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Content Area
              sortedArt.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No artworks found',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSearching
                                  ? 'Try adjusting your search or filters'
                                  : 'Move around to discover art near you',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final artwork = sortedArt[index];
                            return _buildArtworkListItem(artwork);
                          },
                          childCount: sortedArt.length,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtworkListItem(Artwork artwork) {
    double distance = 0;
    if (_currentLocation != null) {
      const Distance distanceCalculator = Distance();
      distance = distanceCalculator.as(LengthUnit.Meter,
        LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        artwork.position,
      );
    }

    return GestureDetector(
      onTap: () {
        // Track artwork visit and increment view count
        context.read<ArtworkProvider>().incrementViewCount(artwork.id);
        
        // Navigate to artwork details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtDetailScreen(artworkId: artwork.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
        children: [
          // Artwork Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(Artwork.getRarityColor(artwork.rarity)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              artwork.arEnabled ? Icons.view_in_ar : Icons.palette,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Artwork Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        artwork.title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(Artwork.getRarityColor(artwork.rarity)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        artwork.rarity.name.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(Artwork.getRarityColor(artwork.rarity)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${artwork.artist}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${distance.round()}m away',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.monetization_on_outlined,
                      size: 12,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${artwork.rewards} KUB8',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Column(
            children: [
              if (artwork.arEnabled)
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, '/ar'),
                  icon: const Icon(Icons.view_in_ar, size: 20),
                  tooltip: 'View in AR',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtDetailScreen(artworkId: artwork.id),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'Details',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildMapControls() {
    return Positioned(
      bottom: 140,
      right: 16,
      child: Column(
        children: [
          // Zoom In
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
              },
              icon: const Icon(Icons.add),
            ),
          ),

          // Zoom Out
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
              },
              icon: const Icon(Icons.remove),
            ),
          ),

          // Center on Location
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _autoCenter 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _autoCenter = !_autoCenter;
                });
                if (_autoCenter && _currentLocation != null) {
                  _getLocation();
                  _mapController.move(
                    LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                    _mapController.camera.zoom,
                  );
                }
              },
              icon: Icon(
                _autoCenter ? Icons.my_location : Icons.location_searching,
                color: _autoCenter ? Colors.white : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtDiscoveryProgress() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final activeProgress = taskProvider.getActiveTaskProgress();
        final overallProgress = taskProvider.getOverallProgress();
        final completedCount = taskProvider.getCompletedTasksCount();
        final totalCount = taskProvider.getTotalAvailableTasksCount();

        return Positioned(
          top: MediaQuery.of(context).padding.top + (_isSearching ? 130 : 80),
          left: 16,
          right: 16,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isDiscoveryExpanded = !_isDiscoveryExpanded;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header (not draggable)
                  Row(
                    children: [
                      SizedBox(width: 24, height: 24, child: InlineProgress(progress: overallProgress, rows: 3, cols: 3, tileSize: 6.0, gap: 2.0, color: Theme.of(context).colorScheme.primary, backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.04), shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Art Discovery Progress',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              '$completedCount/$totalCount tasks completed',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isDiscoveryExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  
                  // Expandable tasks list (draggable content)
                  if (_isDiscoveryExpanded) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onPanStart: (details) {
                        // Handle drag start if needed
                      },
                      onPanEnd: (details) {
                        // Handle drag end if needed
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: activeProgress.map((progress) {
                            final task = TaskService().getTaskById(progress.taskId);
                            if (task == null) return const SizedBox.shrink();
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: task.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      task.icon,
                                      color: task.color,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 6,
                                          child: InlineProgress(
                                            progress: progress.progressPercentage,
                                            rows: 1,
                                            cols: 5,
                                            tileSize: 6.0,
                                            gap: 2.0,
                                            color: task.color,
                                            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.02),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${progress.completed}/${progress.total}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: task.color,
                                        ),
                                      ),
                                      if (progress.isCompleted)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    
                    // Debug buttons for testing (remove in production)
                    if (_isDiscoveryExpanded) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final taskProvider = context.read<TaskProvider>();
                              taskProvider.incrementAchievementProgress('gallery_explorer');
                              
                              // Trigger new achievement system
                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getString('user_id') ?? 'demo_user';
                              await AchievementService().checkAchievements(
                                userId: userId,
                                action: 'event_attended',
                                data: {'eventType': 'gallery'},
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('Visit Museum', style: TextStyle(fontSize: 10)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final taskProvider = context.read<TaskProvider>();
                              taskProvider.incrementAchievementProgress('first_favorite');
                              
                              // Trigger new achievement system
                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getString('user_id') ?? 'demo_user';
                              await AchievementService().checkAchievements(
                                userId: userId,
                                action: 'like_given',
                                data: {'likeCount': 1},
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('Add Favorite', style: TextStyle(fontSize: 10)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final taskProvider = context.read<TaskProvider>();
                              taskProvider.incrementAchievementProgress('art_critic');
                              
                              // Trigger new achievement system
                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getString('user_id') ?? 'demo_user';
                              await AchievementService().checkAchievements(
                                userId: userId,
                                action: 'comment_posted',
                                data: {'commentCount': 1},
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('Review Art', style: TextStyle(fontSize: 10)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _proximityCheckTimer?.cancel();
    _compassSubscription?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _sheetController.dispose();
    _arIntegrationService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    tileProviders?.dispose();
    super.dispose();
  }
}
