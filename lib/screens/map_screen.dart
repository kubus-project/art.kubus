import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/themeprovider.dart';
import '../providers/tile_providers.dart';
import 'art_detail_screen.dart';

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
  
  // Compass and Direction
  double? _direction;
  StreamSubscription<CompassEvent>? _compassSubscription;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  
  // Map Configuration
  TileProviders? tileProviders;
  
  // UI State
  bool _showFilters = false;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _sortBy = 'distance'; // distance, rarity, name
  bool _showListView = false;
  double _currentSheetSize = 0.12; // Track current sheet size for tap handling
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  // Discovery and Progress
  int _discoveredCount = 0;
  double _explorationProgress = 0.0;
  
  // Mock art data for exploration - Enhanced with more details
  final List<Map<String, dynamic>> _artLocations = [
    {
      'position': const LatLng(46.0569, 14.5058),
      'title': 'Digital Sculpture #1',
      'artist': 'CryptoArtist',
      'type': 'AR Sculpture',
      'rarity': 'Rare',
      'discovered': false,
      'distance': 120, // meters
      'description': 'An interactive digital sculpture that responds to touch and sound.',
      'rewards': 150, // KUB8 tokens
      'likes': 234,
      'views': 1500,
      'createdDate': '2024-01-15',
      'arEnabled': true,
      'collection': 'Urban Dreams',
    },
    {
      'position': const LatLng(46.0469, 14.5158),
      'title': 'Neon Dreams',
      'artist': 'VirtualVisionary',
      'type': 'Interactive Art',
      'rarity': 'Epic',
      'discovered': true,
      'distance': 340,
      'description': 'A mesmerizing neon light installation that pulses with the city\'s rhythm.',
      'rewards': 300,
      'likes': 567,
      'views': 3200,
      'createdDate': '2024-02-08',
      'arEnabled': true,
      'collection': 'Light & Sound',
    },
    {
      'position': const LatLng(46.0469, 14.5038),
      'title': 'Quantum Canvas',
      'artist': 'PixelPioneer',
      'type': 'Digital Painting',
      'rarity': 'Common',
      'discovered': false,
      'distance': 89,
      'description': 'A constantly evolving digital painting that changes based on quantum data.',
      'rewards': 75,
      'likes': 123,
      'views': 890,
      'createdDate': '2024-03-12',
      'arEnabled': false,
      'collection': 'Quantum Series',
    },
    {
      'position': const LatLng(46.0599, 14.5058),
      'title': 'Holographic Garden',
      'artist': 'NatureCode',
      'type': 'AR Experience',
      'rarity': 'Legendary',
      'discovered': false,
      'distance': 567,
      'description': 'Experience a holographic garden that blooms as you explore.',
      'rewards': 500,
      'likes': 789,
      'views': 4500,
      'createdDate': '2024-01-20',
      'arEnabled': true,
      'collection': 'Bio-Digital',
    },
    {
      'position': const LatLng(46.0579, 14.5078),
      'title': 'Sound Waves',
      'artist': 'AudioVisual',
      'type': 'Interactive Art',
      'rarity': 'Rare',
      'discovered': true,
      'distance': 220,
      'description': 'Visualize sound as colorful waves that dance around you.',
      'rewards': 200,
      'likes': 456,
      'views': 2100,
      'createdDate': '2024-02-28',
      'arEnabled': true,
      'collection': 'Audio Visual',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _calculateProgress();
  }

  void _calculateProgress() {
    _discoveredCount = _artLocations.where((art) => art['discovered'] == true).length;
    _explorationProgress = _discoveredCount / _artLocations.length;
  }

  void _initializeMap() {
    // Automatically request location on app start
    _getLocation();
    _showIntroDialogIfNeeded();
    // Start location timer for automatic updates
    _startLocationTimer();
    
    // Initialize compass
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

    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(_animationController);

    // Initialize tile providers after context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        tileProviders = TileProviders(Provider.of<ThemeProvider>(context, listen: false));
      }
    });
  }

  void _getLocation() async {
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

      LocationData currentLocation = await location.getLocation();
      if (mounted) {
        setState(() {
          _currentLocation = currentLocation;
        });

        if (_autoCenter && _currentLocation != null) {
          _mapController.move(
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            _mapController.camera.zoom,
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _startLocationTimer() {
    // Start location updates timer if not already running
    if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getLocationUpdate());
    }
  }

  void _getLocationUpdate() async {
    try {
      // Only update location, don't request permissions again
      LocationData currentLocation = await location.getLocation();
      if (mounted) {
        setState(() {
          _currentLocation = currentLocation;
        });

        if (_autoCenter && _currentLocation != null) {
          _mapController.move(
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            _mapController.camera.zoom,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  void _updateDirection(double? newDirection) {
    if (newDirection != null && (newDirection - (_direction ?? 0)).abs() > 1) {
      _rotationAnimation = Tween<double>(begin: _direction ?? 0, end: newDirection)
          .animate(_animationController)
        ..addListener(() {
          setState(() {
            _direction = _rotationAnimation.value;
          });
        });
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _compassSubscription = FlutterCompass.events!.listen((CompassEvent event) {
        if (mounted) {
          _updateDirection(event.heading);
        }
      });
    } else {
      _compassSubscription?.cancel();
      _compassSubscription = null;
    }
  }

  void _showIntroDialogIfNeeded() {
    const seenIntroBoxKey = 'seenMapIntro';
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(seenIntroBoxKey) ?? false) return;

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Welcome to Art Explorer',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Discover digital art and AR experiences around you. Tap on markers to explore artworks, use filters to find specific types, and interact with the art community.',
                style: GoogleFonts.outfit(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                prefs.setBool(seenIntroBoxKey, true);
              },
              child: Text(
                'Start Exploring',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTopOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Search and Controls Row
          Row(
            children: [
              // Search Bar
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        _isSearching ? Icons.search : Icons.search,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _isSearching = value.isNotEmpty;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search for art, artists, locations...',
                            hintStyle: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                          ),
                          style: GoogleFonts.outfit(
                            fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (_isSearching)
                        IconButton(
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
                        ),
                      IconButton(
                        onPressed: () => setState(() => _showFilters = !_showFilters),
                        icon: Icon(
                          Icons.tune,
                          color: _showFilters 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // AR Scanner Button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    _showARUnavailableDialog();
                  },
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Row(
              children: [
                Icon(
                  Icons.explore,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Art Explorer Progress',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _explorationProgress,
                        backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_discoveredCount/${_artLocations.length}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    if (!_showFilters) return const SizedBox.shrink();

    final typeFilters = ['All', 'AR Sculpture', 'Interactive Art', 'Digital Painting', 'AR Experience'];
    final rarityFilters = ['All Rarities', 'Common', 'Rare', 'Epic', 'Legendary'];

    return Positioned(
      top: MediaQuery.of(context).padding.top + 140,
      left: 16,
      right: 16,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'All';
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Type Filters
            Text(
              'Art Type',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: typeFilters.length,
                itemBuilder: (context, index) {
                  final filter = typeFilters[index];
                  final isSelected = _selectedFilter == filter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        filter,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isSelected 
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = selected ? filter : 'All';
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Rarity Filters
            Text(
              'Rarity',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: rarityFilters.length,
                itemBuilder: (context, index) {
                  final filter = rarityFilters[index];
                  final isSelected = _selectedFilter == filter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        filter,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isSelected 
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                      selectedColor: _getRarityColor(filter),
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = selected ? filter : 'All';
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Status and Sort
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sort By',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: _sortBy,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _sortBy = newValue;
                            });
                          }
                        },
                        items: <String>['distance', 'rarity', 'name', 'newest']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value[0].toUpperCase() + value.substring(1),
                              style: GoogleFonts.outfit(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        underline: Container(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _showListView = false),
                            icon: Icon(
                              Icons.map,
                              color: !_showListView 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _showListView = true),
                            icon: Icon(
                              Icons.list,
                              color: _showListView 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    final filteredArt = _getFilteredArtwork();
    final sortedArt = _getSortedArtwork(filteredArt);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: MediaQuery.of(context).size.height * 0.7, // Max 70% of screen height
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.12 / 0.7, // Adjust initial size relative to container
        minChildSize: 0.12 / 0.7, // Adjust min size relative to container
        maxChildSize: 1.0, // Can expand to full container height
        snap: true,
        snapSizes: const [0.12/0.7, 0.35/0.7, 1.0], // Adjust snap sizes
        expand: false,
        builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            setState(() {
              _currentSheetSize = notification.extent;
            });
            return true;
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
          child: Column(
            children: [
              // Draggable handle area - optimized for DraggableScrollableSheet
              GestureDetector(
                onTap: () {
                  // Tap to cycle through snap points
                  final currentSize = _currentSheetSize;
                  double targetSize;
                  
                  if (currentSize <= 0.2) {
                    targetSize = 0.35;
                  } else if (currentSize <= 0.5) {
                    targetSize = 0.7;
                  } else {
                    targetSize = 0.12;
                  }
                  
                  _sheetController.animateTo(
                    targetSize,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.transparent, // Make sure this area is tappable
                  child: Center(
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _currentSheetSize > 0.3 ? 60 : 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: _currentSheetSize > 0.3 ? 0.4 : 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Add subtle visual hint that this area is draggable
                        const SizedBox(height: 4),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _currentSheetSize > 0.3 ? 0.6 : 0.3,
                          child: Icon(
                            Icons.drag_handle,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Header with animated elements
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: _currentSheetSize > 0.3 ? 12 : 8
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: GoogleFonts.outfit(
                            fontSize: _currentSheetSize > 0.3 ? 22 : 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          child: Text(
                            _isSearching && _searchQuery.isNotEmpty 
                                ? 'Search Results' 
                                : 'Nearby Art',
                          ),
                        ),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: GoogleFonts.outfit(
                            fontSize: _currentSheetSize > 0.3 ? 15 : 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          child: Text('${sortedArt.length} artworks found'),
                        ),
                      ],
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _currentSheetSize > 0.2 ? 1.0 : 0.7,
                      child: Row(
                        children: [
                          // Quick action: Discover nearby - now clickable with ripple effect
                          InkWell(
                            onTap: () {
                              // Trigger discover nearby functionality
                              _discoverNearby();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: EdgeInsets.symmetric(
                                horizontal: _currentSheetSize > 0.3 ? 16 : 12, 
                                vertical: _currentSheetSize > 0.3 ? 8 : 6
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.near_me,
                                    size: _currentSheetSize > 0.3 ? 18 : 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Discover',
                                    style: GoogleFonts.outfit(
                                      fontSize: _currentSheetSize > 0.3 ? 14 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showListView = !_showListView;
                                });
                              },
                              icon: Icon(
                                _showListView ? Icons.map : Icons.list,
                                size: _currentSheetSize > 0.3 ? 22 : 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable content area with proper physics for DraggableScrollableSheet
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(top: 8),
                  physics: const AlwaysScrollableScrollPhysics(), // Allow scrolling but don't interfere with sheet dragging
                  itemCount: sortedArt.length,
                  itemBuilder: (context, index) {
                    final art = sortedArt[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: _buildEnhancedArtCard(art),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
    ), // Close DraggableScrollableSheet
    ); // Close Positioned widget
  }

  List<Map<String, dynamic>> _getFilteredArtwork() {
    List<Map<String, dynamic>> filtered = List.from(_artLocations);

    // Apply search filter
    if (_isSearching && _searchQuery.isNotEmpty) {
      filtered = filtered.where((art) {
        final query = _searchQuery.toLowerCase();
        return art['title'].toLowerCase().contains(query) ||
               art['artist'].toLowerCase().contains(query) ||
               art['type'].toLowerCase().contains(query) ||
               art['collection'].toLowerCase().contains(query);
      }).toList();
    }

    // Apply category filter
    if (_selectedFilter != 'All' && _selectedFilter != 'All Rarities' && _selectedFilter != 'All Status') {
      filtered = filtered.where((art) {
        return art['type'] == _selectedFilter || 
               art['rarity'] == _selectedFilter ||
               (_selectedFilter == 'Discovered' && art['discovered']) ||
               (_selectedFilter == 'Undiscovered' && !art['discovered']) ||
               (_selectedFilter == 'AR Enabled' && art['arEnabled']);
      }).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> _getSortedArtwork(List<Map<String, dynamic>> artwork) {
    List<Map<String, dynamic>> sorted = List.from(artwork);

    switch (_sortBy) {
      case 'distance':
        sorted.sort((a, b) => a['distance'].compareTo(b['distance']));
        break;
      case 'rarity':
        final rarityOrder = {'Common': 1, 'Rare': 2, 'Epic': 3, 'Legendary': 4};
        sorted.sort((a, b) => (rarityOrder[b['rarity']] ?? 0).compareTo(rarityOrder[a['rarity']] ?? 0));
        break;
      case 'name':
        sorted.sort((a, b) => a['title'].compareTo(b['title']));
        break;
      case 'newest':
        sorted.sort((a, b) => b['createdDate'].compareTo(a['createdDate']));
        break;
    }

    return sorted;
  }

  Widget _buildEnhancedArtCard(Map<String, dynamic> art) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Art Preview with Collection Badge
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getRarityColor(art['rarity']),
                          _getRarityColor(art['rarity']).withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      art['arEnabled'] ? Icons.view_in_ar : Icons.palette,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  if (art['discovered'])
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Art Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            art['title'],
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRarityColor(art['rarity']).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            art['rarity'],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getRarityColor(art['rarity']),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${art['artist']}',
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
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${art['distance']}m away',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.collections_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            art['collection'],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            art['description'],
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Stats and Actions
          Row(
            children: [
              // Stats
              Row(
                children: [
                  Icon(
                    Icons.favorite_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${art['likes']}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${art['views']}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.monetization_on_outlined,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${art['rewards']} KUB8',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Action Buttons
              Row(
                children: [
                  if (art['arEnabled'])
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to AR experience
                        Navigator.pushNamed(context, '/ar');
                      },
                      icon: const Icon(Icons.view_in_ar, size: 16),
                      label: Text(
                        'AR',
                        style: GoogleFonts.outfit(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to art detail screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArtDetailScreen(artData: art),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: Text(
                      'Details',
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.orange;
      case 'all rarities':
        return Theme.of(context).colorScheme.primary;
      default:
        return Colors.grey;
    }
  }

  void _markAsDiscovered(Map<String, dynamic> art) {
    setState(() {
      art['discovered'] = true;
      _calculateProgress();
    });
    
    // Show discovery reward popup
    _showDiscoveryReward(art);
  }

  void _discoverNearby() {
    // Find the nearest undiscovered artwork
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable location to discover nearby art'),
        ),
      );
      return;
    }

    // Get undiscovered artworks and find closest
    final undiscovered = _artLocations.where((art) => !art['discovered']).toList();
    if (undiscovered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All nearby art has been discovered!'),
        ),
      );
      return;
    }

    // Find closest undiscovered artwork
    Map<String, dynamic>? closestArt;
    double closestDistance = double.infinity;
    
    for (final art in undiscovered) {
      final distance = _calculateDistance(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
        art['latitude'],
        art['longitude'],
      );
      
      if (distance < closestDistance) {
        closestDistance = distance;
        closestArt = art;
      }
    }

    if (closestArt != null) {
      // Move map to closest artwork and show info
      _mapController.move(
        LatLng(closestArt['latitude'], closestArt['longitude']),
        16.0, // Zoom level
      );
      
      // Show info about the closest artwork
      _showArtworkDetail(closestArt);
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple distance calculation using Haversine formula
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = (lat2 - lat1) * (3.14159 / 180);
    final double dLon = (lon2 - lon1) * (3.14159 / 180);
    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(lat1 * (3.14159 / 180)) * cos(lat2 * (3.14159 / 180)) * sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  void _showArtworkDetail(Map<String, dynamic> art) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      art['title'],
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'by ${art['artist']}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      art['description'],
                      style: GoogleFonts.outfit(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    if (!art['discovered'])
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _markAsDiscovered(art);
                            Navigator.pop(context);
                          },
                          child: const Text('Mark as Discovered'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscoveryReward(Map<String, dynamic> art) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.celebration,
              color: Colors.amber,
            ),
            const SizedBox(width: 8),
            Text(
              'Art Discovered!',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getRarityColor(art['rarity']),
                    _getRarityColor(art['rarity']).withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                art['arEnabled'] ? Icons.view_in_ar : Icons.palette,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You discovered "${art['title']}"!',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Reward: ${art['rewards']} KUB8 tokens',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Continue Exploring',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (art['arEnabled'])
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/ar');
              },
              child: Text(
                'Experience AR',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
        ],
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
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                );
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
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                );
              },
              icon: const Icon(Icons.remove),
            ),
          ),
          // Center/Compass
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _autoCenter 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)
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
                  if (_autoCenter) {
                    // Request location when auto-center is enabled
                    if (_currentLocation == null) {
                      _getLocation(); // This will request permissions if needed
                    } else {
                      _mapController.move(
                        LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                        _mapController.camera.zoom,
                      );
                    }
                  }
                  _direction = 0;
                });
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

  @override
  Widget build(BuildContext context) {
    double rotationRadians = -(_direction ?? 0) * (3.14159 / 180); // Convert degrees to radians
    
    return Scaffold(
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Initialize tile providers if not already done
          if (!mounted) return const Center(child: CircularProgressIndicator());
          
          try {
            tileProviders ??= TileProviders(themeProvider);
          } catch (e) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Stack(
            children: [
              // Map
              Transform.scale(
                scale: 1.0,
                child: Transform.rotate(
                  angle: _autoCenter ? rotationRadians : 0,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation != null
                          ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                          : const LatLng(37.7749, -122.4194),
                      initialZoom: 15.0,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      // Tile Layer - use getTileLayer method
                      tileProviders?.getTileLayer() ?? TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        maxZoom: 18,
                      ),
                      // Art Markers
                      MarkerLayer(
                        markers: [
                          // Current location marker
                          if (_currentLocation != null)
                            Marker(
                              point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
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
                              ),
                            ),
                          // Art markers
                          ..._artLocations.map((art) {
                            final isNearby = art['distance'] < 50; // Within 50 meters
                            return Marker(
                              point: art['position'],
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onTap: () {
                                  if (isNearby && !art['discovered']) {
                                    // Allow discovery if close enough
                                    _markAsDiscovered(art);
                                  } else {
                                    // Navigate to art detail screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ArtDetailScreen(artData: art),
                                      ),
                                    );
                                  }
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Pulsing animation for undiscovered nearby art
                                    if (isNearby && !art['discovered'])
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: _getRarityColor(art['rarity']).withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    // Main marker
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: art['discovered'] 
                                            ? Colors.green 
                                            : _getRarityColor(art['rarity']),
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
                                        art['discovered'] 
                                            ? Icons.check 
                                            : (art['arEnabled'] ? Icons.view_in_ar : Icons.palette),
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    // Discovery indicator
                                    if (isNearby && !art['discovered'])
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
                                            Icons.touch_app,
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
              // UI Overlays
              _buildTopOverlay(),
              _buildFilterChips(),
              _buildMapControls(),
              // DraggableScrollableSheet positioned properly in Stack
              _buildBottomSheet(),
            ],
          );
        },
      ),
    );
  }

  void _showARUnavailableDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('AR Feature'),
          content: const Text(
            'AR functionality is currently being improved. Please check back soon for an enhanced experience!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _compassSubscription?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _sheetController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    tileProviders?.dispose();
    super.dispose();
  }
}
