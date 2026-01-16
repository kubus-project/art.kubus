import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../utils/app_animations.dart';
import '../../widgets/app_loading.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
import 'package:provider/provider.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
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
      'icon': Icons.qr_code_scanner,
    },
    {
      'id': 'place',
      'icon': Icons.add_location,
    },
    {
      'id': 'view',
      'icon': Icons.visibility,
    },
    {
      'id': 'create',
      'icon': Icons.create,
    },
  ];

  String _modeName(AppLocalizations l10n, String modeId) {
    switch (modeId) {
      case 'scan':
        return l10n.arModeScanName;
      case 'place':
        return l10n.arModePlaceName;
      case 'view':
        return l10n.arModeViewName;
      case 'create':
        return l10n.arModeCreateName;
      default:
        return l10n.commonUnknown;
    }
  }

  DateTime _parseArtworkTimestamp(Object? raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        // Fall through.
      }
    }
    return DateTime.now();
  }

  String _modeDescription(AppLocalizations l10n, String modeId) {
    switch (modeId) {
      case 'scan':
        return l10n.arModeScanDescription;
      case 'place':
        return l10n.arModePlaceDescription;
      case 'view':
        return l10n.arModeViewDescription;
      case 'create':
        return l10n.arModeCreateDescription;
      default:
        return '';
    }
  }

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
    if (!mounted) return;
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Initialize AR Manager and Integration Service
      await _arManager.initialize();
      await _arIntegrationService.initialize();
      if (!mounted) return;

      // Set up callbacks for AR events
      _arIntegrationService.onMarkerActivated = (marker) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.arMarkerNearbyToast(marker.name)),
            action: SnackBarAction(
              label: l10n.commonView,
              onPressed: () {
                final targetArtworkId = marker.artworkId;
                if (targetArtworkId != null) {
                  _launchARForMarker(targetArtworkId);
                }
              },
            ),
          ),
        );
      };

      _arIntegrationService.onArtworkDiscovered = (artwork) {
        if (kDebugMode) {
          debugPrint('ARScreen: Artwork discovered: ${artwork.title}');
        }
      };

      // Mock location for testing (replace with actual location service)
      _currentLocation = const LatLng(46.0569, 14.5058); // Ljubljana, Slovenia
      await _arIntegrationService.updateLocation(_currentLocation!);
      if (!mounted) return;

      setState(() {
        _isARReady = true;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ARScreen: AR initialization error: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
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

    if (kDebugMode) {
      debugPrint('ARScreen: Launching AR for artwork: ${artwork['title']}');
    }
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
    final l10n = AppLocalizations.of(context)!;

    // If on web, show download app screen instead
    if (platformProvider.isWeb) {
      return DownloadAppScreen(
        feature: l10n.arWebFallbackFeature,
        description: l10n.arWebFallbackDescription,
      );
    }

    return Scaffold(
      // Keep AR chrome transparent so the root gradient can still paint.
      // (The AR view itself remains opaque and renders its own content.)
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
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
                            'title': artworkData['title'] ?? l10n.commonUnknown,
                            'artist':
                                artworkData['artist'] ?? l10n.commonUnknown,
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
                bottom: 20 + KubusLayout.mainBottomNavBarHeight,
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
                      color: AppColorUtils.cyanAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _arModes.map((mode) {
                      final modeId = mode['id'] as String;
                      final modeIcon = mode['icon'] as IconData;
                      final isSelected = modeId == _currentMode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _changeMode(modeId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColorUtils.cyanAccent
                                      .withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColorUtils.cyanAccent
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  modeIcon,
                                  color: isSelected
                                      ? AppColorUtils.cyanAccent
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _modeName(l10n, modeId),
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? AppColorUtils.cyanAccent
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLoading(),
            const SizedBox(height: 24),
            Text(
              l10n.arInitializingTitle,
              style: GoogleFonts.inter(
                color: AppColorUtils.cyanAccent,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _arManager.isInitialized
                  ? l10n.arReadyStatus
                  : l10n.arSettingUpStatus,
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
    final l10n = AppLocalizations.of(context)!;
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
                    color: AppColorUtils.cyanAccent.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.arNoArtworksYetTitle,
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
                      l10n.arNoArtworksYetDescription,
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
                        color: AppColorUtils.cyanAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.view_in_ar,
                        color: AppColorUtils.cyanAccent,
                      ),
                    ),
                    title: Text(
                      artwork['title'] ?? l10n.commonUnknown,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      artwork['artist'] ?? l10n.commonUnknown,
                      style: GoogleFonts.inter(),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.open_in_new,
                        color: AppColorUtils.cyanAccent,
                      ),
                      onPressed: () async {
                        // Launch AR viewer for this artwork using ARManager
                        final messenger = ScaffoldMessenger.of(context);
                        final scheme = Theme.of(context).colorScheme;
                        final l10n = AppLocalizations.of(context)!;
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
                              content: Text(l10n.arModelLoadedToast),
                              backgroundColor: scheme.primary,
                            ),
                          );
                        } catch (e) {
                          if (kDebugMode) {
                            debugPrint('ARScreen: Failed to load AR model: $e');
                          }
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(l10n.arModelLoadFailedToast),
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
    final l10n = AppLocalizations.of(context)!;
    final mode = _arModes.firstWhere((mode) => mode['id'] == _currentMode);
    final modeId = mode['id'] as String;
    final modeIcon = mode['icon'] as IconData;

    // For place and create modes, show AR camera view
    if (_currentMode == 'place' || _currentMode == 'create') {
      return Stack(
        children: [
          // AR camera view from ARManager
          _arManager.createARView(
            onARViewCreated: (controller) {
              if (kDebugMode) {
                debugPrint('ARScreen: AR View created successfully');
              }
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
                      l10n.arPlacingTitle('${_selectedArtwork!['title']}'),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.arPlacingInstruction,
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
              modeIcon,
              color: AppColorUtils.cyanAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.arModePreviewTitle(_modeName(l10n, modeId)),
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
                _modeDescription(l10n, modeId),
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

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    try {
      // Place model in front of camera
      await _arManager.addModel(
        modelPath: _selectedArtwork!['modelURL'] ?? '',
        position: vector.Vector3(0, 0, -1.5), // 1.5 meters in front
        scale: vector.Vector3.all(1.0),
        name: _selectedArtwork!['id'],
      );

      if (kDebugMode) {
        debugPrint(
            'ARScreen: Placed AR artwork: ${_selectedArtwork!['title']}');
      }

      // Note: Discovery tracking would require converting Map to Artwork object
      // This can be implemented when backend integration is complete
    } catch (e) {
      if (mounted) {
        if (kDebugMode) {
          debugPrint('ARScreen: Error placing artwork: $e');
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.arPlaceArtworkFailedToast),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  }

  Widget _buildTopBar(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = themeProvider.isDarkMode;
    final overlayColor = isDark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.95);

    final currentModeId = _currentMode;
    final currentModeIcon = _arModes.firstWhere(
      (mode) => mode['id'] == currentModeId,
    )['icon'] as IconData;

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
                    currentModeIcon,
                    color: AppColorUtils.cyanAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _modeName(l10n, currentModeId),
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
                    ? AppColorUtils.amberAccent.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                border: _flashEnabled
                    ? Border.all(color: AppColorUtils.amberAccent, width: 1.5)
                    : null,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _flashEnabled ? Icons.flash_on : Icons.flash_off,
                  color: _flashEnabled
                      ? AppColorUtils.amberAccent
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
          bottom: 100 + KubusLayout.mainBottomNavBarHeight,
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
    final l10n = AppLocalizations.of(context)!;
    String buttonText = '';
    IconData buttonIcon = Icons.check;

    switch (_currentMode) {
      case 'scan':
        buttonText = l10n.arActionScan;
        buttonIcon = Icons.qr_code_scanner;
        break;
      case 'place':
        buttonText = l10n.arActionPlace;
        buttonIcon = Icons.add_location;
        break;
      case 'view':
        buttonText = l10n.arActionView;
        buttonIcon = Icons.info_outline;
        break;
      case 'create':
        buttonText = l10n.arActionCreate;
        buttonIcon = Icons.create;
        break;
    }

    const buttonTextColor = Colors.white;

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
        backgroundColor: AppColorUtils.cyanAccent,
        foregroundColor: buttonTextColor,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        shadowColor: AppColorUtils.cyanAccent.withValues(alpha: 0.4),
      ),
    );
  }

  // Event handlers

  void _onObjectPlaced(String objectId) {
    if (kDebugMode) {
      debugPrint('ARScreen: Object placed: $objectId');
    }
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.arArtworkPlacedToast),
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
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.arNearbyArtworksTitle,
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
                        subtitle: Text(
                            l10n.commonByArtist(artwork['artist']?.toString() ??
                                l10n.commonUnknown),
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
                                  content: Text(
                                    l10n.arSelectedArtworkToast(
                                      artwork['title']?.toString() ??
                                          l10n.commonUnknown,
                                    ),
                                  ),
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.arSelectArtworkBeforePlacingToast),
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.arNoPlacedArtworksToast)),
      );
      return;
    }

    // Show list of placed objects
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Container(
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
                  l10n.arPlacedArtworksTitle(_placedObjects.length),
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
                        subtitle: Text(
                          l10n.commonByArtist(
                              obj['artist']?.toString() ?? l10n.commonUnknown),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete,
                              color: Theme.of(context).colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _placedObjects.removeAt(index);
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(l10n.arArtworkRemovedToast)),
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
        );
      },
    );
  }

  void _createArtwork() {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final location = _currentLocation;
    if (location == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.arLocationUnavailableToast),
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
          exhibitions: const [],
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
        return l10n.commonFileSizeKb(kb.toStringAsFixed(1));
      }
      final mb = kb / 1024;
      return l10n.commonFileSizeMb(mb.toStringAsFixed(2));
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
            fileError = l10n.arUnableToReadFileError;
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
        if (kDebugMode) {
          debugPrint('ARScreen: File selection failed: $e');
        }
        refresh(() {
          isPickingFile = false;
          fileError = l10n.arFileSelectionFailedError;
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
            content: Text(l10n.arSelectSubjectBeforeMarkerToast),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }
      if (selectedModelBytes == null || selectedModelName == null) {
        refresh(() => fileError = l10n.arAttach3dModelError);
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
        if (selectedSubject?.metadata != null) ...selectedSubject!.metadata!,
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
              content: Text(l10n.arSelectedArtworkUnavailableToast),
              backgroundColor: colorScheme.error,
            ),
          );
          return;
        }

        final walletAddress =
            context.read<WalletProvider>().currentWalletAddress;

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
              content: Text(l10n.arUploadFailedToast),
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
              l10n.commonUnknown;
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
            content: Text(l10n.arMarkerCreatedSwitchToPlaceToast),
            backgroundColor: colorScheme.primary,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ARScreen: Failed to create AR marker: $e');
        }
        refresh(() => isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.arCreateMarkerFailedToast),
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
          final l10n = AppLocalizations.of(context)!;
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
                              l10n.arCreateUploadTitle,
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
                        l10n.arCreateUploadSubtitle,
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
                          labelText: l10n.arCreateSubjectTypeLabel,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: allowedSubjectTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                    '${type.label} (${l10n.commonRequired})'),
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
                            labelText: l10n.arCreateSubjectLabel(
                                selectedSubjectType.label),
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
                                            : l10n.arCreateDefaultDescription(
                                                value.title);
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
                            l10n.arCreateNoSubjectsAvailable(
                              selectedSubjectType.label.toLowerCase(),
                            ),
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: titleController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: l10n.arCreateMarkerTitleLabel,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.arCreateTitleRequiredError;
                          }
                          if (value.trim().length < 3) {
                            return l10n.arCreateTitleMinLengthError;
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
                          labelText: l10n.arCreateDescriptionLabel,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.arCreateDescriptionRequiredError;
                          }
                          if (value.trim().length < 10) {
                            return l10n.arCreateDescriptionMinLengthError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: categoryController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: l10n.arCreateCategoryLabel,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.arCreateAttach3dAssetTitle,
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
                            ? l10n.arCreateSelectModelButton
                            : l10n.arCreateReplaceModelButton),
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
                        l10n.arModelScaleLabel(
                          (selectedScale * 100).toStringAsFixed(0),
                        ),
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
                        title: Text(l10n.arCreatePublicMarkerTitle),
                        subtitle: Text(l10n.arCreatePublicMarkerSubtitle),
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
                                ? l10n.arCreateUploadingLabel
                                : l10n.arCreateUploadAndCreateButton,
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
        builder: (BuildContext context, StateSetter setModalState) {
          final l10n = AppLocalizations.of(context)!;
          final title = artwork['title']?.toString() ?? l10n.commonUnknown;
          final artist = artwork['artist']?.toString() ?? l10n.commonUnknown;
          final model = artwork['model']?.toString() ?? l10n.commonUnknown;
          final scale = artwork['scale'] is num
              ? (artwork['scale'] as num).toDouble()
              : null;
          final scalePercent = scale == null
              ? l10n.commonUnknown
              : (scale * 100).toStringAsFixed(0);

          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
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
                          title,
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
                    l10n.commonByArtist(artist),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(l10n.arDetailModelLabel, model),
                  _buildDetailRow(l10n.arDetailScaleLabel, '$scalePercent%'),
                  _buildDetailRow(
                    l10n.arDetailPlacedLabel,
                    _formatTimestamp(l10n, artwork['timestamp']),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.commonActions,
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
                        l10n.arShareButtonLabel,
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
                        _likedArtworks.contains(artwork['id'])
                            ? l10n.arLikedButtonLabel
                            : l10n.arLikeButtonLabel,
                        onTap: () {
                          _handleLike(artwork);
                          setModalState(
                              () {}); // Update modal state immediately
                        },
                        isActive: _likedArtworks.contains(artwork['id']),
                        activeColor: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      _buildInteractionButton(
                        _savedArtworks.contains(artwork['id'])
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        _savedArtworks.contains(artwork['id'])
                            ? l10n.arSavedButtonLabel
                            : l10n.arSaveButtonLabel,
                        onTap: () {
                          _handleSave(artwork);
                          setModalState(
                              () {}); // Update modal state immediately
                        },
                        isActive: _savedArtworks.contains(artwork['id']),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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

  String _formatTimestamp(AppLocalizations l10n, Object? timestamp) {
    final dateTime = _parseArtworkTimestamp(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return l10n.commonJustNow;
    if (diff.inMinutes < 60) return l10n.commonMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.commonHoursAgo(diff.inHours);
    return l10n.commonDaysAgo(diff.inDays);
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
    final artworkId = (artwork['artworkId'] ?? artwork['id'])?.toString().trim();
    if (artworkId == null || artworkId.isEmpty) return;

    await ShareService().showShareSheet(
      context,
      target: ShareTarget.artwork(
        artworkId: artworkId,
        title: artwork['title']?.toString(),
      ),
      sourceScreen: 'ar_screen',
    );
  }

  Future<void> _handleLike(Map<String, dynamic> artwork) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

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
        artworkTitle: artwork['title']?.toString() ?? l10n.commonUnknown,
        artistName: artwork['artist']?.toString(),
      );
    }

    // Track like in community interactions
    final post = CommunityPost(
      id: artwork['id'],
      authorId: artwork['artworkId'] ?? artwork['id'],
      authorName: artwork['artist'],
      content: artwork['title'],
      timestamp: _parseArtworkTimestamp(artwork['timestamp']),
      isLiked: _likedArtworks.contains(artwork['id']),
    );

    await CommunityService.togglePostLike(
      post,
      currentUserWallet: walletAddress,
      trackUserAction: true,
    );

    if (!mounted) return;
    final isLiked = _likedArtworks.contains(artwork['id']);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? scheme.onPrimary : scheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              isLiked ? l10n.arLikeAddedToast : l10n.arLikeRemovedToast,
            ),
          ],
        ),
        backgroundColor:
            isLiked ? scheme.primary : scheme.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSave(Map<String, dynamic> artwork) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

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
        artworkTitle: artwork['title']?.toString() ?? l10n.commonUnknown,
        artistName: artwork['artist']?.toString(),
      );
    }

    // Track save/bookmark in community interactions
    // Track in profile for "Saved Items" section
    if (_savedArtworks.contains(artwork['id'])) {
      if (kDebugMode) {
        debugPrint('ARScreen: Artwork saved to profile: ${artwork['id']}');
      }
    }

    if (!mounted) return;
    final isSaved = _savedArtworks.contains(artwork['id']);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? scheme.onPrimary : scheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              isSaved ? l10n.arSaveAddedToast : l10n.arSaveRemovedToast,
            ),
          ],
        ),
        backgroundColor:
            isSaved ? scheme.primary : scheme.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: _savedArtworks.contains(artwork['id'])
            ? SnackBarAction(
                label: l10n.commonView,
                textColor: scheme.onPrimary,
                onPressed: () {
                  final navigator = Navigator.of(context);
                  // Close AR screen first, then present collections using a still-mounted navigator
                  navigator.pop();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final navContext = navigator.context;
                    if (navContext.mounted) {
                      ProfileScreenMethods.showCollections(navContext);
                    }
                  });
                },
              )
            : null,
      ),
    );
  }

  void _showARSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final l10n = AppLocalizations.of(context)!;
          final messenger = ScaffoldMessenger.of(context);

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
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
                          l10n.arSettingsTitle,
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
                      l10n.arScannerSettingsTitle,
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
                      title: Text(l10n.arFlashControlTitle,
                          style: GoogleFonts.inter(fontSize: 14)),
                      subtitle: Text(
                          _flashEnabled
                              ? l10n.commonCurrentlyOn
                              : l10n.commonCurrentlyOff,
                          style: GoogleFonts.inter(fontSize: 12)),
                      trailing: Switch(
                        value: _flashEnabled,
                        onChanged: (value) async {
                          if (_scannerController != null) {
                            try {
                              await _scannerController.toggleTorch();
                              if (!context.mounted || !mounted) return;
                              setModalState(
                                  () => _flashEnabled = !_flashEnabled);
                              setState(() => _flashEnabled = !_flashEnabled);
                            } catch (e) {
                              if (kDebugMode) {
                                debugPrint('ARScreen: Flash toggle failed: $e');
                              }
                              if (!context.mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n.arFlashNotAvailableToast),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.qr_code_scanner,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(l10n.arScannerOverlayTitle,
                          style: GoogleFonts.inter(fontSize: 14)),
                      subtitle: Text(l10n.arScannerOverlaySubtitle,
                          style: GoogleFonts.inter(fontSize: 12)),
                      onTap: () {
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.arScannerOverlayResetToast),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    l10n.arDisplayTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(l10n.arShowFeaturePointsTitle,
                        style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(l10n.arShowFeaturePointsSubtitle,
                        style: GoogleFonts.inter(fontSize: 12)),
                    value: _showFeaturePoints,
                    onChanged: (value) {
                      setModalState(() => _showFeaturePoints = value);
                      setState(() => _showFeaturePoints = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.arShowPlanesTitle,
                        style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(l10n.arShowPlanesSubtitle,
                        style: GoogleFonts.inter(fontSize: 12)),
                    value: _showPlanes,
                    onChanged: (value) {
                      setModalState(() => _showPlanes = value);
                      setState(() => _showPlanes = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.arAutoDetectSurfacesTitle,
                        style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(l10n.arAutoDetectSurfacesSubtitle,
                        style: GoogleFonts.inter(fontSize: 12)),
                    value: _autoDetectSurfaces,
                    onChanged: (value) {
                      setModalState(() => _autoDetectSurfaces = value);
                      setState(() => _autoDetectSurfaces = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.arDebugInfoTitle,
                        style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(l10n.arDebugInfoSubtitle,
                        style: GoogleFonts.inter(fontSize: 12)),
                    value: _showDebugInfo,
                    onChanged: (value) {
                      setModalState(() => _showDebugInfo = value);
                      setState(() => _showDebugInfo = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.arModelScaleLabel(
                      (_modelScale * 100).toStringAsFixed(0),
                    ),
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
                    l10n.commonActions,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep),
                    title: Text(l10n.arClearAllArtworksTitle,
                        style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(l10n.arClearAllArtworksSubtitle,
                        style: GoogleFonts.inter(fontSize: 12)),
                    onTap: () {
                      setState(() => _placedObjects.clear());
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.arAllArtworksClearedToast)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: Text(l10n.arResetSessionTitle,
                        style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(l10n.arResetSessionSubtitle,
                        style: GoogleFonts.inter(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      _initializeAR();
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.arSessionResetToast)),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showARNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.arNotSupportedTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.arNotSupportedMessage,
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
                l10n.commonOk,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showARInitializationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.arInitializationFailedTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.arInitializationFailedMessage,
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
                l10n.commonCancel,
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
                l10n.commonRetry,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
