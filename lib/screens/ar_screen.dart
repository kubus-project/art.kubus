import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import '../providers/platform_provider.dart';
import '../services/ar_service.dart';
import '../widgets/ar_view.dart';
import 'download_app_screen.dart';

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
  late Animation<double> _fadeAnimation;
  
  final ARService _arService = ARService();
  final ARController _arController = ARController();
  
  bool _isARReady = false;
  bool _isLoading = true;
  bool _showControls = true;
  String _currentMode = 'scan'; // scan, place, view
  
  final List<Map<String, dynamic>> _arModes = [
    {'id': 'scan', 'name': 'Scan', 'icon': Icons.qr_code_scanner, 'description': 'Discover AR artworks'},
    {'id': 'place', 'name': 'Place', 'icon': Icons.add_location, 'description': 'Position new artwork'},
    {'id': 'view', 'name': 'View', 'icon': Icons.visibility, 'description': 'View placed artworks'},
    {'id': 'create', 'name': 'Create', 'icon': Icons.create, 'description': 'Create AR artwork'},
  ];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _initializeAR();
  }

  Future<void> _initializeAR() async {
    setState(() => _isLoading = true);

    try {
      final platformProvider = Provider.of<PlatformProvider>(context, listen: false);
      
      if (!platformProvider.supportsARFeatures) {
        _showARNotSupportedDialog();
        return;
      }

      final initialized = await _arService.initialize();
      
      if (initialized) {
        await _arController.startSession();
        setState(() {
          _isARReady = true;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        _showARInitializationErrorDialog();
      }
    } catch (e) {
      debugPrint('AR initialization error: $e');
      _showARInitializationErrorDialog();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _arController.dispose();
    _arService.dispose();
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
            // AR View
            if (_isARReady)
              ARView(
                onARViewCreated: _onARViewCreated,
                onObjectPlaced: _onObjectPlaced,
                onObjectTapped: _onObjectTapped,
                showPlanes: true,
                showFeaturePoints: false,
              ),
            
            // Loading overlay
            if (_isLoading)
              _buildLoadingOverlay(),
            
            // AR Controls overlay
            if (_isARReady && _showControls)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildTopBar(themeProvider),
                    const Spacer(),
                    _buildBottomControls(themeProvider),
                  ],
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
              _arService.platformInfo,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final overlayColor = isDark 
        ? Theme.of(context).colorScheme.surface.withOpacity(0.8)
        : Theme.of(context).colorScheme.surface.withOpacity(0.95);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            overlayColor,
            overlayColor.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          // Back button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          // Mode indicator
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
          const SizedBox(width: 12),
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
        ? Theme.of(context).colorScheme.surface.withOpacity(0.8)
        : Theme.of(context).colorScheme.surface.withOpacity(0.95);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            overlayColor,
            overlayColor.withOpacity(0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AR Mode selector
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _arModes.map((mode) {
                final isSelected = mode['id'] == _currentMode;
                return GestureDetector(
                  onTap: () => _changeMode(mode['id']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? themeProvider.accentColor.withOpacity(0.3)
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
                              ? Theme.of(context).colorScheme.onSurface 
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mode['name'],
                          style: GoogleFonts.inter(
                            color: isSelected 
                                ? Theme.of(context).colorScheme.onSurface 
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Action button based on mode
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
        shadowColor: themeProvider.accentColor.withOpacity(0.4),
      ),
    );
  }

  // Event handlers
  void _onARViewCreated(Map<String, dynamic> info) {
    debugPrint('AR View created: $info');
  }

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

  void _onObjectTapped(String objectId) {
    debugPrint('Object tapped: $objectId');
    _showArtworkDetails(objectId);
  }

  void _changeMode(String modeId) {
    setState(() {
      _currentMode = modeId;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanning for artworks...')),
    );
  }

  void _placeArtwork() {
    // Create a new AR object node
    final node = ARObjectNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      modelPath: 'assets/models/default_artwork.glb',
      position: const Vector3(0, 0, -1.5),
    );
    
    _arController.addNode(node);
    _onObjectPlaced(node.id);
  }

  void _viewArtworkDetails() {
    if (_arController.nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No artworks placed yet')),
      );
      return;
    }
    
    _showArtworkDetails(_arController.nodes.first.id);
  }

  void _createArtwork() {
    // Navigate to artwork creation screen
    Navigator.pushNamed(context, '/create_artwork');
  }

  void _showArtworkDetails(String artworkId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
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
                'AR Artwork Details',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Artwork ID: $artworkId',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              // Add more artwork details here
            ],
          ),
        ),
      ),
    );
  }

  void _showARSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
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
                'AR Settings',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: Text('Show Feature Points'),
                value: false,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: Text('Show Planes'),
                value: true,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: Text('Auto-detect Surfaces'),
                value: true,
                onChanged: (value) {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showARNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AR Not Supported'),
        content: const Text(
          'Your device does not support AR features. AR requires ARCore (Android) or ARKit (iOS).',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showARInitializationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AR Initialization Failed'),
        content: const Text(
          'Could not initialize AR. Please check camera permissions and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeAR();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
