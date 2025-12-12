import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_animations.dart';
import '../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/map_marker_subject.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/dao_provider.dart';
import '../../providers/institution_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/platform_provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../services/user_action_logger.dart';
import '../../providers/wallet_provider.dart';
import '../../services/ar_manager.dart';
import '../../services/ar_integration_service.dart';
import '../../services/achievement_service.dart';
import '../../services/ar_marker_service.dart';
import '../../widgets/ar_marker_scanner.dart';
import '../../community/community_interactions.dart';
import '../../utils/marker_subject_utils.dart';
import '../download_app_screen.dart';
import '../community/profile_screen_methods.dart';
/// AR Screen with seamless Android and iOS support
/// On web, redirects to download app screen
class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;

  final ARManager _arManager = ARManager();
  final ARIntegrationService _arIntegrationService = ARIntegrationService();
  final ARMarkerService _arMarkerService = ARMarkerService();

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
    {
      'id': 'scan',
      'name': 'Scan',
      'icon': Icons.qr_code_scanner,
      'description': 'Discover AR artworks'
    },
    {
      'id': 'place',
      'name': 'Place',
      'icon': Icons.add_location,
      'description': 'Position new artwork'
    },
    {
      'id': 'view',
      'name': 'View',
      'icon': Icons.visibility,
      'description': 'View placed artworks'
    },
    {
      'id': 'create',
      'name': 'Create',
      'icon': Icons.create,
      'description': 'Create AR artwork'
    },
  ];

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: AppAnimationTheme.defaults.long,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final animationTheme = context.animationTheme;
    if (_animationController.duration != animationTheme.long) {
      _animationController.duration = animationTheme.long;
    }

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
      final platformProvider =
          Provider.of<PlatformProvider>(context, listen: false);

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
                onPressed: () {
                  final targetArtworkId = marker.artworkId;
                  if (targetArtworkId != null) {
                    _launchARForMarker(targetArtworkId);
                  }
                },
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
        description:
            'Augmented Reality features require native device capabilities. Download the art.kubus app to view digital artworks in your physical space using your phone\'s camera.',
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
                            'id':
                                artworkData['id'] ?? DateTime.now().toString(),
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
            if (_isLoading) _buildLoadingOverlay(),

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.95),
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
                                  ? themeProvider.accentColor
                                      .withValues(alpha: 0.2)
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
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mode['name'],
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? themeProvider.accentColor
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
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
            const AppLoading(),
            const SizedBox(height: 24),
            Text(
              'Initializing AR...',
              style: GoogleFonts.inter(
                color: themeProvider.accentColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _arManager.isInitialized
                  ? 'AR Ready'
                  : 'Setting up AR environment',
              style: GoogleFonts.inter(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 80,
                  bottom:
                      120), // Top padding for app bar, bottom for mode selector
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
                        final scheme = Theme.of(context).colorScheme;
                        try {
                          // Add model to AR scene
                          await _arManager.addModel(
                            modelPath: artwork['modelURL'] ?? '',
                            position: vector.Vector3(0, 0, -1.5),
                            scale: vector.Vector3.all(1.0),
                            name: artwork['id'],
                          );

                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('AR model loaded successfully'),
                              backgroundColor: scheme.primary,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to load AR model: $e'),
                              backgroundColor: scheme.error,
                            ),
                          );
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
      padding: const EdgeInsets.only(
          top: 80,
          bottom: 140), // Top padding for app bar, bottom for mode selector
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
                    _arModes.firstWhere(
                        (mode) => mode['id'] == _currentMode)['icon'],
                    color: themeProvider.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _arModes.firstWhere(
                        (mode) => mode['id'] == _currentMode)['name'],
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
              icon: Icon(Icons.settings,
                  color: Theme.of(context).colorScheme.onSurface, size: 20),
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
      padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 100,
          top: 24), // Extra bottom padding for mode selector
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

    final buttonTextColor =
        themeProvider.isDarkMode ? Colors.white : Colors.white;

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
        backgroundColor: Theme.of(context).colorScheme.primary,
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
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
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.view_in_ar,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(artwork['title'],
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
                                  content:
                                      Text('Selected: ${artwork['title']}'),
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
    if (_selectedArtwork == null) {
      if (_mockArtworks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Select or create an artwork before placing it.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      _selectedArtwork = _mockArtworks.first;
    }

    final selected = _selectedArtwork!;
    final placedObject = {
      'id': 'placed_${DateTime.now().millisecondsSinceEpoch}',
      'artworkId': selected['id'],
      'title': selected['title'],
      'artist': selected['artist'],
      'model': selected['model'] ?? selected['modelURL'],
      'modelURL': selected['modelURL'],
      'scale': ((selected['scale'] as double?) ?? 1.0) * _modelScale,
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
        const SnackBar(
            content: Text('No artworks placed yet. Try placing some first!')),
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
                        icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
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
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final location = _currentLocation;
    if (location == null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
              'Current location unavailable. Move your device to calibrate AR tracking.'),
          backgroundColor: colorScheme.error,
        ),
      );
      return;
    }

    final artworkProvider = context.read<ArtworkProvider>();
    final institutionProvider = context.read<InstitutionProvider>();
    final daoProvider = context.read<DAOProvider>();

    const allowedSubjectTypes = [MarkerSubjectType.artwork];

    final subjectOptionsByType = <MarkerSubjectType, List<MarkerSubjectOption>>{
      for (final type in allowedSubjectTypes)
        type: buildSubjectOptions(
          type: type,
          artworks: artworkProvider.artworks,
          institutions: institutionProvider.institutions,
          events: institutionProvider.events,
          delegates: daoProvider.delegates,
        ),
    };

    bool subjectSelectionRequired(MarkerSubjectType type) => true;

    MarkerSubjectType selectedSubjectType = MarkerSubjectType.artwork;
    MarkerSubjectOption? selectedSubject =
      subjectSelectionRequired(selectedSubjectType) &&
          (subjectOptionsByType[selectedSubjectType] ?? []).isNotEmpty
        ? subjectOptionsByType[selectedSubjectType]!.first
        : null;

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

    Uint8List? selectedModelBytes;
    String? selectedModelName;
    int? selectedModelSize;
    bool isPickingFile = false;
    bool isSubmitting = false;
    bool isPublic = true;
    double selectedScale = 1.0;
    String? fileError;

    String formatFileSize(int bytes) {
      final kb = bytes / 1024;
      if (kb < 1024) {
        return '${kb.toStringAsFixed(1)} KB';
      }
      final mb = kb / 1024;
      return '${mb.toStringAsFixed(2)} MB';
    }

    Future<void> pickModelFile(StateSetter refresh) async {
      try {
        refresh(() {
          isPickingFile = true;
          fileError = null;
        });
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['glb', 'gltf', 'usdz', 'zip'],
          withData: true,
        );

        if (result == null) {
          refresh(() => isPickingFile = false);
          return;
        }

        final file = result.files.single;
        final fileBytes = file.bytes;
        if (fileBytes == null) {
          refresh(() {
            isPickingFile = false;
            fileError = 'Unable to read file data. Please try another file.';
          });
          return;
        }

        refresh(() {
          selectedModelBytes = fileBytes;
          selectedModelName = file.name;
          selectedModelSize = fileBytes.lengthInBytes;
          isPickingFile = false;
          fileError = null;
        });
      } catch (e) {
        refresh(() {
          isPickingFile = false;
          fileError = 'File selection failed: $e';
        });
      }
    }

    Future<void> submit(StateSetter refresh) async {
      if (!formKey.currentState!.validate()) {
        return;
      }
      if (subjectSelectionRequired(selectedSubjectType) &&
          selectedSubject == null) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Select a subject before creating the marker.'),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }
      if (selectedModelBytes == null || selectedModelName == null) {
        refresh(() => fileError = 'Attach a 3D model before continuing.');
        return;
      }

      refresh(() {
        isSubmitting = true;
        fileError = null;
      });

      final metadata = {
        'createdFrom': 'ar_screen_create_mode',
        'subjectType': selectedSubjectType.name,
        'subjectLabel': selectedSubjectType.label,
          if (selectedSubject != null) ...{
            'subjectId': selectedSubject!.id,
            'subjectTitle': selectedSubject!.title,
            'subjectSubtitle': selectedSubject!.subtitle,
          },
        'visibility': isPublic ? 'public' : 'private',
        'uploadTimestamp': DateTime.now().toIso8601String(),
        if (selectedSubject?.metadata != null)
          ...selectedSubject!.metadata!,
      };

      try {
        final selectedArtwork = findArtworkById(
          artworkProvider.artworks,
          selectedSubject!.id,
        );

        if (selectedArtwork == null) {
          refresh(() => isSubmitting = false);
          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                  'Selected artwork is no longer available. Refresh data and try again.'),
              backgroundColor: colorScheme.error,
            ),
          );
          return;
        }

        final walletAddress = context.read<WalletProvider>().currentWalletAddress;

        final marker = await _arMarkerService.createMarkerForArtwork(
          artwork: selectedArtwork,
          modelData: selectedModelBytes!,
          filename: selectedModelName!,
          scale: selectedScale,
          isPublic: isPublic,
          metadata: metadata,
          tags: [selectedSubjectType.label],
          createdBy: walletAddress ?? selectedArtwork.artist,
          activationRadiusMeters: 50,
          rotation: const {'x': 0, 'y': 0, 'z': 0},
        );

        if (marker == null) {
          refresh(() => isSubmitting = false);
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Upload failed. Please try again.'),
              backgroundColor: colorScheme.error,
            ),
          );
          return;
        }

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop();

        final resolvedUrl = marker.getContentURL() ?? marker.modelURL;

        setState(() {
          final artistName = selectedSubject?.metadata?['artist']?.toString() ??
              selectedSubject?.title ??
              'Unknown Artist';
          final newArtwork = {
            'id': marker.id,
            'title': marker.name,
            'artist': artistName,
            'description': marker.description,
            'model': resolvedUrl ?? 'uploaded_model',
            'modelURL': resolvedUrl,
            'scale': marker.scale,
            'timestamp': DateTime.now().toIso8601String(),
          };
          _selectedArtwork = newArtwork;
          _placedObjects.add(newArtwork);
          _currentMode = 'place';
        });

        messenger.showSnackBar(
          SnackBar(
            content: const Text(
                'AR asset uploaded and marker created. Switching to Place mode.'),
            backgroundColor: colorScheme.primary,
          ),
        );
      } catch (e) {
        refresh(() => isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to create AR marker: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final viewInsets = MediaQuery.of(context).viewInsets.bottom;
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + viewInsets,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.create,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Upload AR Asset',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Link an existing artwork, upload a 3D model (GLB/GLTF/USDZ), and we will enrich its AR marker.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<MarkerSubjectType>(
                        initialValue: selectedSubjectType,
                        decoration: InputDecoration(
                          labelText: 'Subject Type',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: allowedSubjectTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text('${type.label} (required)'),
                              ),
                            )
                            .toList(),
                        onChanged: null,
                      ),
                      const SizedBox(height: 16),
                      if ((subjectOptionsByType[selectedSubjectType] ?? [])
                          .isNotEmpty)
                        DropdownButtonFormField<MarkerSubjectOption>(
                          initialValue: selectedSubject,
                          decoration: InputDecoration(
                            labelText: '${selectedSubjectType.label} *',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items:
                              (subjectOptionsByType[selectedSubjectType] ?? [])
                                  .map(
                                    (option) => DropdownMenuItem(
                                      value: option,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(option.title,
                                              style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600)),
                                          if (option.subtitle.isNotEmpty)
                                            Text(
                                              option.subtitle,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setModalState(() {
                                    selectedSubject = value;
                                    titleController.text = value.title;
                                    descriptionController.text =
                                        value.subtitle.isNotEmpty
                                            ? value.subtitle
                                            : 'Marker for ${value.title}';
                                  });
                                },
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'No ${selectedSubjectType.label.toLowerCase()}s available. Use the respective module to create one first.',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: titleController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Marker Title *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
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
                        enabled: !isSubmitting,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required';
                          }
                          if (value.trim().length < 10) {
                            return 'Describe the experience in at least 10 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: categoryController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Attach 3D Asset',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () => pickModelFile(setModalState),
                        icon: isPickingFile
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(selectedModelName == null
                            ? 'Select GLB / GLTF / USDZ'
                            : 'Replace Model'),
                      ),
                      if (selectedModelName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedModelName!,
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (selectedModelSize != null)
                                      Text(
                                        formatFileSize(selectedModelSize!),
                                        style: GoogleFonts.inter(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => setModalState(() {
                                          selectedModelBytes = null;
                                          selectedModelName = null;
                                          selectedModelSize = null;
                                        }),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (fileError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          fileError!,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Model Scale: ${(selectedScale * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Slider(
                        value: selectedScale,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label: '${(selectedScale * 100).toStringAsFixed(0)}%',
                        onChanged: isSubmitting
                            ? null
                            : (value) => setModalState(() {
                                  selectedScale = value;
                                }),
                      ),
                      SwitchListTile(
                        title: const Text('Public Marker'),
                        subtitle: const Text('Visible to nearby explorers'),
                        value: isPublic,
                        onChanged: isSubmitting
                            ? null
                            : (value) => setModalState(() => isPublic = value),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.my_location,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              isSubmitting ? null : () => submit(setModalState),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: isSubmitting
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.upload),
                          label: Text(
                            isSubmitting
                                ? 'Uploading...'
                                : 'Upload & Create Marker',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
      categoryController.dispose();
    });
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Model', artwork['model']),
                _buildDetailRow(
                    'Scale', '${(artwork['scale'] * 100).toStringAsFixed(0)}%'),
                _buildDetailRow(
                    'Placed', _formatTimestamp(artwork['timestamp'])),
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
                      activeColor: Theme.of(context).colorScheme.error,
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
                      activeColor: Theme.of(context).colorScheme.primary,
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
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
    final animationTheme = context.animationTheme;
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
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
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
              duration: animationTheme.short,
              curve: animationTheme.emphasisCurve,
              child: Icon(
                icon,
                color: isActive
                    ? color
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                size: 18,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: animationTheme.short,
              curve: animationTheme.defaultCurve,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? color
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
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
      await SharePlus.instance.share(ShareParams(text: shareText));

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
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text('Artwork shared successfully!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
    final walletAddress = Provider.of<WalletProvider>(context, listen: false)
        .currentWalletAddress;

    final isNowLiked = _likedArtworks.contains(artwork['id']);
    if (isNowLiked) {
      UserActionLogger.logArtworkLike(
        artworkId: artwork['id'].toString(),
        artworkTitle: artwork['title']?.toString() ?? 'Artwork',
        artistName: artwork['artist']?.toString(),
      );
    }

    // Track like in community interactions
    final post = CommunityPost(
      id: artwork['id'],
      authorId: artwork['artworkId'] ?? artwork['id'],
      authorName: artwork['artist'],
      content: artwork['title'],
      timestamp: DateTime.parse(artwork['timestamp']),
      isLiked: _likedArtworks.contains(artwork['id']),
    );

    await CommunityService.togglePostLike(
      post,
      currentUserWallet: walletAddress,
      trackUserAction: true,
    );

    if (mounted) {
      final scheme = Theme.of(context).colorScheme;
      final isLiked = _likedArtworks.contains(artwork['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? scheme.onPrimary : scheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(isLiked ? 'Added to your likes!' : 'Removed from likes'),
            ],
          ),
          backgroundColor: isLiked
              ? scheme.primary
              : scheme.surfaceContainerHighest,
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
    final savedItemsProvider =
        Provider.of<SavedItemsProvider>(context, listen: false);
    await savedItemsProvider.toggleArtworkSaved(artwork['id']);

    final isNowSaved = _savedArtworks.contains(artwork['id']);
    if (isNowSaved) {
      UserActionLogger.logArtworkSave(
        artworkId: artwork['id'].toString(),
        artworkTitle: artwork['title']?.toString() ?? 'Artwork',
        artistName: artwork['artist']?.toString(),
      );
    }

    // Track save/bookmark in community interactions
    // Track in profile for "Saved Items" section
    if (_savedArtworks.contains(artwork['id'])) {
      debugPrint('Artwork saved to profile: ${artwork['id']}');
    }

    if (mounted) {
      final scheme = Theme.of(context).colorScheme;
      final isSaved = _savedArtworks.contains(artwork['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: isSaved ? scheme.onPrimary : scheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(isSaved ? 'Saved to your collection!' : 'Removed from saved items'),
            ],
          ),
          backgroundColor: isSaved
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: _savedArtworks.contains(artwork['id'])
              ? SnackBarAction(
                  label: 'View',
                  textColor: scheme.onPrimary,
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
                    leading: Icon(Icons.flash_on,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text('Flash Control',
                        style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(
                        _flashEnabled ? 'Currently ON' : 'Currently OFF',
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
                                const SnackBar(
                                    content: Text(
                                        'Flash not available on this device')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.qr_code_scanner,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text('Scanner Overlay',
                        style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text('Show/hide scanner guide',
                        style: GoogleFonts.inter(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Scanner overlay resets automatically after 3 seconds')),
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
