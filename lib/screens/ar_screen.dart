import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import '../providers/platform_provider.dart';

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isScanning = false;
  bool _artworkDetected = false;
  
  final List<String> _arModes = ['Scan', 'Create', 'View', 'Collection'];
  int _selectedMode = 0;

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
    
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only initialize camera on platforms that support AR
    final platformProvider = Provider.of<PlatformProvider>(context, listen: false);
    if (platformProvider.supportsARFeatures && !_isCameraInitialized) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: platformProvider.supportsARFeatures
                    ? Stack(
                        children: [
                          _buildCameraView(),
                          _buildOverlay(),
                          _buildTopBar(),
                          _buildBottomControls(),
                          if (_artworkDetected) _buildArtworkInfo(),
                        ],
                      )
                    : _buildUnsupportedPlatform(platformProvider),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCameraView() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildOverlay() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Positioned.fill(
      child: CustomPaint(
        painter: AROverlayPainter(
          accentColor: themeProvider.accentColor,
          isScanning: _isScanning,
          artworkDetected: _artworkDetected,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 24,
      right: 24,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: themeProvider.accentColor.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.view_in_ar,
                  color: themeProvider.accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'AR Mode',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              // TODO: Toggle flash
            },
            icon: const Icon(
              Icons.flash_off,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 24,
      right: 24,
      child: Column(
        children: [
          _buildModeSelector(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                Icons.photo_library,
                'Gallery',
                () {
                  // TODO: Open gallery
                },
              ),
              _buildMainActionButton(),
              _buildActionButton(
                Icons.settings,
                'Settings',
                () {
                  // TODO: Open AR settings
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: themeProvider.accentColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _arModes.asMap().entries.map((entry) {
          final index = entry.key;
          final mode = entry.value;
          final isSelected = _selectedMode == index;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedMode = index;
                _isScanning = index == 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? themeProvider.accentColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                mode,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected 
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainActionButton() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedMode == 0) { // Scan mode
            _isScanning = !_isScanning;
            if (_isScanning) {
              _simulateArtworkDetection();
            }
          } else if (_selectedMode == 1) { // Create mode
            // TODO: Start AR creation
          } else if (_selectedMode == 2) { // View mode
            // TODO: View AR artworks
          } else if (_selectedMode == 3) { // Collection mode
            // TODO: View collection
          }
        });
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeProvider.accentColor,
              themeProvider.accentColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: themeProvider.accentColor.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          _getMainActionIcon(),
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  IconData _getMainActionIcon() {
    switch (_selectedMode) {
      case 0: // Scan
        return _isScanning ? Icons.stop : Icons.search;
      case 1: // Create
        return Icons.add;
      case 2: // View
        return Icons.visibility;
      case 3: // Collection
        return Icons.collections;
      default:
        return Icons.search;
    }
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkInfo() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final web3Provider = Provider.of<Web3Provider>(context);
    
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeProvider.accentColor.withOpacity(0.9),
              themeProvider.accentColor.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: themeProvider.accentColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.view_in_ar,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digital Convergence #42',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'by CryptoArtist',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _artworkDetected = false;
                    });
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'An immersive AR experience exploring the fusion of digital and physical reality through interactive geometric forms.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.currency_bitcoin,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '150 KUB8',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '1/1 Edition',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '234',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: View in AR
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: themeProvider.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'View in AR',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: web3Provider.isConnected ? () {
                      // TODO: Purchase NFT
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white),
                      ),
                    ),
                    child: Text(
                      'Purchase',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _simulateArtworkDetection() {
    // Simulate artwork detection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isScanning) {
        setState(() {
          _artworkDetected = true;
          _isScanning = false;
        });
      }
    });
  }

  Widget _buildUnsupportedPlatform(PlatformProvider platformProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              platformProvider.getARIcon(),
              size: 80,
              color: platformProvider.getUnsupportedFeatureColor(context),
            ),
            const SizedBox(height: 24),
            Text(
              'AR Features Not Available',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              platformProvider.getUnsupportedFeatureMessage('AR functionality'),
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              'Available AR features:',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                _buildFeatureItem('📱', 'Scan QR codes to view artwork information'),
                _buildFeatureItem('🎨', 'Browse digital art collections'),
                _buildFeatureItem('💎', 'View NFT metadata and details'),
                _buildFeatureItem('🔗', 'Connect with artists and collectors'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String icon, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.inter(
                color: Colors.grey[300],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AROverlayPainter extends CustomPainter {
  final Color accentColor;
  final bool isScanning;
  final bool artworkDetected;

  AROverlayPainter({
    required this.accentColor,
    required this.isScanning,
    required this.artworkDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scanAreaSize = size.width * 0.6;

    if (isScanning) {
      // Draw scanning frame
      final rect = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: scanAreaSize,
        height: scanAreaSize,
      );

      // Draw corner brackets
      const cornerLength = 30.0;
      final cornerPaint = Paint()
        ..color = accentColor
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Top-left corner
      canvas.drawLine(
        Offset(rect.left, rect.top + cornerLength),
        Offset(rect.left, rect.top),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top),
        Offset(rect.left + cornerLength, rect.top),
        cornerPaint,
      );

      // Top-right corner
      canvas.drawLine(
        Offset(rect.right - cornerLength, rect.top),
        Offset(rect.right, rect.top),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.top + cornerLength),
        cornerPaint,
      );

      // Bottom-left corner
      canvas.drawLine(
        Offset(rect.left, rect.bottom - cornerLength),
        Offset(rect.left, rect.bottom),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.bottom),
        Offset(rect.left + cornerLength, rect.bottom),
        cornerPaint,
      );

      // Bottom-right corner
      canvas.drawLine(
        Offset(rect.right - cornerLength, rect.bottom),
        Offset(rect.right, rect.bottom),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rect.right, rect.bottom),
        Offset(rect.right, rect.bottom - cornerLength),
        cornerPaint,
      );

      // Draw scanning line (animated)
      final scanLinePaint = Paint()
        ..color = accentColor.withOpacity(0.8)
        ..strokeWidth = 2.0;

      canvas.drawLine(
        Offset(rect.left, centerY),
        Offset(rect.right, centerY),
        scanLinePaint,
      );
    }

    if (artworkDetected) {
      // Draw detection outline
      final detectionPaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;

      final detectionRect = Rect.fromCenter(
        center: Offset(centerX, centerY * 0.8),
        width: scanAreaSize * 0.8,
        height: scanAreaSize * 0.6,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(detectionRect, const Radius.circular(12)),
        detectionPaint,
      );

      // Draw detection points
      final pointPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;

      final points = [
        detectionRect.topLeft,
        detectionRect.topRight,
        detectionRect.bottomLeft,
        detectionRect.bottomRight,
        Offset(detectionRect.center.dx, detectionRect.top),
        Offset(detectionRect.center.dx, detectionRect.bottom),
        Offset(detectionRect.left, detectionRect.center.dy),
        Offset(detectionRect.right, detectionRect.center.dy),
      ];

      for (final point in points) {
        canvas.drawCircle(point, 6, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(AROverlayPainter oldDelegate) {
    return oldDelegate.isScanning != isScanning ||
        oldDelegate.artworkDetected != artworkDetected ||
        oldDelegate.accentColor != accentColor;
  }
}
