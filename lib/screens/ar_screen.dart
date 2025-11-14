import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/themeprovider.dart';
import '../providers/platform_provider.dart';
import '../providers/saved_items_provider.dart';
import '../services/ar_manager.dart';
import '../services/ar_integration_service.dart';
import '../services/achievement_service.dart';
import '../widgets/ar_marker_scanner.dart';
import '../community/community_interactions.dart';
import 'download_app_screen.dart';
import 'profile_screen_methods.dart';

/// AR Screen with seamless Android and iOS support
/// On web, redirects to download app screen
class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  
  final ARManager _arManager = ARManager();
  final ARIntegrationService _arIntegrationService = ARIntegrationService();
  
  bool _isARReady = false;
  bool _isLoading = true;
  final bool _showControls = true;
  String _currentMode = 'scan'; // scan, place, view
  LatLng? _currentLocation;
  
  // AR Settings
  bool _showFeaturePoints = false;
  bool _showPlanes = true;
  bool _autoDetectSurfaces = true;
  bool _showDebugInfo = false;
  double _modelScale = 1.0;
  
  // Scanner controls
  bool _flashEnabled = false;
  dynamic _scannerController;
  
  // Mock data for testing
  final List<Map<String, dynamic>> _mockArtworks = [
    {
      'id': 'artwork_1',
      'title': 'Digital Cube',
      'artist': 'Test Artist',
      'description': 'A simple 3D cube for testing AR placement',
      'model': 'cube',
      'scale': 0.3,
    },
    {
      'id': 'artwork_2',
      'title': 'Sphere Sculpture',
      'artist': 'Mock Artist',
      'description': 'A spherical artwork floating in space',
      'model': 'sphere',
      'scale': 0.25,
    },
    {
      'id': 'artwork_3',
      'title': 'Pyramid Art',
      'artist': 'Demo Creator',
      'description': 'A geometric pyramid installation',
      'model': 'pyramid',
      'scale': 0.35,
    },
  ];
  
  final List<Map<String, dynamic>> _placedObjects = [];
  Map<String, dynamic>? _selectedArtwork;
  final Set<String> _likedArtworks = {};
  final Set<String> _savedArtworks = {};
  

  
  final List<Map<String, dynamic>> _arModes = [
    {'id': 'scan', 'name': 'Scan', 'icon': Icons.qr_code_scanner, 'description': 'Discover AR artworks'},
    {'id': 'place', 'name': 'Place', 'icon': Icons.add_location, 'description': 'Position new artwork'},
    {'id': 'view', 'name': 'View', 'icon': Icons.visibility, 'description': 'View placed artworks'},
    {'id': 'create', 'name': 'Create', 'icon': Icons.create, 'description': 'Create AR artwork'},
  ];

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize AR only once after dependencies are available
    if (!_hasInitialized) {
      _hasInitialized = true;
      // Schedule initialization after the first frame to avoid showing dialogs during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeAR();
        }
      });
    }
  }

  Future<void> _initializeAR() async {
    setState(() => _isLoading = true);

    try {
      final platformProvider = Provider.of<PlatformProvider>(context, listen: false);
      
      if (!platformProvider.supportsARFeatures) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showARNotSupportedDialog();
            }
          });
        }
        setState(() => _isLoading = false);
        return;
      }

      // Initialize AR Manager and Integration Service
      await _arManager.initialize();
      await _arIntegrationService.initialize();
      
      // Set up callbacks for AR events
      _arIntegrationService.onMarkerActivated = (marker) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AR marker nearby: ${marker.name}'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () => _launchARForMarker(marker.artworkId),
              ),
            ),
          );
        }
      };
      
      _arIntegrationService.onArtworkDiscovered = (artwork) {
        debugPrint('Artwork discovered: ${artwork.title}');
      };
      
      // Mock location for testing (replace with actual location service)
      _currentLocation = const LatLng(46.0569, 14.5058); // Ljubljana, Slovenia
      await _arIntegrationService.updateLocation(_currentLocation!);
      
      setState(() {
        _isARReady = true;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      debugPrint('AR initialization error: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showARInitializationErrorDialog();
          }
        });
      }
    }
  }

  void _launchARForMarker(String? artworkId) {
    if (artworkId == null) return;
    // Find artwork and launch AR
    final artwork = _mockArtworks.firstWhere(
      (a) => a['id'] == artworkId,
      orElse: () => _mockArtworks.first,
    );
    
    setState(() {
      _selectedArtwork = artwork;
      _currentMode = 'view';
    });
    
    debugPrint('Launching AR for artwork: ${artwork['title']}');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _arManager.dispose();
    _arIntegrationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final platformProvider = Provider.of<PlatformProvider>(context);
    
    // If on web, show download app screen instead
    if (platformProvider.isWeb) {
      return const DownloadAppScreen(
        feature: 'AR Experience',
        description: 'Augmented Reality features require native device capabilities. Download the art.kubus app to view digital artworks in your physical space using your phone\'s camera.',
      );
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main AR View - QR Scanner for 'scan' mode, camera view for others
            if (_isARReady)
              _currentMode == 'scan'
                  ? ARMarkerScanner(
                      onArtworkFound: (artworkData) async {
                        setState(() {
                          // Store scanned artwork
                          _placedObjects.add({
                            'id': artworkData['id'] ?? DateTime.now().toString(),
                            'title': artworkData['title'] ?? 'Unknown',
                            'artist': artworkData['artist'] ?? 'Unknown',
                            'modelUrl': artworkData['modelUrl'],
                            'timestamp': DateTime.now().millisecondsSinceEpoch,
                          });
                        });
                      },
                      onControllerReady: (controller) {
                        setState(() {
                          _scannerController = controller;
                        });
                      },
                    )
                  : _currentMode == 'view'
                      ? _buildViewMode(themeProvider)
                      : _buildModePreview(themeProvider),
            
            // Loading overlay
            if (_isLoading)
              _buildLoadingOverlay(),
            
            // Top bar with mode and settings (for all modes)
            if (_isARReady)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(themeProvider),
              ),
            
            // Bottom controls overlay (only for non-scan modes)
            if (_isARReady && _showControls && _currentMode != 'scan')
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControls(themeProvider),
              ),
            
            // Mode selector overlay for all modes (positioned at bottom)
            if (_isARReady)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: themeProvider.accentColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _arModes.map((mode) {
                      final isSelected = mode['id'] == _currentMode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _changeMode(mode['id']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? themeProvider.accentColor.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? themeProvider.accentColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  mode['icon'],
                                  color: isSelected 
                                      ? themeProvider.accentColor
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mode['name'],
                                  style: GoogleFonts.inter(
                                    color: isSelected 
                                        ? themeProvider.accentColor
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(themeProvider.accentColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Initializing AR...',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _arManager.isInitialized ? 'AR Ready' : 'Setting up AR environment',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewMode(ThemeProvider themeProvider) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _placedObjects.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_off,
                    size: 64,
                    color: themeProvider.accentColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Artworks Yet',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Scan QR codes to discover AR artworks',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 80, bottom: 120), // Top padding for app bar, bottom for mode selector
              itemCount: _placedObjects.length,
              itemBuilder: (context, index) {
                final artwork = _placedObjects[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: themeProvider.accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.view_in_ar,
                        color: themeProvider.accentColor,
                      ),
                    ),
                    title: Text(
                      artwork['title'] ?? 'Unknown',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      artwork['artist'] ?? 'Unknown Artist',
                      style: GoogleFonts.inter(),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.open_in_new,
                        color: themeProvider.accentColor,
                      ),
                      onPressed: () async {
                        // Launch AR viewer for this artwork using ARManager
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          // Add model to AR scene
                          await _arManager.addModel(
                            modelPath: artwork['modelURL'] ?? '',
                            position: vector.Vector3(0, 0, -1.5),
                            scale: vector.Vector3.all(1.0),
                            name: artwork['id'],
                          );
                          
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('AR model loaded successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to load AR model: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildModePreview(ThemeProvider themeProvider) {
    final mode = _arModes.firstWhere((mode) => mode['id'] == _currentMode);
    
    // For place and create modes, show AR camera view
    if (_currentMode == 'place' || _currentMode == 'create') {
      return Stack(
        children: [
          // AR camera view from ARManager
          _arManager.createARView(
            onARViewCreated: (controller) {
              debugPrint('AR View created successfully');
              // Automatically place selected artwork if in place mode
              if (_currentMode == 'place' && _selectedArtwork != null) {
                _placeSelectedArtwork();
              }
            },
          ),
          // Instruction overlay for place mode
          if (_currentMode == 'place' && _selectedArtwork != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Placing: ${_selectedArtwork!['title']}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Move your device to find a flat surface',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    
    // For view mode, show placeholder (will be replaced with actual AR view when artwork selected)
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(top: 80, bottom: 140), // Top padding for app bar, bottom for mode selector
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mode['icon'],
              color: themeProvider.accentColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '${mode['name']} Mode',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                mode['description'],
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to place selected artwork in AR
  Future<void> _placeSelectedArtwork() async {
    if (_selectedArtwork == null) return;
    
    try {
      // Place model in front of camera
      await _arManager.addModel(
        modelPath: _selectedArtwork!['modelURL'] ?? '',
        position: vector.Vector3(0, 0, -1.5), // 1.5 meters in front
        scale: vector.Vector3.all(1.0),
        name: _selectedArtwork!['id'],
      );
      
      debugPrint('Placed AR artwork: ${_selectedArtwork!['title']}');
      
      // Note: Discovery tracking would require converting Map to Artwork object
      // This can be implemented when backend integration is complete
    } catch (e) {
      debugPrint('Error placing artwork: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place artwork: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTopBar(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final overlayColor = isDark 
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.95);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            overlayColor,
            overlayColor.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          // Mode indicator (back button removed during AR camera view)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _arModes.firstWhere((mode) => mode['id'] == _currentMode)['icon'],
                    color: themeProvider.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _arModes.firstWhere((mode) => mode['id'] == _currentMode)['name'],
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Flash button (only in scan mode)
          if (_currentMode == 'scan' && _scannerController != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _flashEnabled
                    ? themeProvider.accentColor.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                border: _flashEnabled
                    ? Border.all(color: themeProvider.accentColor, width: 1.5)
                    : null,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _flashEnabled ? Icons.flash_on : Icons.flash_off,
                  color: _flashEnabled
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
                onPressed: () async {
                  try {
                    await _scannerController.toggleTorch();
                    setState(() {
                      _flashEnabled = !_flashEnabled;
                    });
                  } catch (e) {
                    // Flash not available
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Settings button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface, size: 20),
              onPressed: _showARSettings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final overlayColor = isDark 
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.95);
    
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100, top: 24), // Extra bottom padding for mode selector
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            overlayColor,
            overlayColor.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action button based on mode (mode selector removed - now unified at bottom)
          _buildActionButton(themeProvider),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeProvider themeProvider) {
    String buttonText = '';
    IconData buttonIcon = Icons.check;
    
    switch (_currentMode) {
      case 'scan':
        buttonText = 'Scan for Artwork';
        buttonIcon = Icons.qr_code_scanner;
        break;
      case 'place':
        buttonText = 'Place Artwork Here';
        buttonIcon = Icons.add_location;
        break;
      case 'view':
        buttonText = 'View Details';
        buttonIcon = Icons.info_outline;
        break;
      case 'create':
        buttonText = 'Create AR Artwork';
        buttonIcon = Icons.create;
        break;
    }

    final buttonTextColor = themeProvider.isDarkMode ? Colors.white : Colors.white;
    
    return ElevatedButton.icon(
      onPressed: _handleAction,
      icon: Icon(buttonIcon, color: buttonTextColor),
      label: Text(
        buttonText,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: buttonTextColor,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: themeProvider.accentColor,
        foregroundColor: buttonTextColor,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        shadowColor: themeProvider.accentColor.withValues(alpha: 0.4),
      ),
    );
  }

  // Event handlers
  

  void _onObjectPlaced(String objectId) {
    debugPrint('Object placed: $objectId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Artwork placed successfully!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }


  void _changeMode(String modeId) {
    setState(() {
      _currentMode = modeId;
      // Clear scanner controller when leaving scan mode
      if (modeId != 'scan') {
        _scannerController = null;
        _flashEnabled = false;
      }
    });
  }

  void _handleAction() {
    switch (_currentMode) {
      case 'scan':
        _startScanning();
        break;
      case 'place':
        _placeArtwork();
        break;
      case 'view':
        _viewArtworkDetails();
        break;
      case 'create':
        _createArtwork();
        break;
    }
  }

  void _startScanning() {
    // Show available artworks in scan mode (data from backend)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nearby Artworks',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _mockArtworks.length,
                  itemBuilder: (context, index) {
                    final artwork = _mockArtworks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.view_in_ar, 
                            color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(artwork['title'],
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('by ${artwork['artist']}',
                          style: GoogleFonts.inter(fontSize: 12)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          setState(() {
                            _selectedArtwork = artwork;
                            _currentMode = 'place';
                          });
                          Navigator.pop(context);
                          
                          // Show snackbar after navigation completes and context is still mounted
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Selected: ${artwork['title']}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _placeArtwork() {
    _selectedArtwork ??= _mockArtworks.first;
    
    final placedObject = {
      'id': 'placed_${DateTime.now().millisecondsSinceEpoch}',
      'artworkId': _selectedArtwork!['id'],
      'title': _selectedArtwork!['title'],
      'artist': _selectedArtwork!['artist'],
      'model': _selectedArtwork!['model'],
      'scale': (_selectedArtwork!['scale'] as double) * _modelScale,
      'position': {'x': 0.0, 'y': 0.0, 'z': -1.5},
      'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0},
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _placedObjects.add(placedObject);
    });
    
    _onObjectPlaced(placedObject['id'] as String);
  }

  void _viewArtworkDetails() {
    if (_placedObjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No artworks placed yet. Try placing some first!')),
      );
      return;
    }
    
    // Show list of placed objects
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Placed Artworks (${_placedObjects.length})',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _placedObjects.length,
                itemBuilder: (context, index) {
                  final obj = _placedObjects[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(Icons.view_in_ar, 
                        color: Theme.of(context).colorScheme.primary),
                      title: Text(obj['title']),
                      subtitle: Text('by ${obj['artist']}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red[400]),
                        onPressed: () {
                          setState(() {
                            _placedObjects.removeAt(index);
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Artwork removed')),
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showArtworkDetails(obj['id']);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createArtwork() {
    // Show create artwork dialog
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create AR Artwork',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Artwork Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Select 3D Model',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  ChoiceChip(
                    label: const Text('Cube'),
                    selected: true,
                    onSelected: (selected) {},
                  ),
                  ChoiceChip(
                    label: const Text('Sphere'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                  ChoiceChip(
                    label: const Text('Pyramid'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Artwork created! Switch to Place mode to position it.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Create Artwork', 
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showArtworkDetails(String artworkId) async {
    final artwork = _placedObjects.firstWhere(
      (obj) => obj['id'] == artworkId,
      orElse: () => {},
    );
    
    if (artwork.isEmpty) return;
    
    // Track AR view achievement
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'demo_user';
    await AchievementService().checkAchievements(
      userId: userId,
      action: 'ar_viewed',
      data: {'viewCount': _placedObjects.length},
    );
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      artwork['title'],
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'by ${artwork['artist']}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Model', artwork['model']),
              _buildDetailRow('Scale', '${(artwork['scale'] * 100).toStringAsFixed(0)}%'),
              _buildDetailRow('Placed', _formatTimestamp(artwork['timestamp'])),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Actions',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInteractionButton(
                    Icons.share_outlined,
                    'Share',
                    onTap: () {
                      _handleShare(artwork);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildInteractionButton(
                    _likedArtworks.contains(artwork['id']) 
                        ? Icons.favorite 
                        : Icons.favorite_border,
                    _likedArtworks.contains(artwork['id']) ? 'Liked' : 'Like',
                    onTap: () {
                      _handleLike(artwork);
                      setModalState(() {}); // Update modal state immediately
                    },
                    isActive: _likedArtworks.contains(artwork['id']),
                    activeColor: Colors.red,
                  ),
                  const SizedBox(width: 12),
                  _buildInteractionButton(
                    _savedArtworks.contains(artwork['id']) 
                        ? Icons.bookmark 
                        : Icons.bookmark_border,
                    _savedArtworks.contains(artwork['id']) ? 'Saved' : 'Save',
                    onTap: () {
                      _handleSave(artwork);
                      setModalState(() {}); // Update modal state immediately
                    },
                    isActive: _savedArtworks.contains(artwork['id']),
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Build animated interaction button with visual feedback
  Widget _buildInteractionButton(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final color = isActive && activeColor != null
        ? activeColor
        : Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTapDown: (_) {
        // Immediate haptic-like feedback via rebuild
        if (onTap != null && mounted) {
          setState(() {
            // Force immediate rebuild for ultra-fast visual response
          });
        }
      },
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isActive
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isActive ? color : Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: Icon(
                icon,
                color: isActive
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  // Social interaction handlers
  Future<void> _handleShare(Map<String, dynamic> artwork) async {
    try {
      final shareText = '''
🎨 Check out this AR artwork on art.kubus!

"${artwork['title']}"
by ${artwork['artist']}

Experience it in augmented reality!
''';
      
      // Use share_plus to share
      await Share.share(shareText, subject: 'AR Artwork: ${artwork['title']}');
      
      // Track share in community interactions
      final post = CommunityPost(
        id: artwork['id'],
        authorId: artwork['artworkId'] ?? artwork['id'],
        authorName: artwork['artist'],
        content: artwork['title'],
        timestamp: DateTime.parse(artwork['timestamp']),
      );
      
      await CommunityService.sharePost(post);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Artwork shared successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLike(Map<String, dynamic> artwork) async {
    setState(() {
      if (_likedArtworks.contains(artwork['id'])) {
        _likedArtworks.remove(artwork['id']);
      } else {
        _likedArtworks.add(artwork['id']);
      }
    });
    
    // Track like in community interactions
    final post = CommunityPost(
      id: artwork['id'],
      authorId: artwork['artworkId'] ?? artwork['id'],
      authorName: artwork['artist'],
      content: artwork['title'],
      timestamp: DateTime.parse(artwork['timestamp']),
      isLiked: _likedArtworks.contains(artwork['id']),
    );
    
    await CommunityService.togglePostLike(post);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _likedArtworks.contains(artwork['id']) 
                    ? Icons.favorite 
                    : Icons.favorite_border,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(_likedArtworks.contains(artwork['id']) 
                  ? 'Added to your likes!'
                  : 'Removed from likes'),
            ],
          ),
          backgroundColor: _likedArtworks.contains(artwork['id']) 
              ? Colors.pink 
              : Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleSave(Map<String, dynamic> artwork) async {
    setState(() {
      if (_savedArtworks.contains(artwork['id'])) {
        _savedArtworks.remove(artwork['id']);
      } else {
        _savedArtworks.add(artwork['id']);
      }
    });
    
    // Update SavedItemsProvider
    final savedItemsProvider = Provider.of<SavedItemsProvider>(context, listen: false);
    await savedItemsProvider.toggleArtworkSaved(artwork['id']);
    
    // Track save/bookmark in community interactions
    final post = CommunityPost(
      id: artwork['id'],
      authorId: artwork['artworkId'] ?? artwork['id'],
      authorName: artwork['artist'],
      content: artwork['title'],
      timestamp: DateTime.parse(artwork['timestamp']),
      isBookmarked: _savedArtworks.contains(artwork['id']),
    );
    
    await CommunityService.toggleBookmark(post);
    
    // Track in profile for "Saved Items" section
    if (_savedArtworks.contains(artwork['id'])) {
      debugPrint('Artwork saved to profile: ${artwork['id']}');
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _savedArtworks.contains(artwork['id']) 
                    ? Icons.bookmark 
                    : Icons.bookmark_border,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(_savedArtworks.contains(artwork['id']) 
                  ? 'Saved to your collection!'
                  : 'Removed from saved items'),
            ],
          ),
          backgroundColor: _savedArtworks.contains(artwork['id']) 
              ? Colors.blue 
              : Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: _savedArtworks.contains(artwork['id'])
              ? SnackBarAction(
                  label: 'View',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to profile collections using proper navigation
                    Navigator.of(context).pop(); // Close AR screen first
                    
                    // Import ProfileScreenMethods is already available
                    // Show collections modal instead of double pop which causes assertion
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        ProfileScreenMethods.showCollections(context);
                      }
                    });
                  },
                )
              : null,
        ),
      );
    }
  }

  void _showARSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AR Settings',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Scan Settings Section
                if (_currentMode == 'scan') ...[
                  Text(
                    'Scanner Settings',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Icon(Icons.flash_on, color: Theme.of(context).colorScheme.primary),
                    title: Text('Flash Control',
                      style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(_flashEnabled ? 'Currently ON' : 'Currently OFF',
                      style: GoogleFonts.inter(fontSize: 12)),
                    trailing: Switch(
                      value: _flashEnabled,
                      onChanged: (value) async {
                        if (_scannerController != null) {
                          try {
                            await _scannerController.toggleTorch();
                            setModalState(() => _flashEnabled = !_flashEnabled);
                            setState(() => _flashEnabled = !_flashEnabled);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Flash not available on this device')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.primary),
                    title: Text('Scanner Overlay',
                      style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text('Show/hide scanner guide',
                      style: GoogleFonts.inter(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scanner overlay resets automatically after 3 seconds')),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                Text(
                  'AR Display',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text('Show Feature Points',
                    style: GoogleFonts.inter(fontSize: 14)),
                  subtitle: Text('Display tracking points on surfaces',
                    style: GoogleFonts.inter(fontSize: 12)),
                  value: _showFeaturePoints,
                  onChanged: (value) {
                    setModalState(() => _showFeaturePoints = value);
                    setState(() => _showFeaturePoints = value);
                  },
                ),
                SwitchListTile(
                  title: Text('Show Planes',
                    style: GoogleFonts.inter(fontSize: 14)),
                  subtitle: Text('Display detected plane surfaces',
                    style: GoogleFonts.inter(fontSize: 12)),
                  value: _showPlanes,
                  onChanged: (value) {
                    setModalState(() => _showPlanes = value);
                    setState(() => _showPlanes = value);
                  },
                ),
                SwitchListTile(
                  title: Text('Auto-detect Surfaces',
                    style: GoogleFonts.inter(fontSize: 14)),
                  subtitle: Text('Automatically detect flat surfaces',
                    style: GoogleFonts.inter(fontSize: 12)),
                  value: _autoDetectSurfaces,
                  onChanged: (value) {
                    setModalState(() => _autoDetectSurfaces = value);
                    setState(() => _autoDetectSurfaces = value);
                  },
                ),
                SwitchListTile(
                  title: Text('Debug Info',
                    style: GoogleFonts.inter(fontSize: 14)),
                  subtitle: Text('Show technical information',
                    style: GoogleFonts.inter(fontSize: 12)),
                  value: _showDebugInfo,
                  onChanged: (value) {
                    setModalState(() => _showDebugInfo = value);
                    setState(() => _showDebugInfo = value);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Model Scale: ${(_modelScale * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Slider(
                  value: _modelScale,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${(_modelScale * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    setModalState(() => _modelScale = value);
                    setState(() => _modelScale = value);
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Actions',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.delete_sweep),
                  title: Text('Clear All Artworks',
                    style: GoogleFonts.inter(fontSize: 14)),
                  subtitle: Text('Remove all placed AR objects',
                    style: GoogleFonts.inter(fontSize: 12)),
                  onTap: () {
                    setState(() => _placedObjects.clear());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All artworks cleared')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text('Reset AR Session',
                    style: GoogleFonts.inter(fontSize: 14)),
                  subtitle: Text('Restart AR tracking',
                    style: GoogleFonts.inter(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _initializeAR();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AR session reset')),
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

  void _showARNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'AR Not Supported',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Your device does not support AR features. AR requires ARCore (Android) or ARKit (iOS).',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showARInitializationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'AR Initialization Failed',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Could not initialize AR. Please check camera permissions and try again.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeAR();
            },
            child: Text(
              'Retry',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
